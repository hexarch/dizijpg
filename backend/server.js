// dizi.jpg API — auth, TMDB proxy (önbellekli), izleme/puan/liste/istatistik
import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import pg from 'pg';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import nodemailer from 'nodemailer';
import { AsyncLocalStorage } from 'async_hooks';
import os from 'os';
import geoip from 'geoip-lite';
import admin from 'firebase-admin';
import { disaAktar, iceAktar } from './veri_aktar.js';

// ---------- FCM push (servis hesabı varsa etkin) ----------
const FIREBASE_SA_YOL = process.env.FIREBASE_SA_YOL || '/app/firebase-admin.json';
let fcmHazir = false;
try {
  if (fs.existsSync(FIREBASE_SA_YOL)) {
    admin.initializeApp({
      credential: admin.credential.cert(
        JSON.parse(fs.readFileSync(FIREBASE_SA_YOL, 'utf8')),
      ),
    });
    fcmHazir = true;
    console.log('FCM push etkin');
  } else {
    console.log('FCM push kapalı (servis hesabı dosyası yok)');
  }
} catch (e) {
  console.error('FCM init hatası:', e.message);
}

const {
  DATABASE_URL,
  JWT_SECRET,
  TMDB_TOKEN,
  PORT = 8500,
  // Admin panel erişimi: virgülle ayrılmış IP listesi + isteğe bağlı gizli anahtar.
  ADMIN_IPLER = '',
  ADMIN_TOKEN = '',
} = process.env;

if (!DATABASE_URL || !JWT_SECRET || !TMDB_TOKEN) {
  console.error('Eksik ortam değişkeni (DATABASE_URL / JWT_SECRET / TMDB_TOKEN)');
  process.exit(1);
}

const havuz = new pg.Pool({ connectionString: DATABASE_URL });
const app = express();

// İstek başına TMDB dili: istemci X-Dil başlığıyla uygulama dilini gönderir,
// tmdbGetir bunu okuyup içeriği (başlık/özet/tür) o dilde çeker.
const istekBaglam = new AsyncLocalStorage();
// Uygulama dil kodu → TMDB dil kodu. TMDB çoğu ISO 639-1 kodunu kabul eder;
// bazıları için bölge eklemek daha iyi sonuç verir. Bilinmeyen → 'en'.
const TMDB_DIL = {
  tr: 'tr-TR', en: 'en-US', es: 'es-ES', de: 'de-DE', fr: 'fr-FR',
  it: 'it-IT', pt: 'pt-BR', ru: 'ru-RU', ja: 'ja-JP', ko: 'ko-KR',
  zh: 'zh-CN', ar: 'ar-SA', hi: 'hi-IN', nl: 'nl-NL', pl: 'pl-PL',
  sv: 'sv-SE', da: 'da-DK', fi: 'fi-FI', nb: 'nb-NO', cs: 'cs-CZ',
  el: 'el-GR', hu: 'hu-HU', ro: 'ro-RO', bg: 'bg-BG', uk: 'uk-UA',
  sr: 'sr-RS', he: 'he-IL', fa: 'fa-IR', ur: 'ur-PK', bn: 'bn-BD',
  ta: 'ta-IN', te: 'te-IN', mr: 'mr-IN', gu: 'gu-IN', kn: 'kn-IN',
  ml: 'ml-IN', pa: 'pa-IN', th: 'th-TH', vi: 'vi-VN', id: 'id-ID',
  ms: 'ms-MY', fil: 'tl-PH', sw: 'sw-KE', az: 'az-AZ', am: 'am-ET',
  my: 'my-MM',
};
// nginx arkasındayız: req.ip gerçek istemci IP'sini (X-Forwarded-For) yansıtsın,
// yoksa tüm kullanıcılar hız limitinde tek IP gibi görünür.
app.set('trust proxy', 1);
app.use(express.json({ limit: '1mb' }));

// Avatar ve yorum medyası (compose'ta kalıcı volume'a bağlanır)
const AVATAR_DIZIN = process.env.AVATAR_DIZIN || './avatarlar';
const MEDYA_DIZIN = process.env.MEDYA_DIZIN || './medya';
fs.mkdirSync(AVATAR_DIZIN, { recursive: true });
fs.mkdirSync(MEDYA_DIZIN, { recursive: true });
const statikSecenek = { maxAge: '365d', immutable: true, fallthrough: false };
// DİKKAT: statik sunucu yalnızca GET/HEAD'e bakmalı; aksi halde POST /medya
// (yükleme ucu) 405 ile burada ölür ve route'a hiç ulaşmaz.
const avatarStatik = express.static(AVATAR_DIZIN, statikSecenek);
const medyaStatik = express.static(MEDYA_DIZIN, statikSecenek);
const yalnizGet = (statik) => (req, res, next) =>
  (req.method === 'GET' || req.method === 'HEAD')
    ? statik(req, res, next)
    : next();
app.use('/avatarlar', yalnizGet(avatarStatik));
app.use('/medya', yalnizGet(medyaStatik));

// CORS: web sürümü (dizijpg.com) tarayıcıdan istek atabilsin.
app.use((req, res, next) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Dil');
  res.set('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
  // Yüklenen dosyalar tarayıcıda içerik koklamasıyla çalıştırılamasın.
  res.set('X-Content-Type-Options', 'nosniff');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// İstek dilini bağlama koy: TMDB içeriği kullanıcının dilinde gelsin.
app.use((req, _res, next) => {
  const kod = String(req.headers['x-dil'] || 'tr').toLowerCase();
  const tmdbDil = TMDB_DIL[kod] || 'en-US';
  istekBaglam.run({ tmdbDil }, next);
});

// ---------- gerçek istemci IP (Cloudflare arkasında) ----------
// CF-Connecting-IP gerçek ziyaretçiyi verir; req.ip Cloudflare edge IP'sidir.
function gercekIp(req) {
  return (
    req.headers['cf-connecting-ip'] ||
    (req.headers['x-forwarded-for'] || '').split(',')[0].trim() ||
    req.ip ||
    ''
  ).replace('::ffff:', '');
}

// ---------- istek takibi (admin panel; bellek içi, kalıcı değil) ----------
const ISTEK = {
  son: [], // son N istek (globe + akış)
  toplam: 0,
  ulke: new Map(), // ülke kodu → sayı
  dakika: new Map(), // epoch-dakika → sayı (istek/dk grafiği)
};
const ISTEK_SINIR = 400;
app.use((req, res, next) => {
  if (req.method === 'OPTIONS') return next();
  const bas = Date.now();
  res.on('finish', () => {
    try {
      const ip = gercekIp(req);
      const g = geoip.lookup(ip);
      const dk = Math.floor(Date.now() / 60000);
      ISTEK.toplam++;
      ISTEK.dakika.set(dk, (ISTEK.dakika.get(dk) || 0) + 1);
      for (const k of ISTEK.dakika.keys()) if (k < dk - 120) ISTEK.dakika.delete(k);
      if (g?.country) ISTEK.ulke.set(g.country, (ISTEK.ulke.get(g.country) || 0) + 1);
      ISTEK.son.unshift({
        ip,
        yol: req.path,
        method: req.method,
        kod: res.statusCode,
        sure: Date.now() - bas,
        ts: Date.now(),
        ulke: g?.country || null,
        sehir: g?.city || null,
        ll: g?.ll || null,
        kullanici: req.kullanici?.id || null,
      });
      if (ISTEK.son.length > ISTEK_SINIR) ISTEK.son.length = ISTEK_SINIR;
    } catch { /* takip asla isteği bozmasın */ }
  });
  next();
});

// Sayısal yol parametreleri INT kolonlara bağlanıyor: harf içeren veya taşan
// değer 500 yerine 400 dönsün (1-9 haneli → int4 taşması da engellenir).
const sayiParam = (ad) => app.param(ad, (req, res, next, val) =>
  /^\d{1,9}$/.test(val) ? next() : res.status(400).json({ hata: `Geçersiz ${ad}` }));
sayiParam('tmdbId');
sayiParam('id');
sayiParam('yil');

// ---------- mail (kendi sunucumuz: host üzerindeki Postfix'e SMTP ile) ----------
// API konteynerde çalıştığından host.docker.internal:25 üzerinden gönderir.
const MAIL_FROM = process.env.MAIL_FROM || 'dizi.jpg <noreply@dizijpg.com>';
const MAIL_HOST = process.env.MAIL_HOST || 'host.docker.internal';
const MAIL_PORT = parseInt(process.env.MAIL_PORT || '25', 10);
const mailUlastirici = nodemailer.createTransport({
  host: MAIL_HOST,
  port: MAIL_PORT,
  secure: false,
  ignoreTLS: true, // yerel ağ; Postfix relay
  tls: { rejectUnauthorized: false },
});

// ---------- yardımcılar ----------
const TMDB = 'https://api.themoviedb.org/3';
const ONBELLEK_TTL_SN = { varsayilan: 6 * 3600, uzun: 7 * 24 * 3600 };

async function tmdbGetir(yol, ttlSn = ONBELLEK_TTL_SN.varsayilan) {
  // İçerik dilini isteğin diline göre ayarla: çağrılar 'language=tr-TR' yazsa da
  // gerçek dil buradan gelir. Önbellek anahtarı da dili içerdiğinden dil-başına
  // ayrı önbelleklenir.
  const dil = istekBaglam.getStore()?.tmdbDil || 'tr-TR';
  if (/[?&]language=/.test(yol)) {
    yol = yol.replace(/([?&]language=)[a-zA-Z-]+/, `$1${dil}`);
  } else {
    yol += (yol.includes('?') ? '&' : '?') + 'language=' + dil;
  }
  const anahtar = yol;
  const { rows } = await havuz.query(
    `SELECT veri FROM tmdb_onbellek
     WHERE anahtar = $1 AND guncelleme > now() - ($2 || ' seconds')::interval`,
    [anahtar, ttlSn],
  );
  if (rows.length) return rows[0].veri;

  // Geçici ağ hatalarına ve rate-limit'e (429) karşı yeniden dene.
  let cevap;
  for (let deneme = 0; ; deneme++) {
    try {
      cevap = await fetch(`${TMDB}${yol}`, {
        headers: { Authorization: `Bearer ${TMDB_TOKEN}` },
        signal: AbortSignal.timeout(15000),
      });
      if (cevap.status === 429 && deneme < 4) {
        await new Promise((r) => setTimeout(r, 1500));
        continue; // rate limit → bekle ve tekrar dene
      }
      break;
    } catch (e) {
      if (deneme >= 2) throw Object.assign(new Error('TMDB erişilemedi'), { status: 502 });
      await new Promise((r) => setTimeout(r, 600));
    }
  }
  if (!cevap.ok) {
    const hata = new Error(`TMDB ${cevap.status}`);
    hata.status = cevap.status === 404 ? 404 : 502;
    throw hata;
  }
  const veri = await cevap.json();
  await havuz.query(
    `INSERT INTO tmdb_onbellek (anahtar, veri, guncelleme)
     VALUES ($1, $2, now())
     ON CONFLICT (anahtar) DO UPDATE SET veri = $2, guncelleme = now()`,
    [anahtar, veri],
  );
  return veri;
}

// Geçerli TMDB id: tam sayı, 1..1e9 (int4 taşması → temiz 400).
function gecerliTmdb(x) { return Number.isInteger(x) && x > 0 && x <= 1e9; }

function jwtUret(kullanici) {
  return jwt.sign(
    // sv = şifre sürümü: şifre değişince artar, eski token'lar geçersiz olur.
    { id: kullanici.id, kullanici_adi: kullanici.kullanici_adi,
      sv: kullanici.sifre_surumu ?? 0 },
    JWT_SECRET,
    { expiresIn: '90d' },
  );
}

// Şifre sürümü önbelleği (id → {sv, zaman}): her istekte DB'ye gitmemek için
// 30 sn TTL. Şifre değişince DB'deki sürüm artar; önbellek en geç 30 sn'de
// yenilenir, böylece çalınmış eski token'lar kısa sürede reddedilir.
const sifreSurumOnbellek = new Map();
async function sifreSurumuGecerli(id, tokenSv) {
  const simdi = Date.now();
  let e = sifreSurumOnbellek.get(id);
  if (!e || simdi - e.zaman > 30000) {
    const { rows } = await havuz.query(
      'SELECT sifre_surumu FROM kullanicilar WHERE id=$1', [id]);
    if (!rows.length) return false; // hesap silinmiş
    e = { sv: rows[0].sifre_surumu, zaman: simdi };
    sifreSurumOnbellek.set(id, e);
    if (sifreSurumOnbellek.size > 20000) {
      for (const [k, v] of sifreSurumOnbellek) {
        if (simdi - v.zaman > 60000) sifreSurumOnbellek.delete(k);
      }
    }
  }
  return (tokenSv ?? 0) === e.sv;
}
// Şifre değişince önbelleği hemen düşür (yeni token anında geçerli olsun).
function sifreSurumOnbellekSil(id) { sifreSurumOnbellek.delete(id); }

// Çevrimiçi göstergesi için son_gorulme; her istekte değil, kullanıcı başına
// en fazla 20 sn'de bir DB'ye yazılır (yazma yükünü azaltır).
const sonGorulmeYazildi = new Map();
function sonGorulmeGuncelle(kullaniciId) {
  const simdi = Date.now();
  if (simdi - (sonGorulmeYazildi.get(kullaniciId) || 0) < 20000) return;
  sonGorulmeYazildi.set(kullaniciId, simdi);
  havuz.query('UPDATE kullanicilar SET son_gorulme=now() WHERE id=$1', [kullaniciId])
    .catch(() => {});
  if (sonGorulmeYazildi.size > 10000) {
    const esik = simdi - 60000;
    for (const [k, t] of sonGorulmeYazildi) if (t < esik) sonGorulmeYazildi.delete(k);
  }
}

async function girisZorunlu(req, res, next) {
  const baslik = req.headers.authorization || '';
  const token = baslik.startsWith('Bearer ') ? baslik.slice(7) : null;
  if (!token) return res.status(401).json({ hata: 'Giriş gerekli' });
  let kimlik;
  try {
    kimlik = jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
  } catch {
    return res.status(401).json({ hata: 'Geçersiz oturum' });
  }
  // Şifre değiştiyse (veya hesap silindiyse) eski token reddedilir.
  if (!(await sifreSurumuGecerli(kimlik.id, kimlik.sv))) {
    return res.status(401).json({ hata: 'Oturum sonlandı, tekrar giriş yap' });
  }
  req.kullanici = kimlik;
  sonGorulmeGuncelle(req.kullanici.id);
  next();
}

// Token varsa req.kullanici'yi doldurur; yoksa geçer (herkese açık uçlarda
// "giriş yapan kişi bunu takip ediyor mu / beğendi mi" bilgisi için).
function girisIsteğeBagli(req, _res, next) {
  const baslik = req.headers.authorization || '';
  const token = baslik.startsWith('Bearer ') ? baslik.slice(7) : null;
  if (token) {
    try { req.kullanici = jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] }); } catch { /* anonim */ }
  }
  next();
}

const sarici = (fn) => (req, res) =>
  fn(req, res).catch((e) => {
    console.error(req.path, e.message);
    res.status(e.status || 500).json({ hata: e.status ? e.message : 'Sunucu hatası' });
  });

// Basit bellek içi hız limiti: anahtar başına saatte en fazla `limit` istek.
function hizLimiti(limit, anahtarUret) {
  const sayaclar = new Map();
  return (req, res, next) => {
    const simdi = Date.now();
    const anahtar = anahtarUret(req);
    let kayit = sayaclar.get(anahtar);
    if (!kayit || simdi > kayit.sifirlama) {
      kayit = { sayi: 0, sifirlama: simdi + 3600_000 };
      sayaclar.set(anahtar, kayit);
    }
    if (++kayit.sayi > limit) {
      return res.status(429).json({ hata: 'Çok fazla istek; biraz sonra tekrar dene' });
    }
    // Bellek emniyeti: yalnızca süresi dolan kayıtları at (clear() herkesin limitini sıfırlıyordu)
    if (sayaclar.size > 10000) {
      for (const [k, v] of sayaclar) {
        if (simdi > v.sifirlama) sayaclar.delete(k);
      }
    }
    next();
  };
}
const yuklemeLimiti = hizLimiti(40, (req) => `y:${req.kullanici.id}`);
const authLimiti = hizLimiti(30, (req) => `a:${req.ip}`);
const veriLimiti = hizLimiti(6, (req) => `v:${req.kullanici.id}`);
const tmdbLimiti = hizLimiti(600, (req) => `t:${req.ip}`);
const takvimLimiti = hizLimiti(60, (req) => `k:${req.kullanici.id}`);
const akisLimiti = hizLimiti(240, (req) => `f:${req.kullanici.id}`);
const mesajLimiti = hizLimiti(300, (req) => `m:${req.kullanici.id}`);
// Yorum spam + @etiket bildirim seli koruması
const yorumLimiti = hizLimiti(60, (req) => `c:${req.kullanici.id}`);
// Kimliksiz arama (tam-tarama LIKE) DoS koruması: IP başına
const aramaLimiti = hizLimiti(120, (req) => `s:${req.ip}`);
// İstemci hata bildirimi seli koruması: IP başına
const hataLimiti = hizLimiti(60, (req) => `h:${req.ip}`);

// Bildirim ekler; kendi eylemine bildirim düşmez, hata akışı bozmaz.
// Push bildirim şablonları (alıcının diline göre; {ad} = @kullanıcı).
const PUSH_SABLON = {
  tr: { takip: '{ad} seni takip etmeye başladı', begeni: '{ad} yorumunu beğendi', yanit: '{ad} yorumuna yanıt verdi', mesaj: '{ad} sana mesaj gönderdi', etiket: '{ad} bir yorumda seni etiketledi' },
  en: { takip: '{ad} started following you', begeni: '{ad} liked your comment', yanit: '{ad} replied to your comment', mesaj: '{ad} sent you a message', etiket: '{ad} mentioned you in a comment' },
  es: { takip: '{ad} empezó a seguirte', begeni: '{ad} le gustó tu comentario', yanit: '{ad} respondió a tu comentario', mesaj: '{ad} te envió un mensaje', etiket: '{ad} te mencionó en un comentario' },
  pt: { takip: '{ad} começou a te seguir', begeni: '{ad} curtiu seu comentário', yanit: '{ad} respondeu ao seu comentário', mesaj: '{ad} te enviou uma mensagem', etiket: '{ad} te mencionou em um comentário' },
  de: { takip: '{ad} folgt dir jetzt', begeni: '{ad} gefällt dein Kommentar', yanit: '{ad} hat auf deinen Kommentar geantwortet', mesaj: '{ad} hat dir eine Nachricht geschickt', etiket: '{ad} hat dich in einem Kommentar erwähnt' },
  fr: { takip: '{ad} a commencé à te suivre', begeni: '{ad} a aimé ton commentaire', yanit: '{ad} a répondu à ton commentaire', mesaj: '{ad} t\'a envoyé un message', etiket: '{ad} t\'a mentionné dans un commentaire' },
  it: { takip: '{ad} ha iniziato a seguirti', begeni: '{ad} ha messo mi piace al tuo commento', yanit: '{ad} ha risposto al tuo commento', mesaj: '{ad} ti ha inviato un messaggio', etiket: '{ad} ti ha menzionato in un commento' },
  ru: { takip: '{ad} подписался на тебя', begeni: '{ad} оценил твой комментарий', yanit: '{ad} ответил на твой комментарий', mesaj: '{ad} отправил тебе сообщение', etiket: '{ad} упомянул тебя в комментарии' },
  ar: { takip: '{ad} بدأ بمتابعتك', begeni: '{ad} أعجب بتعليقك', yanit: '{ad} رد على تعليقك', mesaj: '{ad} أرسل لك رسالة', etiket: '{ad} أشار إليك في تعليق' },
  hi: { takip: '{ad} ने आपको फ़ॉलो किया', begeni: '{ad} ने आपके कमेंट को पसंद किया', yanit: '{ad} ने आपके कमेंट का जवाब दिया', mesaj: '{ad} ने आपको मैसेज भेजा', etiket: '{ad} ने एक कमेंट में आपको मेंशन किया' },
  id: { takip: '{ad} mulai mengikutimu', begeni: '{ad} menyukai komentarmu', yanit: '{ad} membalas komentarmu', mesaj: '{ad} mengirimimu pesan', etiket: '{ad} menyebutmu di komentar' },
  ja: { takip: '{ad}さんがあなたをフォローしました', begeni: '{ad}さんがあなたのコメントにいいねしました', yanit: '{ad}さんがあなたのコメントに返信しました', mesaj: '{ad}さんがメッセージを送りました', etiket: '{ad}さんがコメントであなたをメンションしました' },
  ko: { takip: '{ad}님이 회원님을 팔로우했어요', begeni: '{ad}님이 회원님의 댓글을 좋아해요', yanit: '{ad}님이 회원님의 댓글에 답글을 남겼어요', mesaj: '{ad}님이 메시지를 보냈어요', etiket: '{ad}님이 댓글에서 회원님을 언급했어요' },
  zh: { takip: '{ad} 关注了你', begeni: '{ad} 赞了你的评论', yanit: '{ad} 回复了你的评论', mesaj: '{ad} 给你发了消息', etiket: '{ad} 在评论中提到了你' },
  nl: { takip: '{ad} volgt je nu', begeni: '{ad} vindt je reactie leuk', yanit: '{ad} heeft op je reactie gereageerd', mesaj: '{ad} heeft je een bericht gestuurd', etiket: '{ad} heeft je genoemd in een reactie' },
  pl: { takip: '{ad} zaczął cię obserwować', begeni: '{ad} polubił twój komentarz', yanit: '{ad} odpowiedział na twój komentarz', mesaj: '{ad} wysłał ci wiadomość', etiket: '{ad} wspomniał o tobie w komentarzu' },
};

// Alıcının cihazlarına anlık push gönderir (fire-and-forget, hata yutulur).
// ekstra.metin: mesaj bildiriminde gövdede gösterilecek içerik.
async function pushBildirim(aliciId, tur, aktorId, ekstra = null) {
  if (!fcmHazir || !aliciId || aliciId === aktorId) return;
  try {
    const [akt, tok] = await Promise.all([
      havuz.query('SELECT kullanici_adi, avatar FROM kullanicilar WHERE id=$1', [aktorId]),
      havuz.query('SELECT token, dil FROM cihaz_tokenlari WHERE kullanici_id=$1', [aliciId]),
    ]);
    if (!tok.rows.length) return;
    const aktorAdi = akt.rows[0]?.kullanici_adi || '';
    const ad = '@' + aktorAdi;
    const dil = tok.rows[0].dil || 'tr';
    const sablon = PUSH_SABLON[dil] || PUSH_SABLON.en;
    const govde = (sablon[tur] || '').replace('{ad}', ad);
    if (!govde) return;
    const tokens = tok.rows.map((r) => r.token);
    // Derin bağlantı + görsel için ortak veri (FCM data değerleri string olmalı)
    const veri = {
      tur: String(tur),
      ad: aktorAdi,
      avatar: akt.rows[0]?.avatar || '',
    };
    let paket;
    if (tur === 'mesaj') {
      // Veri-mesajı: istemci gönderenin avatarıyla, mesaj İÇERİKLİ yerel
      // bildirim kurar ve dokununca sohbeti açar. notification alanı olsaydı
      // sistem kendisi basar, avatar/derin bağlantı özelleşemezdi.
      paket = {
        tokens,
        data: {
          ...veri,
          baslik: ad,
          metin: String(ekstra?.metin || govde).slice(0, 500),
        },
        android: { priority: 'high' },
      };
    } else {
      paket = {
        tokens,
        notification: { title: 'dizi.jpg', body: govde },
        data: veri,
        android: { priority: 'high', notification: { channelId: 'dizijpg_bildirim' } },
      };
    }
    const yanit = await admin.messaging().sendEachForMulticast(paket);
    const gecersiz = [];
    yanit.responses.forEach((r, i) => {
      const kod = r.error?.code || '';
      if (!r.success && /not-registered|invalid-argument|invalid-registration/.test(kod)) {
        gecersiz.push(tokens[i]);
      }
    });
    if (gecersiz.length) {
      await havuz.query('DELETE FROM cihaz_tokenlari WHERE token = ANY($1)', [gecersiz]);
    }
  } catch (e) {
    console.error('push:', e.message);
  }
}

async function bildirimEkle(aliciId, tur, aktorId, yorumId = null, pushEkstra = null) {
  if (!aliciId || aliciId === aktorId) return;
  await havuz.query(
    'INSERT INTO bildirimler (kullanici_id, tur, aktor_id, yorum_id) VALUES ($1,$2,$3,$4)',
    [aliciId, tur, aktorId, yorumId],
  ).catch(() => {});
  pushBildirim(aliciId, tur, aktorId, pushEkstra); // anlık push (beklemeden)
}

// Metindeki @kullanici_adi etiketlerini bulup 'etiket' bildirimi gönderir.
// Kullanıcı adları küçük harf/rakam/alt çizgi 3-20 karakter (kayıt kuralıyla aynı).
// haricId: bu id'ye ayrı bildirim gidiyorsa (ör. yanıtlanan) çift bildirim engellenir.
async function etiketBildirimleriGonder(metin, aktorId, yorumId, haricId = null) {
  const bulunan = new Set();
  const re = /@([a-z0-9_]{3,20})/g;
  let m;
  while ((m = re.exec(String(metin || '').toLowerCase())) !== null) bulunan.add(m[1]);
  if (bulunan.size === 0) return;
  try {
    const { rows } = await havuz.query(
      `SELECT id FROM kullanicilar
       WHERE lower(kullanici_adi) = ANY($1) AND misafir = false`,
      [[...bulunan]],
    );
    for (const r of rows) {
      if (r.id === aktorId || r.id === haricId) continue;
      bildirimEkle(r.id, 'etiket', aktorId, yorumId);
    }
  } catch { /* etiket bildirimi başarısızsa yorum akışı bozulmaz */ }
}

// ---------- sağlık ----------
app.get('/saglik', sarici(async (_req, res) => {
  await havuz.query('SELECT 1');
  res.json({ durum: 'ok', servis: 'dizi.jpg API' });
}));

// İstemci hata/çökme bildirimi (self-hosted; Firebase gerektirmez).
// Anonim de kabul edilir; varsa kullanıcıyı iliştirir. Alanlar sınırlanır.
app.post('/hata-bildir', hataLimiti, girisIsteğeBagli, sarici(async (req, res) => {
  const g = req.body || {};
  const kirp = (v, n) => (typeof v === 'string' ? v.slice(0, n) : null);
  const mesaj = kirp(g.mesaj, 2000);
  if (!mesaj) return res.status(400).json({ hata: 'mesaj gerekli' });
  await havuz.query(
    `INSERT INTO hatalar (kullanici_id, mesaj, yigin, platform, surum, yol)
     VALUES ($1,$2,$3,$4,$5,$6)`,
    [
      req.kullanici?.id ?? null,
      mesaj,
      kirp(g.yigin, 8000),
      kirp(g.platform, 40),
      kirp(g.surum, 40),
      kirp(g.yol, 200),
    ],
  );
  res.json({ durum: 'alindi' });
}));

// ---------- auth ----------
app.post('/auth/kayit', authLimiti, sarici(async (req, res) => {
  const { email, kullanici_adi, sifre } = req.body || {};
  if (!email?.includes('@') || !kullanici_adi || (sifre || '').length < 6) {
    return res.status(400).json({ hata: 'Geçerli e-posta, kullanıcı adı ve en az 6 karakter şifre gerekli' });
  }
  if (!/^[a-z0-9_]{3,20}$/.test(kullanici_adi)) {
    return res.status(400).json({ hata: 'Kullanıcı adı 3-20 karakter, küçük harf/rakam/alt çizgi olmalı' });
  }
  const hash = await bcrypt.hash(sifre, 10);
  try {
    const { rows } = await havuz.query(
      `INSERT INTO kullanicilar (email, kullanici_adi, sifre_hash)
       VALUES (lower($1), $2, $3)
       RETURNING id, kullanici_adi, email, misafir`,
      [email, kullanici_adi, hash],
    );
    res.json({ token: jwtUret(rows[0]), kullanici: rows[0] });
  } catch (e) {
    if (e.code === '23505') {
      return res.status(409).json({ hata: 'Bu e-posta veya kullanıcı adı zaten kayıtlı' });
    }
    throw e;
  }
}));

// Misafir girişi: hesap anında oluşur, veri toplamaya hemen başlanır.
// Kullanıcı isterse sonradan /auth/bagla ile e-postaya bağlar.
app.post('/auth/misafir', authLimiti, sarici(async (_req, res) => {
  for (let deneme = 0; deneme < 5; deneme++) {
    const ad = 'misafir_' + crypto.randomBytes(4).toString('hex');
    try {
      const { rows } = await havuz.query(
        `INSERT INTO kullanicilar (email, kullanici_adi, sifre_hash, misafir)
         VALUES (NULL, $1, NULL, true)
         RETURNING id, kullanici_adi, email, misafir`,
        [ad],
      );
      return res.json({ token: jwtUret(rows[0]), kullanici: rows[0] });
    } catch (e) {
      if (e.code !== '23505') throw e; // ad çakıştıysa yeniden dene
    }
  }
  res.status(500).json({ hata: 'Misafir hesabı oluşturulamadı' });
}));

// Misafir hesabını e-postaya bağlar (veriler korunur).
app.post('/auth/bagla', girisZorunlu, sarici(async (req, res) => {
  const { email, sifre, kullanici_adi } = req.body || {};
  if (!email?.includes('@') || (sifre || '').length < 6) {
    return res.status(400).json({ hata: 'Geçerli e-posta ve en az 6 karakter şifre gerekli' });
  }
  if (kullanici_adi && !/^[a-z0-9_]{3,20}$/.test(kullanici_adi)) {
    return res.status(400).json({ hata: 'Kullanıcı adı 3-20 karakter, küçük harf/rakam/alt çizgi olmalı' });
  }
  const mevcut = await havuz.query(
    'SELECT misafir FROM kullanicilar WHERE id=$1', [req.kullanici.id]);
  if (!mevcut.rows.length || !mevcut.rows[0].misafir) {
    return res.status(400).json({ hata: 'Bu hesap zaten bağlı' });
  }
  const hash = await bcrypt.hash(sifre, 10);
  try {
    const { rows } = await havuz.query(
      `UPDATE kullanicilar
       SET email = lower($1), sifre_hash = $2, misafir = false,
           kullanici_adi = COALESCE($3, kullanici_adi)
       WHERE id = $4
       RETURNING id, kullanici_adi, email, misafir`,
      [email, hash, kullanici_adi || null, req.kullanici.id],
    );
    res.json({ token: jwtUret(rows[0]), kullanici: rows[0] });
  } catch (e) {
    if (e.code === '23505') {
      return res.status(409).json({ hata: 'Bu e-posta veya kullanıcı adı zaten kayıtlı' });
    }
    throw e;
  }
}));

app.post('/auth/giris', authLimiti, sarici(async (req, res) => {
  const { email, sifre } = req.body || {};
  const { rows } = await havuz.query(
    'SELECT * FROM kullanicilar WHERE email = lower($1) OR kullanici_adi = $1',
    [email || ''],
  );
  if (!rows.length || !rows[0].sifre_hash ||
      !(await bcrypt.compare(sifre || '', rows[0].sifre_hash))) {
    return res.status(401).json({ hata: 'E-posta/kullanıcı adı veya şifre hatalı' });
  }
  if (rows[0].yasakli) {
    return res.status(403).json({ hata: 'Hesabın askıya alındı' });
  }
  const { id, kullanici_adi, email: eposta, misafir } = rows[0];
  res.json({
    token: jwtUret(rows[0]),
    kullanici: { id, kullanici_adi, email: eposta, misafir },
  });
}));

// ---------- TMDB proxy (beyaz listeli) ----------
const TMDB_IZINLI = [
  /^\/trending\/(tv|movie|all)\/(day|week)$/,
  /^\/search\/(tv|movie|multi|person)$/,
  /^\/discover\/(tv|movie)$/,
  /^\/(tv|movie)\/\d+$/,
  /^\/tv\/\d+\/season\/\d+$/,
  /^\/tv\/\d+\/season\/\d+\/episode\/\d+$/,
  /^\/(tv|movie)\/\d+\/(credits|videos|recommendations|similar|watch\/providers)$/,
  /^\/person\/\d+$/,
  /^\/person\/\d+\/combined_credits$/,
  /^\/genre\/(tv|movie)\/list$/,
  /^\/find\/\d+$/, // TheTVDB→TMDB eşlemesi (veri içe aktarımı)
];

// TheTVDB dizi id'sinden TMDB tv id'si bul (veri içe aktarımı için, önbellekli).
async function tvdbdenTmdb(tvdbId) {
  if (!/^\d+$/.test(String(tvdbId))) return null;
  const veri = await tmdbGetir(
    `/find/${tvdbId}?external_source=tvdb_id&language=tr-TR`, ONBELLEK_TTL_SN.uzun);
  return veri?.tv_results?.[0]?.id || null;
}

// TMDB arama sonuçlarından EN İYİ eşleşme: önce ada birebir (normalize) uyanlar,
// aralarında en çok oy alan (klasik/yerleşik yapım yeni aynı-adlıya tercih edilir —
// ör. One Piece animesi, One Piece canlı-aksiyonuna). Yanlış içe aktarımı azaltır.
function enIyiEslesme(sonuclar, sorgu) {
  if (!Array.isArray(sonuclar) || !sonuclar.length) return null;
  const norm = (s) => String(s || '').toLowerCase().replace(/[^a-z0-9]/g, '');
  const hedef = norm(String(sorgu).replace(/\s*\(\d{4}\)\s*$/, ''));
  const alanlar = (r) => [r.name, r.original_name, r.title, r.original_title];
  const tam = sonuclar.filter((r) => alanlar(r).some((a) => norm(a) === hedef));
  const havuz = tam.length ? tam : sonuclar;
  return havuz
    .slice()
    .sort((a, b) => (b.vote_count || 0) - (a.vote_count || 0))[0];
}

// Dizi adından TMDB tv id'si (isimle arama; içe aktarım yedeği, önbellekli).
async function isimdenTmdbTv(isim) {
  const q = encodeURIComponent(String(isim).slice(0, 100));
  const veri = await tmdbGetir(
    `/search/tv?query=${q}&language=tr-TR`, ONBELLEK_TTL_SN.uzun);
  return enIyiEslesme(veri?.results, isim)?.id || null;
}

// TMDB dizi toplam bölüm sayısı (bitirme tespiti için, önbellekli).
async function tmdbBolumSayisi(tmdbId) {
  const veri = await tmdbGetir(`/tv/${tmdbId}?language=tr-TR`, ONBELLEK_TTL_SN.uzun);
  return veri?.number_of_episodes || null;
}

// Film adından TMDB film id'si (izlenen filmleri eşlemek için, önbellekli).
async function isimdenTmdbFilm(isim) {
  const q = encodeURIComponent(String(isim).slice(0, 100));
  const veri = await tmdbGetir(
    `/search/movie?query=${q}&language=tr-TR`, ONBELLEK_TTL_SN.uzun);
  return enIyiEslesme(veri?.results, isim)?.id || null;
}

app.get('/tmdb/*', tmdbLimiti, sarici(async (req, res) => {
  const yol = req.path.replace(/^\/tmdb/, '');
  if (!TMDB_IZINLI.some((r) => r.test(yol))) {
    return res.status(403).json({ hata: 'Bu TMDB yoluna izin yok' });
  }
  const parametreler = new URLSearchParams(req.query);
  if (!parametreler.has('language')) parametreler.set('language', 'tr-TR');
  // Detay sayfalarına ek verileri tek istekte iliştir.
  if (/^\/(tv|movie)\/\d+$/.test(yol) && !parametreler.has('append_to_response')) {
    parametreler.set('append_to_response', 'credits,videos,recommendations,external_ids,watch/providers');
  }
  const tam = `${yol}?${parametreler.toString()}`;
  const uzunTtl = /^\/(tv|movie|person)\//.test(yol);
  res.json(await tmdbGetir(tam, uzunTtl ? ONBELLEK_TTL_SN.uzun : ONBELLEK_TTL_SN.varsayilan));
}));

// ---------- izleme ----------
// Bir dizinin YAYINLANMIŞ bölümleri: [sezon, bolum] çiftleri.
// Özel sezonlar (0) hariç; last_episode_to_air'den sonrası sayılmaz.
async function yayinlanmisBolumler(tmdbId) {
  const dizi = await tmdbGetir(`/tv/${tmdbId}?language=tr-TR`, ONBELLEK_TTL_SN.uzun);
  const son = dizi.last_episode_to_air;
  const ciftler = [];
  for (const s of dizi.seasons || []) {
    const no = s.season_number;
    if (!Number.isInteger(no) || no < 1) continue;
    let adet = s.episode_count || 0;
    if (son && Number.isInteger(son.season_number)) {
      if (no > son.season_number) continue;
      if (no === son.season_number) adet = Math.min(adet, son.episode_number || adet);
    }
    for (let b = 1; b <= Math.min(adet, 500); b++) ciftler.push([no, b]);
  }
  return ciftler;
}

// Dizi durumu otomatiği:
// - En az bir bölüm izlendiyse durumu olmayan / "izleyeceğim" dizi "izliyorum" olur.
// - "bitirdim" YALNIZ dizi gerçekten bittiyse (TMDB status Ended/Canceled) VE
//   tüm bölümler izlendiyse verilir. Devam eden dizide yetişmiş kullanıcı
//   "izliyorum"da kalır; yeni sezon gelen "bitirdim" de "izliyorum"a döner
//   (ör. Silo: bitirilmişti, 3. sezon başladı → tekrar izliyorum).
// - "bıraktım" bilinçli bir seçim: bölüm işaretlemek onu bozmaz.
async function diziDurumunuGuncelle(kullaniciId, tmdbId) {
  try {
    const { rows } = await havuz.query(
      `SELECT count(*)::int AS n FROM izlemeler
       WHERE kullanici_id=$1 AND tur='tv' AND tmdb_id=$2 AND sezon >= 1`,
      [kullaniciId, tmdbId],
    );
    if (rows[0].n > 0) {
      await havuz.query(
        `INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum, guncelleme)
         VALUES ($1,'tv',$2,'izliyorum',now())
         ON CONFLICT (kullanici_id, tur, tmdb_id) DO UPDATE
         SET durum='izliyorum', guncelleme=now()
         WHERE durumlar.durum = 'izleyecegim'`,
        [kullaniciId, tmdbId],
      );
    }
    const dizi = await tmdbGetir(`/tv/${tmdbId}?language=tr-TR`, ONBELLEK_TTL_SN.uzun);
    const bitti = ['Ended', 'Canceled'].includes(dizi.status);
    const toplam = (await yayinlanmisBolumler(tmdbId)).length;
    if (!toplam) return;
    if (rows[0].n >= toplam && bitti) {
      await havuz.query(
        `INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum, guncelleme)
         VALUES ($1,'tv',$2,'bitirdim',now())
         ON CONFLICT (kullanici_id, tur, tmdb_id)
         DO UPDATE SET durum='bitirdim', guncelleme=now()
         WHERE durumlar.durum <> 'bitirdim'`,
        [kullaniciId, tmdbId],
      );
    } else {
      await havuz.query(
        `UPDATE durumlar SET durum='izliyorum', guncelleme=now()
         WHERE kullanici_id=$1 AND tur='tv' AND tmdb_id=$2 AND durum='bitirdim'`,
        [kullaniciId, tmdbId],
      );
    }
  } catch {
    // TMDB'ye ulaşılamazsa durum kendiliğinden değişmez — sorun değil
  }
}

// "Bitirdim" dizilere yeni bölüm geldiyse durumu "izliyorum"a düşür.
// (Ör. Silo: bitirilmişti, yeni sezon başladı → tekrar izliyorum'a döner.)
// 12 saatte bir tarama; TMDB önbelleği sayesinde ucuz, 8'li öbekle.
async function bitenleriTara() {
  try {
    // Yalnız bölüm takibi YAPILAN diziler: hiç bölüm işaretlemeden elle
    // "bitirdim" diyen kullanıcının seçimi taramayla bozulmaz.
    const { rows } = await havuz.query(
      `SELECT d.kullanici_id, d.tmdb_id FROM durumlar d
       WHERE d.tur='tv' AND d.durum='bitirdim'
         AND EXISTS (SELECT 1 FROM izlemeler i
                     WHERE i.kullanici_id=d.kullanici_id AND i.tur='tv'
                       AND i.tmdb_id=d.tmdb_id AND i.sezon>=1)`);
    for (let i = 0; i < rows.length; i += 8) {
      await Promise.all(rows.slice(i, i + 8).map((r) =>
        diziDurumunuGuncelle(r.kullanici_id, r.tmdb_id)));
    }
  } catch {
    // tarama başarısızsa bir sonraki turda tekrar denenir
  }
}
setInterval(bitenleriTara, 12 * 60 * 60 * 1000);
setTimeout(bitenleriTara, 60 * 1000); // açılıştan 1 dk sonra ilk tarama

app.post('/izleme/toggle', girisZorunlu, sarici(async (req, res) => {
  const { tmdb_id, tur, sezon = 0, bolum = 0 } = req.body || {};
  if (!gecerliTmdb(tmdb_id) || !['tv', 'movie'].includes(tur) ||
      !Number.isInteger(sezon) || !Number.isInteger(bolum) ||
      sezon < 0 || bolum < 0) {
    return res.status(400).json({ hata: 'Geçersiz tmdb_id/tur/sezon/bolum' });
  }
  const silindi = await havuz.query(
    `DELETE FROM izlemeler
     WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3 AND sezon=$4 AND bolum=$5`,
    [req.kullanici.id, tur, tmdb_id, sezon, bolum],
  );
  if (silindi.rowCount === 0) {
    await havuz.query(
      `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum)
       VALUES ($1,$2,$3,$4,$5) ON CONFLICT DO NOTHING`,
      [req.kullanici.id, tur, tmdb_id, sezon, bolum],
    );
  }
  // Dizi tamamlandıysa otomatik "bitirdim" (geri alındıysa düşür)
  if (tur === 'tv') await diziDurumunuGuncelle(req.kullanici.id, tmdb_id);
  res.json({ izlendi: silindi.rowCount === 0 });
}));

// Bir sezonun tamamını işaretle/kaldır
app.post('/izleme/sezon', girisZorunlu, sarici(async (req, res) => {
  const { tmdb_id, sezon, bolum_sayisi, isaretle = true } = req.body || {};
  // Tam sayı + pozitif + makul aralık: negatif bolum_sayisi boş INSERT'e yol açıp
  // SQL sözdizimi hatası (500) veriyordu; int4 taşması da engellenir.
  if (!gecerliTmdb(tmdb_id) || tmdb_id < 1 || tmdb_id > 1e9 ||
      !Number.isInteger(sezon) || sezon < 0 || sezon > 1e6 ||
      !Number.isInteger(bolum_sayisi) || bolum_sayisi < 1 || bolum_sayisi > 500) {
    return res.status(400).json({ hata: 'Geçersiz tmdb_id / sezon / bolum_sayisi' });
  }
  if (isaretle) {
    const degerler = [];
    for (let b = 1; b <= Math.min(bolum_sayisi, 500); b++) degerler.push(`($1,'tv',$2,$3,${b})`);
    await havuz.query(
      `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum)
       VALUES ${degerler.join(',')} ON CONFLICT DO NOTHING`,
      [req.kullanici.id, tmdb_id, sezon],
    );
  } else {
    await havuz.query(
      `DELETE FROM izlemeler WHERE kullanici_id=$1 AND tur='tv' AND tmdb_id=$2 AND sezon=$3`,
      [req.kullanici.id, tmdb_id, sezon],
    );
  }
  // Sezon işaretlemesi diziyi tamamlamış olabilir (veya bozmuş)
  await diziDurumunuGuncelle(req.kullanici.id, tmdb_id);
  res.json({ tamam: true });
}));

// Bir içerikteki izleme haritam
app.get('/izleme/:tur/:tmdbId', girisZorunlu, sarici(async (req, res) => {
  const { rows } = await havuz.query(
    `SELECT sezon, bolum FROM izlemeler
     WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3 ORDER BY sezon, bolum`,
    [req.kullanici.id, req.params.tur, req.params.tmdbId],
  );
  res.json({ izlenenler: rows });
}));

// İçeriği tamamen sıfırla: hiç izlenmemiş sayılır, listelerden kalkar.
// (Puan ve yorumlar bilinçli olarak KORUNUR.)
app.post('/icerik/sifirla', girisZorunlu, sarici(async (req, res) => {
  const { tmdb_id, tur } = req.body || {};
  if (!['tv', 'movie'].includes(tur) || !gecerliTmdb(tmdb_id)) {
    return res.status(400).json({ hata: 'Geçersiz tür veya tmdb_id' });
  }
  const p = [req.kullanici.id, tur, tmdb_id];
  await Promise.all([
    havuz.query('DELETE FROM izlemeler WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('DELETE FROM durumlar WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('DELETE FROM favoriler WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('DELETE FROM izleme_kaynaklari WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query(
      `DELETE FROM liste_ogeleri o USING listeler l
       WHERE o.liste_id = l.id AND l.kullanici_id=$1 AND o.tur=$2 AND o.tmdb_id=$3`, p),
  ]);
  res.json({ tamam: true });
}));

// ---------- durum / puan / favori ----------
app.post('/durum', girisZorunlu, sarici(async (req, res) => {
  const { tmdb_id, tur, durum } = req.body || {};
  if (!['tv', 'movie'].includes(tur) || !gecerliTmdb(tmdb_id)) {
    return res.status(400).json({ hata: 'Geçersiz tür veya tmdb_id' });
  }
  if (durum != null && durum !== ''
      && !['izleyecegim', 'izliyorum', 'bitirdim', 'biraktim'].includes(durum)) {
    return res.status(400).json({ hata: 'Geçersiz durum' });
  }
  if (durum === null || durum === '') {
    await havuz.query(
      'DELETE FROM durumlar WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3',
      [req.kullanici.id, tur, tmdb_id],
    );
    return res.json({ durum: null });
  }
  await havuz.query(
    `INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum, guncelleme)
     VALUES ($1,$2,$3,$4,now())
     ON CONFLICT (kullanici_id, tur, tmdb_id) DO UPDATE SET durum=$4, guncelleme=now()`,
    [req.kullanici.id, tur, tmdb_id, durum],
  );
  // "Bitirdim": yayınlanmış her şey izlendi sayılır.
  // Filmde tek kayıt; dizide son yayınlanan bölüme kadar tüm bölümler.
  if (durum === 'bitirdim') {
    if (tur === 'movie') {
      await havuz.query(
        `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum)
         VALUES ($1,'movie',$2,0,0) ON CONFLICT DO NOTHING`,
        [req.kullanici.id, tmdb_id],
      );
    } else {
      try {
        const ciftler = await yayinlanmisBolumler(tmdb_id);
        if (ciftler.length > 0 && ciftler.length <= 10000) {
          await havuz.query(
            `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum)
             SELECT $1, 'tv', $2, s, b FROM unnest($3::int[], $4::int[]) AS t(s, b)
             ON CONFLICT DO NOTHING`,
            [req.kullanici.id, tmdb_id,
              ciftler.map((c) => c[0]), ciftler.map((c) => c[1])],
          );
        }
      } catch {
        // TMDB'ye ulaşılamazsa durum yine de kaydedilmiş olur
      }
    }
  }
  res.json({ durum });
}));

// İçeriği izlemiş kullanıcılar (detaydaki göz ikonu listesi).
// Kullanıcı adları zaten herkese açık olduğundan giriş şartı yok.
app.get('/izleyenler/:tur/:tmdbId', sarici(async (req, res) => {
  const { tur } = req.params;
  const tmdbId = Number(req.params.tmdbId);
  if (!['tv', 'movie'].includes(tur) || !gecerliTmdb(tmdbId)) {
    return res.status(400).json({ hata: 'Geçersiz tür veya tmdb_id' });
  }
  const [sayi, kullanicilar] = await Promise.all([
    havuz.query(
      `SELECT COUNT(DISTINCT i.kullanici_id)::int AS n
       FROM izlemeler i JOIN kullanicilar k ON k.id = i.kullanici_id AND k.misafir = false
       WHERE i.tur=$1 AND i.tmdb_id=$2`,
      [tur, tmdbId],
    ),
    havuz.query(
      `SELECT k.kullanici_adi, k.avatar
       FROM (SELECT kullanici_id, MAX(tarih) AS son FROM izlemeler
             WHERE tur=$1 AND tmdb_id=$2 GROUP BY kullanici_id) i
       JOIN kullanicilar k ON k.id = i.kullanici_id AND k.misafir = false
       ORDER BY i.son DESC NULLS LAST, k.kullanici_adi
       LIMIT 200`,
      [tur, tmdbId],
    ),
  ]);
  res.json({ sayi: sayi.rows[0].n, kullanicilar: kullanicilar.rows });
}));

app.post('/puan', girisZorunlu, sarici(async (req, res) => {
  const { tmdb_id, tur, puan, yorum = null } = req.body || {};
  if (!['tv', 'movie', 'person'].includes(tur) || !gecerliTmdb(tmdb_id)) {
    return res.status(400).json({ hata: 'Geçersiz tür veya tmdb_id' });
  }
  if (puan != null && (!Number.isInteger(puan) || puan < 1 || puan > 10)) {
    return res.status(400).json({ hata: 'Puan 1-10 arası olmalı' });
  }
  if (yorum != null && String(yorum).length > 2000) {
    return res.status(400).json({ hata: 'İnceleme en fazla 2000 karakter olabilir' });
  }
  if (!puan) {
    await havuz.query(
      'DELETE FROM puanlar WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3',
      [req.kullanici.id, tur, tmdb_id],
    );
    return res.json({ silindi: true });
  }
  await havuz.query(
    `INSERT INTO puanlar (kullanici_id, tur, tmdb_id, puan, yorum, tarih)
     VALUES ($1,$2,$3,$4,$5,now())
     ON CONFLICT (kullanici_id, tur, tmdb_id) DO UPDATE SET puan=$4, yorum=$5, tarih=now()`,
    [req.kullanici.id, tur, tmdb_id, puan, yorum],
  );
  res.json({ tamam: true });
}));

// Bir içeriğin herkese açık incelemeleri
app.get('/incelemeler/:tur/:tmdbId', sarici(async (req, res) => {
  const { rows } = await havuz.query(
    `SELECT p.puan, p.yorum, p.tarih, k.kullanici_adi
     FROM puanlar p JOIN kullanicilar k ON k.id = p.kullanici_id
     WHERE p.tur=$1 AND p.tmdb_id=$2 AND p.yorum IS NOT NULL AND p.yorum != ''
     ORDER BY p.tarih DESC LIMIT 50`,
    [req.params.tur, req.params.tmdbId],
  );
  const ort = await havuz.query(
    `SELECT round(avg(puan)::numeric, 1) AS ortalama, count(*) AS adet
     FROM puanlar WHERE tur=$1 AND tmdb_id=$2`,
    [req.params.tur, req.params.tmdbId],
  );
  res.json({ incelemeler: rows, ...ort.rows[0] });
}));

app.post('/favori/toggle', girisZorunlu, sarici(async (req, res) => {
  const { tmdb_id, tur } = req.body || {};
  if (!['tv', 'movie'].includes(tur) || !gecerliTmdb(tmdb_id)) {
    return res.status(400).json({ hata: 'Geçersiz tür veya tmdb_id' });
  }
  const silindi = await havuz.query(
    'DELETE FROM favoriler WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3',
    [req.kullanici.id, tur, tmdb_id],
  );
  if (silindi.rowCount === 0) {
    await havuz.query(
      'INSERT INTO favoriler (kullanici_id, tur, tmdb_id) VALUES ($1,$2,$3)',
      [req.kullanici.id, tur, tmdb_id],
    );
  }
  res.json({ favori: silindi.rowCount === 0 });
}));

// İçerik hakkında kullanıcının tüm durumu (tek istekte)
app.get('/benim/:tur/:tmdbId', girisZorunlu, sarici(async (req, res) => {
  const p = [req.kullanici.id, req.params.tur, req.params.tmdbId];
  const [izleme, durum, puan, favori, kaynak] = await Promise.all([
    havuz.query('SELECT sezon, bolum FROM izlemeler WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('SELECT durum FROM durumlar WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('SELECT puan, yorum FROM puanlar WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('SELECT 1 FROM favoriler WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('SELECT platform FROM izleme_kaynaklari WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
  ]);
  res.json({
    izlenenler: izleme.rows,
    durum: durum.rows[0]?.durum || null,
    puan: puan.rows[0] || null,
    favori: favori.rows.length > 0,
    kaynak: kaynak.rows[0]?.platform || null,
  });
}));

// ---------- emoji tepkileri + nereden izledin ----------
const TEPKI_EMOJILERI = ['😄', '😢', '😮', '🥱', '😭', '😂', '😱', '😍'];

// Hedef doğrulama: tur/tmdb_id zorunlu; sezon+bolum ya ikisi birden ya hiç.
function tepkiHedef(govde) {
  const { tmdb_id, tur } = govde || {};
  let { sezon = null, bolum = null } = govde || {};
  if (!['tv', 'movie'].includes(tur) || !gecerliTmdb(tmdb_id)) return null;
  if ((sezon == null) !== (bolum == null)) return null;
  if (sezon != null && (!Number.isInteger(sezon) || !Number.isInteger(bolum)
      || sezon < 0 || bolum < 0)) return null;
  return { tur, tmdb_id, sezon, bolum };
}

async function tepkiSayilari(hedef, kullaniciId) {
  const p = [hedef.tur, hedef.tmdb_id, hedef.sezon ?? -1, hedef.bolum ?? -1];
  const [toplam, benim] = await Promise.all([
    havuz.query(
      `SELECT emoji, count(*)::int AS sayi FROM tepkiler
       WHERE tur=$1 AND tmdb_id=$2 AND COALESCE(sezon,-1)=$3 AND COALESCE(bolum,-1)=$4
       GROUP BY emoji`, p),
    kullaniciId
      ? havuz.query(
          `SELECT emoji FROM tepkiler
           WHERE tur=$1 AND tmdb_id=$2 AND COALESCE(sezon,-1)=$3 AND COALESCE(bolum,-1)=$4
             AND kullanici_id=$5`, [...p, kullaniciId])
      : { rows: [] },
  ]);
  const sayilar = {};
  for (const r of toplam.rows) sayilar[r.emoji] = r.sayi;
  return { sayilar, benim: benim.rows[0]?.emoji || null };
}

app.get('/tepkiler/:tur/:tmdbId', girisIsteğeBagli, sarici(async (req, res) => {
  const hedef = tepkiHedef({
    tur: req.params.tur,
    tmdb_id: Number(req.params.tmdbId),
    sezon: req.query.sezon != null ? Number(req.query.sezon) : null,
    bolum: req.query.bolum != null ? Number(req.query.bolum) : null,
  });
  if (!hedef) return res.status(400).json({ hata: 'Geçersiz hedef' });
  res.json(await tepkiSayilari(hedef, req.kullanici?.id));
}));

app.post('/tepki', girisZorunlu, sarici(async (req, res) => {
  const hedef = tepkiHedef(req.body);
  if (!hedef) return res.status(400).json({ hata: 'Geçersiz hedef' });
  const { emoji = null } = req.body || {};
  if (emoji != null && !TEPKI_EMOJILERI.includes(emoji)) {
    return res.status(400).json({ hata: 'Geçersiz emoji' });
  }
  if (emoji == null) {
    await havuz.query(
      `DELETE FROM tepkiler WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3
         AND COALESCE(sezon,-1)=$4 AND COALESCE(bolum,-1)=$5`,
      [req.kullanici.id, hedef.tur, hedef.tmdb_id, hedef.sezon ?? -1, hedef.bolum ?? -1],
    );
  } else {
    await havuz.query(
      `INSERT INTO tepkiler (kullanici_id, tur, tmdb_id, sezon, bolum, emoji)
       VALUES ($1,$2,$3,$4,$5,$6)
       ON CONFLICT (kullanici_id, tur, tmdb_id, COALESCE(sezon,-1), COALESCE(bolum,-1))
       DO UPDATE SET emoji=$6, tarih=now()`,
      [req.kullanici.id, hedef.tur, hedef.tmdb_id, hedef.sezon, hedef.bolum, emoji],
    );
  }
  res.json(await tepkiSayilari(hedef, req.kullanici.id));
}));

app.post('/kaynak', girisZorunlu, sarici(async (req, res) => {
  const { tmdb_id, tur, platform = null } = req.body || {};
  if (!['tv', 'movie'].includes(tur) || !gecerliTmdb(tmdb_id)) {
    return res.status(400).json({ hata: 'Geçersiz tür veya tmdb_id' });
  }
  if (platform == null || platform === '') {
    await havuz.query(
      'DELETE FROM izleme_kaynaklari WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3',
      [req.kullanici.id, tur, tmdb_id],
    );
    return res.json({ platform: null });
  }
  const p = String(platform).trim().slice(0, 30);
  if (!p) return res.status(400).json({ hata: 'Geçersiz platform' });
  await havuz.query(
    `INSERT INTO izleme_kaynaklari (kullanici_id, tur, tmdb_id, platform)
     VALUES ($1,$2,$3,$4)
     ON CONFLICT (kullanici_id, tur, tmdb_id) DO UPDATE SET platform=$4, tarih=now()`,
    [req.kullanici.id, tur, tmdb_id, p],
  );
  res.json({ platform: p });
}));

// ---------- listeler ----------
app.get('/listelerim', girisZorunlu, sarici(async (req, res) => {
  const { rows } = await havuz.query(
    `SELECT l.*, count(o.tmdb_id)::int AS oge_sayisi
     FROM listeler l LEFT JOIN liste_ogeleri o ON o.liste_id = l.id
     WHERE l.kullanici_id=$1 GROUP BY l.id ORDER BY l.olusturma DESC`,
    [req.kullanici.id],
  );
  res.json({ listeler: rows });
}));

app.post('/listeler', girisZorunlu, sarici(async (req, res) => {
  const { ad, aciklama = '', herkese_acik = true } = req.body || {};
  if (!ad || String(ad).trim().length === 0) {
    return res.status(400).json({ hata: 'Liste adı gerekli' });
  }
  if (String(ad).length > 60 || String(aciklama).length > 300) {
    return res.status(400).json({ hata: 'Ad en fazla 60, açıklama 300 karakter olabilir' });
  }
  const { rows } = await havuz.query(
    `INSERT INTO listeler (kullanici_id, ad, aciklama, herkese_acik)
     VALUES ($1,$2,$3,$4) RETURNING *`,
    [req.kullanici.id, ad, aciklama, herkese_acik],
  );
  res.json(rows[0]);
}));

app.delete('/listeler/:id', girisZorunlu, sarici(async (req, res) => {
  await havuz.query('DELETE FROM listeler WHERE id=$1 AND kullanici_id=$2',
    [req.params.id, req.kullanici.id]);
  res.json({ tamam: true });
}));

app.post('/listeler/:id/oge', girisZorunlu, sarici(async (req, res) => {
  const { tmdb_id, tur, ekle = true } = req.body || {};
  if (!['tv', 'movie'].includes(tur) || !gecerliTmdb(tmdb_id)) {
    return res.status(400).json({ hata: 'Geçersiz tür veya tmdb_id' });
  }
  const sahip = await havuz.query(
    'SELECT 1 FROM listeler WHERE id=$1 AND kullanici_id=$2',
    [req.params.id, req.kullanici.id],
  );
  if (!sahip.rows.length) return res.status(404).json({ hata: 'Liste bulunamadı' });
  if (ekle) {
    await havuz.query(
      `INSERT INTO liste_ogeleri (liste_id, tmdb_id, tur) VALUES ($1,$2,$3)
       ON CONFLICT DO NOTHING`,
      [req.params.id, tmdb_id, tur],
    );
  } else {
    await havuz.query(
      'DELETE FROM liste_ogeleri WHERE liste_id=$1 AND tmdb_id=$2 AND tur=$3',
      [req.params.id, tmdb_id, tur],
    );
  }
  res.json({ tamam: true });
}));

app.get('/listeler/:id', sarici(async (req, res) => {
  const liste = await havuz.query(
    `SELECT l.*, k.kullanici_adi FROM listeler l
     JOIN kullanicilar k ON k.id = l.kullanici_id WHERE l.id=$1`,
    [req.params.id],
  );
  if (!liste.rows.length) return res.status(404).json({ hata: 'Liste bulunamadı' });
  // Gizli listeyi yalnızca sahibi görebilir.
  if (!liste.rows[0].herkese_acik) {
    const baslik = req.headers.authorization || '';
    const token = baslik.startsWith('Bearer ') ? baslik.slice(7) : null;
    let kimlik = null;
    try { kimlik = token ? jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] }) : null; } catch { /* gizli kalsın */ }
    if (kimlik?.id !== liste.rows[0].kullanici_id) {
      return res.status(404).json({ hata: 'Liste bulunamadı' });
    }
  }
  const ogeler = await havuz.query(
    'SELECT tmdb_id, tur, eklenme FROM liste_ogeleri WHERE liste_id=$1 ORDER BY eklenme DESC',
    [req.params.id],
  );
  res.json({ ...liste.rows[0], ogeler: ogeler.rows });
}));

// ---------- kitaplığım / istatistik / takvim ----------
app.get('/kitapligim', girisZorunlu, sarici(async (req, res) => {
  const { rows } = await havuz.query(
    `SELECT tur, tmdb_id, durum, guncelleme FROM durumlar
     WHERE kullanici_id=$1 ORDER BY guncelleme DESC`,
    [req.kullanici.id],
  );
  const favoriler = await havuz.query(
    'SELECT tur, tmdb_id FROM favoriler WHERE kullanici_id=$1 ORDER BY tarih DESC',
    [req.kullanici.id],
  );
  res.json({ durumlar: rows, favoriler: favoriler.rows });
}));

app.get('/istatistiklerim', girisZorunlu, sarici(async (req, res) => {
  const [bolum, film, dizi, yorum, sosyal, etkilesim] = await Promise.all([
    havuz.query(
      `SELECT count(*)::int AS adet FROM izlemeler WHERE kullanici_id=$1 AND tur='tv'`,
      [req.kullanici.id]),
    havuz.query(
      `SELECT count(*)::int AS adet FROM izlemeler WHERE kullanici_id=$1 AND tur='movie'`,
      [req.kullanici.id]),
    havuz.query(
      `SELECT count(DISTINCT tmdb_id)::int AS adet FROM izlemeler WHERE kullanici_id=$1 AND tur='tv'`,
      [req.kullanici.id]),
    havuz.query(
      `SELECT count(*)::int AS adet FROM yorumlar WHERE kullanici_id=$1`,
      [req.kullanici.id]),
    havuz.query(
      `SELECT
         (SELECT count(*)::int FROM takipler WHERE takip_edilen_id=$1) AS takipci,
         (SELECT count(*)::int FROM takipler WHERE takip_eden_id=$1) AS takip`,
      [req.kullanici.id]),
    // Yorum görüntülenmeleri (foto/video ekli yorumlar dahil — medya
    // görüntülenmesi yorum görüntülenmesiyle aynı sayaçtır) + alınan beğeni.
    havuz.query(
      `SELECT
         (SELECT COALESCE(sum(goruntulenme),0)::int FROM yorumlar
          WHERE kullanici_id=$1) AS goruntulenme,
         (SELECT count(*)::int FROM yorum_begeniler b
          JOIN yorumlar y ON y.id=b.yorum_id
          WHERE y.kullanici_id=$1) AS begeni`,
      [req.kullanici.id]),
  ]);
  res.json({
    izlenen_bolum: bolum.rows[0].adet,
    izlenen_film: film.rows[0].adet,
    takip_edilen_dizi: dizi.rows[0].adet,
    yorum_sayisi: yorum.rows[0].adet,
    takipci_sayisi: sosyal.rows[0].takipci,
    takip_sayisi: sosyal.rows[0].takip,
    toplam_goruntulenme: etkilesim.rows[0].goruntulenme,
    toplam_begeni: etkilesim.rows[0].begeni,
    // Yaklaşık süreler: bölüm ~42 dk, film ~110 dk
    tahmini_dakika: bolum.rows[0].adet * 42 + film.rows[0].adet * 110,
  });
}));

// Otomatik "İzlediklerim" listesi: izlenmiş filmler + en az bir bölümü
// izlenmiş diziler. En son izlenen önce gelir.
app.get('/izlediklerim', girisZorunlu, sarici(async (req, res) => {
  const tur = req.query.tur;
  // Tek tür istendiyse yalnız onu döndür (profildeki Dizi/Film sayacından).
  if (tur === 'tv' || tur === 'movie') {
    const { rows } = await havuz.query(
      `SELECT tur, tmdb_id, count(*)::int AS sayi, max(tarih) AS son
       FROM izlemeler WHERE kullanici_id=$1 AND tur=$2
       GROUP BY tur, tmdb_id ORDER BY son DESC, tmdb_id DESC LIMIT 500`,
      [req.kullanici.id, tur],
    );
    return res.json({
      ogeler: rows.map(({ tur, tmdb_id, sayi }) => ({ tur, tmdb_id, sayi })),
    });
  }
  // Tür belirtilmezse her türden ayrı limit: tek LIMIT 200 bir türü aç bırakıyordu
  // (son 200 film olunca diziler 3'e düşüyordu).
  const { rows } = await havuz.query(
    `(SELECT tur, tmdb_id, count(*)::int AS sayi, max(tarih) AS son
      FROM izlemeler WHERE kullanici_id=$1 AND tur='tv'
      GROUP BY tur, tmdb_id ORDER BY son DESC, tmdb_id DESC LIMIT 200)
     UNION ALL
     (SELECT tur, tmdb_id, count(*)::int AS sayi, max(tarih) AS son
      FROM izlemeler WHERE kullanici_id=$1 AND tur='movie'
      GROUP BY tur, tmdb_id ORDER BY son DESC, tmdb_id DESC LIMIT 200)
     ORDER BY son DESC, tmdb_id DESC`,
    [req.kullanici.id],
  );
  res.json({
    ogeler: rows.map(({ tur, tmdb_id, sayi }) => ({ tur, tmdb_id, sayi })),
  });
}));

// İzlediğim dizilerin yaklaşan bölümleri
// Takvim: izlediğin son bölümden SONRAKİ tüm izlenmemiş bölümler (yetişme)
// + yayın tarihi belli gelecek bölümler. Başlanmamış (izleyeceğim) dizilerde
// arşiv dökülmez, yalnızca gelecek bölümler gelir. Tarihe göre sıralı.
app.get('/takvim', girisZorunlu, takvimLimiti, sarici(async (req, res) => {
  // İki ayrı liste döner:
  //  - takvim: GERÇEK takvim penceresi — son 60 gün + TÜM gelecek tarihli
  //    bölümler, izlenenler de dahil (izlendi bayrağıyla ✓ gösterilir).
  //  - yetisme: yayınlanmış ama İZLENMEMİŞ arşiv (en ileri izlenenden sonrası,
  //    dizi başına 15) — eski "Naruto 2003" yığını takvimi boğmasın diye ayrı.
  //  - yaklasan: eski istemciler için (yetisme + gelecek izlenmemişler).
  const { rows } = await havuz.query(
    `SELECT tmdb_id FROM durumlar
     WHERE kullanici_id=$1 AND tur='tv' AND durum IN ('izliyorum','izleyecegim')
     LIMIT 60`,
    [req.kullanici.id],
  );
  const izl = await havuz.query(
    `SELECT tmdb_id, sezon, bolum FROM izlemeler
     WHERE kullanici_id=$1 AND tur='tv'`,
    [req.kullanici.id],
  );
  const izlenen = new Set(izl.rows.map((r) => `${r.tmdb_id}:${r.sezon}:${r.bolum}`));
  const bugun = new Date().toISOString().slice(0, 10);
  const geri = new Date(Date.now() - 60 * 86400000).toISOString().slice(0, 10);
  const YETISME_SINIR = 15; // tek dizi yetişme listesini boğmasın
  const TAKVIM_SINIR = 40; // tek dizi takvim penceresini boğmasın
  const takvim = [];
  const yetisme = [];
  const diziIsle = async ({ tmdb_id }) => {
    try {
      const dizi = await tmdbGetir(`/tv/${tmdb_id}?language=tr-TR`, ONBELLEK_TTL_SN.varsayilan);
      // İzlenen en ileri bölüm
      let maxS = 0;
      let maxB = 0;
      for (const r of izl.rows) {
        if (r.tmdb_id !== tmdb_id) continue;
        if (r.sezon > maxS || (r.sezon === maxS && r.bolum > maxB)) {
          maxS = r.sezon;
          maxB = r.bolum;
        }
      }
      // Getirilecek sezonlar: yetişme aralığı (en ileri izlenenden +4 sezon) +
      // pencere sezonları (son yayınlanan ve sıradaki bölümün sezonları —
      // izlenen güncel bölümler de takvimde ✓ ile görünsün diye).
      const yetismeSezonlari = (dizi.seasons || [])
        .filter((s) => s.season_number > 0 && s.season_number >= Math.max(maxS, 1))
        .slice(0, 4)
        .map((s) => s.season_number);
      const sezonNolar = new Set(yetismeSezonlari);
      if (dizi.last_episode_to_air?.season_number > 0) {
        sezonNolar.add(dizi.last_episode_to_air.season_number);
      }
      if (dizi.next_episode_to_air?.season_number > 0) {
        sezonNolar.add(dizi.next_episode_to_air.season_number);
      }
      let yetEk = 0;
      let takEk = 0;
      for (const sn of [...sezonNolar].sort((a, b) => a - b)) {
        if (yetEk >= YETISME_SINIR && takEk >= TAKVIM_SINIR) break;
        const sez = await tmdbGetir(
          `/tv/${tmdb_id}/season/${sn}?language=tr-TR`,
          ONBELLEK_TTL_SN.varsayilan,
        );
        for (const b of (sez.episodes || [])) {
          if (!b.air_date) continue; // yayın tarihi belli olmayanlar gelmez
          const bn = b.episode_number;
          const kayit = {
            tmdb_id,
            dizi_adi: dizi.name,
            poster: dizi.poster_path,
            sezon: sn,
            bolum: bn,
            bolum_adi: b.name,
            tarih: b.air_date,
          };
          const izlendiMi = izlenen.has(`${tmdb_id}:${sn}:${bn}`);
          // Takvim penceresi: son 60 gün + tüm gelecek (izlenenler dahil)
          if (b.air_date >= geri && takEk < TAKVIM_SINIR) {
            takvim.push({ ...kayit, izlendi: izlendiMi });
            takEk++;
          }
          // Yetişme: yayınlanmış + izlenmemiş + en ileri izlenenden sonra;
          // başlanmamış (izleyeceğim) dizinin arşivi dökülmez.
          if (
            yetismeSezonlari.includes(sn) && yetEk < YETISME_SINIR &&
            maxS > 0 && b.air_date <= bugun && !izlendiMi &&
            !(sn < maxS || (sn === maxS && bn <= maxB))
          ) {
            yetisme.push(kayit);
            yetEk++;
          }
        }
      }
    } catch { /* tek dizi hatası takvimi bozmasın */ }
  };
  for (let i = 0; i < rows.length; i += 8) {
    await Promise.all(rows.slice(i, i + 8).map(diziIsle));
  }
  takvim.sort((a, b) => a.tarih.localeCompare(b.tarih));
  yetisme.sort((a, b) => a.tarih.localeCompare(b.tarih));
  // Eski istemci uyumu (APK ≤1.8.2): yetişme + gelecekteki izlenmemişler
  const yaklasan = [
    ...yetisme,
    ...takvim.filter((t) => !t.izlendi && t.tarih > bugun),
  ].sort((a, b) => a.tarih.localeCompare(b.tarih));
  res.json({ takvim, yetisme, yaklasan });
}));

// ---------- profilim ----------
// Sosyal bağlantı platform beyaz listesi (app'teki listeyle aynı olmalı)
const SOSYAL_PLATFORMLAR = new Set([
  'instagram', 'facebook', 'x', 'tiktok', 'discord', 'steam', 'xbox',
  'epicgames', 'imdb', 'vk', 'youtube', 'twitch', 'spotify', 'github',
  'reddit', 'telegram', 'snapchat', 'pinterest', 'letterboxd',
]);
// [{platform, deger}] × ≤3 doğrular; bozuksa null döner.
function sosyalDogrula(sosyal) {
  if (!Array.isArray(sosyal) || sosyal.length > 3) return null;
  const temiz = [];
  const gorulen = new Set();
  for (const s of sosyal) {
    const platform = String(s?.platform || '');
    const deger = String(s?.deger || '').trim();
    if (!SOSYAL_PLATFORMLAR.has(platform) || gorulen.has(platform)) return null;
    // Kullanıcı adı/handle: url enjeksiyonunu engelle (boşluk, <>, tırnak yok)
    if (!/^[A-Za-z0-9._@/-]{1,100}$/.test(deger)) return null;
    gorulen.add(platform);
    temiz.push({ platform, deger });
  }
  return temiz;
}

app.get('/profilim', girisZorunlu, sarici(async (req, res) => {
  const { rows } = await havuz.query(
    `SELECT id, kullanici_adi, email, misafir, avatar, kapak, bio, ulke, sosyal
     FROM kullanicilar WHERE id=$1`,
    [req.kullanici.id],
  );
  if (!rows.length) return res.status(404).json({ hata: 'Kullanıcı bulunamadı' });
  res.json(rows[0]);
}));

app.post('/profilim', girisZorunlu, sarici(async (req, res) => {
  const { bio, ulke, sosyal } = req.body || {};
  if (bio != null && (typeof bio !== 'string' || bio.length > 300)) {
    return res.status(400).json({ hata: 'Bio en fazla 300 karakter olabilir' });
  }
  if (ulke != null && (typeof ulke !== 'string' || ulke.length > 60)) {
    return res.status(400).json({ hata: 'Geçersiz ülke' });
  }
  let sosyalTemiz = null;
  if (sosyal !== undefined) {
    sosyalTemiz = sosyalDogrula(sosyal);
    if (sosyalTemiz === null) {
      return res.status(400).json({ hata: 'Geçersiz sosyal bağlantı' });
    }
  }
  // Boş string alanı temizler; gönderilmeyen alan olduğu gibi kalır.
  const { rows } = await havuz.query(
    `UPDATE kullanicilar
     SET bio  = CASE WHEN $1 THEN NULLIF($2, '') ELSE bio  END,
         ulke = CASE WHEN $3 THEN NULLIF($4, '') ELSE ulke END,
         sosyal = CASE WHEN $5 THEN $6::jsonb ELSE sosyal END
     WHERE id=$7
     RETURNING id, kullanici_adi, email, misafir, avatar, bio, ulke, sosyal`,
    [bio !== undefined, bio ?? '', ulke !== undefined, ulke ?? '',
     sosyal !== undefined, JSON.stringify(sosyalTemiz ?? []), req.kullanici.id],
  );
  res.json(rows[0]);
}));

// Avatar yükleme: gövde ham resim verisi (GIF dahil). Tür sihirli baytlardan doğrulanır.
const RESIM_TURLERI = [
  { uzanti: 'gif', kontrol: (b) => b.slice(0, 4).toString('ascii') === 'GIF8' },
  { uzanti: 'png', kontrol: (b) => b[0] === 0x89 && b.slice(1, 4).toString('ascii') === 'PNG' },
  { uzanti: 'jpg', kontrol: (b) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
  {
    uzanti: 'webp',
    kontrol: (b) => b.slice(0, 4).toString('ascii') === 'RIFF' &&
      b.slice(8, 12).toString('ascii') === 'WEBP',
  },
];

// Avatar ve kapak aynı mantıkla yüklenir; yalnızca hedef sütun/ön ek değişir.
function profilResmiUcu(sutun) {
  return [
    girisZorunlu,
    yuklemeLimiti,
    express.raw({ type: ['image/*', 'application/octet-stream'], limit: '10mb' }),
    sarici(async (req, res) => {
      const veri = req.body;
      if (!Buffer.isBuffer(veri) || veri.length < 12) {
        return res.status(400).json({ hata: 'Resim verisi gerekli' });
      }
      const tur = RESIM_TURLERI.find((t) => t.kontrol(veri));
      if (!tur) {
        return res.status(400).json({ hata: 'Yalnızca GIF, PNG, JPEG veya WebP yüklenebilir' });
      }
      const dosya = `${sutun}${req.kullanici.id}-${Date.now()}.${tur.uzanti}`;
      fs.writeFileSync(path.join(AVATAR_DIZIN, dosya), veri);
      const yeniYol = `/avatarlar/${dosya}`;
      const eski = await havuz.query(
        `SELECT ${sutun} FROM kullanicilar WHERE id=$1`, [req.kullanici.id]);
      await havuz.query(
        `UPDATE kullanicilar SET ${sutun}=$1 WHERE id=$2`, [yeniYol, req.kullanici.id]);
      // Eski dosyayı temizle (varsa ve bizim dizindeyse)
      const eskiYol = eski.rows[0]?.[sutun];
      if (eskiYol?.startsWith('/avatarlar/')) {
        fs.unlink(path.join(AVATAR_DIZIN, path.basename(eskiYol)), () => {});
      }
      res.json({ [sutun]: yeniYol });
    }),
  ];
}

app.post('/profilim/avatar', ...profilResmiUcu('avatar'));
app.post('/profilim/kapak', ...profilResmiUcu('kapak'));

// ---------- yorum medyası ----------
const VIDEO_TURLERI = [
  { uzanti: 'mp4', kontrol: (b) => b.slice(4, 8).toString('ascii') === 'ftyp' },
  {
    uzanti: 'webm',
    kontrol: (b) => b[0] === 0x1a && b[1] === 0x45 && b[2] === 0xdf && b[3] === 0xa3,
  },
];
// Sesli mesaj: OggS (opus) net ayırt edilir; m4a yalnız 'M4A' markasıyla (mp4
// video ile karışmasın). VIDEO'dan ÖNCE denenir.
const SES_TURLERI = [
  { uzanti: 'ogg', kontrol: (b) => b.slice(0, 4).toString('ascii') === 'OggS' },
  {
    uzanti: 'm4a',
    kontrol: (b) => b.slice(4, 8).toString('ascii') === 'ftyp'
      && b.slice(8, 11).toString('ascii') === 'M4A',
  },
  {
    uzanti: 'mp3',
    kontrol: (b) => (b[0] === 0x49 && b[1] === 0x44 && b[2] === 0x33)
      || (b[0] === 0xff && (b[1] & 0xe0) === 0xe0),
  },
  { uzanti: 'aac', kontrol: (b) => b[0] === 0xff && (b[1] & 0xf6) === 0xf0 },
];

// Yorum eki yükleme: ham gövde, fotoğraf veya video. Dönen yol yorumda kullanılır.
app.post('/medya',
  girisZorunlu,
  yuklemeLimiti,
  express.raw({ type: ['image/*', 'video/*', 'audio/*', 'application/octet-stream'], limit: '30mb' }),
  sarici(async (req, res) => {
    const veri = req.body;
    if (!Buffer.isBuffer(veri) || veri.length < 12) {
      return res.status(400).json({ hata: 'Dosya verisi gerekli' });
    }
    const tur = [...RESIM_TURLERI, ...SES_TURLERI, ...VIDEO_TURLERI].find((t) => t.kontrol(veri));
    if (!tur) {
      return res.status(400).json({ hata: 'Desteklenen türler: GIF, PNG, JPEG, WebP, MP4, WebM, ses' });
    }
    // Dosya adı yükleyenin kimliğini taşır; yorum eklerken sahiplik bununla doğrulanır.
    const dosya = `m${req.kullanici.id}-${crypto.randomBytes(8).toString('hex')}.${tur.uzanti}`;
    fs.writeFileSync(path.join(MEDYA_DIZIN, dosya), veri);
    res.json({
      yol: `/medya/${dosya}`,
      video: VIDEO_TURLERI.includes(tur),
      ses: SES_TURLERI.includes(tur),
    });
  }));

// ---------- yorumlar ----------
const YORUM_TURLERI = ['tv', 'movie', 'person'];

app.get('/yorumlar/:tur/:tmdbId', girisIsteğeBagli, sarici(async (req, res) => {
  if (!YORUM_TURLERI.includes(req.params.tur)) {
    return res.status(400).json({ hata: 'Geçersiz tür' });
  }
  const sezon = req.query.sezon != null ? parseInt(req.query.sezon, 10) : null;
  const bolum = req.query.bolum != null ? parseInt(req.query.bolum, 10) : null;
  if (Number.isNaN(sezon) || Number.isNaN(bolum)) {
    return res.status(400).json({ hata: 'Geçersiz sezon/bolum' });
  }
  const benId = req.kullanici?.id || 0;
  const { rows } = await havuz.query(
    `SELECT y.id, y.kullanici_id, y.metin, y.medya, y.tarih, y.sezon, y.bolum,
            y.ust_id, y.goruntulenme, k.kullanici_adi, k.avatar,
            (SELECT count(*)::int FROM yorum_begeniler b WHERE b.yorum_id=y.id) AS begeni,
            EXISTS(SELECT 1 FROM yorum_begeniler b
                   WHERE b.yorum_id=y.id AND b.kullanici_id=$5) AS begendim
     FROM yorumlar y JOIN kullanicilar k ON k.id = y.kullanici_id
     WHERE y.tur=$1 AND y.tmdb_id=$2
       AND y.sezon IS NOT DISTINCT FROM $3 AND y.bolum IS NOT DISTINCT FROM $4
     ORDER BY y.tarih DESC LIMIT 100`,
    [req.params.tur, req.params.tmdbId, sezon, bolum, benId],
  );
  // Görüntülenme: kişi başı tek sayılır. Girişliyse kullanıcı kimliği,
  // değilse IP anahtarı kullanılır; yalnızca ilk görüntülemede artar.
  if (rows.length) {
    const izleyen = req.kullanici?.id
      ? `u:${req.kullanici.id}`
      : `ip:${req.headers['x-real-ip'] || req.ip || '?'}`;
    const idler = rows.map((r) => r.id);
    havuz.query(
      `WITH yeni AS (
         INSERT INTO yorum_goruntuleyen (yorum_id, izleyen)
         SELECT id, $2 FROM unnest($1::int[]) AS id
         ON CONFLICT DO NOTHING RETURNING yorum_id
       )
       UPDATE yorumlar SET goruntulenme = goruntulenme + 1
       WHERE id IN (SELECT yorum_id FROM yeni)`,
      [idler, izleyen],
    ).catch(() => {});
  }
  res.json({ yorumlar: rows });
}));

// ---------- sosyal akış ----------
// Ortak SELECT/FROM/filtreler: guvenli = spoiler-emniyetli kitaplık eşleşmesi.
const AKIS_GOVDE = `
     FROM yorumlar y
     JOIN kullanicilar k ON k.id = y.kullanici_id
     CROSS JOIN LATERAL (SELECT (
         (y.tur='movie' AND y.sezon IS NULL AND EXISTS (
            SELECT 1 FROM izlemeler i WHERE i.kullanici_id=$1
              AND i.tur='movie' AND i.tmdb_id=y.tmdb_id))
         OR (y.tur='tv' AND y.sezon IS NOT NULL AND EXISTS (
            SELECT 1 FROM izlemeler i WHERE i.kullanici_id=$1
              AND i.tur='tv' AND i.tmdb_id=y.tmdb_id
              AND i.sezon=y.sezon AND i.bolum=y.bolum))
         OR (y.tur='tv' AND y.sezon IS NULL AND EXISTS (
            SELECT 1 FROM durumlar d WHERE d.kullanici_id=$1
              AND d.tur='tv' AND d.tmdb_id=y.tmdb_id
              AND d.durum IN ('izliyorum','bitirdim')))
       ) AS guvenli) g
     WHERE y.kullanici_id <> $1
       AND NOT k.yasakli
       AND y.kullanici_id NOT IN (
         SELECT engellenen_id FROM engellemeler WHERE engelleyen_id=$1
         UNION SELECT engelleyen_id FROM engellemeler WHERE engellenen_id=$1)
       AND y.ust_id IS NULL`;
const AKIS_ALANLAR = `
     SELECT y.id, y.kullanici_id, y.tur, y.tmdb_id, y.sezon, y.bolum,
            y.metin, y.medya, y.tarih, y.goruntulenme,
            k.kullanici_adi, k.avatar, g.guvenli,
            (SELECT count(*)::int FROM yorum_begeniler b WHERE b.yorum_id=y.id) AS begeni,
            EXISTS(SELECT 1 FROM yorum_begeniler b
                   WHERE b.yorum_id=y.id AND b.kullanici_id=$1) AS begendim`;
// Akış uygunluk kuralı (asla boş kalmaz):
//  - Bölüm yorumları YALNIZ o bölüm izlendiyse (spoiler: tamamen dışarıda).
//  - Film/dizi-geneli yorumlar herkesten; kitaplıkta "guvenli" değilse istemci
//    bulanık gösterir (spoiler bayrağı).
//  - Kişi yorumları: takip edilenlerden VEYA izlenen yapımların kadrosundan.
const AKIS_KURAL = `
       AND (
         g.guvenli
         OR (y.sezon IS NULL AND y.tur <> 'person' AND y.kullanici_id IN (
            SELECT takip_edilen_id FROM takipler WHERE takip_eden_id=$1))
         OR (y.tur='person' AND (
            y.tmdb_id = ANY($3::int[])
            OR y.kullanici_id IN (
              SELECT takip_edilen_id FROM takipler WHERE takip_eden_id=$1)))
         OR (y.sezon IS NULL AND y.tur <> 'person')
       )`;

// Son izlenen 20 yapımın oyuncu/yönetmen TMDB id'leri (önbellekli credits).
async function kadroKisileri(benId) {
  const kadro = new Set();
  try {
    const son = await havuz.query(
      `SELECT tur, tmdb_id, max(tarih) AS son FROM izlemeler
       WHERE kullanici_id=$1 GROUP BY tur, tmdb_id ORDER BY son DESC LIMIT 20`,
      [benId]);
    await Promise.all(son.rows.map(async (r) => {
      try {
        const v = await tmdbGetir(`/${r.tur}/${r.tmdb_id}/credits`, ONBELLEK_TTL_SN.uzun);
        for (const o of (v.cast || []).slice(0, 20)) kadro.add(o.id);
        for (const c of v.crew || []) {
          if (c.job === 'Director' || c.department === 'Directing') kadro.add(c.id);
        }
      } catch { /* kadro alınamazsa o yapım atlanır */ }
    }));
  } catch { /* kadro tamamen boş kalabilir */ }
  return [...kadro];
}

// Satır listesi için içerik adı + poster haritası (kişide profile_path).
async function akisIcerikleri(rows) {
  const anahtarlar = [...new Set(rows.map((r) => `${r.tur}:${r.tmdb_id}`))];
  const icerikler = {};
  await Promise.all(anahtarlar.map(async (a) => {
    const [tur, id] = a.split(':');
    try {
      const v = await tmdbGetir(`/${tur}/${id}?language=tr-TR`, ONBELLEK_TTL_SN.uzun);
      icerikler[a] = {
        ad: v.name || v.title || '?',
        poster: v.poster_path || v.profile_path || null,
      };
    } catch {
      icerikler[a] = { ad: '?', poster: null };
    }
  }));
  return icerikler;
}

const akisSatiri = ({ guvenli, ...r }) => ({
  ...r,
  // İzlemediğin içeriğin yorumu: istemci bulanık gösterir. Kişi yorumları
  // ve kitaplık eşleşmeleri spoiler sayılmaz.
  spoiler: !(guvenli || r.tur === 'person'),
});

app.get('/akis', girisZorunlu, akisLimiti, sarici(async (req, res) => {
  const once = parseInt(req.query.once, 10) || null; // sayfalama: bu id'den eskiler
  const benId = req.kullanici.id;
  const kadro = await kadroKisileri(benId);
  let { rows } = await havuz.query(
    `${AKIS_ALANLAR} ${AKIS_GOVDE}
       AND ($2::int IS NULL OR y.id < $2)
       ${AKIS_KURAL}
     ORDER BY y.id DESC LIMIT 30`,
    [benId, once, kadro],
  );
  let kaynak = 'akis';
  // FALLBACK (yalnız ilk sayfa boşsa): günün en beğenilenleri → ayın en
  // beğenilenleri (görülenler hariç) → SON ÇARE: ayın en beğenilenleri
  // görülmüş olsa da. Bölüm yorumları burada da asla yer almaz.
  if (!rows.length && once === null) {
    const populer = (gun, gorulmusHaric) => havuz.query(
      `${AKIS_ALANLAR} ${AKIS_GOVDE}
         AND y.sezon IS NULL AND y.tur <> 'person'
         AND y.tarih >= now() - make_interval(days => $2)
         ${gorulmusHaric
           ? `AND y.id NOT IN (SELECT yorum_id FROM akis_goruldu WHERE kullanici_id=$1)`
           : ''}
       ORDER BY begeni DESC, y.id DESC LIMIT 30`,
      [benId, gun]);
    for (const [gun, haric] of [[1, true], [30, true], [30, false]]) {
      const p = await populer(gun, haric);
      if (p.rows.length) { rows = p.rows; kaynak = 'populer'; break; }
    }
  }
  // Gösterilenler işaretlenir (popüler fallback rotasyonu için; hata yutulur)
  if (rows.length) {
    havuz.query(
      `INSERT INTO akis_goruldu (kullanici_id, yorum_id)
       SELECT $1, unnest($2::int[]) ON CONFLICT DO NOTHING`,
      [benId, rows.map((r) => r.id)]).catch(() => {});
  }
  res.json({
    kaynak,
    akis: rows.map(akisSatiri),
    icerikler: await akisIcerikleri(rows),
  });
}));

// Keşfet (Reels tarzı): akışla AYNI uygunluk/öncelik; videolu postlar önce,
// sonra diğer medyalılar, sonra yazılı yorumlar. Tek sayfa (60), takip durumu
// dahil — istemci ızgara + tam ekran dikey kaydırma olarak gösterir.
app.get('/kesfet-akis', girisZorunlu, akisLimiti, sarici(async (req, res) => {
  const benId = req.kullanici.id;
  const kadro = await kadroKisileri(benId);
  const { rows } = await havuz.query(
    `${AKIS_ALANLAR},
            EXISTS (SELECT 1 FROM unnest(y.medya) mm
                    WHERE mm LIKE '%.mp4' OR mm LIKE '%.webm') AS videolu,
            EXISTS (SELECT 1 FROM takipler t
                    WHERE t.takip_eden_id=$1 AND t.takip_edilen_id=y.kullanici_id)
              AS takip_ediyorum
     ${AKIS_GOVDE}
       AND ($2::int IS NULL OR true)
       ${AKIS_KURAL}
     ORDER BY (EXISTS (SELECT 1 FROM unnest(y.medya) mm
                       WHERE mm LIKE '%.mp4' OR mm LIKE '%.webm')) DESC,
              (cardinality(y.medya) > 0) DESC,
              y.id DESC
     LIMIT 60`,
    [benId, null, kadro],
  );
  res.json({
    akis: rows.map(akisSatiri),
    icerikler: await akisIcerikleri(rows),
  });
}));

// ---------- bildirimler ----------
app.get('/bildirimler', girisZorunlu, sarici(async (req, res) => {
  const [liste, okunmamis] = await Promise.all([
    havuz.query(
      `SELECT b.id, b.tur, b.yorum_id, b.okundu, b.tarih,
              k.kullanici_adi AS aktor, k.avatar AS aktor_avatar,
              y.tur AS yorum_tur, y.tmdb_id AS yorum_tmdb,
              y.sezon AS yorum_sezon, y.bolum AS yorum_bolum
       FROM bildirimler b
       LEFT JOIN kullanicilar k ON k.id = b.aktor_id
       LEFT JOIN yorumlar y ON y.id = b.yorum_id
       WHERE b.kullanici_id=$1 ORDER BY b.id DESC LIMIT 50`,
      [req.kullanici.id]),
    havuz.query(
      'SELECT count(*)::int AS adet FROM bildirimler WHERE kullanici_id=$1 AND NOT okundu',
      [req.kullanici.id]),
  ]);
  res.json({ bildirimler: liste.rows, okunmamis: okunmamis.rows[0].adet });
}));

app.post('/bildirimler/okundu', girisZorunlu, sarici(async (req, res) => {
  await havuz.query(
    'UPDATE bildirimler SET okundu=true WHERE kullanici_id=$1 AND NOT okundu',
    [req.kullanici.id]);
  res.json({ tamam: true });
}));

// ---------- özel mesajlar ----------
// Sohbet listesi: partner başına son mesaj + okunmamış sayısı.
app.get('/sohbetler', girisZorunlu, sarici(async (req, res) => {
  const { rows } = await havuz.query(
    `SELECT DISTINCT ON (LEAST(m.gonderen_id,m.alici_id), GREATEST(m.gonderen_id,m.alici_id))
            m.id, m.metin, m.medya, m.icerik_tur, m.tarih, m.gonderen_id,
            k.id AS partner_id, k.kullanici_adi AS partner, k.avatar AS partner_avatar,
            (SELECT count(*)::int FROM mesajlar o
             WHERE o.alici_id=$1 AND o.gonderen_id=k.id AND NOT o.okundu) AS okunmamis
     FROM mesajlar m
     JOIN kullanicilar k
       ON k.id = CASE WHEN m.gonderen_id=$1 THEN m.alici_id ELSE m.gonderen_id END
     WHERE m.gonderen_id=$1 OR m.alici_id=$1
     ORDER BY LEAST(m.gonderen_id,m.alici_id), GREATEST(m.gonderen_id,m.alici_id), m.id DESC`,
    [req.kullanici.id],
  );
  rows.sort((a, b) => b.id - a.id);
  const toplam = await havuz.query(
    'SELECT count(*)::int AS adet FROM mesajlar WHERE alici_id=$1 AND NOT okundu',
    [req.kullanici.id]);
  res.json({ sohbetler: rows, okunmamis: toplam.rows[0].adet });
}));

// "Yazıyor..." durumu: bellek içi, kalıcı değil. gonderen:alici -> zaman
const yaziyorlar = new Map();
app.post('/yaziyor', girisZorunlu, sarici(async (req, res) => {
  const k = await havuz.query(
    'SELECT id FROM kullanicilar WHERE kullanici_adi=$1',
    [req.body?.kullanici_adi]);
  if (k.rows.length) {
    yaziyorlar.set(`${req.kullanici.id}:${k.rows[0].id}`, Date.now());
    if (yaziyorlar.size > 5000) {
      const esik = Date.now() - 60_000;
      for (const [anahtar, zaman] of yaziyorlar) {
        if (zaman < esik) yaziyorlar.delete(anahtar);
      }
    }
  }
  res.json({ tamam: true });
}));

// Bir kullanıcıyla mesajlaşma geçmişi; gelenler okundu işaretlenir.
app.get('/mesajlar/:kullaniciAdi', girisZorunlu, sarici(async (req, res) => {
  const k = await havuz.query(
    `SELECT id, kullanici_adi, avatar, son_gorulme
     FROM kullanicilar WHERE kullanici_adi=$1`,
    [req.params.kullaniciAdi]);
  if (!k.rows.length) return res.status(404).json({ hata: 'Kullanıcı bulunamadı' });
  const partnerId = k.rows[0].id;
  const once = parseInt(req.query.once, 10) || null;
  // Alıntılanan mesajın kısa önizlemesi de gelir (LEFT JOIN yanit).
  const { rows } = await havuz.query(
    `SELECT m.id, m.gonderen_id, m.metin, m.medya, m.ses_dalga, m.icerik_tur, m.icerik_id,
            m.okundu, m.duzenlendi, m.yanit_id, m.tarih,
            y.metin AS yanit_metin, y.gonderen_id AS yanit_gonderen,
            y.medya AS yanit_medya, y.icerik_tur AS yanit_icerik_tur
     FROM mesajlar m
     LEFT JOIN mesajlar y ON y.id = m.yanit_id
     WHERE ((m.gonderen_id=$1 AND m.alici_id=$2) OR (m.gonderen_id=$2 AND m.alici_id=$1))
       AND ($3::int IS NULL OR m.id < $3)
     ORDER BY m.id DESC LIMIT 50`,
    [req.kullanici.id, partnerId, once],
  );
  // Paylaşılan içerik kartları için ad + poster (önbellekli TMDB)
  const anahtarlar = [...new Set(rows
    .filter((r) => r.icerik_tur && r.icerik_id)
    .map((r) => `${r.icerik_tur}:${r.icerik_id}`))];
  const icerikler = {};
  await Promise.all(anahtarlar.map(async (a) => {
    const [tur, tmdbId] = a.split(':');
    try {
      const v = await tmdbGetir(`/${tur}/${tmdbId}?language=tr-TR`, ONBELLEK_TTL_SN.uzun);
      icerikler[a] = { ad: v.name || v.title || '?', poster: v.poster_path || null };
    } catch {
      icerikler[a] = { ad: '?', poster: null };
    }
  }));
  havuz.query(
    'UPDATE mesajlar SET okundu=true WHERE alici_id=$1 AND gonderen_id=$2 AND NOT okundu',
    [req.kullanici.id, partnerId]).catch(() => {});
  // Sohbeti okumak zildeki 'mesaj' bildirimini de düşürür; yoksa
  // kullanıcı DM'i okuduğu halde rozette 1 görmeye devam ediyordu.
  havuz.query(
    `UPDATE bildirimler SET okundu=true
     WHERE kullanici_id=$1 AND aktor_id=$2 AND tur='mesaj' AND NOT okundu`,
    [req.kullanici.id, partnerId]).catch(() => {});
  res.json({
    mesajlar: rows.reverse(),
    partner: k.rows[0],
    icerikler,
    yaziyor:
      Date.now() - (yaziyorlar.get(`${partnerId}:${req.kullanici.id}`) || 0) <
      6000,
  });
}));

app.post('/mesajlar', girisZorunlu, mesajLimiti, sarici(async (req, res) => {
  const {
    kullanici_adi, metin, medya = null, ses_dalga = null,
    icerik_tur = null, icerik_id = null, yanit_id = null,
  } = req.body || {};
  const temiz = String(metin || '').trim();
  if (temiz.length > 2000) {
    return res.status(400).json({ hata: 'Mesaj en fazla 2000 karakter olabilir' });
  }
  if (yanit_id != null && !Number.isInteger(yanit_id)) {
    return res.status(400).json({ hata: 'Geçersiz yanit_id' });
  }
  // Medya: yalnızca bu kullanıcının yüklediği, bizim ürettiğimiz adlar
  if (medya != null &&
      (typeof medya !== 'string' ||
       !new RegExp(`^/medya/m${req.kullanici.id}-[0-9a-f]{16}\\.(gif|png|jpg|webp|mp4|webm|ogg|m4a|mp3|aac)$`).test(medya) ||
       !fs.existsSync(path.join(MEDYA_DIZIN, path.basename(medya))))) {
    return res.status(400).json({ hata: 'Geçersiz medya' });
  }
  // Ses dalgası: yalnız ses medyasında, "<saniye>:<en çok 64 örnek>" biçiminde
  const sesMi = medya != null && /\.(ogg|m4a|mp3|aac)$/.test(medya);
  if (ses_dalga != null &&
      (typeof ses_dalga !== 'string' || !sesMi ||
       !/^\d{1,3}:[0-9a-v]{1,64}$/.test(ses_dalga))) {
    return res.status(400).json({ hata: 'Geçersiz ses dalgası' });
  }
  // İçerik paylaşımı: dizi/film kartı
  const icerikVar = icerik_tur != null || icerik_id != null;
  if (icerikVar &&
      (!['tv', 'movie'].includes(icerik_tur) || !Number.isInteger(icerik_id))) {
    return res.status(400).json({ hata: 'Geçersiz içerik' });
  }
  if (!temiz && !medya && !icerikVar) {
    return res.status(400).json({ hata: 'Boş mesaj gönderilemez' });
  }
  const k = await havuz.query(
    'SELECT id FROM kullanicilar WHERE kullanici_adi=$1', [kullanici_adi]);
  if (!k.rows.length) return res.status(404).json({ hata: 'Kullanıcı bulunamadı' });
  const aliciId = k.rows[0].id;
  if (aliciId === req.kullanici.id) {
    return res.status(400).json({ hata: 'Kendine mesaj gönderemezsin' });
  }
  // Engelleme: taraflardan biri diğerini engellediyse mesaj gitmez.
  const engel = await havuz.query(
    `SELECT 1 FROM engellemeler
     WHERE (engelleyen_id=$1 AND engellenen_id=$2)
        OR (engelleyen_id=$2 AND engellenen_id=$1) LIMIT 1`,
    [req.kullanici.id, aliciId],
  );
  if (engel.rows.length) {
    return res.status(403).json({ hata: 'Bu kullanıcıyla mesajlaşamazsın' });
  }
  // Alıntılanan mesaj bu iki kişiye ait olmalı (başka sohbetten alıntı olmaz)
  let gecerliYanit = null;
  if (yanit_id != null) {
    const y = await havuz.query(
      `SELECT id FROM mesajlar WHERE id=$1
       AND ((gonderen_id=$2 AND alici_id=$3) OR (gonderen_id=$3 AND alici_id=$2))`,
      [yanit_id, req.kullanici.id, aliciId],
    );
    if (y.rows.length) gecerliYanit = yanit_id;
  }
  const { rows } = await havuz.query(
    `INSERT INTO mesajlar (gonderen_id, alici_id, metin, medya, ses_dalga,
                           icerik_tur, icerik_id, yanit_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id, tarih`,
    [req.kullanici.id, aliciId, temiz || null, medya, sesMi ? ses_dalga : null,
     icerikVar ? icerik_tur : null, icerikVar ? icerik_id : null, gecerliYanit],
  );
  // Push gövdesinde mesajın kendisi görünsün (boşsa şablona düşer)
  bildirimEkle(aliciId, 'mesaj', req.kullanici.id, null,
    temiz ? { metin: temiz } : null);
  res.json({ id: rows[0].id, tarih: rows[0].tarih });
}));

// Kendi mesajını düzenle (yalnız metin; medya/içerik kartı düzenlenmez)
app.patch('/mesajlar/:id', girisZorunlu, sarici(async (req, res) => {
  const id = Number(req.params.id);
  const { metin } = req.body || {};
  const temiz = String(metin || '').trim();
  if (!Number.isInteger(id)) return res.status(400).json({ hata: 'Geçersiz id' });
  if (!temiz || temiz.length > 2000) {
    return res.status(400).json({ hata: 'Mesaj 1-2000 karakter olmalı' });
  }
  // Yalnız kendi METİN mesajını (medya/içerik kartı olmayan) düzenleyebilir
  const { rows } = await havuz.query(
    `UPDATE mesajlar SET metin=$1, duzenlendi=true
     WHERE id=$2 AND gonderen_id=$3 AND medya IS NULL AND icerik_tur IS NULL
     RETURNING id`,
    [temiz, id, req.kullanici.id],
  );
  if (!rows.length) return res.status(404).json({ hata: 'Mesaj bulunamadı veya düzenlenemez' });
  res.json({ tamam: true });
}));

// Kendi mesajını sil (iki taraftan da kalkar; medyası varsa dosyayı da temizler)
app.delete('/mesajlar/:id', girisZorunlu, sarici(async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ hata: 'Geçersiz id' });
  const { rows } = await havuz.query(
    'DELETE FROM mesajlar WHERE id=$1 AND gonderen_id=$2 RETURNING medya',
    [id, req.kullanici.id],
  );
  if (!rows.length) return res.status(404).json({ hata: 'Mesaj bulunamadı' });
  if (rows[0].medya) {
    fs.unlink(path.join(MEDYA_DIZIN, path.basename(rows[0].medya)), () => {});
  }
  res.json({ tamam: true });
}));

// ---------- şifre sıfırlama ----------
app.post('/auth/sifre-sifirla-istek', authLimiti, sarici(async (req, res) => {
  const { email } = req.body || {};
  // Hesap var/yok bilgisi sızdırılmaz: her durumda aynı cevap.
  const cevap = { mesaj: 'Hesap varsa sıfırlama kodu e-postana gönderildi' };
  const { rows } = await havuz.query(
    'SELECT id FROM kullanicilar WHERE email=$1 AND NOT misafir', [email]);
  if (!rows.length) return res.json(cevap);
  // Kripto-güvenli 6 haneli kod (Math.random tahmin edilebilir PRNG'dir).
  const kod = String(crypto.randomInt(100000, 1000000));
  const hash = await bcrypt.hash(kod, 10);
  await havuz.query(
    `INSERT INTO sifirlama_kodlari (kullanici_id, kod_hash, bitis)
     VALUES ($1,$2, now() + interval '15 minutes')
     ON CONFLICT (kullanici_id) DO UPDATE SET kod_hash=$2, bitis=now() + interval '15 minutes'`,
    [rows[0].id, hash],
  );
  mailUlastirici.sendMail({
    from: MAIL_FROM,
    to: email,
    subject: 'dizi.jpg şifre sıfırlama kodun',
    text: `Şifre sıfırlama kodun: ${kod}\n\n15 dakika geçerlidir. Sen istemediysen bu e-postayı yok say.`,
  }).catch((e) => console.error('sifirlama maili:', e.message));
  res.json(cevap);
}));

app.post('/auth/sifre-sifirla', authLimiti, sarici(async (req, res) => {
  const { email, kod, sifre } = req.body || {};
  if ((sifre || '').length < 6) {
    return res.status(400).json({ hata: 'Şifre en az 6 karakter olmalı' });
  }
  const { rows } = await havuz.query(
    `SELECT k.id, k.kullanici_adi, s.kod_hash, s.bitis
     FROM kullanicilar k JOIN sifirlama_kodlari s ON s.kullanici_id=k.id
     WHERE k.email=$1`, [email]);
  const kayit = rows[0];
  if (!kayit || new Date(kayit.bitis) < new Date()
      || !(await bcrypt.compare(String(kod || ''), kayit.kod_hash))) {
    return res.status(400).json({ hata: 'Kod geçersiz veya süresi dolmuş' });
  }
  const hash = await bcrypt.hash(sifre, 10);
  // Şifre sürümünü artır: eski JWT'ler (çalınmış olabilir) geçersiz olsun.
  await havuz.query(
    'UPDATE kullanicilar SET sifre_hash=$1, sifre_surumu=sifre_surumu+1 WHERE id=$2',
    [hash, kayit.id]);
  await havuz.query('DELETE FROM sifirlama_kodlari WHERE kullanici_id=$1', [kayit.id]);
  sifreSurumOnbellekSil(kayit.id);
  const kullanici = await havuz.query(
    'SELECT id, kullanici_adi, email, misafir, avatar, sifre_surumu FROM kullanicilar WHERE id=$1',
    [kayit.id]);
  res.json({ token: jwtUret(kullanici.rows[0]), kullanici: kullanici.rows[0] });
}));

// ---------- sana özel öneriler ----------
// Son izlenen/puanlanan içeriklerin TMDB önerilerinden, kitaplıkta olmayanlar.
app.get('/onerilen', girisZorunlu, takvimLimiti, sarici(async (req, res) => {
  const [kaynaklar, eldekiler] = await Promise.all([
    havuz.query(
      `SELECT tur, tmdb_id, max(tarih) AS son FROM izlemeler
       WHERE kullanici_id=$1 GROUP BY tur, tmdb_id ORDER BY son DESC LIMIT 6`,
      [req.kullanici.id]),
    havuz.query(
      `SELECT tur, tmdb_id FROM izlemeler WHERE kullanici_id=$1
       UNION SELECT tur, tmdb_id FROM durumlar WHERE kullanici_id=$1`,
      [req.kullanici.id]),
  ]);
  const eldeki = new Set(eldekiler.rows.map((r) => `${r.tur}:${r.tmdb_id}`));
  const oneriler = [];
  const gorulen = new Set();
  await Promise.all(kaynaklar.rows.map(async ({ tur, tmdb_id }) => {
    try {
      const v = await tmdbGetir(
        `/${tur}/${tmdb_id}/recommendations?language=tr-TR`, ONBELLEK_TTL_SN.uzun);
      for (const r of (v.results || []).slice(0, 8)) {
        const rTur = r.media_type || tur;
        const anahtar = `${rTur}:${r.id}`;
        if (eldeki.has(anahtar) || gorulen.has(anahtar)) continue;
        gorulen.add(anahtar);
        oneriler.push({ ...r, media_type: rTur });
      }
    } catch { /* tek kaynak hatası öneriyi bozmasın */ }
  }));
  oneriler.sort((a, b) => ((b.vote_count || 0) - (a.vote_count || 0)));
  res.json({ oneriler: oneriler.slice(0, 20) });
}));

// ---------- yıl özeti ----------
app.get('/ozet/:yil', girisZorunlu, sarici(async (req, res) => {
  const yil = parseInt(req.params.yil, 10);
  if (!yil || yil < 2000 || yil > 2100) {
    return res.status(400).json({ hata: 'Geçersiz yıl' });
  }
  const p = [req.kullanici.id, yil];
  const [bolum, film, diziler, puanlar, yorum] = await Promise.all([
    havuz.query(
      `SELECT count(*)::int AS adet FROM izlemeler
       WHERE kullanici_id=$1 AND tur='tv' AND date_part('year', tarih)=$2`, p),
    havuz.query(
      `SELECT count(*)::int AS adet FROM izlemeler
       WHERE kullanici_id=$1 AND tur='movie' AND date_part('year', tarih)=$2`, p),
    havuz.query(
      `SELECT tmdb_id, count(*)::int AS adet FROM izlemeler
       WHERE kullanici_id=$1 AND tur='tv' AND date_part('year', tarih)=$2
       GROUP BY tmdb_id ORDER BY adet DESC LIMIT 5`, p),
    havuz.query(
      `SELECT count(*)::int AS adet, coalesce(avg(puan),0)::float AS ortalama
       FROM puanlar WHERE kullanici_id=$1 AND date_part('year', tarih)=$2`, p),
    havuz.query(
      `SELECT count(*)::int AS adet FROM yorumlar
       WHERE kullanici_id=$1 AND date_part('year', tarih)=$2`, p),
  ]);
  // En çok izlenen dizilerin adları (önbellekli TMDB)
  const enCok = [];
  await Promise.all(diziler.rows.map(async (r) => {
    try {
      const v = await tmdbGetir(`/tv/${r.tmdb_id}?language=tr-TR`, ONBELLEK_TTL_SN.uzun);
      enCok.push({ tmdb_id: r.tmdb_id, ad: v.name, poster: v.poster_path, bolum: r.adet });
    } catch { /* atla */ }
  }));
  enCok.sort((a, b) => b.bolum - a.bolum);
  res.json({
    yil,
    bolum: bolum.rows[0].adet,
    film: film.rows[0].adet,
    dakika: bolum.rows[0].adet * 42 + film.rows[0].adet * 110,
    puan_sayisi: puanlar.rows[0].adet,
    puan_ortalama: puanlar.rows[0].ortalama,
    yorum: yorum.rows[0].adet,
    en_cok: enCok,
  });
}));

// ---------- rozetler ----------
// Eşiklerden hesaplanır, tablo yok. kod → (eşik, mevcut değer).
// Hem /rozetler (kendi, tümü) hem /profil (açık profil, kazanılanlar) kullanır.
async function rozetleriHesapla(kullaniciId) {
  const { rows } = await havuz.query(
    `SELECT
       (SELECT count(*)::int FROM izlemeler WHERE kullanici_id=$1 AND tur='tv') AS bolum,
       (SELECT count(*)::int FROM izlemeler WHERE kullanici_id=$1 AND tur='movie') AS film,
       (SELECT count(*)::int FROM yorumlar WHERE kullanici_id=$1) AS yorum,
       (SELECT count(*)::int FROM puanlar WHERE kullanici_id=$1) AS puan,
       (SELECT count(*)::int FROM takipler WHERE takip_edilen_id=$1) AS takipci,
       (SELECT count(*)::int FROM durumlar WHERE kullanici_id=$1 AND durum='bitirdim') AS bitirilen,
       (SELECT count(*)::int FROM yorum_begeniler b
        JOIN yorumlar y ON y.id=b.yorum_id WHERE y.kullanici_id=$1) AS begeni_alinan`,
    [kullaniciId]);
  const s = rows[0];
  const tanimlar = [
    ['ilk_bolum', s.bolum, 1], ['bolum_100', s.bolum, 100],
    ['bolum_500', s.bolum, 500], ['bolum_1000', s.bolum, 1000],
    ['bolum_5000', s.bolum, 5000],
    ['ilk_film', s.film, 1], ['film_10', s.film, 10],
    ['film_50', s.film, 50], ['film_100', s.film, 100],
    ['ilk_yorum', s.yorum, 1], ['yorum_25', s.yorum, 25], ['yorum_100', s.yorum, 100],
    ['puan_10', s.puan, 10], ['puan_50', s.puan, 50], ['puan_100', s.puan, 100],
    ['ilk_takipci', s.takipci, 1], ['takipci_10', s.takipci, 10],
    ['takipci_50', s.takipci, 50],
    ['bitiren_10', s.bitirilen, 10], ['bitiren_25', s.bitirilen, 25],
    ['bitiren_50', s.bitirilen, 50],
    ['begeni_10', s.begeni_alinan, 10], ['begeni_100', s.begeni_alinan, 100],
  ];
  return tanimlar.map(([kod, deger, esik]) => ({
    kod, esik, deger, kazanildi: deger >= esik,
  }));
}

app.get('/rozetler', girisZorunlu, sarici(async (req, res) => {
  res.json({ rozetler: await rozetleriHesapla(req.kullanici.id) });
}));

// Yorum beğen / beğeniyi geri al
app.post('/yorumlar/:id/begen', girisZorunlu, sarici(async (req, res) => {
  const silindi = await havuz.query(
    'DELETE FROM yorum_begeniler WHERE yorum_id=$1 AND kullanici_id=$2',
    [req.params.id, req.kullanici.id],
  );
  if (silindi.rowCount === 0) {
    try {
      await havuz.query(
        'INSERT INTO yorum_begeniler (yorum_id, kullanici_id) VALUES ($1,$2)',
        [req.params.id, req.kullanici.id],
      );
      const sahip = await havuz.query(
        'SELECT kullanici_id FROM yorumlar WHERE id=$1', [req.params.id]);
      bildirimEkle(sahip.rows[0]?.kullanici_id, 'begeni', req.kullanici.id,
        parseInt(req.params.id, 10));
    } catch (e) {
      if (e.code === '23503') return res.status(404).json({ hata: 'Yorum bulunamadı' });
      throw e;
    }
  }
  const { rows } = await havuz.query(
    'SELECT count(*)::int AS begeni FROM yorum_begeniler WHERE yorum_id=$1',
    [req.params.id],
  );
  res.json({ begendim: silindi.rowCount === 0, begeni: rows[0].begeni });
}));

app.post('/yorumlar', girisZorunlu, yorumLimiti, sarici(async (req, res) => {
  let { tur, tmdb_id, sezon = null, bolum = null } = req.body || {};
  const { metin, medya = [], ust_id = null } = req.body || {};
  // Yanıt: hedef alanları üst yorumdan alınır; yanıtın yanıtı üst yoruma bağlanır (tek seviye).
  let gercekUst = null;
  if (ust_id != null) {
    if (!Number.isInteger(ust_id)) {
      return res.status(400).json({ hata: 'Geçersiz ust_id' });
    }
    const ust = await havuz.query(
      'SELECT id, ust_id, kullanici_id, tur, tmdb_id, sezon, bolum FROM yorumlar WHERE id=$1',
      [ust_id],
    );
    if (!ust.rows.length) {
      return res.status(404).json({ hata: 'Yanıtlanan yorum bulunamadı' });
    }
    const u = ust.rows[0];
    gercekUst = u.ust_id || u.id;
    tur = u.tur;
    tmdb_id = u.tmdb_id;
    sezon = u.sezon;
    bolum = u.bolum;
  }
  if (!YORUM_TURLERI.includes(tur) || !gecerliTmdb(tmdb_id)) {
    return res.status(400).json({ hata: 'Geçersiz tür veya tmdb_id' });
  }
  if ((sezon == null) !== (bolum == null) ||
      (sezon != null && (!Number.isInteger(sezon) || !Number.isInteger(bolum)))) {
    return res.status(400).json({ hata: 'Bölüm yorumu için sezon ve bolum birlikte gerekli' });
  }
  const temiz = String(metin || '').trim();
  if (!temiz || temiz.length > 1000) {
    return res.status(400).json({ hata: 'Yorum 1-1000 karakter olmalı' });
  }
  if (!Array.isArray(medya) || medya.length > 4) {
    return res.status(400).json({ hata: 'En fazla 4 medya eklenebilir' });
  }
  for (const m of medya) {
    // Yalnızca bu kullanıcının yüklediği, bizim ürettiğimiz adlar kabul edilir.
    if (typeof m !== 'string' ||
        !new RegExp(`^/medya/m${req.kullanici.id}-[0-9a-f]{16}\\.(gif|png|jpg|webp|mp4|webm|ogg|m4a|mp3|aac)$`).test(m) ||
        !fs.existsSync(path.join(MEDYA_DIZIN, path.basename(m)))) {
      return res.status(400).json({ hata: 'Geçersiz medya' });
    }
  }
  const { rows } = await havuz.query(
    `INSERT INTO yorumlar (kullanici_id, tur, tmdb_id, sezon, bolum, metin, medya, ust_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id, tarih`,
    [req.kullanici.id, tur, tmdb_id, sezon, bolum, temiz, medya, gercekUst],
  );
  let yanitlananSahip = null;
  if (gercekUst) {
    const sahip = await havuz.query(
      'SELECT kullanici_id FROM yorumlar WHERE id=$1', [gercekUst]);
    yanitlananSahip = sahip.rows[0]?.kullanici_id ?? null;
    bildirimEkle(yanitlananSahip, 'yanit', req.kullanici.id, rows[0].id);
  }
  // @etiketlenen kullanıcılara bildirim (yanıtlanan zaten 'yanit' aldıysa hariç)
  etiketBildirimleriGonder(temiz, req.kullanici.id, rows[0].id, yanitlananSahip);
  res.json({ id: rows[0].id, tarih: rows[0].tarih });
}));

app.delete('/yorumlar/:id', girisZorunlu, sarici(async (req, res) => {
  const { rows } = await havuz.query(
    'DELETE FROM yorumlar WHERE id=$1 AND kullanici_id=$2 RETURNING medya',
    [req.params.id, req.kullanici.id],
  );
  if (!rows.length) return res.status(404).json({ hata: 'Yorum bulunamadı' });
  for (const m of rows[0].medya || []) {
    fs.unlink(path.join(MEDYA_DIZIN, path.basename(m)), () => {});
  }
  res.json({ tamam: true });
}));

// ---------- takip ----------
// Kullanıcı adına göre takip et / bırak
app.post('/takip/:kullaniciAdi', girisZorunlu, sarici(async (req, res) => {
  const hedef = await havuz.query(
    'SELECT id FROM kullanicilar WHERE kullanici_adi=$1', [req.params.kullaniciAdi]);
  if (!hedef.rows.length) return res.status(404).json({ hata: 'Kullanıcı bulunamadı' });
  const hedefId = hedef.rows[0].id;
  if (hedefId === req.kullanici.id) {
    return res.status(400).json({ hata: 'Kendini takip edemezsin' });
  }
  const silindi = await havuz.query(
    'DELETE FROM takipler WHERE takip_eden_id=$1 AND takip_edilen_id=$2',
    [req.kullanici.id, hedefId],
  );
  if (silindi.rowCount === 0) {
    await havuz.query(
      'INSERT INTO takipler (takip_eden_id, takip_edilen_id) VALUES ($1,$2) ON CONFLICT DO NOTHING',
      [req.kullanici.id, hedefId],
    );
    bildirimEkle(hedefId, 'takip', req.kullanici.id);
  }
  const say = await havuz.query(
    'SELECT count(*)::int AS adet FROM takipler WHERE takip_edilen_id=$1', [hedefId]);
  res.json({ takip: silindi.rowCount === 0, takipci: say.rows[0].adet });
}));

// Bir kullanıcının takipçileri / takip ettikleri
async function takipListesi(kullaniciAdi, sutun, digerSutun) {
  const k = await havuz.query('SELECT id FROM kullanicilar WHERE kullanici_adi=$1', [kullaniciAdi]);
  if (!k.rows.length) return null;
  const { rows } = await havuz.query(
    `SELECT ku.kullanici_adi, ku.avatar, ku.bio
     FROM takipler t JOIN kullanicilar ku ON ku.id = t.${digerSutun}
     WHERE t.${sutun} = $1
     ORDER BY t.tarih DESC LIMIT 500`,
    [k.rows[0].id],
  );
  return rows;
}

app.get('/takipciler/:kullaniciAdi', sarici(async (req, res) => {
  const liste = await takipListesi(req.params.kullaniciAdi, 'takip_edilen_id', 'takip_eden_id');
  if (liste === null) return res.status(404).json({ hata: 'Kullanıcı bulunamadı' });
  res.json({ kullanicilar: liste });
}));

app.get('/takipedilenler/:kullaniciAdi', sarici(async (req, res) => {
  const liste = await takipListesi(req.params.kullaniciAdi, 'takip_eden_id', 'takip_edilen_id');
  if (liste === null) return res.status(404).json({ hata: 'Kullanıcı bulunamadı' });
  res.json({ kullanicilar: liste });
}));

// Kullanıcı arama (keşfet / takip için)
app.get('/kullanici-ara', aramaLimiti, sarici(async (req, res) => {
  const q = String(req.query.q || '').trim().toLowerCase();
  if (q.length < 2) return res.json({ kullanicilar: [] });
  const { rows } = await havuz.query(
    `SELECT kullanici_adi, avatar, bio FROM kullanicilar
     WHERE misafir = false AND kullanici_adi LIKE $1
     ORDER BY (kullanici_adi = $2) DESC, kullanici_adi LIMIT 30`,
    [`%${q}%`, q],
  );
  res.json({ kullanicilar: rows });
}));

// ---------- veri dışa / içe aktarma (GDPR) ----------
// Dışa aktar: tüm veriyi ZIP'leyip kullanıcının kayıtlı e-postasına gönderir.
app.post('/veri/disa-aktar', girisZorunlu, veriLimiti, sarici(async (req, res) => {
  const k = await havuz.query(
    'SELECT email, kullanici_adi FROM kullanicilar WHERE id=$1', [req.kullanici.id]);
  const eposta = k.rows[0]?.email;
  if (!eposta) {
    return res.status(400).json({
      hata: 'Verilerini e-postayla almak için önce hesabına e-posta bağlamalısın',
    });
  }
  const zip = await disaAktar(havuz, req.kullanici.id);
  const tarih = new Date().toISOString().slice(0, 10);
  await mailUlastirici.sendMail({
    from: MAIL_FROM,
    to: eposta,
    subject: 'dizi.jpg — Verilerin',
    text: 'Merhaba,\n\nTalep ettiğin dizi.jpg verilerin ekte ZIP olarak yer alıyor. '
      + 'Bu ZIP\'i uygulamada Ayarlar > Veri içe aktar ile geri yükleyebilirsin.\n\n'
      + 'Bu isteği sen yapmadıysan lütfen dikkate alma.\n\ndizi.jpg',
    attachments: [{ filename: `dizijpg-verilerim-${tarih}.zip`, content: zip }],
  });
  res.json({ tamam: true, mesaj: `Verilerin ${eposta} adresine gönderildi` });
}));

// İçe aktar: ham ZIP gövdesi. Yalnızca kendi hesabına yükler.
app.post('/veri/ice-aktar',
  girisZorunlu,
  veriLimiti,
  express.raw({ type: ['application/zip', 'application/octet-stream'], limit: '50mb' }),
  sarici(async (req, res) => {
    if (!Buffer.isBuffer(req.body) || req.body.length < 4) {
      return res.status(400).json({ hata: 'ZIP verisi gerekli' });
    }
    // ZIP sihirli baytı (PK\x03\x04 / boş arşiv PK\x05\x06)
    if (!(req.body[0] === 0x50 && req.body[1] === 0x4b)) {
      return res.status(400).json({ hata: 'Geçerli bir ZIP dosyası değil' });
    }
    const ozet = await iceAktar(
      havuz, req.kullanici.id, req.body, tvdbdenTmdb, isimdenTmdbTv,
      tmdbBolumSayisi, isimdenTmdbFilm);
    res.json({ tamam: true, ozet });
  }));

// ---------- herkese açık profil ----------
app.get('/profil/:kullaniciAdi', girisIsteğeBagli, sarici(async (req, res) => {
  const k = await havuz.query(
    'SELECT id, kullanici_adi, avatar, kapak, bio, ulke, sosyal, olusturma FROM kullanicilar WHERE kullanici_adi=$1',
    [req.params.kullaniciAdi],
  );
  if (!k.rows.length) return res.status(404).json({ hata: 'Kullanıcı bulunamadı' });
  const id = k.rows[0].id;
  const benId = req.kullanici?.id || 0;
  const [istatistik, listeler, sonIncelemeler, yorumlar, takip, izlenenler, rozetler] = await Promise.all([
    havuz.query(
      `SELECT
         (SELECT count(*)::int FROM izlemeler WHERE kullanici_id=$1 AND tur='tv') AS bolum,
         (SELECT count(*)::int FROM izlemeler WHERE kullanici_id=$1 AND tur='movie') AS film,
         (SELECT count(DISTINCT tmdb_id)::int FROM izlemeler WHERE kullanici_id=$1 AND tur='tv') AS dizi,
         (SELECT count(*)::int FROM takipler WHERE takip_edilen_id=$1) AS takipci,
         (SELECT count(*)::int FROM takipler WHERE takip_eden_id=$1) AS takip_edilen,
         (SELECT count(*)::int FROM yorumlar WHERE kullanici_id=$1) AS yorum,
         (SELECT COALESCE(sum(goruntulenme),0)::int FROM yorumlar
          WHERE kullanici_id=$1) AS toplam_goruntulenme,
         (SELECT count(*)::int FROM yorum_begeniler b
          JOIN yorumlar y2 ON y2.id=b.yorum_id
          WHERE y2.kullanici_id=$1) AS toplam_begeni`,
      [id]),
    havuz.query(
      `SELECT l.id, l.ad, l.aciklama,
              (SELECT count(*)::int FROM liste_ogeleri o WHERE o.liste_id=l.id) AS oge_sayisi
       FROM listeler l WHERE l.kullanici_id=$1 AND l.herkese_acik=true
       ORDER BY l.olusturma DESC`,
      [id]),
    havuz.query(
      `SELECT tur, tmdb_id, puan, yorum, tarih FROM puanlar
       WHERE kullanici_id=$1 AND yorum IS NOT NULL ORDER BY tarih DESC LIMIT 10`,
      [id]),
    // Kullanıcının yorumları, beğeni ve görüntülenme sayılarıyla
    havuz.query(
      `SELECT y.id, y.tur, y.tmdb_id, y.sezon, y.bolum, y.metin, y.medya,
              y.goruntulenme, y.tarih,
              (SELECT count(*)::int FROM yorum_begeniler b WHERE b.yorum_id=y.id) AS begeni
       FROM yorumlar y WHERE y.kullanici_id=$1 ORDER BY y.tarih DESC LIMIT 20`,
      [id]),
    havuz.query(
      `SELECT EXISTS(SELECT 1 FROM takipler WHERE takip_eden_id=$1 AND takip_edilen_id=$2) AS var,
              EXISTS(SELECT 1 FROM engellemeler WHERE engelleyen_id=$1 AND engellenen_id=$2) AS engel`,
      [benId, id]),
    // Tür başına ayrı limit: yoksa son izlenen filmler dizileri listeden atıyor
    havuz.query(
      `(SELECT tur, tmdb_id, count(*)::int AS sayi, max(tarih) AS son
        FROM izlemeler WHERE kullanici_id=$1 AND tur='tv'
        GROUP BY tur, tmdb_id ORDER BY son DESC, tmdb_id DESC LIMIT 60)
       UNION ALL
       (SELECT tur, tmdb_id, count(*)::int AS sayi, max(tarih) AS son
        FROM izlemeler WHERE kullanici_id=$1 AND tur='movie'
        GROUP BY tur, tmdb_id ORDER BY son DESC, tmdb_id DESC LIMIT 60)
       ORDER BY son DESC, tmdb_id DESC`,
      [id]),
    rozetleriHesapla(id),
  ]);
  // Yorum kartları için içerik adı + poster (önbellekli TMDB)
  const anahtarlar = [...new Set(yorumlar.rows.map((y) => `${y.tur}:${y.tmdb_id}`))];
  const icerikler = {};
  await Promise.all(anahtarlar.map(async (a) => {
    const [tur, tmdbId] = a.split(':');
    try {
      const v = await tmdbGetir(`/${tur}/${tmdbId}?language=tr-TR`, ONBELLEK_TTL_SN.uzun);
      icerikler[a] = {
        ad: v.name || v.title || '?',
        poster: v.poster_path || v.profile_path || null,
      };
    } catch {
      icerikler[a] = { ad: '?', poster: null };
    }
  }));
  res.json({
    ...k.rows[0],
    ben_mi: benId === id,
    takip_ediyorum: takip.rows[0].var,
    engelledim: takip.rows[0].engel,
    istatistik: {
      ...istatistik.rows[0],
      // Yaklaşık ekran süresi (bölüm ~42 dk, film ~110 dk) — açık profilde de görünür
      tahmini_dakika:
        istatistik.rows[0].bolum * 42 + istatistik.rows[0].film * 110,
    },
    // Açık profilde yalnız kazanılan rozetler gösterilir
    rozetler: rozetler.filter((r) => r.kazanildi),
    listeler: listeler.rows,
    incelemeler: sonIncelemeler.rows,
    yorumlar: yorumlar.rows,
    icerikler,
    izlenenler: izlenenler.rows.map(({ tur, tmdb_id, sayi }) => ({ tur, tmdb_id, sayi })),
  });
}));

// ---------- hesap silme (Play Store gereksinimi) ----------
// Girişli kullanıcı kendi hesabını + tüm verisini siler (FK CASCADE).
app.delete('/hesabim', girisZorunlu, sarici(async (req, res) => {
  const { sifre } = req.body || {};
  const { rows } = await havuz.query(
    'SELECT sifre_hash FROM kullanicilar WHERE id=$1', [req.kullanici.id],
  );
  if (!rows.length) return res.status(404).json({ hata: 'Hesap bulunamadı' });
  // Şifreli hesaplarda silmeden önce şifre doğrula (kaza/kötüye kullanım koruması).
  if (rows[0].sifre_hash && !(await bcrypt.compare(sifre || '', rows[0].sifre_hash))) {
    return res.status(401).json({ hata: 'Şifre hatalı' });
  }
  await havuz.query('DELETE FROM kullanicilar WHERE id=$1', [req.kullanici.id]);
  sifreSurumOnbellekSil(req.kullanici.id);
  res.json({ durum: 'silindi' });
}));

// ---------- şikayet + engelleme (Play Store UGC gereksinimi) ----------
const sikayetLimiti = hizLimiti(20, (req) => `sk:${req.kullanici.id}`);
const SIKAYET_TUR = ['yorum', 'mesaj', 'kullanici', 'liste'];

app.post('/sikayet', girisZorunlu, sikayetLimiti, sarici(async (req, res) => {
  const { tur, hedef_id, sebep } = req.body || {};
  if (!SIKAYET_TUR.includes(tur) || !gecerliTmdb(hedef_id)) {
    return res.status(400).json({ hata: 'Geçersiz şikayet' });
  }
  const metin = String(sebep || '').slice(0, 500).trim();
  if (!metin) return res.status(400).json({ hata: 'Sebep gerekli' });
  await havuz.query(
    'INSERT INTO sikayetler (sikayet_eden_id, tur, hedef_id, sebep) VALUES ($1,$2,$3,$4)',
    [req.kullanici.id, tur, hedef_id, metin],
  );
  res.json({ durum: 'alindi' });
}));

// Kullanıcıyı engelle/engeli kaldır (toggle).
app.post('/engelle/:kullaniciAdi', girisZorunlu, sarici(async (req, res) => {
  const hedef = await havuz.query(
    'SELECT id FROM kullanicilar WHERE kullanici_adi=$1', [req.params.kullaniciAdi],
  );
  if (!hedef.rows.length) return res.status(404).json({ hata: 'Kullanıcı yok' });
  const hedefId = hedef.rows[0].id;
  if (hedefId === req.kullanici.id) {
    return res.status(400).json({ hata: 'Kendini engelleyemezsin' });
  }
  const mevcut = await havuz.query(
    'SELECT 1 FROM engellemeler WHERE engelleyen_id=$1 AND engellenen_id=$2',
    [req.kullanici.id, hedefId],
  );
  if (mevcut.rows.length) {
    await havuz.query(
      'DELETE FROM engellemeler WHERE engelleyen_id=$1 AND engellenen_id=$2',
      [req.kullanici.id, hedefId],
    );
    return res.json({ engellendi: false });
  }
  await havuz.query(
    'INSERT INTO engellemeler (engelleyen_id, engellenen_id) VALUES ($1,$2)',
    [req.kullanici.id, hedefId],
  );
  // Engellenince karşılıklı takip de kalksın.
  await havuz.query(
    `DELETE FROM takipler WHERE (takip_eden_id=$1 AND takip_edilen_id=$2)
       OR (takip_eden_id=$2 AND takip_edilen_id=$1)`,
    [req.kullanici.id, hedefId],
  );
  res.json({ engellendi: true });
}));

// ---------- FCM cihaz token kaydı ----------
app.post('/cihaz-token', girisZorunlu, sarici(async (req, res) => {
  const { token, platform, dil } = req.body || {};
  if (typeof token !== 'string' || token.length < 20 || token.length > 4096) {
    return res.status(400).json({ hata: 'Geçersiz token' });
  }
  await havuz.query(
    `INSERT INTO cihaz_tokenlari (token, kullanici_id, platform, dil, guncelleme)
     VALUES ($1,$2,$3,$4,now())
     ON CONFLICT (token) DO UPDATE
       SET kullanici_id=$2, platform=$3, dil=$4, guncelleme=now()`,
    [token, req.kullanici.id, String(platform || '').slice(0, 20),
     String(dil || 'tr').slice(0, 10)],
  );
  res.json({ durum: 'kayitli' });
}));

app.delete('/cihaz-token', girisZorunlu, sarici(async (req, res) => {
  const { token } = req.body || {};
  if (token) {
    await havuz.query(
      'DELETE FROM cihaz_tokenlari WHERE token=$1 AND kullanici_id=$2',
      [token, req.kullanici.id]);
  }
  res.json({ durum: 'silindi' });
}));

// Engellediğim kullanıcılar.
app.get('/engellenenler', girisZorunlu, sarici(async (req, res) => {
  const { rows } = await havuz.query(
    `SELECT k.id, k.kullanici_adi, k.avatar FROM engellemeler e
       JOIN kullanicilar k ON k.id = e.engellenen_id
     WHERE e.engelleyen_id=$1 ORDER BY e.tarih DESC`,
    [req.kullanici.id],
  );
  res.json({ kullanicilar: rows });
}));

// ---------- admin panel (IP kısıtlı) ----------
// Erişim: gerçek IP ADMIN_IPLER listesinde VEYA ADMIN_TOKEN eşleşiyorsa.
function adminKisit(req, res, next) {
  const ip = gercekIp(req);
  const izinli = ADMIN_IPLER.split(',').map((s) => s.trim()).filter(Boolean);
  const tokenGecerli = ADMIN_TOKEN &&
    (req.headers['x-admin-token'] === ADMIN_TOKEN || req.query.token === ADMIN_TOKEN);
  if (izinli.includes(ip) || tokenGecerli) return next();
  return res.status(403).json({ hata: 'Erişim reddedildi' });
}

const ADMIN_HTML = fs.existsSync('./admin.html')
  ? fs.readFileSync('./admin.html', 'utf8')
  : '<h1>admin.html bulunamadı</h1>';
app.get('/admin', adminKisit, (_req, res) => res.type('html').send(ADMIN_HTML));

// Genel özet: kullanıcı/hata/şikayet sayıları + sistem + istek/dk + ülkeler.
app.get('/admin/ozet', adminKisit, sarici(async (_req, res) => {
  const [ku, h24, hT, sy, sT, cv] = await Promise.all([
    havuz.query('SELECT count(*)::int n, count(*) FILTER (WHERE misafir)::int misafir FROM kullanicilar'),
    havuz.query("SELECT count(*)::int n FROM hatalar WHERE tarih > now() - interval '24 hours'"),
    havuz.query('SELECT count(*)::int n FROM hatalar'),
    havuz.query("SELECT count(*)::int n FROM sikayetler WHERE durum='yeni'"),
    havuz.query('SELECT count(*)::int n FROM sikayetler'),
    havuz.query("SELECT count(*)::int n FROM kullanicilar WHERE son_gorulme > now() - interval '3 minutes'"),
  ]);
  const simdiDk = Math.floor(Date.now() / 60000);
  const seri = [];
  for (let i = 59; i >= 0; i--) seri.push(ISTEK.dakika.get(simdiDk - i) || 0);
  const ulkeler = [...ISTEK.ulke.entries()]
    .map(([ulke, sayi]) => ({ ulke, sayi }))
    .sort((a, b) => b.sayi - a.sayi)
    .slice(0, 40);
  let disk = null;
  try {
    const s = fs.statfsSync('/');
    disk = { toplam: s.blocks * s.bsize, bos: s.bfree * s.bsize };
  } catch { /* statfs yoksa atla */ }
  res.json({
    kullanici: ku.rows[0].n,
    misafir: ku.rows[0].misafir,
    cevrimici: cv.rows[0].n,
    hata24: h24.rows[0].n,
    hataToplam: hT.rows[0].n,
    sikayetYeni: sy.rows[0].n,
    sikayetToplam: sT.rows[0].n,
    istekToplam: ISTEK.toplam,
    istekSeri: seri,
    ulkeler,
    sistem: {
      yuk: os.loadavg(),
      cpu: os.cpus().length,
      bellekToplam: os.totalmem(),
      bellekBos: os.freemem(),
      uptime: os.uptime(),
      apiUptime: process.uptime(),
      disk,
    },
  });
}));

// Son hareketler: yorumlar, izlemeler, durum eklemeleri, yeni kayıtlar +
// çevrimiçi kullanıcılar (son_gorulme ≤ 3 dk; yazım aralığı 20 sn).
app.get('/admin/hareketler', adminKisit, sarici(async (_req, res) => {
  const [yorumlar, izlemeler, durumlar, yeniler, cevrimici] = await Promise.all([
    havuz.query(
      `SELECT y.id, y.tur, y.tmdb_id, y.sezon, y.bolum, LEFT(y.metin,140) AS metin,
              cardinality(y.medya) AS medya_sayi, y.goruntulenme, y.tarih,
              k.kullanici_adi,
              (SELECT count(*)::int FROM yorum_begeniler b WHERE b.yorum_id=y.id) AS begeni
       FROM yorumlar y JOIN kullanicilar k ON k.id=y.kullanici_id
       ORDER BY y.id DESC LIMIT 30`),
    havuz.query(
      `SELECT i.tur, i.tmdb_id, i.sezon, i.bolum, i.tarih, k.kullanici_adi
       FROM izlemeler i JOIN kullanicilar k ON k.id=i.kullanici_id
       ORDER BY i.tarih DESC LIMIT 30`),
    havuz.query(
      `SELECT d.tur, d.tmdb_id, d.durum, d.guncelleme AS tarih, k.kullanici_adi
       FROM durumlar d JOIN kullanicilar k ON k.id=d.kullanici_id
       ORDER BY d.guncelleme DESC LIMIT 30`),
    havuz.query(
      `SELECT kullanici_adi, misafir, olusturma FROM kullanicilar
       ORDER BY id DESC LIMIT 30`),
    havuz.query(
      `SELECT kullanici_adi, misafir, son_gorulme FROM kullanicilar
       WHERE son_gorulme > now() - interval '3 minutes'
       ORDER BY son_gorulme DESC LIMIT 100`),
  ]);
  // İçerik adları (önbellekli TMDB; panelde ne izlendiği okunur olsun)
  const anahtarlar = [...new Set([
    ...yorumlar.rows, ...izlemeler.rows, ...durumlar.rows,
  ].map((r) => `${r.tur}:${r.tmdb_id}`))];
  const icerikler = {};
  await Promise.all(anahtarlar.map(async (a) => {
    const [tur, id] = a.split(':');
    try {
      const v = await tmdbGetir(`/${tur}/${id}?language=tr-TR`, ONBELLEK_TTL_SN.uzun);
      icerikler[a] = v.name || v.title || '?';
    } catch { icerikler[a] = '?'; }
  }));
  res.json({
    yorumlar: yorumlar.rows,
    izlemeler: izlemeler.rows,
    durumlar: durumlar.rows,
    yeni_kullanicilar: yeniler.rows,
    cevrimici: { sayi: cevrimici.rows.length, liste: cevrimici.rows },
    icerikler,
  });
}));

// Kullanıcı detayı: moderasyon için tam profil + etkileşim + son IP'ler.
app.get('/admin/kullanici/:ad', adminKisit, sarici(async (req, res) => {
  const k = await havuz.query(
    `SELECT id, kullanici_adi, email, misafir, yasakli, bio, ulke, sosyal,
            olusturma, son_gorulme FROM kullanicilar WHERE kullanici_adi=$1`,
    [req.params.ad]);
  if (!k.rows.length) return res.status(404).json({ hata: 'Kullanıcı bulunamadı' });
  const id = k.rows[0].id;
  const [ist, yorumlar, sikayet] = await Promise.all([
    havuz.query(
      `SELECT
         (SELECT count(*)::int FROM izlemeler WHERE kullanici_id=$1) AS izleme,
         (SELECT count(*)::int FROM yorumlar WHERE kullanici_id=$1) AS yorum,
         (SELECT count(*)::int FROM mesajlar WHERE gonderen_id=$1) AS mesaj,
         (SELECT count(*)::int FROM takipler WHERE takip_edilen_id=$1) AS takipci,
         (SELECT COALESCE(sum(goruntulenme),0)::int FROM yorumlar
          WHERE kullanici_id=$1) AS goruntulenme,
         (SELECT count(*)::int FROM yorum_begeniler b
          JOIN yorumlar y ON y.id=b.yorum_id WHERE y.kullanici_id=$1) AS begeni,
         (SELECT count(*)::int FROM cihaz_tokenlari WHERE kullanici_id=$1) AS cihaz`,
      [id]),
    havuz.query(
      `SELECT id, tur, tmdb_id, sezon, bolum, LEFT(metin,200) AS metin,
              cardinality(medya) AS medya_sayi, goruntulenme, tarih
       FROM yorumlar WHERE kullanici_id=$1 ORDER BY id DESC LIMIT 20`,
      [id]),
    havuz.query(
      `SELECT
         (SELECT count(*)::int FROM sikayetler
          WHERE tur='kullanici' AND hedef_id=$1) AS hakkinda,
         (SELECT count(*)::int FROM sikayetler s
          JOIN yorumlar y ON s.tur='yorum' AND y.id=s.hedef_id
          WHERE y.kullanici_id=$1) AS yorum_sikayet,
         (SELECT count(*)::int FROM sikayetler WHERE sikayet_eden_id=$1) AS ettigi`,
      [id]).catch(() => ({ rows: [{ hakkinda: null, yorum_sikayet: null, ettigi: null }] })),
  ]);
  // Bellek-içi istek halkasından bu kullanıcının son IP'leri
  const ipler = [];
  const gorulenIp = new Set();
  for (const i of ISTEK.son) {
    if (i.kullanici !== id || gorulenIp.has(i.ip)) continue;
    gorulenIp.add(i.ip);
    ipler.push({ ip: i.ip, ulke: i.ulke, sehir: i.sehir, ts: i.ts });
    if (ipler.length >= 10) break;
  }
  res.json({
    ...k.rows[0],
    istatistik: ist.rows[0],
    sikayet: sikayet.rows[0],
    son_yorumlar: yorumlar.rows,
    son_ipler: ipler,
  });
}));

// Son istekler (3D globe + canlı akış için).
app.get('/admin/istekler', adminKisit, (_req, res) => {
  res.json({ istekler: ISTEK.son.slice(0, 250) });
});

// Hata günlüğü.
app.get('/admin/hatalar', adminKisit, sarici(async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit, 10) || 100, 500);
  const { rows } = await havuz.query(
    `SELECT h.id, h.mesaj, h.yigin, h.platform, h.surum, h.yol, h.tarih,
            k.kullanici_adi
       FROM hatalar h LEFT JOIN kullanicilar k ON k.id = h.kullanici_id
     ORDER BY h.id DESC LIMIT $1`, [limit],
  );
  res.json({ hatalar: rows });
}));

// Şikayetler (hedef özetiyle zenginleştirilmiş).
app.get('/admin/sikayetler', adminKisit, sarici(async (req, res) => {
  const durum = req.query.durum;
  const filtre = ['yeni', 'incelendi', 'kapatildi'].includes(durum);
  const { rows } = await havuz.query(
    `SELECT s.*, k.kullanici_adi AS eden FROM sikayetler s
       LEFT JOIN kullanicilar k ON k.id = s.sikayet_eden_id
     ${filtre ? 'WHERE s.durum=$1' : ''} ORDER BY s.id DESC LIMIT 300`,
    filtre ? [durum] : [],
  );
  // Hedefleri toplu çöz: yorum metni + kullanıcı adı.
  const yorumIds = rows.filter((r) => r.tur === 'yorum').map((r) => r.hedef_id);
  const kulIds = rows.filter((r) => r.tur === 'kullanici').map((r) => r.hedef_id);
  const yorumlar = yorumIds.length
    ? (await havuz.query('SELECT id, metin, kullanici_id FROM yorumlar WHERE id = ANY($1)', [yorumIds])).rows
    : [];
  const kullar = kulIds.length
    ? (await havuz.query('SELECT id, kullanici_adi, yasakli FROM kullanicilar WHERE id = ANY($1)', [kulIds])).rows
    : [];
  const yMap = new Map(yorumlar.map((y) => [y.id, y]));
  const kMap = new Map(kullar.map((k) => [k.id, k]));
  for (const r of rows) {
    if (r.tur === 'yorum') {
      const y = yMap.get(r.hedef_id);
      r.hedef_ozet = y ? y.metin.slice(0, 200) : '(silinmiş yorum)';
      r.hedef_kullanici_id = y?.kullanici_id ?? null;
    } else if (r.tur === 'kullanici') {
      const k = kMap.get(r.hedef_id);
      r.hedef_ozet = k ? '@' + k.kullanici_adi : '(silinmiş kullanıcı)';
      r.hedef_yasakli = k?.yasakli ?? null;
    }
  }
  res.json({ sikayetler: rows });
}));

// Moderasyon aksiyonları.
app.post('/admin/sikayet-durum', adminKisit, sarici(async (req, res) => {
  const { id, durum } = req.body || {};
  if (!['yeni', 'incelendi', 'kapatildi'].includes(durum)) {
    return res.status(400).json({ hata: 'Geçersiz durum' });
  }
  await havuz.query('UPDATE sikayetler SET durum=$1 WHERE id=$2', [durum, id]);
  res.json({ durum: 'ok' });
}));
app.post('/admin/yorum-sil', adminKisit, sarici(async (req, res) => {
  await havuz.query('DELETE FROM yorumlar WHERE id=$1', [req.body?.id]);
  res.json({ durum: 'ok' });
}));
app.post('/admin/kullanici-ban', adminKisit, sarici(async (req, res) => {
  const { id, yasakli } = req.body || {};
  if (yasakli) {
    await havuz.query(
      'UPDATE kullanicilar SET yasakli=true, sifre_surumu=sifre_surumu+1 WHERE id=$1', [id],
    );
  } else {
    await havuz.query('UPDATE kullanicilar SET yasakli=false WHERE id=$1', [id]);
  }
  sifreSurumOnbellekSil(id);
  res.json({ durum: 'ok' });
}));

// Son durak hata yakalayıcı: varsayılan Express işleyicisi yığın izi
// sızdırmasın (statik 404, gövde limiti aşımı vb. buraya düşer).
app.use((err, _req, res, _next) => {
  const kod = err.status || err.statusCode || 500;
  if (kod >= 500) console.error(err.message);
  res.status(kod).json({
    hata: kod === 404 ? 'Bulunamadı'
        : err.type === 'entity.too.large' ? 'Dosya çok büyük'
        : kod >= 500 ? 'Sunucu hatası' : 'Geçersiz istek',
  });
});

app.listen(PORT, '0.0.0.0', () => console.log(`dizi.jpg API ${PORT} portunda`));
