// dizi.jpg API — auth, TMDB proxy (önbellekli), izleme/puan/liste/istatistik
import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import pg from 'pg';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import nodemailer from 'nodemailer';
import { execFile } from 'child_process';
import { AsyncLocalStorage } from 'async_hooks';
import os from 'os';
import geoip from 'geoip-lite';
import admin from 'firebase-admin';
import { disaAktar, iceAktar } from './veri_aktar.js';
import {
  dizinOzet, turDagilimi, oksuzler, oksuzSil, yedekDurumu,
} from './depolama.js';
import { emojiSay, EMOJI_YEDEK } from './emoji.js';
import {
  AGIRLIK_ANAHTARLARI, SAYIM_SINYALLERI, SAYI_ALANLARI, ARSIV_YAS_SAAT,
  VARSAYILAN_AKIS, VARSAYILAN_KESFET, ayarBirlestir, hacimUygula,
  siralaVeKotala, imlecCoz, imlecYaz, TohumDeposu, tohumUret,
} from './siralama.js';
import {
  mailKutulari, mailAyristir, mailKimlikCoz, gelenMailler, htmlKisirlastir,
} from './mail_kutu.js';

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

// Havuz: /akis, /takvim gibi uçlar Promise.all ile istek başına 20-30 paralel
// sorgu açtığından varsayılan max=10 tek istekte tükeniyordu. Postgres
// max_connections=100 içinde güvenli tavan + timeout'lar (asılı bağlantı yerine
// hızlı hata).
const havuz = new pg.Pool({
  connectionString: DATABASE_URL,
  max: 30,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});
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

// Video için küçük resim: ilk saniyeden bir kare alınıp <dosya>.jpg olarak
// yazılır. Keşfet ızgarası bunu gösterir — video yerine resim koymak, aynı
// anda onlarca çözücü açılmasını (ve telefonun ısınmasını) engeller.
// Başarısız olursa sessiz geçilir; istemci kapak yoksa postere düşer.
function videoKaresiCikar(dosyaYolu) {
  return new Promise((bitti) => {
    execFile('ffmpeg', [
      '-y', '-ss', '0.5', '-i', dosyaYolu,
      '-frames:v', '1', '-vf', 'scale=480:-2',
      '-q:v', '4', `${dosyaYolu}.jpg`,
    ], { timeout: 20000 }, (hata) => bitti(!hata));
  });
}

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

// CORS: yalnız kendi web kökenlerimize izin ver (mobil uygulama native HTTP
// kullanır, CORS'a tabi değildir; bu yüzden kısıtlamak mobili etkilemez).
// Eskiden '*' idi — JWT başlık-tabanlı olduğu için kimlik hırsızlığı riski
// düşüktü ama gereksiz genişti. Bilinmeyen köken CORS başlığı almaz.
const CORS_KOKENLER = new Set([
  'https://dizijpg.com',
  'https://www.dizijpg.com',
]);
app.use((req, res, next) => {
  const koken = req.headers.origin;
  if (koken && CORS_KOKENLER.has(koken)) {
    res.set('Access-Control-Allow-Origin', koken);
    res.set('Vary', 'Origin');
  }
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Dil');
  res.set('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
  // Yüklenen dosyalar tarayıcıda içerik koklamasıyla çalıştırılamasın.
  res.set('X-Content-Type-Options', 'nosniff');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// İstek dilini bağlama koy: TMDB içeriği kullanıcının dilinde gelsin.
app.use((req, _res, next) => {
  // Dil önce ADRESTEN (?dil=xx) okunur: Cloudflare önbellek anahtarı yalnız
  // URL'dir, başlığa bakmaz — dil adreste olmasaydı bir dilin yanıtı başka
  // dildeki kullanıcıya servis edilirdi.
  const kod = String(req.query?.dil || req.headers['x-dil'] || 'tr').toLowerCase();
  const tmdbDil = TMDB_DIL[kod] || 'en-US';
  istekBaglam.run({ tmdbDil, dil: kod }, next);
});

// ---------- gerçek istemci IP (Cloudflare arkasında) ----------
// GÜVENLİK: nginx, real_ip modülüyle CF-Connecting-IP'yi doğrular ve gerçek
// istemci IP'sini X-Real-IP başlığına yazar; ayrıca istemciden gelen
// CF-Connecting-IP / X-Forwarded-For başlıklarını $remote_addr ile EZER.
// Bu yüzden yalnız X-Real-IP güvenilirdir — istemci onu spoof edemez (nginx
// her istekte üzerine yazar). Origin'e doğrudan (CF atlanarak) bağlanan biri
// bile admin/hız-limiti kontrolünü sahte IP ile atlatamaz. Ham
// CF-Connecting-IP/X-Forwarded-For'a ARTIK GÜVENİLMEZ.
function gercekIp(req) {
  return (req.headers['x-real-ip'] || req.ip || '').replace('::ffff:', '');
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

// Sıfırlama kodu tek kullanımlık bir kimlik bilgisidir: günlüğe düz yazılırsa
// panele erişen biri istediği hesabın şifresini sıfırlayabilir. Maskele.
function mailGovdeTemizle(metin, tur) {
  const t = tur === 'sifirlama'
    ? String(metin).replace(/\b\d{6}\b/g, '••••••') : String(metin);
  return t.length > 20000 ? `${t.slice(0, 20000)}\n…(kırpıldı)` : t;
}

// Postfix gönderdiği mailin kopyasını saklamaz — her gönderim `mailler`
// tablosuna da yazılır ki admin panelinde "kime ne göndermişiz" görülebilsin.
// Günlük yazımı gönderimi bloklamaz/başarısız etmez (ateşle-unut).
async function mailGonder(secenekler, bilgi = {}) {
  const ek = secenekler.attachments?.[0];
  let sonuc = null;
  let hata = null;
  try {
    sonuc = await mailUlastirici.sendMail({ from: MAIL_FROM, ...secenekler });
  } catch (e) {
    hata = e.message;
  }
  havuz.query(
    `INSERT INTO mailler (kime, konu, govde, tur, kullanici_id, ek_ad, ek_boyut,
                          durum, hata, mesaj_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
    [
      String(secenekler.to || ''), secenekler.subject || null,
      mailGovdeTemizle(secenekler.text || '', bilgi.tur), bilgi.tur || null,
      bilgi.kullanici_id || null, ek?.filename || null, ek?.content?.length ?? null,
      hata ? 'hata' : 'gonderildi', hata, sonuc?.messageId || null,
    ],
  ).catch((e) => console.error('mail gunlugu:', e.message));
  if (hata) throw new Error(hata);
  return sonuc;
}

// ---------- yardımcılar ----------
const TMDB = 'https://api.themoviedb.org/3';
const ONBELLEK_TTL_SN = { varsayilan: 6 * 3600, uzun: 7 * 24 * 3600 };

async function tmdbGetir(yol, ttlSn = ONBELLEK_TTL_SN.varsayilan, dilZorla = null) {
  // İçerik dilini isteğin diline göre ayarla: çağrılar 'language=tr-TR' yazsa da
  // gerçek dil buradan gelir. Önbellek anahtarı da dili içerdiğinden dil-başına
  // ayrı önbelleklenir. dilZorla: İngilizceye düşerken kullanılır.
  const dil = dilZorla || istekBaglam.getStore()?.tmdbDil || 'tr-TR';
  // /images uçlarında DİL OLMAZ: `language` görselleri dile göre süzer, bölüm
  // kareleri ise dilsizdir (iso_639_1: null) → dil verilirse liste BOŞ döner.
  // Görselde metin yok, tek önbellek girdisi bütün dillere hizmet eder.
  if (/\/images(\?|$)/.test(yol)) {
    yol = yol
      .replace(/([?&])language=[a-zA-Z-]*&?/g, '$1')
      .replace(/[?&]$/, '');
  } else if (/[?&]language=/.test(yol)) {
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

// Çok sayıda TMDB kaydını TEK sorguda önbellekten okur; yalnız eksik olanlar
// TMDB'ye gider. Akış/takvim gibi ekranlar 30-60 içeriği tek tek sorduğunda
// istek başına o kadar veritabanı gidiş-gelişi oluyordu.
//
// Dönen Map'e iki sayaç iliştirilir (Map'in kendisi bir nesne; iterasyonu
// etkilemez, eski çağıranlar hiç fark etmez):
//   .eksik → hiçbir şekilde (ne taze ne bayat) elde edilemeyen yol sayısı
//   .bayat → taze istek başarısız olduğu için ESKİ önbellekten servis edilen
// "Bayat-veriyle-devam": TMDB bir kez tökezleyince (429/ağ/5xx) o dizi
// takvimden SESSİZCE düşüyordu. Ayda bir yayınlanan dizinin 6 saat eski
// sezon verisi, diziyi takvimden silmekten kat kat iyidir.
async function tmdbTopluGetir(yollar, ttlSn = ONBELLEK_TTL_SN.varsayilan, dilZorla = null) {
  const dil = dilZorla || istekBaglam.getStore()?.tmdbDil || 'tr-TR';
  const anahtarla = (yol) => (/[?&]language=/.test(yol)
    ? yol.replace(/([?&]language=)[a-zA-Z-]+/, `$1${dil}`)
    : yol + (yol.includes('?') ? '&' : '?') + 'language=' + dil);
  const benzersiz = [...new Set(yollar)];
  const sonuc = new Map();
  sonuc.eksik = 0;
  sonuc.bayat = 0;
  if (!benzersiz.length) return sonuc;
  const anahtarlar = benzersiz.map(anahtarla);
  const { rows } = await havuz.query(
    `SELECT anahtar, veri FROM tmdb_onbellek
     WHERE anahtar = ANY($1::text[]) AND guncelleme > now() - ($2 || ' seconds')::interval`,
    [anahtarlar, ttlSn],
  );
  const onbellek = new Map(rows.map((r) => [r.anahtar, r.veri]));
  const eksik = [];
  benzersiz.forEach((yol, i) => {
    const v = onbellek.get(anahtarlar[i]);
    if (v !== undefined) sonuc.set(yol, v);
    else eksik.push(yol);
  });
  // Eksikler: 8'li öbekler (tmdbGetir tek tek önbelleğe de yazar)
  const basarisiz = [];
  for (let i = 0; i < eksik.length; i += 8) {
    const obek = eksik.slice(i, i + 8);
    const veriler = await Promise.all(
      obek.map((y) => tmdbGetir(y, ttlSn, dilZorla).catch((e) => {
        // SESSİZ YUTMA YOK: hangi yol, hangi hata — günlüğe düşsün.
        console.error(`tmdb hata: ${anahtarla(y)} -> ${e?.message || e}`);
        return null;
      })),
    );
    obek.forEach((y, j) => {
      if (veriler[j] != null) sonuc.set(y, veriler[j]);
      else basarisiz.push(y);
    });
  }
  // Bayat-veriyle-devam: taze istek başarısızsa TTL'i geçmiş ESKİ satırı kullan.
  if (basarisiz.length) {
    const bayatAnahtarlar = basarisiz.map(anahtarla);
    let bayatHarita = new Map();
    try {
      const { rows: bayatSatirlar } = await havuz.query(
        `SELECT anahtar, veri FROM tmdb_onbellek WHERE anahtar = ANY($1::text[])`,
        [bayatAnahtarlar],
      );
      bayatHarita = new Map(bayatSatirlar.map((r) => [r.anahtar, r.veri]));
    } catch (e) {
      console.error(`tmdb bayat okuma hatasi: ${e?.message || e}`);
    }
    basarisiz.forEach((y, i) => {
      const v = bayatHarita.get(bayatAnahtarlar[i]);
      if (v !== undefined) {
        sonuc.set(y, v);
        sonuc.bayat++;
      } else {
        sonuc.eksik++;
        console.error(`tmdb elde edilemedi (bayat kopya da yok): ${bayatAnahtarlar[i]}`);
      }
    });
  }
  return sonuc;
}

// Latin alfabesi kullanan bir kullanıcıya Çince/Japonca/Korece/Kiril başlık
// göstermek işe yaramaz: TMDB o dilde çevirisi olmayan yapımda ORİJİNAL adı
// döndürür. Böyle başlıkları (ve boş özetleri) İngilizcesiyle değiştiririz.
const LATIN_DISI_AD =
  /[\u3040-\u30ff\u4e00-\u9fff\uac00-\ud7af\u0400-\u04ff\u0600-\u06ff\u0e00-\u0e7f\u0900-\u097f\u0590-\u05ff]/;
const LATIN_DILLER = new Set([
  'tr', 'en', 'es', 'pt', 'fr', 'it', 'de', 'nl', 'sv', 'da', 'nb', 'pl',
  'cs', 'ro', 'hu', 'fi', 'id', 'ms', 'fil', 'sw', 'vi', 'az', 'hr', 'sq',
]);
function latinDisiMi(v) {
  return !!v && LATIN_DISI_AD.test(String(v.name || v.title || ''));
}

// Türkçe başlıklardan HANGİSİ gerçekten kullanılıyor?
// TMDB'nin Türkçe başlığı bazen kimsenin demediği birebir çeviri oluyor
// ("Man of Steel" → "Çelik Adam"). Varsayılan olarak ORİJİNAL adı gösteririz;
// Türkçesi yerleşmiş klasikler bu listede istisna tutulur.
const TURKCE_ADI_YAYGIN = new Set([
  120, 121, 122,          // Yüzüklerin Efendisi üçlemesi
  122917, 57158, 49051,   // Hobbit üçlemesi
  22, 58, 285, 1865, 166426, // Karayip Korsanları serisi
  671, 672, 673, 674, 675, 767, 12444, 12445, // Harry Potter serisi
  11, 1891, 1892, 1893, 1894, 1895, 140607, 181808, 181812, // Star Wars
  862, 863, 10193, 301528, // Oyuncak Hikayesi
  354912, 508442, 12,      // Coco, Soul, Kayıp Balık Nemo
  278, 238, 240, 424,      // Esaretin Bedeli, Baba 1-2, Schindler'in Listesi
]);
/// Gösterilecek adı seçer: orijinal ad Latin alfabesindeyse ONU tercih eder
/// (izleyici genelde orijinal adı kullanır); Türkçesi yerleşmiş yapımlarda ve
/// orijinali okunamayan (Çince/Japonca/Korece) yapımlarda yerel adı bırakır.
function adTercihUygula(v) {
  if (!v || typeof v !== 'object') return v;
  const orijinal = v.original_title || v.original_name;
  const yerel = v.title || v.name;
  if (!orijinal || !yerel || orijinal === yerel) return v;
  if (TURKCE_ADI_YAYGIN.has(v.id)) return v;
  if (LATIN_DISI_AD.test(String(orijinal))) return v; // orijinali okunamaz
  return v.title ? { ...v, title: orijinal } : { ...v, name: orijinal };
}
function ingilizceBirlestir(v, e) {
  if (!e) return v;
  return {
    ...v,
    name: e.name || v.name,
    title: e.title || v.title,
    overview: v.overview || e.overview,
  };
}
/// Yanıttaki (liste ya da tekil) okunamayan başlıkları İngilizcesiyle değiştirir.
async function latinAdaDus(veri, yol, ttlSn) {
  const dil = istekBaglam.getStore()?.dil || 'tr';
  if (!LATIN_DILLER.has(dil)) return veri; // Kiril/Arap kullanıcıda gerek yok
  const liste = Array.isArray(veri?.results) ? veri.results : null;
  if (liste) {
    let sonuc = liste;
    if (liste.some(latinDisiMi)) {
      const en = await tmdbGetir(yol, ttlSn, 'en-US').catch(() => null);
      if (Array.isArray(en?.results)) {
        const harita = new Map(en.results.map((r) => [r.id, r]));
        sonuc = liste.map((r) => (latinDisiMi(r) ? ingilizceBirlestir(r, harita.get(r.id)) : r));
      }
    }
    return { ...veri, results: sonuc.map(adTercihUygula) };
  }
  if (latinDisiMi(veri)) {
    const en = await tmdbGetir(yol, ttlSn, 'en-US').catch(() => null);
    return adTercihUygula(ingilizceBirlestir(veri, en));
  }
  return adTercihUygula(veri);
}

// ---------- gönderi dili + çeviri ----------
// Dış servis YOK: yazı sistemi + sık kelime sezgisiyle kaynak dili kestirir.
// Amaç kusursuz tespit değil, "bu gönderi zaten kullanıcının dilinde mi?"
// sorusuna yetecek isabet; yanılırsa en fazla gereksiz bir çevir düğmesi çıkar.
const YAZI_SISTEMI = [
  [/[\u3040-\u30ff]/, 'ja'], [/[\uac00-\ud7af]/, 'ko'],
  [/[\u0e00-\u0e7f]/, 'th'], [/[\u0590-\u05ff]/, 'he'],
  [/[\u0600-\u06ff]/, 'ar'], [/[\u0900-\u097f]/, 'hi'],
  [/[\u0980-\u09ff]/, 'bn'], [/[\u0400-\u04ff]/, 'ru'],
  [/[\u0370-\u03ff]/, 'el'], [/[\u4e00-\u9fff]/, 'zh'],
];
// Latin alfabesi: ayırt edici kelimeler (küçük harfe indirgenmiş metinde aranır)
const DIL_KELIMELERI = {
  tr: ['bir','ve','bu','için','çok','ama','daha','ben','sen','değil','gibi','olan','şey','yok','var'],
  en: ['the','and','is','of','to','in','this','that','with','you','for','was','are','it'],
  es: ['el','la','de','que','los','una','por','con','para','como','pero','más'],
  pt: ['de','que','não','uma','com','para','mais','como','mas','muito'],
  fr: ['le','la','les','des','une','pour','avec','dans','pas','plus','être'],
  de: ['der','die','das','und','ist','nicht','für','mit','auch','eine','aber'],
  it: ['il','la','di','che','per','non','con','una','sono','anche','più'],
  nl: ['de','het','een','van','en','is','niet','voor','met','maar'],
  pl: ['nie','się','jest','tak','ale','jak','tym','czy'],
  id: ['yang','dan','ini','itu','untuk','dengan','tidak','saya'],
  vi: ['của','và','các','một','người','những','được','trong'],
};
function dilTespit(ham) {
  const metin = String(ham || '')
    .replace(/[#@][\w._-]+/g, ' ')   // etiket ve kullanıcı adları dile karışmasın
    .replace(/https?:\/\/\S+/g, ' ')
    .trim();
  if (metin.length < 3) return null;
  for (const [desen, kod] of YAZI_SISTEMI) {
    if (desen.test(metin)) return kod;
  }
  const kucuk = ' ' + metin.toLowerCase().replace(/[^\p{L}\s]/gu, ' ').replace(/\s+/g, ' ') + ' ';
  const puanlar = {};
  for (const [kod, kelimeler] of Object.entries(DIL_KELIMELERI)) {
    puanlar[kod] = kelimeler.reduce((t, k) => t + (kucuk.includes(` ${k} `) ? 1 : 0), 0);
  }
  // Türkçeye özgü harfler güçlü kanıt
  if (/[ğışİĞİŞ]/.test(metin)) puanlar.tr += 2;
  const [enIyi, puan] = Object.entries(puanlar).sort((a, b) => b[1] - a[1])[0];
  if (puan >= 2) return enIyi;
  if (puan === 1) return enIyi;
  // Ayırt edici kelime yok (çok kısa/emoji): Türkçe harf varsa tr, yoksa bilinmiyor
  return /[ğışçöüĞİŞÇÖÜ]/.test(metin) ? 'tr' : null;
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
// GÜVENLİK: banlanan/şifresi değişen kullanıcının eski token'ı burada da
// geçersizdir (girisZorunlu ile aynı sürüm kontrolü); aksi halde banlı
// kullanıcı okuma uçlarında hâlâ kimlik olarak sayılırdı. Doğrulama
// başarısızsa istek anonim devam eder (uç yine de çalışır).
async function girisIsteğeBagli(req, _res, next) {
  const baslik = req.headers.authorization || '';
  const token = baslik.startsWith('Bearer ') ? baslik.slice(7) : null;
  if (token) {
    try {
      const kimlik = jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
      if (await sifreSurumuGecerli(kimlik.id, kimlik.sv)) req.kullanici = kimlik;
    } catch { /* anonim */ }
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
    // Beğeni/yanıt/etiket: dokununca doğrudan o gönderiye gidilebilsin
    if (ekstra?.yorum_id) veri.yorum_id = String(ekstra.yorum_id);
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

// Bildirim türü → alıcının kapatabildiği tercih kolonu (sabit; kullanıcı verisi değil).
const BILDIRIM_TERCIH_KOLON = {
  begeni: 'bildir_begeni',
  yanit: 'bildir_yanit',
  takip: 'bildir_takip',
  mesaj: 'bildir_mesaj',
  etiket: 'bildir_etiket',
};

async function bildirimEkle(aliciId, tur, aktorId, yorumId = null, pushEkstra = null) {
  if (!aliciId || aliciId === aktorId) return;
  // Alıcı bu türü kapattıysa ne uygulama-içi bildirim ne de push gönder.
  const kolon = BILDIRIM_TERCIH_KOLON[tur];
  if (kolon) {
    const t = await havuz
      .query(`SELECT ${kolon} AS ac FROM kullanicilar WHERE id=$1`, [aliciId])
      .catch(() => ({ rows: [] }));
    if (t.rows.length && t.rows[0].ac === false) return;
  }
  await havuz.query(
    'INSERT INTO bildirimler (kullanici_id, tur, aktor_id, yorum_id) VALUES ($1,$2,$3,$4)',
    [aliciId, tur, aktorId, yorumId],
  ).catch(() => {});
  // Push data'sına yorum_id de gider (dokununca doğrudan gönderiye)
  pushBildirim(aliciId, tur, aktorId, { ...(pushEkstra || {}), yorum_id: yorumId });
}

// Metindeki @kullanici_adi etiketlerini bulup 'etiket' bildirimi gönderir.
// Kullanıcı adları küçük harf/rakam/nokta/tire/alt çizgi 3-20 karakter (kayıt kuralıyla aynı);
// başta/sonda nokta-tire olmaz ki cümle sonu noktası ada yapışmasın.
// haricId: bu id'ye ayrı bildirim gidiyorsa (ör. yanıtlanan) çift bildirim engellenir.
async function etiketBildirimleriGonder(metin, aktorId, yorumId, haricId = null) {
  const bulunan = new Set();
  const re = /@([a-z0-9_][a-z0-9_.-]{1,18}[a-z0-9_])/g;
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

// Sürüm kapısı: uygulama açılışta kendi derleme numarasını sorar.
// zorunlu=true ise kapatılamayan güncelleme ekranı, oneri=true ise
// kapatılabilir uyarı gösterilir. Ayar yoksa ikisi de false (kimse engellenmez).
// Ayarlar nadiren değişir; 60 sn bellek önbelleği ile her açılışta DB'ye gidilmez.
let AYAR_ONBELLEK = { ts: 0, deger: {} };
async function ayarlariGetir() {
  if (Date.now() - AYAR_ONBELLEK.ts < 60000) return AYAR_ONBELLEK.deger;
  const { rows } = await havuz.query('SELECT anahtar, deger FROM ayarlar');
  AYAR_ONBELLEK = { ts: Date.now(), deger: Object.fromEntries(rows.map((r) => [r.anahtar, r.deger])) };
  return AYAR_ONBELLEK.deger;
}
app.get('/surum-kontrol', sarici(async (req, res) => {
  const a = await ayarlariGetir();
  const derleme = parseInt(req.query.derleme, 10);
  const min = parseInt(a.min_derleme, 10);
  const oneri = parseInt(a.onerilen_derleme, 10);
  const gecerli = Number.isInteger(derleme) && derleme > 0;
  res.json({
    zorunlu: gecerli && Number.isInteger(min) ? derleme < min : false,
    oneri: gecerli && Number.isInteger(oneri) ? derleme < oneri : false,
    min_derleme: Number.isInteger(min) ? min : null,
    onerilen_derleme: Number.isInteger(oneri) ? oneri : null,
    url: a.guncelleme_url || null,
    not: a.guncelleme_notu || null,
  });
}));

// ---------- OG / link önizleme (bot'lar için) ----------
// Flutter SPA'nın index.html'inde içerik-özel meta yok; WhatsApp/Twitter/
// Facebook gibi botlar JS çalıştırmaz. nginx bot User-Agent'ını /og/...'e
// yönlendirir; bu uçlar paylaşılan içeriğe göre OG/Twitter meta'lı küçük HTML
// döndürür (gerçek tarayıcılar normal Flutter index.html'i alır).
function htmlKacir(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}
// SEO — canonical TEK yerde üretilir (SEO-PLANI 0.3): her zaman apex host,
// sorgu parametresiz ve sondaki eğik çizgi olmadan. www, trailing slash ve
// UTM yinelemeleri böylece tek hamlede birleşir.
const SITE_KOK = 'https://dizijpg.com';
function kanonikUrl(url) {
  let yol;
  try { yol = new URL(String(url ?? ''), SITE_KOK).pathname; } catch { yol = '/'; }
  yol = yol.replace(/\/+$/, ''); // sondaki eğik çizgi (kök hariç)
  return SITE_KOK + (yol || '/');
}

// `indexle=false` -> noindex,follow: sayfa indekse girmez ama iç bağlantılar
// takip edilir. Kural için `ozgunIcerikVar()`e bakınız (tek tanım noktası).
function ogSayfa({ baslik, aciklama, gorsel, url, tur = 'website',
                   canonical, indexle = true }) {
  const b = htmlKacir(baslik);
  const a = htmlKacir(String(aciklama || '').replace(/\s+/g, ' ').trim().slice(0, 200));
  const g = htmlKacir(gorsel || '');
  const u = htmlKacir(url);
  const kan = htmlKacir(kanonikUrl(canonical || url));
  const gorselKart = g ? 'summary_large_image' : 'summary';
  return `<!doctype html><html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${b}</title>
<meta name="description" content="${a}">
<link rel="canonical" href="${kan}">${indexle ? '' : '\n<meta name="robots" content="noindex,follow">'}
<meta property="og:type" content="${htmlKacir(tur)}">
<meta property="og:site_name" content="dizi.jpg">
<meta property="og:title" content="${b}">
<meta property="og:description" content="${a}">${g ? `\n<meta property="og:image" content="${g}">` : ''}
<meta property="og:url" content="${u}">
<meta name="twitter:card" content="${gorselKart}">
<meta name="twitter:title" content="${b}">
<meta name="twitter:description" content="${a}">${g ? `\n<meta name="twitter:image" content="${g}">` : ''}
</head><body><h1>${b}</h1><p>${a}</p><p><a href="${u}">dizi.jpg</a></p></body></html>`;
}
const tmdbGorsel = (yol, boyut = 'w780') =>
  yol ? `https://image.tmdb.org/t/p/${boyut}${yol}` : '';

// SEO — "özgün içeriği var mı" kuralı TEK yerde (SEO-PLANI 0.3 + 0.2).
// Bir sayfa yalnızca yasaklı OLMAYAN bir kullanıcının o içeriğe yazdığı en az
// bir yorum VEYA inceleme metni varsa indekslenmeye değer sayılır. Aynı kural
// sitemap kapsamını da belirler (SITEMAP_SORGU); iki yerde ayrı yazılırsa
// sitemap'e girip noindex yiyen (ya da tersi) sayfalar oluşur.
async function ozgunIcerikVar(tur, tmdbId) {
  try {
    const { rows } = await havuz.query(
      `SELECT 1 WHERE EXISTS (
         SELECT 1 FROM yorumlar y JOIN kullanicilar k ON k.id = y.kullanici_id
          WHERE y.tur = $1 AND y.tmdb_id = $2 AND NOT k.yasakli)
        OR EXISTS (
         SELECT 1 FROM puanlar p JOIN kullanicilar k ON k.id = p.kullanici_id
          WHERE p.tur = $1 AND p.tmdb_id = $2 AND NOT k.yasakli
            AND p.yorum IS NOT NULL AND btrim(p.yorum) <> '')`,
      [tur, tmdbId]);
    return rows.length > 0;
  } catch (e) {
    // DB hatasında İNDEKSLE tarafına düş: geçici bir arıza yüzünden değerli
    // sayfaların indeksten düşmesi, birkaç ince sayfanın taranmasından pahalı.
    console.error('ozgunIcerikVar', e.message);
    return true;
  }
}

app.get('/og/icerik/:tur/:tmdbId', sarici(async (req, res) => {
  const { tur, tmdbId } = req.params;
  const id = parseInt(tmdbId, 10);
  const url = `https://dizijpg.com/icerik/${tur}/${tmdbId}`;
  if (!['tv', 'movie'].includes(tur) || !gecerliTmdb(id)) {
    return res.type('html').send(ogSayfa({ baslik: 'dizi.jpg', url, indexle: false }));
  }
  try {
    const v = await tmdbGetir(`/${tur}/${tmdbId}`, ONBELLEK_TTL_SN.uzun);
    const ad = v.name || v.title || 'dizi.jpg';
    const yil = String(v.first_air_date || v.release_date || '').slice(0, 4);
    res.type('html').send(ogSayfa({
      baslik: `${ad}${yil ? ` (${yil})` : ''} — dizi.jpg`,
      aciklama: v.overview,
      gorsel: tmdbGorsel(v.poster_path) || tmdbGorsel(v.backdrop_path, 'w1280'),
      url,
      canonical: `${SITE_KOK}/icerik/${tur}/${id}`,
      indexle: await ozgunIcerikVar(tur, id),
      tur: tur === 'tv' ? 'video.tv_show' : 'video.movie',
    }));
  } catch {
    // TMDB'de bulunamadı/erişilemedi -> indekse girmesin (soft 404).
    res.type('html').send(ogSayfa({ baslik: 'dizi.jpg', url, indexle: false }));
  }
}));

app.get('/og/kisi/:id', sarici(async (req, res) => {
  const kid = parseInt(req.params.id, 10);
  const url = `https://dizijpg.com/kisi/${req.params.id}`;
  if (!gecerliTmdb(kid)) {
    return res.type('html').send(ogSayfa({ baslik: 'dizi.jpg', url, indexle: false }));
  }
  try {
    const v = await tmdbGetir(`/person/${req.params.id}`, ONBELLEK_TTL_SN.uzun);
    res.type('html').send(ogSayfa({
      baslik: `${v.name || 'dizi.jpg'} — dizi.jpg`,
      aciklama: v.biography || 'dizi.jpg üzerinde keşfet.',
      gorsel: tmdbGorsel(v.profile_path, 'w500'),
      url,
      canonical: `${SITE_KOK}/kisi/${kid}`,
      // Kişi sayfaları da aynı kurala tabi: özgün yorum yoksa TMDB kopyasıdır,
      // indekse girmesin ama bağlantıları takip edilsin (sınırsız tarama alanı).
      indexle: await ozgunIcerikVar('person', kid),
      tur: 'profile',
    }));
  } catch {
    res.type('html').send(ogSayfa({ baslik: 'dizi.jpg', url, indexle: false }));
  }
}));

app.get('/og/gonderi/:id', sarici(async (req, res) => {
  const id = parseInt(req.params.id, 10);
  const url = `https://dizijpg.com/gonderi/${req.params.id}`;
  if (!gecerliTmdb(id)) {
    return res.type('html').send(ogSayfa({ baslik: 'dizi.jpg', url, indexle: false }));
  }
  try {
    const { rows } = await havuz.query(
      `SELECT y.metin, y.medya, y.tur, y.tmdb_id, k.kullanici_adi
       FROM yorumlar y JOIN kullanicilar k ON k.id=y.kullanici_id
       WHERE y.id=$1 AND NOT k.yasakli`, [id]);
    if (!rows.length) {
      // Gönderi yok / yazarı yasaklı -> indekslenecek içerik yok.
      return res.type('html').send(ogSayfa({ baslik: 'dizi.jpg', url, indexle: false }));
    }
    const y = rows[0];
    // Görsel: yorumun fotoğrafı (video değil) varsa o, yoksa içeriğin posteri
    const foto = (y.medya || []).find(
      (m) => !m.endsWith('.mp4') && !m.endsWith('.webm'));
    let gorsel = foto ? `https://dizijpg.com/api${foto}` : '';
    let icerikAd = '';
    try {
      const v = await tmdbGetir(`/${y.tur}/${y.tmdb_id}`, ONBELLEK_TTL_SN.uzun);
      icerikAd = v.name || v.title || '';
      if (!gorsel) gorsel = tmdbGorsel(v.poster_path);
    } catch { /* içerik alınamazsa pos+ad boş */ }
    res.type('html').send(ogSayfa({
      baslik: `@${y.kullanici_adi}${icerikAd ? ` · ${icerikAd}` : ''} — dizi.jpg`,
      aciklama: y.metin || 'dizi.jpg üzerinde bir gönderi.',
      gorsel,
      url,
      canonical: `${SITE_KOK}/gonderi/${id}`,
      // Gönderinin kendisi özgün içeriktir -> indekslenebilir.
      tur: 'article',
    }));
  } catch {
    res.type('html').send(ogSayfa({ baslik: 'dizi.jpg', url, indexle: false }));
  }
}));

// ---------- Sitemap (SEO-PLANI 0.2) ----------
// KAPSAM KURALI: yalnızca ÖZGÜN İÇERİĞİ OLAN sayfalar. Tüm TMDB kimlikleri
// konursa Google'a sınırsız tarama alanı açılır ve ince sayfalar indekslenir.
// Kapsam, `ozgunIcerikVar()` ile birebir aynı koşulu kullanır.
const SITEMAP_SORGU = `
  SELECT tur, tmdb_id, max(tarih) AS son FROM (
    SELECT y.tur, y.tmdb_id, y.tarih
      FROM yorumlar y JOIN kullanicilar k ON k.id = y.kullanici_id
     WHERE NOT k.yasakli AND y.tur IN ('tv','movie')
    UNION ALL
    SELECT p.tur, p.tmdb_id, p.tarih
      FROM puanlar p JOIN kullanicilar k ON k.id = p.kullanici_id
     WHERE NOT k.yasakli AND p.tur IN ('tv','movie')
       AND p.yorum IS NOT NULL AND btrim(p.yorum) <> ''
  ) t GROUP BY tur, tmdb_id ORDER BY son DESC`;

const SITEMAP_SAYFA_BOYU = 20000;      // sitemap başına URL (protokol sınırı 50.000)
const SITEMAP_TTL_MS = 6 * 3600 * 1000; // sorgu tüm yorum tablosunu tarar; her istekte çalışmasın
let sitemapOnbellek = { ts: 0, sayfalar: [], adet: 0 };
let sitemapUretimi = null;              // eşzamanlı istekler tek sorguyu paylaşsın

const gunTarihi = (d) => new Date(d).toISOString().slice(0, 10); // W3C: YYYY-MM-DD

async function sitemapUret() {
  const { rows } = await havuz.query(SITEMAP_SORGU);
  const sayfalar = [];
  for (let i = 0; i < rows.length; i += SITEMAP_SAYFA_BOYU) {
    sayfalar.push(rows.slice(i, i + SITEMAP_SAYFA_BOYU).map((r) => ({
      loc: `${SITE_KOK}/icerik/${r.tur}/${r.tmdb_id}`,
      lastmod: gunTarihi(r.son),
    })));
  }
  if (!sayfalar.length) sayfalar.push([]);
  return { ts: Date.now(), sayfalar, adet: rows.length };
}

async function sitemapVerisi() {
  const taze = Date.now() - sitemapOnbellek.ts < SITEMAP_TTL_MS;
  if (taze && sitemapOnbellek.sayfalar.length) return sitemapOnbellek;
  if (!sitemapUretimi) {
    sitemapUretimi = sitemapUret().then(
      (v) => { sitemapOnbellek = v; sitemapUretimi = null; return v; },
      (e) => {
        sitemapUretimi = null;
        // Üretim başarısızsa bayat önbellek, boş sitemap'ten iyidir.
        if (sitemapOnbellek.sayfalar.length) return sitemapOnbellek;
        throw e;
      });
  }
  return sitemapUretimi;
}

function sitemapGonder(res, xml) {
  res.set('Cache-Control', 'public, max-age=3600');
  res.type('application/xml').send(xml);
}

app.get('/sitemap.xml', sarici(async (_req, res) => {
  const d = await sitemapVerisi();
  const tarih = gunTarihi(d.ts || Date.now());
  const parcalar = ['genel', ...d.sayfalar.map((_, i) => `icerik-${i + 1}`)];
  sitemapGonder(res, `<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${parcalar.map((p) =>
    `  <sitemap><loc>${SITE_KOK}/sitemap-${p}.xml</loc><lastmod>${tarih}</lastmod></sitemap>`
  ).join('\n')}
</sitemapindex>
`);
}));

app.get('/sitemap-genel.xml', sarici(async (_req, res) => {
  sitemapGonder(res, `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>${SITE_KOK}/</loc><changefreq>daily</changefreq><priority>1.0</priority></url>
</urlset>
`);
}));

// Yol ".xml" ile bittiği için düz string rota yerine regex (path-to-regexp
// nokta+parametre bileşimini beklendiği gibi ayırmıyor).
app.get(/^\/sitemap-icerik-(\d+)\.xml$/, sarici(async (req, res) => {
  const d = await sitemapVerisi();
  const n = parseInt(req.params[0], 10);
  const sayfa = d.sayfalar[n - 1];
  if (!sayfa) return res.status(404).type('text/plain').send('yok');
  sitemapGonder(res, `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${sayfa.map((u) =>
    `  <url><loc>${htmlKacir(u.loc)}</loc><lastmod>${u.lastmod}</lastmod>`
    + `<changefreq>weekly</changefreq><priority>0.8</priority></url>`
  ).join('\n')}
</urlset>
`);
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
  if (!/^(?!.*\.\.)[a-z0-9_][a-z0-9_.-]{1,18}[a-z0-9_]$/.test(kullanici_adi)) {
    return res.status(400).json({ hata: 'Kullanıcı adı 3-20 karakter; küçük harf, rakam, nokta, tire ve alt çizgi kullanılabilir (başta/sonda nokta-tire olamaz)' });
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
  if (kullanici_adi && !/^(?!.*\.\.)[a-z0-9_][a-z0-9_.-]{1,18}[a-z0-9_]$/.test(kullanici_adi)) {
    return res.status(400).json({ hata: 'Kullanıcı adı 3-20 karakter; küçük harf, rakam, nokta, tire ve alt çizgi kullanılabilir (başta/sonda nokta-tire olamaz)' });
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

// Google ile giriş/kayıt: istemci Google'dan aldığı kimliği yollar, sunucu
// Google'a doğrulatır. Android id_token, web ise erişim token'ı gönderir
// (GIS web akışı id_token vermiyor). E-posta doğrulanmış Google hesabı =
// e-posta sahipliği kanıtı: hesap varsa girilir, yoksa oluşturulur.
const GOOGLE_ISTEMCI = '1026295944597-alc4fpkc2gvtn1qmq92hols5oba98h55.apps.googleusercontent.com';

app.post('/auth/google', authLimiti, sarici(async (req, res) => {
  const { kimlik, erisim } = req.body || {};
  let bilgi = null;
  try {
    if (kimlik) {
      const c = await fetch('https://oauth2.googleapis.com/tokeninfo?id_token=' + encodeURIComponent(kimlik));
      if (c.ok) {
        const d = await c.json();
        if (d.aud === GOOGLE_ISTEMCI && String(d.email_verified) === 'true') {
          bilgi = { email: d.email };
        }
      }
    } else if (erisim) {
      // Erişim token'ı iki adımda: önce bizim istemciye mi verilmiş (aud),
      // sonra e-posta kime ait (userinfo).
      const t = await fetch('https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=' + encodeURIComponent(erisim));
      if (t.ok) {
        const ti = await t.json();
        if (ti.aud === GOOGLE_ISTEMCI || ti.azp === GOOGLE_ISTEMCI) {
          const u = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
            headers: { Authorization: 'Bearer ' + erisim },
          });
          if (u.ok) {
            const d = await u.json();
            if (d.email_verified) bilgi = { email: d.email };
          }
        }
      }
    }
  } catch { /* ağ hatası → aşağıda 401 */ }
  if (!bilgi?.email) {
    return res.status(401).json({ hata: 'Google doğrulaması başarısız' });
  }

  const email = bilgi.email.toLowerCase();
  const mevcut = await havuz.query(
    'SELECT * FROM kullanicilar WHERE email = lower($1)', [email]);
  if (mevcut.rows.length) {
    const k = mevcut.rows[0];
    if (k.yasakli) return res.status(403).json({ hata: 'Hesabın askıya alındı' });
    const { id, kullanici_adi, email: eposta, misafir } = k;
    return res.json({
      token: jwtUret(k),
      kullanici: { id, kullanici_adi, email: eposta, misafir },
      yeni: false,
    });
  }
  // Yeni hesap: ad e-postanın ön ekinden türetilir, çakışırsa sonek eklenir.
  // Şifre alanına rastgele hash yazılır; kullanıcı isterse şifre sıfırlama ile belirler.
  let kok = email.split('@')[0].replace(/[^a-z0-9_.-]/g, '').replace(/\.{2,}/g, '.')
    .replace(/^[.-]+|[.-]+$/g, '').slice(0, 15);
  if (kok.length < 3) kok = 'kullanici';
  for (let deneme = 0; deneme < 6; deneme++) {
    const ad = deneme === 0 ? kok : kok.slice(0, 12) + '_' + crypto.randomBytes(2).toString('hex');
    try {
      const { rows } = await havuz.query(
        `INSERT INTO kullanicilar (email, kullanici_adi, sifre_hash)
         VALUES (lower($1), $2, $3)
         RETURNING id, kullanici_adi, email, misafir`,
        [email, ad, await bcrypt.hash(crypto.randomBytes(16).toString('hex'), 10)],
      );
      return res.json({ token: jwtUret(rows[0]), kullanici: rows[0], yeni: true });
    } catch (e) {
      if (e.code !== '23505') throw e; // ad çakıştıysa yeniden dene
    }
  }
  res.status(500).json({ hata: 'Hesap oluşturulamadı' });
}));

// ---------- TMDB proxy (beyaz listeli) ----------
const TMDB_IZINLI = [
  /^\/trending\/(tv|movie|all)\/(day|week)$/,
  /^\/search\/(tv|movie|multi|person)$/,
  /^\/discover\/(tv|movie)$/,
  /^\/(tv|movie)\/\d+$/,
  /^\/tv\/\d+\/season\/\d+$/,
  /^\/tv\/\d+\/season\/\d+\/episode\/\d+$/,
  /^\/tv\/\d+\/season\/\d+\/episode\/\d+\/images$/, // bölüm kareleri (stills)
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
  parametreler.delete('dil'); // yalnız önbellek anahtarı için vardı
  // /images uçlarında `language` görselleri DİLE GÖRE SÜZER: bölüm kareleri
  // dilsiz (iso_639_1: null) olduğu için language=tr-TR boş liste döndürür.
  // Dil parametresini tamamen düşürüp tüm kareleri alıyoruz (metin yok).
  if (/\/images$/.test(yol)) {
    parametreler.delete('language');
  } else if (!parametreler.has('language')) {
    parametreler.set('language', 'tr-TR');
  }
  // Detay sayfalarına ek verileri tek istekte iliştir.
  if (/^\/(tv|movie)\/\d+$/.test(yol) && !parametreler.has('append_to_response')) {
    parametreler.set('append_to_response', 'credits,videos,recommendations,external_ids,watch/providers');
  }
  const tam = `${yol}?${parametreler.toString()}`;
  const uzunTtl = /^\/(tv|movie|person)\//.test(yol);
  // Katalog verisi herkeste AYNI (kişiye özel alan yok) → Cloudflare kenarında
  // önbelleklensin: istek Amerika'daki sunucuya gitmeden en yakın kenardan
  // döner. Dil adreste (?dil=xx) taşındığı için diller karışmaz.
  res.set(
    'Cache-Control',
    `public, max-age=${uzunTtl ? 86400 : 3600}, s-maxage=${uzunTtl ? 604800 : 21600}`,
  );
  const ttl = uzunTtl ? ONBELLEK_TTL_SN.uzun : ONBELLEK_TTL_SN.varsayilan;
  res.json(await latinAdaDus(await tmdbGetir(tam, ttl), tam, ttl));
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

// Büyüyen tabloların günlük budaması (sınırsız şişmeyi önler). Süresi geçen
// akış-görüldü kayıtları, eski TMDB önbelleği, görüntülenme izleri ve hata
// günlükleri silinir. Popüler fallback zaten 30 günden eskiyi önemsemez.
async function tablolariBuda() {
  const isler = [
    `DELETE FROM akis_goruldu WHERE tarih < now() - interval '30 days'`,
    `DELETE FROM tmdb_onbellek WHERE guncelleme < now() - interval '30 days'`,
    `DELETE FROM yorum_goruntuleyen WHERE tarih < now() - interval '90 days'`,
    `DELETE FROM hatalar WHERE tarih < now() - interval '30 days'`,
  ];
  for (const sql of isler) {
    try { await havuz.query(sql); } catch (e) { console.error('buda:', e.message); }
  }
}
setInterval(tablolariBuda, 24 * 60 * 60 * 1000);
setTimeout(tablolariBuda, 5 * 60 * 1000); // açılıştan 5 dk sonra

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
app.get('/izleyenler/:tur/:tmdbId', girisIsteğeBagli, sarici(async (req, res) => {
  const { tur } = req.params;
  const tmdbId = Number(req.params.tmdbId);
  if (!['tv', 'movie'].includes(tur) || !gecerliTmdb(tmdbId)) {
    return res.status(400).json({ hata: 'Geçersiz tür veya tmdb_id' });
  }
  const benId = req.kullanici?.id || 0;
  // Gizlilik: izlenenlerini gizleyen ya da BU içeriği gizleyen kullanıcı
  // listede/sayılarda görünmez (kendisi hariç).
  const gizliYok = `AND (k.id = $3 OR (
        k.izlenenler_gizli = false
        AND NOT EXISTS (SELECT 1 FROM gizli_icerikler g
              WHERE g.kullanici_id=k.id AND g.tur=$1 AND g.tmdb_id=$2)))`;
  const [sayi, kullanicilar, takip] = await Promise.all([
    havuz.query(
      `SELECT COUNT(DISTINCT i.kullanici_id)::int AS n
       FROM izlemeler i JOIN kullanicilar k ON k.id = i.kullanici_id AND k.misafir = false
       WHERE i.tur=$1 AND i.tmdb_id=$2 ${gizliYok}`,
      [tur, tmdbId, benId],
    ),
    // Takip ettiklerin ÖNCE (sosyal kanıt), sonra son izleyen sırasıyla.
    havuz.query(
      `SELECT k.kullanici_adi, k.avatar,
              EXISTS (SELECT 1 FROM takipler t
                      WHERE t.takip_eden_id=$3 AND t.takip_edilen_id=k.id) AS takip_ediyorum
       FROM (SELECT kullanici_id, MAX(tarih) AS son FROM izlemeler
             WHERE tur=$1 AND tmdb_id=$2 GROUP BY kullanici_id) i
       JOIN kullanicilar k ON k.id = i.kullanici_id AND k.misafir = false
       WHERE true ${gizliYok}
       ORDER BY (EXISTS (SELECT 1 FROM takipler t
                 WHERE t.takip_eden_id=$3 AND t.takip_edilen_id=k.id)) DESC,
                i.son DESC NULLS LAST, k.kullanici_adi
       LIMIT 200`,
      [tur, tmdbId, benId],
    ),
    // "Takip ettiğin N kişi izledi" tam sayısı
    benId
      ? havuz.query(
          `SELECT COUNT(DISTINCT i.kullanici_id)::int AS n
           FROM izlemeler i
           JOIN takipler t ON t.takip_edilen_id=i.kullanici_id AND t.takip_eden_id=$3
           JOIN kullanicilar k ON k.id = i.kullanici_id
           WHERE i.tur=$1 AND i.tmdb_id=$2 ${gizliYok}`,
          [tur, tmdbId, benId],
        )
      : Promise.resolve({ rows: [{ n: 0 }] }),
  ]);
  res.json({
    sayi: sayi.rows[0].n,
    kullanicilar: kullanicilar.rows,
    takip_sayi: takip.rows[0].n,
  });
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
  const [izleme, durum, puan, favori, kaynak, gizli] = await Promise.all([
    havuz.query('SELECT sezon, bolum FROM izlemeler WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('SELECT durum, tekrar FROM durumlar WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('SELECT puan, yorum FROM puanlar WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('SELECT 1 FROM favoriler WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('SELECT platform FROM izleme_kaynaklari WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('SELECT 1 FROM gizli_icerikler WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
  ]);
  res.json({
    izlenenler: izleme.rows,
    durum: durum.rows[0]?.durum || null,
    tekrar: durum.rows[0]?.tekrar || 0,
    puan: puan.rows[0] || null,
    favori: favori.rows.length > 0,
    kaynak: kaynak.rows[0]?.platform || null,
    gizli: gizli.rows.length > 0,
  });
}));

// #6 Yeniden izleme sayacı: yalnız "bitirdim" durumundaki içerikte artırılır
// (Letterboxd tarzı). deger=+1/-1 (geri alma). 0'ın altına inmez, üst sınır 99.
app.post('/rewatch', girisZorunlu, sarici(async (req, res) => {
  const { tur, tmdb_id } = req.body || {};
  const deger = req.body?.deger === -1 ? -1 : 1;
  if (!['tv', 'movie'].includes(tur) || !gecerliTmdb(tmdb_id)) {
    return res.status(400).json({ hata: 'Geçersiz tür veya tmdb_id' });
  }
  const { rows } = await havuz.query(
    `UPDATE durumlar SET tekrar = LEAST(99, GREATEST(0, tekrar + $4)), guncelleme = now()
     WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3 AND durum='bitirdim'
     RETURNING tekrar`,
    [req.kullanici.id, tur, tmdb_id, deger],
  );
  if (!rows.length) {
    return res.status(400).json({ hata: 'Önce içeriği "bitirdim" olarak işaretle' });
  }
  res.json({ tekrar: rows[0].tekrar });
}));

// #9 Bildirim tercihleri: hangi bildirim türleri açık.
app.get('/bildirim-tercihleri', girisZorunlu, sarici(async (req, res) => {
  const { rows } = await havuz.query(
    'SELECT bildir_begeni, bildir_yanit, bildir_takip, bildir_mesaj, bildir_etiket FROM kullanicilar WHERE id=$1',
    [req.kullanici.id],
  );
  res.json(rows[0] || {});
}));
app.post('/bildirim-tercihleri', girisZorunlu, sarici(async (req, res) => {
  const g = req.body || {};
  // Yalnız bilinen 5 anahtar; her biri boolean'a zorlanır (eksik = değişmez).
  const alanlar = ['bildir_begeni', 'bildir_yanit', 'bildir_takip', 'bildir_mesaj', 'bildir_etiket'];
  const set = [];
  const deg = [req.kullanici.id];
  for (const a of alanlar) {
    if (typeof g[a] === 'boolean') {
      deg.push(g[a]);
      set.push(`${a}=$${deg.length}`);
    }
  }
  if (!set.length) return res.status(400).json({ hata: 'Değiştirilecek tercih yok' });
  const { rows } = await havuz.query(
    `UPDATE kullanicilar SET ${set.join(', ')} WHERE id=$1
     RETURNING bildir_begeni, bildir_yanit, bildir_takip, bildir_mesaj, bildir_etiket`,
    deg,
  );
  res.json(rows[0]);
}));

// Gizlilik tercihleri: izlenenler/yorumlar/yanıtlar açık profilde gizli mi.
// Üçü de NEGATİF polarite (true = gizli) ve varsayılanı false: yükseltme
// kimsenin profilini sessizce boşaltmaz.
app.get('/gizlilik-tercihleri', girisZorunlu, sarici(async (req, res) => {
  const { rows } = await havuz.query(
    'SELECT izlenenler_gizli, yorumlar_gizli, yanitlar_gizli FROM kullanicilar WHERE id=$1',
    [req.kullanici.id],
  );
  res.json(rows[0] || {});
}));
app.post('/gizlilik-tercihleri', girisZorunlu, sarici(async (req, res) => {
  const g = req.body || {};
  // Yalnız bilinen 3 anahtar; boolean'a zorlanır (eksik = değişmez).
  const alanlar = ['izlenenler_gizli', 'yorumlar_gizli', 'yanitlar_gizli'];
  const set = [];
  const deg = [req.kullanici.id];
  for (const a of alanlar) {
    if (typeof g[a] === 'boolean') {
      deg.push(g[a]);
      set.push(`${a}=$${deg.length}`);
    }
  }
  if (!set.length) return res.status(400).json({ hata: 'Değiştirilecek tercih yok' });
  const { rows } = await havuz.query(
    `UPDATE kullanicilar SET ${set.join(', ')} WHERE id=$1
     RETURNING izlenenler_gizli, yorumlar_gizli, yanitlar_gizli`,
    deg,
  );
  res.json(rows[0]);
}));

// İçerik bazlı gizleme: bu dizi/film açık profildeki izlenen şeritlerinde,
// yorum listesinde ve içeriğin "izleyenler" listesinde görünmez.
app.post('/gizle', girisZorunlu, sarici(async (req, res) => {
  const { tur, tmdb_id, gizli } = req.body || {};
  if (!['tv', 'movie'].includes(tur) || !gecerliTmdb(tmdb_id) || typeof gizli !== 'boolean') {
    return res.status(400).json({ hata: 'Geçersiz istek' });
  }
  if (gizli) {
    await havuz.query(
      `INSERT INTO gizli_icerikler (kullanici_id, tur, tmdb_id)
       VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`,
      [req.kullanici.id, tur, tmdb_id],
    );
  } else {
    await havuz.query(
      'DELETE FROM gizli_icerikler WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3',
      [req.kullanici.id, tur, tmdb_id],
    );
  }
  res.json({ gizli });
}));

// Geri bildirim: kullanıcı görüş/önerisi (Ayarlar > Geri Bildirim).
const geriBildirimLimiti = hizLimiti(10, (req) => `gb:${req.kullanici.id}`);
app.post('/geri-bildirim', girisZorunlu, geriBildirimLimiti, sarici(async (req, res) => {
  const metin = typeof req.body?.metin === 'string' ? req.body.metin.trim() : '';
  if (metin.length < 3 || metin.length > 2000) {
    return res.status(400).json({ hata: 'Geri bildirim 3-2000 karakter olmalı' });
  }
  // Sürüm/platform: hangi derlemeden geldiğini bilmeden "bende olmuyor"
  // raporları kovalanamıyor (eski sürümde kalmış kullanıcı düzeltilmiş hatayı
  // bildiriyor). İstemci yollamazsa NULL kalır.
  const kirp = (v) => (typeof v === 'string' ? v.slice(0, 40) : null);
  await havuz.query(
    `INSERT INTO geri_bildirimler (kullanici_id, metin, surum, platform)
     VALUES ($1,$2,$3,$4)`,
    [req.kullanici.id, metin, kirp(req.body?.surum), kirp(req.body?.platform)],
  );
  res.json({ tamam: true });
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
    // DİKKAT: burada LIMIT 60 vardı ve SIRALAMA YOKTU — 60'tan çok dizi izleyen
    // kullanıcıda hangi dizilerin geleceği rastgeleydi; izlenen dizi (ör. Silo)
    // sessizce takvimden düşüyordu. Artık izliyorum önce, son güncellenen önce
    // ve sınır 200. (Sezon/dizi verileri toplu okunduğu için maliyet düşük.)
    `SELECT tmdb_id FROM durumlar
     WHERE kullanici_id=$1 AND tur='tv' AND durum IN ('izliyorum','izleyecegim')
     ORDER BY (durum = 'izliyorum') DESC, guncelleme DESC NULLS LAST
     LIMIT 200`,
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
  // Tüm dizilerin detayı TEK sorguda önbellekten (eksikler TMDB'den);
  // eskiden dizi başına ayrı sorgu gidiyordu.
  const diziHarita = await tmdbTopluGetir(
    rows.map((r) => `/tv/${r.tmdb_id}?language=tr-TR`),
    ONBELLEK_TTL_SN.varsayilan,
  );
  // İzlenen en ileri bölüm (dizi başına)
  const enIleri = (tmdb_id) => {
    let maxS = 0;
    let maxB = 0;
    for (const r of izl.rows) {
      if (r.tmdb_id !== tmdb_id) continue;
      if (r.sezon > maxS || (r.sezon === maxS && r.bolum > maxB)) {
        maxS = r.sezon;
        maxB = r.bolum;
      }
    }
    return { maxS, maxB };
  };
  // Getirilecek sezonlar: yetişme aralığı (en ileri izlenenden +4 sezon) +
  // pencere sezonları (son yayınlanan ve sıradaki bölümün sezonları —
  // izlenen güncel bölümler de takvimde ✓ ile görünsün diye).
  const hedefSezonlar = (dizi, maxS) => {
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
    return { yetismeSezonlari, sezonNolar };
  };
  // Gereken TÜM sezonlar da tek toplu okumayla gelsin
  const sezonYollari = [];
  for (const { tmdb_id } of rows) {
    const dizi = diziHarita.get(`/tv/${tmdb_id}?language=tr-TR`);
    if (!dizi) continue;
    const { sezonNolar } = hedefSezonlar(dizi, enIleri(tmdb_id).maxS);
    for (const sn of sezonNolar) {
      sezonYollari.push(`/tv/${tmdb_id}/season/${sn}?language=tr-TR`);
    }
  }
  const sezonHarita = await tmdbTopluGetir(sezonYollari, ONBELLEK_TTL_SN.varsayilan);

  const diziIsle = async ({ tmdb_id }) => {
    try {
      const dizi = diziHarita.get(`/tv/${tmdb_id}?language=tr-TR`);
      if (!dizi) return;
      const { maxS, maxB } = enIleri(tmdb_id);
      const { yetismeSezonlari, sezonNolar } = hedefSezonlar(dizi, maxS);
      let yetEk = 0;
      let takEk = 0;
      for (const sn of [...sezonNolar].sort((a, b) => a - b)) {
        if (yetEk >= YETISME_SINIR && takEk >= TAKVIM_SINIR) break;
        const sez = sezonHarita.get(`/tv/${tmdb_id}/season/${sn}?language=tr-TR`);
        if (!sez) continue;
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
  // Eksik = getirilemeyen dizi/sezon sayısı. 0 değilse bu yanıt EKSİKTİR:
  // istemci bunu kendi önbelleğinin üstüne YAZMAMALI (eksik kopya kalıcılaşır).
  const eksik = (diziHarita.eksik || 0) + (sezonHarita.eksik || 0);
  const bayat = (diziHarita.bayat || 0) + (sezonHarita.bayat || 0);
  if (eksik || bayat) {
    console.error(
      `takvim eksik: kullanici=${req.kullanici.id} eksik=${eksik} bayat=${bayat} dizi=${rows.length}`,
    );
  }
  res.json({ takvim, yetisme, yaklasan, eksik, bayat });
}));

// ---------- profilim ----------
// Sosyal bağlantı platform beyaz listesi (app'teki listeyle aynı olmalı)
const SOSYAL_PLATFORMLAR = new Set([
  'instagram', 'facebook', 'x', 'tiktok', 'discord', 'steam', 'xbox',
  'epicgames', 'imdb', 'vk', 'youtube', 'twitch', 'spotify', 'github',
  'reddit', 'telegram', 'snapchat', 'pinterest', 'letterboxd', 'website',
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
  // 100mb: Instagram'dan aktarılan videolar özgün kalitesinde yüklensin
  // (40-70MB olabiliyor). nginx tarafında client_max_body_size 105m.
  express.raw({ type: ['image/*', 'video/*', 'audio/*', 'application/octet-stream'], limit: '100mb' }),
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
    const tamYol = path.join(MEDYA_DIZIN, dosya);
    fs.writeFileSync(tamYol, veri);
    const videoMu = VIDEO_TURLERI.includes(tur);
    // Kare çıkarma yüklemeyi ~1 sn uzatır ama ızgarayı çok hafifletir.
    const kapakVar = videoMu ? await videoKaresiCikar(tamYol) : false;
    // Altyazı işini KUYRUĞA at — yüklemeyi BEKLETMEDEN. Konuşma tanıma
    // dakikalar sürebilir; kullanıcı gönderisini beklemesin. Sunucudaki işçi
    // (araclar/altyazi_uret.js --isle --surekli) kuyruğu sırayla boşaltır.
    // Kuyruğa yazamamak yüklemeyi BOZMAZ: altyazı sonradan doldurulabilir.
    if (videoMu) {
      havuz.query(
        `INSERT INTO video_altyazi_durum (medya, durum) VALUES ($1, 'bekliyor')
         ON CONFLICT (medya) DO NOTHING`,
        [`/medya/${dosya}`],
      ).catch(() => {});
    }
    res.json({
      yol: `/medya/${dosya}`,
      video: videoMu,
      ses: SES_TURLERI.includes(tur),
      kapak: kapakVar ? `/medya/${dosya}.jpg` : null,
    });
  }));


// ---------- video altyazıları ----------
// Oynayan videonun o anki cümlesi ekranda gösterilir (sol alt). Metin
// ÇEVİRİDİR: kaynak Türkçe ise İngilizce, değilse Türkçe — gönderi metni
// çevirisiyle AYNI kural. Segmentler sunucuda whisper.cpp ile ÖNCEDEN üretilir
// (araclar/altyazi_uret.js); bu uç yalnız hazır veriyi okur, hiçbir şey üretmez.
//
// Altyazı YOKSA 200 + boş liste döner: istemci sessizce altyazısız oynatır,
// 404 gürültüsü yapmaz ve her açılışta yeniden denemez.
const ALTYAZI_DOSYA = /^m\d+-[0-9a-f]{6,32}\.(mp4|webm)$/;
// Reels'te kullanıcı bir oturumda yüzlerce video geçebilir; sınır bol tutuldu.
const altyaziLimiti = hizLimiti(900, (req) => `az:${req.kullanici?.id || req.ip}`);

app.get('/altyazi/:dosya', girisIsteğeBagli, altyaziLimiti, sarici(async (req, res) => {
  const dosya = String(req.params.dosya || '');
  if (!ALTYAZI_DOSYA.test(dosya)) {
    return res.status(400).json({ hata: 'Geçersiz medya adı' });
  }
  const medya = `/medya/${dosya}`;
  const { rows } = await havuz.query(
    `SELECT baslangic_ms, bitis_ms, metin, kaynak_dil, hedef_dil
       FROM video_altyazilar WHERE medya = $1 ORDER BY sira LIMIT 2000`,
    [medya],
  );
  // Kısa anahtar: tek videoda yüzlerce segment olabiliyor, alan adları
  // gövdenin yarısını yiyordu. b=başlangıç ms, s=son ms, m=metin.
  res.json({
    kaynak_dil: rows[0]?.kaynak_dil || null,
    hedef_dil: rows[0]?.hedef_dil || null,
    segmentler: rows.map((r) => ({
      b: r.baslangic_ms, s: r.bitis_ms, m: r.metin,
    })),
  });
}));

// Toplu içerik kartı: kitaplık/profil şeritleri 30 karo için 30 ayrı istek
// yerine TEK istek atar. Ölçüm: tek tek 30 x ~61 KB = ~1,8 MB; buradan ~3 KB.
app.post('/icerikler', girisIsteğeBagli, tmdbLimiti, sarici(async (req, res) => {
  const gelen = req.body?.anahtarlar;
  if (!Array.isArray(gelen)) {
    return res.status(400).json({ hata: 'anahtarlar dizisi gerekli' });
  }
  // "tur:id" biçimi + makul tavan (tek ekranda bu kadarı zaten görünmez)
  const anahtarlar = [...new Set(gelen)]
    .filter((a) => typeof a === 'string' && /^(tv|movie):\d{1,9}$/.test(a))
    .slice(0, 120);
  if (!anahtarlar.length) return res.json({ icerikler: {} });
  res.json({ icerikler: await icerikKartlari(anahtarlar) });
}));

// ---------- yorumlar ----------
const YORUM_TURLERI = ['tv', 'movie', 'person'];

// Tek gönderi (paylaşılan link → /gonderi/:id): yorumu + içerik bilgisini
// Reels/akış formatında döndürür. Engellenen/yasaklı kullanıcının gönderisi
// 404. Her açılışta görüntülenme +1 (tekrar görüntülemeler de sayılır).
app.get('/yorum/:id', girisIsteğeBagli, sarici(async (req, res) => {
  const yorumId = parseInt(req.params.id, 10);
  if (!gecerliTmdb(yorumId)) return res.status(400).json({ hata: 'Geçersiz id' });
  const benId = req.kullanici?.id || 0;
  const { rows } = await havuz.query(
    `SELECT y.id, y.kullanici_id, y.tur, y.tmdb_id, y.sezon, y.bolum,
            y.metin, y.medya, y.tarih, y.goruntulenme, y.spoiler,
            k.kullanici_adi, k.avatar, y.kaynak_dil,
            (SELECT c.metin FROM metin_cevirileri c
                   WHERE c.ozet = md5(btrim(y.metin)) AND c.dil = $3) AS ceviri_metin,
            (SELECT count(*)::int FROM yorum_begeniler b WHERE b.yorum_id=y.id) AS begeni,
            EXISTS(SELECT 1 FROM yorum_begeniler b
                   WHERE b.yorum_id=y.id AND b.kullanici_id=$2) AS begendim,
            EXISTS(SELECT 1 FROM takipler
                   WHERE takip_eden_id=$2 AND takip_edilen_id=y.kullanici_id) AS takip_ediyorum,
            EXISTS(SELECT 1 FROM unnest(y.medya) m
                   WHERE m LIKE '%.mp4' OR m LIKE '%.webm') AS videolu
     FROM yorumlar y JOIN kullanicilar k ON k.id=y.kullanici_id
     WHERE y.id=$1 AND NOT k.yasakli
       AND y.kullanici_id NOT IN (
         SELECT engellenen_id FROM engellemeler WHERE engelleyen_id=$2
         UNION SELECT engelleyen_id FROM engellemeler WHERE engellenen_id=$2)`,
    [yorumId, benId, istekBaglam.getStore()?.dil || 'tr'],
  );
  if (!rows.length) return res.status(404).json({ hata: 'Gönderi bulunamadı' });
  const y = rows[0];
  // Görüntülenme: HER açılış sayılır (aynı kişinin tekrarları dahil).
  havuz.query(
    'UPDATE yorumlar SET goruntulenme = goruntulenme + 1 WHERE id=$1',
    [yorumId],
  ).catch(() => {});
  // İçerik adı + poster (Reels'in beklediği icerikler haritası)
  const anahtar = `${y.tur}:${y.tmdb_id}`;
  const icerikler = {};
  try {
    const v = await tmdbGetir(`/${y.tur === 'person' ? 'person' : y.tur}/${y.tmdb_id}`, ONBELLEK_TTL_SN.uzun);
    icerikler[anahtar] = {
      ad: v.name || v.title || '?',
      poster: v.poster_path || v.profile_path || null,
    };
  } catch {
    icerikler[anahtar] = { ad: '?', poster: null };
  }
  res.json({ yorum: ceviriUygula(y), icerikler });
}));

// ROTA SIRASI ONEMLI: bu uç /yorumlar/:tur/:tmdbId'den ÖNCE kaydedilmeli.
// Sonra kaydedilseydi Express /yorumlar/4927/begenenler adresini
// tur=4927, tmdbId='begenenler' diye eşleştirir ve 400 dönerdi
// (3 Ağu'da tam bu oldu, uçtan uca curl yakaladı).
// Beğeni düğmesine BASILI TUTUNCA açılan "beğenenler" listesi.
// Oturumsuz da 200 döner (kullanıcı adları zaten herkese açık, SEO sayfaları
// oturumsuz geziliyor); o durumda takip_ediyorum hep false olur ve istemci
// takip düğmesi yerine giriş istemi gösterir.
const BEGENEN_SAYFA = 30;
const begenenLimiti = hizLimiti(300, (req) => `bg:${req.kullanici?.id || req.ip}`);

app.get('/yorumlar/:id/begenenler', girisIsteğeBagli, begenenLimiti, sarici(async (req, res) => {
  const yorumId = Number(req.params.id);
  if (!Number.isInteger(yorumId) || yorumId <= 0) {
    return res.status(400).json({ hata: 'Geçersiz yorum' });
  }
  // İmleç: "<ISO tarih>|<kullanici_id>" — son satırın anahtarı. Sıralama
  // (tarih DESC, kullanici_id DESC) olduğu için bu ikili benzersizdir ve
  // OFFSET'in aksine araya giren yeni beğenide satır tekrarlatmaz.
  const ham = String(req.query.imlec || '');
  let imlecTarih = null;
  let imlecId = null;
  if (ham) {
    const ayrac = ham.lastIndexOf('|');
    const t = ayrac > 0 ? new Date(ham.slice(0, ayrac)) : new Date(NaN);
    const i = ayrac > 0 ? Number(ham.slice(ayrac + 1)) : NaN;
    if (Number.isNaN(t.getTime()) || !Number.isInteger(i) || i <= 0) {
      return res.status(400).json({ hata: 'Geçersiz imleç' });
    }
    imlecTarih = t.toISOString();
    imlecId = i;
  }
  const benId = req.kullanici?.id || 0;

  // İlk sayfada yorumun varlığı + toplam sayı da döner (modal başlığı).
  const bas = imlecTarih
    ? null
    : await havuz.query(
      `SELECT EXISTS(SELECT 1 FROM yorumlar WHERE id=$1) AS var,
              (SELECT count(*)::int FROM yorum_begeniler WHERE yorum_id=$1) AS n`,
      [yorumId],
    );
  if (bas && !bas.rows[0].var) {
    return res.status(404).json({ hata: 'Yorum bulunamadı' });
  }

  // Bir fazlasını iste: dönen satır sayısı sayfayı aşıyorsa devamı var.
  const { rows } = await havuz.query(
    `SELECT k.id AS kullanici_id, k.kullanici_adi, k.avatar, b.tarih,
            ($2::int > 0 AND EXISTS (SELECT 1 FROM takipler t
               WHERE t.takip_eden_id=$2 AND t.takip_edilen_id=k.id)) AS takip_ediyorum,
            (k.id = $2::int) AS ben_mi
     FROM yorum_begeniler b
     JOIN kullanicilar k ON k.id = b.kullanici_id
     WHERE b.yorum_id=$1
       AND ($3::timestamptz IS NULL
            OR (b.tarih, b.kullanici_id) < ($3::timestamptz, $4::int))
       AND ($2::int = 0 OR k.id NOT IN (
              SELECT engellenen_id FROM engellemeler WHERE engelleyen_id=$2
              UNION SELECT engelleyen_id FROM engellemeler WHERE engellenen_id=$2))
     ORDER BY b.tarih DESC, b.kullanici_id DESC
     LIMIT ${BEGENEN_SAYFA + 1}`,
    [yorumId, benId, imlecTarih, imlecId],
  );
  const devam = rows.length > BEGENEN_SAYFA;
  const sayfa = devam ? rows.slice(0, BEGENEN_SAYFA) : rows;
  const son = sayfa[sayfa.length - 1];
  res.json({
    begenenler: sayfa.map((r) => ({
      kullanici_id: r.kullanici_id,
      kullanici_adi: r.kullanici_adi,
      avatar: r.avatar,
      takip_ediyorum: r.takip_ediyorum,
      ben_mi: r.ben_mi,
    })),
    imlec: devam ? `${new Date(son.tarih).toISOString()}|${son.kullanici_id}` : null,
    ...(bas ? { toplam: bas.rows[0].n } : {}),
  });
}));

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
  // Kapsam iki türlü:
  //  - sezon+bolum verildiyse (BÖLÜM sayfası): YALNIZ o bölümün yorumları.
  //    Dizi geneli oraya sızmaz, bölüm sayfası çöplüğe dönmez.
  //  - verilmediyse (DİZİ/film/kişi sayfası): dizi geneli + TÜM bölüm yorumları
  //    birlikte, tarihe göre. Eskiden "sezon IS NOT DISTINCT FROM NULL" koşulu
  //    bölüm yorumlarını dizi sayfasından tamamen dışarıda bırakıyordu.
  // Limit ÜST yorumlara uygulanır; yanıtlar üstünden koparılmasın diye ayrıca
  // toplanır (eski düz LIMIT 100 yanıtı listeye alıp üstünü dışarıda bırakabiliyordu).
  //
  // OTOMATİK SPOİLER PERDESİ (akıştaki kuralın aynısı — AKIS_GOVDE'deki
  // `guvenli` hesabının bölüm dalı): bölüm yorumu, o bölüm `izlemeler`de
  // KAYITLI DEĞİLSE bulanık gelir. Dizi sayfası artık tüm bölüm yorumlarını
  // listelediği için (7b76d08) 9. sezonu izlemeyen kişi 9. sezon yorumunu
  // açıkta görüyordu. Kapsam bilinçli olarak dar:
  //  - YALNIZ dizi/film sayfası listesinde (sezon parametresi yokken). Bölüm
  //    sayfasına kullanıcı o bölümü BİLEREK açarak gelir; oradaki davranış
  //    değişmez.
  //  - YALNIZ bölüm yorumlarında (y.sezon IS NOT NULL). Dizi geneline yazılan
  //    yorumda bölüm spoiler'ı yoktur; akıştaki `durumlar` dalını buraya
  //    taşımak, kitaplığında olmayan her diziyi baştan sona bulanık gösterirdi.
  //  - Kendi yorumun ve AI hesabının yorumları muaf (akıştaki muafiyetin aynısı).
  // İzlemeler TEK sorguda toplanır (`izlenen` CTE'si = tek indeks taraması);
  // 100 yorum için 100 ayrı izleme sorgusu ATILMAZ.
  const { rows } = await havuz.query(
    `WITH ustler AS (
       SELECT y.id FROM yorumlar y
       WHERE y.tur=$1 AND y.tmdb_id=$2 AND y.ust_id IS NULL
         AND ($3::int IS NULL OR (y.sezon = $3 AND y.bolum = $4))
       ORDER BY y.tarih DESC LIMIT 100),
     izlenen AS (
       SELECT i.sezon, i.bolum FROM izlemeler i
       WHERE $3::int IS NULL AND i.kullanici_id=$5
         AND i.tur=$1 AND i.tmdb_id=$2::int)
     SELECT y.id, y.kullanici_id, y.metin, y.medya, y.tarih, y.sezon, y.bolum,
            y.ust_id, y.goruntulenme, k.kullanici_adi, k.avatar, y.kaynak_dil,
            (y.spoiler OR (
               $3::int IS NULL AND y.sezon IS NOT NULL
               AND y.kullanici_id <> $5 AND k.kullanici_adi <> $7
               AND NOT EXISTS (SELECT 1 FROM izlenen iz
                     WHERE iz.sezon = y.sezon AND iz.bolum = y.bolum)
             )) AS spoiler,
            (SELECT c.metin FROM metin_cevirileri c
                   WHERE c.ozet = md5(btrim(y.metin)) AND c.dil = $6) AS ceviri_metin,
            (SELECT count(*)::int FROM yorum_begeniler b WHERE b.yorum_id=y.id) AS begeni,
            EXISTS(SELECT 1 FROM yorum_begeniler b
                   WHERE b.yorum_id=y.id AND b.kullanici_id=$5) AS begendim
     FROM yorumlar y JOIN kullanicilar k ON k.id = y.kullanici_id
     WHERE y.id IN (SELECT id FROM ustler)
        OR y.ust_id IN (SELECT id FROM ustler)
     ORDER BY y.tarih DESC`,
    [req.params.tur, req.params.tmdbId, sezon, bolum, benId,
     istekBaglam.getStore()?.dil || 'tr', AI_KULLANICI],
  );
  // Görüntülenme: HER listeleme sayılır (aynı kişinin tekrarları dahil).
  if (rows.length) {
    havuz.query(
      'UPDATE yorumlar SET goruntulenme = goruntulenme + 1 WHERE id = ANY($1::int[])',
      [rows.map((r) => r.id)],
    ).catch(() => {});
  }
  res.json({ yorumlar: rows.map(ceviriUygula) });
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
            y.metin, y.medya, y.tarih, y.goruntulenme, y.spoiler AS spoiler_isaret,
            k.kullanici_adi, k.avatar, g.guvenli, y.kaynak_dil,
            (SELECT c.metin FROM metin_cevirileri c
                   WHERE c.ozet = md5(btrim(y.metin)) AND c.dil = $4) AS ceviri_metin,
            (SELECT count(*)::int FROM yorum_begeniler b WHERE b.yorum_id=y.id) AS begeni,
            (SELECT count(*)::int FROM yorumlar c WHERE c.ust_id=y.id) AS yanit,
            EXISTS(SELECT 1 FROM yorum_begeniler b
                   WHERE b.yorum_id=y.id AND b.kullanici_id=$1) AS begendim,
            -- Akış kartındaki "Takip Et" düğmesi: takip ediyorsan düğme HİÇ
            -- çizilmez. Alan burada (ortak SELECT) üretilir ki /akis ve
            -- /kesfet-akis aynı sözleşmeyi döndürsün.
            EXISTS(SELECT 1 FROM takipler t
                   WHERE t.takip_eden_id=$1 AND t.takip_edilen_id=y.kullanici_id)
              AS takip_ediyorum`;
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

// ---------- SIRALAMA ALGORİTMASI (ALGORITMA-PLANI.md) ----------
// Medya kategorisi: 0 videolu, 1 fotoğraflı, 2 yazılı. Eskiden Keşfet'in KATI
// bölümlemesiydi (bütün videolar, sonra bütün fotoğraflar); artık `medya`
// ağırlığının merdiven girdisi — çok ilgili bir fotoğraf, alakasız bir videoyu
// geçebilir. `unnest` PAHALI (EXPLAIN'de 4.511 çağrı), bu yüzden yalnız
// `medya` ağırlığı > 0 iken sorguya konur.
const KESFET_VIDEOLU = `EXISTS (SELECT 1 FROM unnest(y.medya) mm
                    WHERE mm LIKE '%.mp4' OR mm LIKE '%.webm')`;
const KESFET_KAT = `CASE WHEN ${KESFET_VIDEOLU} THEN 0
                         WHEN cardinality(y.medya) > 0 THEN 1 ELSE 2 END`;

// Skorlanacak aday havuzunun tavanı — BÜTÜN HAVUZU KAPSAMALI.
//
// Plan 400 aday öneriyordu; ÖLÇÜM BUNU ÇÜRÜTTÜ ve tavan yükseltildi:
// arşiv gönderileri (Instagram aktarımı) id aralığı 86–2280'de, güncel
// içerik ise 4949'a kadar uzanıyor. `ORDER BY y.id DESC LIMIT 1500`
// penceresinde arşivden **0** gönderi ve 460 videonun yalnız **33'ü** vardı.
// Yani dar pencere, kullanıcının açıkça istediği "eski mi yeni mi" yüzdelik
// düğmesini ANLAMSIZ kılıyordu (sıralanacak eski içerik kalmıyor) ve Keşfet
// videolarının %93'ünü siliyordu.
//
// Ölçülen maliyet (EXPLAIN ANALYZE, jit off): 4.829 aday → 73,5 ms. Bu sorgu
// tur başına BİR KEZ çalışır (sonuç 10 dk tohum önbelleğinde), sonraki
// sayfalar yalnız id ile satır çeker (17,6 ms).
// Plan §7.4'ün eşiği aynen geçerli: gönderi 25.000'i geçince havuz tarihe
// göre pencerelenmeli + taban skor materyalize edilmeli (bugün 4.845).
const ADAY_AZAMI = 25000;

// Tur tohumu deposu (plan §4.5): ilk sayfada sıralı id listesi DONDURULUR.
// 4.845 id ≈ 39 KB/oturum → 800 kayıt tavanı ≈ 31 MB en kötü hal.
const tohumDeposu = new TohumDeposu({ ttlMs: 600000, azami: 800 });

const jsonCoz = (s) => { try { return JSON.parse(s); } catch { return null; } };

// Ayarlar MEVCUT `ayarlar` tablosundan okunur (yeni tablo/önbellek YOK) —
// `ayarlariGetir()` 60 sn önbellekli ve POST /admin/ayar onu sıfırlıyor, yani
// panelden yapılan değişiklik ANINDA etkili.
async function algoritmaAyarlari() {
  const a = await ayarlariGetir();
  const acik = a.algoritma_acik !== '0';
  return {
    acik,
    akis_acik: acik && a.algoritma_akis_acik !== '0',
    kesfet_acik: acik && a.algoritma_kesfet_acik !== '0',
    akis: ayarBirlestir(jsonCoz(a.algoritma_akis), 'akis'),
    kesfet: ayarBirlestir(jsonCoz(a.algoritma_kesfet), 'kesfet'),
  };
}

// Hacim ölçümleri: hangi sayım sinyalinin P95'i eşiğin altında kaldığı buradan
// belirlenir (plan §4.3) ve panelde canlı rozet olarak gösterilir.
// BAYAT VERİ SERVİS EDİLİR: ölçüm sorgusu birkaç yüz ms sürebiliyor, bunu bir
// kullanıcı isteğinin önüne koymak gecikme sıçraması yaratırdı. Süresi geçince
// eldeki değer hemen döner, tazeleme ARKADA yapılır.
let ALG_OLCUM = { ts: 0, deger: null, calisiyor: false };
const ALG_OLCUM_TTL = 600000;
const ALG_OLCUM_SQL = `
  WITH g AS (SELECT id, kullanici_id, tarih FROM yorumlar WHERE ust_id IS NULL),
       b AS (SELECT yorum_id, count(*)::int n FROM yorum_begeniler GROUP BY yorum_id),
       r AS (SELECT ust_id, count(*)::int n FROM yorumlar
             WHERE ust_id IS NOT NULL GROUP BY ust_id),
       tb AS (SELECT b2.yorum_id, count(DISTINCT b2.kullanici_id)::int n
              FROM yorum_begeniler b2
              JOIN takipler t ON t.takip_edilen_id = b2.kullanici_id
              GROUP BY b2.yorum_id)
  SELECT
    (SELECT count(*) FROM g)::int AS gonderi,
    (SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY COALESCE(b.n, 0))
       FROM g LEFT JOIN b ON b.yorum_id = g.id) AS begeni_p95,
    (SELECT count(*) FROM g WHERE NOT EXISTS
       (SELECT 1 FROM yorum_begeniler bb WHERE bb.yorum_id = g.id))::int AS begenisiz,
    (SELECT count(*) FROM yorum_begeniler)::int AS begeni_toplam,
    (SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY COALESCE(r.n, 0))
       FROM g LEFT JOIN r ON r.ust_id = g.id) AS yanit_p95,
    (SELECT count(*) FROM yorumlar WHERE ust_id IS NOT NULL)::int AS yanit_toplam,
    (SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY COALESCE(tb.n, 0))
       FROM g LEFT JOIN tb ON tb.yorum_id = g.id) AS takip_begendi_p95,
    (SELECT count(*) FROM takipler)::int AS takip_toplam,
    (SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY populerlik)
       FROM icerik_dizini WHERE populerlik > 0) AS icerik_pop_p95,
    (SELECT count(*) FROM icerik_dizini)::int AS dizin,
    (SELECT count(*) FROM (SELECT DISTINCT tur, tmdb_id FROM yorumlar
                           WHERE ust_id IS NULL) s)::int AS yapim,
    (SELECT count(*) FROM (SELECT DISTINCT y.tur, y.tmdb_id FROM yorumlar y
       JOIN icerik_dizini ic ON ic.tur = y.tur AND ic.tmdb_id = y.tmdb_id
       WHERE y.ust_id IS NULL) s)::int AS yapim_dizinde,
    (SELECT count(*) FROM g JOIN kullanicilar k ON k.id = g.kullanici_id
       WHERE k.kullanici_adi = $1)::int AS ai_gonderi,
    (SELECT count(*) FROM g WHERE g.tarih < now() - make_interval(hours => $2))::int AS arsiv_gonderi,
    (SELECT count(*) FROM yorumlar y WHERE y.ust_id IS NULL AND EXISTS
       (SELECT 1 FROM unnest(y.medya) m WHERE m LIKE '%.mp4' OR m LIKE '%.webm'))::int AS video,
    (SELECT count(*) FROM yorumlar y WHERE y.ust_id IS NULL
       AND y.tarih < now() - make_interval(hours => $2) AND EXISTS
       (SELECT 1 FROM unnest(y.medya) m WHERE m LIKE '%.mp4' OR m LIKE '%.webm'))::int AS arsiv_video`;

async function olcumHesapla() {
  const { rows } = await havuz.query(ALG_OLCUM_SQL, [AI_KULLANICI, ARSIV_YAS_SAAT]);
  const r = rows[0] || {};
  const say = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);
  return {
    ...r,
    p95: {
      begeni: say(r.begeni_p95),
      yanit: say(r.yanit_p95),
      takip_begendi: say(r.takip_begendi_p95),
      icerik_pop: say(r.icerik_pop_p95),
    },
  };
}

async function algoritmaOlcumleri() {
  const taze = ALG_OLCUM.deger && Date.now() - ALG_OLCUM.ts < ALG_OLCUM_TTL;
  if (!taze && !ALG_OLCUM.calisiyor) {
    ALG_OLCUM.calisiyor = true;
    const is = olcumHesapla()
      .then((d) => { ALG_OLCUM = { ts: Date.now(), deger: d, calisiyor: false }; return d; })
      .catch(() => { ALG_OLCUM.calisiyor = false; return ALG_OLCUM.deger; });
    // İlk ölçümde bekle (elde hiç veri yok); sonrakilerde bayatı servis et.
    if (!ALG_OLCUM.deger) return (await is) || { p95: {} };
  }
  return ALG_OLCUM.deger || { p95: {} };
}

// Yazar kalitesi: gönderi başına beğeni. KENDİ beğenisi sayılmaz (plan §7.1 —
// `POST /yorumlar/:id/begen` sahip kontrolü yapmıyor, tek satırlık istismar
// yolu olurdu). Ölçüm: dizi.jpg.ai 0,018 · alcelik 1,25 (69 kat fark).
let ALG_YAZAR = { ts: 0, harita: new Map(), calisiyor: false };
async function yazarKaliteleri() {
  const taze = ALG_YAZAR.ts && Date.now() - ALG_YAZAR.ts < ALG_OLCUM_TTL;
  if (!taze && !ALG_YAZAR.calisiyor) {
    ALG_YAZAR.calisiyor = true;
    const is = havuz.query(
      `SELECT y.kullanici_id, count(*)::int AS gonderi,
              count(b.yorum_id)::int AS begeni
         FROM yorumlar y
         LEFT JOIN yorum_begeniler b
           ON b.yorum_id = y.id AND b.kullanici_id <> y.kullanici_id
        WHERE y.ust_id IS NULL
        GROUP BY y.kullanici_id`)
      .then(({ rows }) => {
        const h = new Map();
        for (const r of rows) h.set(r.kullanici_id, r.begeni / Math.max(1, r.gonderi));
        ALG_YAZAR = { ts: Date.now(), harita: h, calisiyor: false };
        return h;
      })
      .catch(() => { ALG_YAZAR.calisiyor = false; return ALG_YAZAR.harita; });
    if (!ALG_YAZAR.ts) return await is;
  }
  return ALG_YAZAR.harita;
}

// Skorlanacak aday havuzu. Sert filtreler (AKIS_GOVDE + AKIS_KURAL + görülmüş)
// DEĞİŞMEDEN uygulanır — engelleme/yasak/bölüm uygunluğu skora GİRMEZ (§7.3).
// Susmuş sinyallerin alt sorguları SORGUYA HİÇ KONMAZ: hacim eşiği aynı
// zamanda bir performans korumasıdır.
async function adaylariGetir({ benId, dil, kadro, hacim, gorulenHaric, kat }) {
  const p = hacim.pay;
  const alan = [
    'y.id', 'y.kullanici_id', 'y.tur', 'y.tmdb_id',
    'y.spoiler AS spoiler_isaret',
    // TAM SAYI saniye olarak: `EXTRACT(...)/3600` numeric döner ve satır başına
    // ~18 baytlık ondalık metin taşır. 4.840 adayda bu boşuna aktarımdır;
    // saat ve `arsiv` bayrağı Node'da tek bölmeyle türetilir.
    'EXTRACT(EPOCH FROM (now() - y.tarih))::int AS yas_sn',
    'g.guvenli',
    '(k.kullanici_adi = $4) AS ai',
    // KOŞULSUZ: alt sorgusu yok (saf kolon karşılaştırması), maliyeti sıfır.
    // Ayrıca $2'yi HER ZAMAN kullanır — Postgres kullanılmayan parametrenin
    // tipini çıkaramaz ("could not determine data type of parameter $2") ve
    // Keşfet'te `dil` ağırlığı 0 olduğu için bu sorgu patlıyordu.
    '(y.kaynak_dil IS NULL OR y.kaynak_dil = $2) AS dil_uygun',
  ];
  if (p.takip_ettigim > 0) {
    alan.push(`EXISTS(SELECT 1 FROM takipler t
       WHERE t.takip_eden_id=$1 AND t.takip_edilen_id=y.kullanici_id) AS takip_ediyorum`);
  }
  if (p.icerik_pop > 0) {
    alan.push(`(SELECT ic.populerlik FROM icerik_dizini ic
       WHERE ic.tur=y.tur AND ic.tmdb_id=y.tmdb_id) AS populerlik`);
  }
  if (p.kitaplik > 0) {
    alan.push(`(SELECT d.durum FROM durumlar d WHERE d.kullanici_id=$1
       AND d.tur=y.tur AND d.tmdb_id=y.tmdb_id) AS durum`);
  }
  if (kat) alan.push(`${KESFET_KAT} AS kat`);
  if (p.begeni > 0) {
    alan.push(`(SELECT count(*)::int FROM yorum_begeniler b
       WHERE b.yorum_id=y.id AND b.kullanici_id <> y.kullanici_id) AS begeni`);
  }
  if (p.yanit > 0) {
    alan.push('(SELECT count(*)::int FROM yorumlar c WHERE c.ust_id=y.id) AS yanit');
  }
  if (p.takip_begendi > 0) {
    alan.push(`(SELECT count(*)::int FROM yorum_begeniler b
       JOIN takipler t ON t.takip_edilen_id=b.kullanici_id AND t.takip_eden_id=$1
       WHERE b.yorum_id=y.id) AS takip_begendi`);
  }
  const sql = `SELECT ${alan.join(',\n           ')}
     ${AKIS_GOVDE}
       ${gorulenHaric
    ? `AND NOT EXISTS (SELECT 1 FROM akis_goruldu ag
           WHERE ag.kullanici_id=$1 AND ag.yorum_id=y.id)` : ''}
       ${AKIS_KURAL}
     ORDER BY y.id DESC LIMIT ${ADAY_AZAMI}`;
  // DİKKAT: her parametre sorguda GERÇEKTEN kullanılmalı; kullanılmayan
  // parametrenin tipini Postgres çıkaramaz ve sorgu patlar
  // ("could not determine data type of parameter $N").
  const par = [benId, dil, kadro, AI_KULLANICI];
  // JIT KAPALI — ÖLÇÜLDÜ VE ŞART: bu sorgunun maliyet tahmini 115.589,
  // `jit_above_cost` ise 100.000. Postgres LLVM derlemesine giriyor ve
  // EXPLAIN'de 381 ms'i SADECE kod üretimine harcıyor (toplam 545 ms).
  // `SET LOCAL jit=off` ile aynı sorgu 41 ms. İşlem içinde LOCAL kullanılıyor
  // ki havuzdaki bağlantıya sızmasın; sorgu salt okunur, işlem zararsız.
  const istemci = await havuz.connect();
  try {
    await istemci.query('BEGIN');
    await istemci.query('SET LOCAL jit = off');
    const { rows } = await istemci.query(sql, par);
    await istemci.query('COMMIT');
    const kalite = await yazarKaliteleri();
    for (const r of rows) {
      r.yazar_kalite = kalite.get(r.kullanici_id) || 0;
      r.yas_saat = r.yas_sn / 3600;
      r.arsiv = r.yas_saat >= ARSIV_YAS_SAAT;
    }
    return rows;
  } catch (e) {
    await istemci.query('ROLLBACK').catch(() => {});
    throw e;
  } finally {
    istemci.release();
  }
}

// Dondurulmuş sıralı id listesini getir; yoksa hesapla ve tohuma yaz.
async function turListesi({ benId, yuzey, dil, kadro, ayar, olcum, tohum, gorulenHaric }) {
  const anahtar = `${benId}:${yuzey}:${tohum}`;
  const eldeki = tohumDeposu.oku(anahtar);
  if (eldeki) return eldeki;
  const hacim = hacimUygula(ayar, olcum);
  const adaylar = await adaylariGetir({
    benId, dil, kadro, hacim, gorulenHaric, kat: hacim.pay.medya > 0,
  });
  const { idler } = siralaVeKotala(adaylar, ayar, olcum);
  tohumDeposu.yaz(anahtar, idler);
  return idler;
}

// Sıralı id listesinin bir dilimi için TAM satırları getir. Sert filtreler
// BURADA DA uygulanır (savunma katmanı): liste dondurulduktan sonra kullanıcı
// birini engellerse o gönderi yine de düşer.
async function satirlariGetir({ benId, dil, kadro, idler, kesfet }) {
  if (!idler.length) return [];
  const { rows } = await havuz.query(
    `${AKIS_ALANLAR}${kesfet ? `,\n            ${KESFET_VIDEOLU} AS videolu` : ''}
     ${AKIS_GOVDE}
       AND y.id = ANY($2::int[])
       ${AKIS_KURAL}`,
    [benId, idler, kadro, dil]);
  const harita = new Map(rows.map((r) => [r.id, r]));
  return idler.map((id) => harita.get(id)).filter(Boolean);
}

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
// "tur:tmdb_id" anahtarlarından {ad, poster} haritası. Okunamayan (Çince vb.)
// başlıklar İngilizcesiyle, birebir çeviri başlıklar orijinaliyle değiştirilir.
async function icerikBilgileri(anahtarlar) {
  const yollar = anahtarlar.map((a) => {
    const [tur, id] = a.split(':');
    return `/${tur}/${id}?language=tr-TR`;
  });
  const harita = await tmdbTopluGetir(yollar, ONBELLEK_TTL_SN.uzun);
  // Latin dışı başlıklar için tek toplu İngilizce okuma
  const latinDili = LATIN_DILLER.has(istekBaglam.getStore()?.dil || 'tr');
  const enYollar = latinDili
    ? yollar.filter((y) => latinDisiMi(harita.get(y)))
    : [];
  const enHarita = enYollar.length
    ? await tmdbTopluGetir(enYollar, ONBELLEK_TTL_SN.uzun, 'en-US')
    : new Map();
  const icerikler = {};
  anahtarlar.forEach((a, i) => {
    let v = harita.get(yollar[i]);
    if (!v) { icerikler[a] = { ad: '?', poster: null }; return; }
    if (latinDili) {
      if (latinDisiMi(v)) v = ingilizceBirlestir(v, enHarita.get(yollar[i]));
      v = adTercihUygula(v);
    }
    icerikler[a] = {
      ad: v.name || v.title || '?',
      poster: v.poster_path || v.profile_path || null,
    };
  });
  return icerikler;
}


// Poster kartının ihtiyacı olan ALANLAR (ad, poster, puan, bölüm sayısı).
// icerikBilgileri yalnız ad+poster döner; kart ayrıca puan ve dizi ilerlemesi
// için bölüm sayısı ister. Tek tek /tmdb/tv/:id çağırmak yerine bu kullanılır:
// tek içerik detayı ~61 KB, buradaki özet ~100 bayt.
async function icerikKartlari(anahtarlar) {
  const yollar = anahtarlar.map((a) => {
    const [tur, id] = a.split(':');
    return `/${tur}/${id}?language=tr-TR`;
  });
  const harita = await tmdbTopluGetir(yollar, ONBELLEK_TTL_SN.uzun);
  const latinDili = LATIN_DILLER.has(istekBaglam.getStore()?.dil || 'tr');
  const enYollar = latinDili
    ? yollar.filter((y) => latinDisiMi(harita.get(y)))
    : [];
  const enHarita = enYollar.length
    ? await tmdbTopluGetir(enYollar, ONBELLEK_TTL_SN.uzun, 'en-US')
    : new Map();
  const kartlar = {};
  anahtarlar.forEach((a, i) => {
    let v = harita.get(yollar[i]);
    if (!v) return; // bulunamayan içerik atlanır; istemci iskelet gösterir
    if (latinDili) {
      if (latinDisiMi(v)) v = ingilizceBirlestir(v, enHarita.get(yollar[i]));
      v = adTercihUygula(v);
    }
    kartlar[a] = {
      id: v.id,
      name: v.name || null,
      title: v.title || null,
      poster_path: v.poster_path || null,
      vote_average: v.vote_average ?? 0,
      number_of_episodes: v.number_of_episodes ?? null,
    };
  });
  return kartlar;
}

async function akisIcerikleri(rows) {
  return icerikBilgileri([...new Set(rows.map((r) => `${r.tur}:${r.tmdb_id}`))]);
}

// dizi.jpg AI hesabı: tanıtım yorumları spoilersız yazılır, izlenmemiş içerik
// bulanıklığından muaftır (işaretlenirse yine bulanık olur).
const AI_KULLANICI = 'dizi.jpg.ai';

// Gönderiyi OKUYANIN dilinde göster: metnin o dilde hazır çevirisi varsa
// (ve gönderi zaten o dilde değilse) `metin` alanına çeviri konur, orijinal
// `orijinal_metin`de kalır. Böylece eski istemciler bile (uygulama güncellemesi
// beklemeden) kendi dillerinde okur; yeni istemci "Orijinali göster" sunar.
// `ceviri_var`: çeviri UYGULANDIYSA düğmeye gerek yok → false. Uygulanmadıysa
// ama gönderi yabancı dildeyse true — /ceviri ucu artık hazır çeviri yoksa
// ANINDA üretiyor, yani düğme her yabancı gönderide iş görür.
function ceviriUygula({ ceviri_metin, ...r }) {
  const dil = istekBaglam.getStore()?.dil || 'tr';
  if (ceviri_metin && r.kaynak_dil && r.kaynak_dil !== dil) {
    return { ...r, metin: ceviri_metin, orijinal_metin: r.metin,
      cevrildi: true, ceviri_var: false };
  }
  return { ...r, cevrildi: false,
    ceviri_var: !!(r.kaynak_dil && r.kaynak_dil !== dil
      && String(r.metin || '').trim().length > 1) };
}

const akisSatiri = ({ guvenli, spoiler_isaret, ...ham }) => ({
  ...ceviriUygula(ham),
  // İstemci bulanık gösterir. İki kaynak: (1) izlemediğin içeriğin yorumu
  // (otomatik), (2) yazan kişinin "spoiler içerir" işareti. Kişi yorumları ve
  // kitaplık eşleşmeleri otomatik spoiler sayılmaz ama işaretliyse yine bulanık.
  spoiler: spoiler_isaret === true ||
    !(guvenli || ham.tur === 'person' || ham.kullanici_adi === AI_KULLANICI),
});

// ---------- Sık kullanılan emojiler (yorum kutusunun üstündeki 8'li satır) ----
// Yeni tablo YOK: mevcut yorum metinleri taranır (emoji.js grafem ayıklayıcı).
// Maliyet iki nedenle küçük: (1) sorgular indeksli ve LIMIT'li, (2) sonuçlar
// önbelleklenir — genel liste saatte bir, kişiye özel liste 5 dakikada bir.
const EMOJI_GENEL_TARAMA = 1500; // son N yorum (id DESC = birincil anahtar taraması)
const EMOJI_BENIM_TARAMA = 300; // kişinin son N yorumu (idx_yorum_kullanici)
let emojiGenelOnbellek = { zaman: 0, liste: [] };
const emojiBenimOnbellek = new Map(); // kullanici_id -> { zaman, liste }

async function emojilerGenel() {
  if (emojiGenelOnbellek.liste.length &&
      Date.now() - emojiGenelOnbellek.zaman < 3600_000) {
    return emojiGenelOnbellek.liste;
  }
  const { rows } = await havuz.query(
    'SELECT metin FROM yorumlar ORDER BY id DESC LIMIT $1', [EMOJI_GENEL_TARAMA]);
  emojiGenelOnbellek = { zaman: Date.now(), liste: emojiSay(rows.map((r) => r.metin)) };
  return emojiGenelOnbellek.liste;
}

async function emojilerBenim(kullaniciId) {
  const kayit = emojiBenimOnbellek.get(kullaniciId);
  if (kayit && Date.now() - kayit.zaman < 300_000) return kayit.liste;
  const { rows } = await havuz.query(
    'SELECT metin FROM yorumlar WHERE kullanici_id=$1 ORDER BY tarih DESC LIMIT $2',
    [kullaniciId, EMOJI_BENIM_TARAMA]);
  const liste = emojiSay(rows.map((r) => r.metin));
  if (emojiBenimOnbellek.size > 5000) emojiBenimOnbellek.clear();
  emojiBenimOnbellek.set(kullaniciId, { zaman: Date.now(), liste });
  return liste;
}

const emojiLimiti = hizLimiti(120, (req) => `em:${req.kullanici.id}`);
app.get('/emojiler/sik', girisZorunlu, emojiLimiti, sarici(async (req, res) => {
  const [benim, genel] = await Promise.all([
    emojilerBenim(req.kullanici.id), emojilerGenel(),
  ]);
  // İstemci sırayla birleştirir: önce kendi emojilerin, eksik kalırsa uygulama
  // geneli, o da boşsa yedek — satır asla boş görünmez.
  res.json({ benim, genel, yedek: EMOJI_YEDEK });
}));

const AKIS_SAYFA = 30;

app.get('/akis', girisZorunlu, akisLimiti, sarici(async (req, res) => {
  const benId = req.kullanici.id;
  const dil = istekBaglam.getStore()?.dil || 'tr';
  const kadro = await kadroKisileri(benId);
  const alg = await algoritmaAyarlari();
  // KULLANICI SEÇİMİ (varsayılan "Önerilen"): `?sira=kronolojik` gelirse
  // bugünkü saf id-azalan yol birebir çalışır.
  const kronolojik = String(req.query.sira || '') === 'kronolojik';
  const cozum = imlecCoz(req.query.imlec, req.query.once);

  // ---- ÖNERİLEN (skorlu) ----
  // GERİYE UYUM: eski istemci `?once=<id>` gönderir (opak imleç bilmez). O
  // istek kronolojik yola düşer — akış KIRILMAZ, yalnız 2. sayfadan itibaren
  // bugünkü sırayla devam eder (plan §4.5 "imleçte : yoksa bugünkü davranış").
  if (alg.akis_acik && !kronolojik && cozum.bicim !== 'eski_akis') {
    const olcum = await algoritmaOlcumleri();
    const tohum = cozum.bicim === 'yeni' ? cozum.tohum : tohumUret(benId, 'akis');
    const ofset = cozum.bicim === 'yeni' ? cozum.ofset : 0;
    const idler = await turListesi({
      benId, yuzey: 'akis', dil, kadro, ayar: alg.akis, olcum, tohum,
      gorulenHaric: true,
    });
    const dilim = idler.slice(ofset, ofset + AKIS_SAYFA);
    const satir = await satirlariGetir({ benId, dil, kadro, idler: dilim });
    // İlk sayfa gerçekten boşsa bugünkü popüler yedeğine düşülür (aşağıdaki
    // ortak kod yolu); dolu ise skorlu sayfa döner.
    if (satir.length || ofset > 0) {
      const sonrakiOfset = ofset + dilim.length;
      return res.json({
        kaynak: 'akis',
        sira: 'onerilen',
        imlec: sonrakiOfset < idler.length ? imlecYaz(tohum, sonrakiOfset) : null,
        akis: satir.map(akisSatiri),
        icerikler: await akisIcerikleri(satir),
      });
    }
  }

  // ---- KRONOLOJİK (bugünkü kod yolu, aynen korundu) ----
  const once = cozum.bicim === 'eski_akis' ? cozum.once : null;
  let { rows } = await havuz.query(
    `${AKIS_ALANLAR} ${AKIS_GOVDE}
       AND ($2::int IS NULL OR y.id < $2)
       AND NOT EXISTS (SELECT 1 FROM akis_goruldu ag WHERE ag.kullanici_id=$1 AND ag.yorum_id=y.id)
       ${AKIS_KURAL}
     ORDER BY y.id DESC LIMIT 30`,
    [benId, once, kadro, dil],
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
           ? `AND NOT EXISTS (SELECT 1 FROM akis_goruldu ag WHERE ag.kullanici_id=$1 AND ag.yorum_id=y.id)`
           : ''}
       ORDER BY begeni DESC, y.id DESC LIMIT 30`,
      [benId, gun, null, istekBaglam.getStore()?.dil || 'tr']);
    for (const [gun, haric] of [[1, true], [30, true], [30, false]]) {
      const p = await populer(gun, haric);
      if (p.rows.length) { rows = p.rows; kaynak = 'populer'; break; }
    }
  }
  // "Görüldü" işaretlemesini TAMAMEN istemci yapar (POST /akis/goruldu) —
  // yalnız kullanıcının EKRANDA gerçekten gördüğü kartlar (popüler fallback
  // dahil) işaretlenir. Sunucu döndürdü diye görüldü sayılmaz; kaydırmadan
  // kapatılan gönderiler tekrar gelir, popüler rotasyonu da istemci-görünürlükle
  // döner.
  res.json({
    kaynak,
    sira: 'kronolojik',
    akis: rows.map(akisSatiri),
    icerikler: await akisIcerikleri(rows),
  });
}));

// Keşfet (Reels tarzı): akışla AYNI uygunluk kuralları.
const KESFET_ILK = 60; // ilk sayfa: eski istemciler de aynı doluluğu görsün
const KESFET_SAYFA = 30; // sonraki sayfalar

// İki turlu akış:
//  1. tur — görülmemişler (akis_goruldu'da olmayanlar), imleçle sayfa sayfa.
//  2. tur — havuz tükenince BAŞTAN, görülenler dahil (`tekrar: true`).
// `imlec` yanıtta gelir, istemci OLDUĞU GİBİ geri gönderir — bu yüzden Keşfet
// tarafında imleç biçimini değiştirmek eski istemcileri KIRMAZ (opak). Yine de
// eski `<tur>:<kat>:<id>` biçimi tanınmaya devam eder: yolda olan istekler ve
// önbellekten dönen imleçler için (plan §7.5, zorunlu madde).
// `imlec: null` → gerçekten bitti, istemci daha fazla istememeli.
app.get('/kesfet-akis', girisZorunlu, akisLimiti, sarici(async (req, res) => {
  const benId = req.kullanici.id;
  const dil = istekBaglam.getStore()?.dil || 'tr';
  const kadro = await kadroKisileri(benId);
  const alg = await algoritmaAyarlari();
  const kronolojik = String(req.query.sira || '') === 'kronolojik';
  const c = imlecCoz(req.query.imlec);

  // ---- ÖNERİLEN (skorlu) ----
  if (alg.kesfet_acik && !kronolojik && c.bicim !== 'eski_kesfet') {
    const olcum = await algoritmaOlcumleri();
    const ilk = c.bicim !== 'yeni';
    let tur = ilk ? 0 : c.tur;
    let tohum = ilk ? tohumUret(benId, 'kesfet') : c.tohum;
    let ofset = ilk ? 0 : c.ofset;
    const adet = ilk ? KESFET_ILK : KESFET_SAYFA;

    let idler = await turListesi({
      benId, yuzey: 'kesfet', dil, kadro, ayar: alg.kesfet, olcum, tohum,
      gorulenHaric: tur === 0,
    });
    // 1. tur bitti → 2. tura geç (görülenler dahil, yeni tohum, baştan).
    if (ofset >= idler.length && tur === 0) {
      tur = 1; ofset = 0; tohum = `t${tohumUret(benId, 'kesfet')}`;
      idler = await turListesi({
        benId, yuzey: 'kesfet', dil, kadro, ayar: alg.kesfet, olcum, tohum,
        gorulenHaric: false,
      });
    }
    const dilim = idler.slice(ofset, ofset + adet);
    const satir = await satirlariGetir({
      benId, dil, kadro, idler: dilim, kesfet: true,
    });
    if (satir.length || !ilk) {
      const sonrakiOfset = ofset + dilim.length;
      return res.json({
        akis: satir.map(akisSatiri),
        icerikler: await akisIcerikleri(satir),
        tekrar: tur === 1,
        sira: 'onerilen',
        imlec: sonrakiOfset < idler.length
          ? imlecYaz(tohum, sonrakiOfset, tur)
          : (tur === 1 ? null : imlecYaz(tohum, idler.length, 0)),
      });
    }
  }

  // ---- KRONOLOJİK (bugünkü kod yolu, aynen korundu) ----
  let tekrar = c.bicim === 'eski_kesfet' ? c.tekrar : false;
  const kat = c.bicim === 'eski_kesfet' ? c.kat : null;
  const once = c.bicim === 'eski_kesfet' ? c.once : null;
  const adet = c.bicim === 'eski_kesfet' ? KESFET_SAYFA : KESFET_ILK;

  // gorulenHaric: görülenleri hariç tut (1. tur).
  const sorgula = (gorulenHaric, katV, onceV) => havuz.query(
    `${AKIS_ALANLAR},
            ${KESFET_VIDEOLU} AS videolu,
            ${KESFET_KAT} AS kat
     ${AKIS_GOVDE}
       AND ($2::int IS NULL
            OR (${KESFET_KAT}, -y.id) > ($5::int, -$2::int))
       ${gorulenHaric
         ? `AND NOT EXISTS (SELECT 1 FROM akis_goruldu ag WHERE ag.kullanici_id=$1 AND ag.yorum_id=y.id)`
         : ''}
       ${AKIS_KURAL}
     ORDER BY ${KESFET_KAT}, y.id DESC
     LIMIT ${adet}`,
    [benId, onceV, kadro, dil, katV]);

  let { rows } = await sorgula(!tekrar, kat, once);
  // Görülmemiş havuz TAM sayfa sınırında bittiyse boş döner: hemen 2. tura geç.
  if (!rows.length && !tekrar) {
    tekrar = true;
    ({ rows } = await sorgula(false, null, null));
  }
  const son = rows[rows.length - 1];
  const imlec = rows.length >= adet
    ? `${tekrar ? 1 : 0}:${son.kat}:${son.id}`
    : (tekrar ? null : '1:'); // 1. tur bitti → 2. tur baştan başlar
  res.json({
    akis: rows.map(akisSatiri),
    icerikler: await akisIcerikleri(rows),
    tekrar, // bu sayfa "daha önce görülenlerin tekrarı" mı
    sira: 'kronolojik',
    imlec,
  });
}));

// İstemci, kullanıcının EKRANDA gördüğü akış/keşfet kartlarını bildirir;
// bunlar bir daha gösterilmez (akis_goruldu). En fazla 200 id/istek.
// Ayrıca her bildirim görüntülenme sayar (aynı kişinin tekrarları dahil —
// istemci oturum içinde aynı kartı bir kez bildirir).
app.post('/akis/goruldu', girisZorunlu, sarici(async (req, res) => {
  const idler = Array.isArray(req.body?.idler)
    ? req.body.idler.filter((x) => Number.isInteger(x) && x > 0).slice(0, 200)
    : [];
  if (idler.length) {
    await Promise.all([
      havuz.query(
        `INSERT INTO akis_goruldu (kullanici_id, yorum_id)
         SELECT $1, unnest($2::int[]) ON CONFLICT DO NOTHING`,
        [req.kullanici.id, idler]).catch(() => {}),
      havuz.query(
        'UPDATE yorumlar SET goruntulenme = goruntulenme + 1 WHERE id = ANY($1::int[])',
        [idler]).catch(() => {}),
    ]);
  }
  res.json({ tamam: true });
}));

// ---------- gönderi çevirisi ----------
// Hazır çeviri yoksa ANINDA üretilir: anahtarsız genel çeviri ucu. Sonuç
// metin_cevirileri'ne yazılır, böylece aynı metin bir daha dışarı sorulmaz
// (Instagram aktarımlarında aynı metin onlarca gönderide tekrar ediyor).
// Başarısız olursa null döner; uç {yok:true} ile temiz cevap verir.
const CEVIRI_UCU = 'https://translate.googleapis.com/translate_a/single';
const CEVIRI_AZAMI = 4000; // uzun metinler ucu 413'e düşürüyor

async function metniCevir(metin, hedefDil, kaynakDil) {
  const kirp = String(metin || '').slice(0, CEVIRI_AZAMI);
  if (kirp.trim().length < 2) return null;
  const url = `${CEVIRI_UCU}?client=gtx&sl=${encodeURIComponent(kaynakDil || 'auto')}`
    + `&tl=${encodeURIComponent(hedefDil)}&dt=t&q=${encodeURIComponent(kirp)}`;
  try {
    const cevap = await fetch(url, { signal: AbortSignal.timeout(12000) });
    if (!cevap.ok) return null;
    const veri = await cevap.json();
    if (!Array.isArray(veri?.[0])) return null;
    // [0] = cümle cümle [[çeviri, orijinal, ...], ...]
    const sonuc = veri[0]
      .map((p) => (Array.isArray(p) && typeof p[0] === 'string' ? p[0] : ''))
      .join('');
    return sonuc.trim() ? sonuc : null;
  } catch {
    return null; // ağ/zaman aşımı/blok → çeviri yok
  }
}

// Dış çeviri ucunu koru: kullanıcı başına saatte 120 gönderi çevirisi.
const ceviriLimiti = hizLimiti(120, (req) => `cv:${req.kullanici?.id || req.ip}`);

app.get('/ceviri/:yorumId', girisIsteğeBagli, ceviriLimiti, sarici(async (req, res) => {
  const id = parseInt(req.params.yorumId, 10);
  if (!gecerliTmdb(id)) return res.status(400).json({ hata: 'Geçersiz id' });
  const dil = String(req.query.dil || istekBaglam.getStore()?.dil || 'tr').toLowerCase();
  if (!/^[a-z]{2,3}$/.test(dil)) return res.status(400).json({ hata: 'Geçersiz dil' });
  const { rows } = await havuz.query(
    `SELECT btrim(y.metin) AS metin, y.kaynak_dil, md5(btrim(y.metin)) AS ozet,
            (SELECT c.metin FROM metin_cevirileri c
              WHERE c.ozet = md5(btrim(y.metin)) AND c.dil = $2) AS ceviri
     FROM yorumlar y WHERE y.id = $1`,
    [id, dil],
  );
  if (!rows.length) return res.json({ yok: true });
  const y = rows[0];
  if (y.ceviri) return res.json({ metin: y.ceviri, dil });
  // Zaten okuyanın dilindeyse çevirmeye gerek yok
  if (!y.metin || y.kaynak_dil === dil) return res.json({ yok: true });
  const ceviri = await metniCevir(y.metin, dil, y.kaynak_dil);
  if (!ceviri) return res.json({ yok: true });
  await havuz.query(
    `INSERT INTO metin_cevirileri (ozet, dil, metin) VALUES ($1, $2, $3)
     ON CONFLICT (ozet, dil) DO NOTHING`,
    [y.ozet, dil, ceviri],
  ).catch(() => {});
  res.json({ metin: ceviri, dil });
}));

// Admin: çevrilmeyi bekleyen BENZERSİZ metinler (en çok görülenler önce).
app.get('/admin/cevrilecek', adminKisit, sarici(async (req, res) => {
  const dil = String(req.query.dil || 'en').toLowerCase();
  const limit = Math.min(parseInt(req.query.limit, 10) || 200, 1000);
  const kaynak = req.query.kaynak ? String(req.query.kaynak).toLowerCase() : null;
  const { rows } = await havuz.query(
    `SELECT md5(btrim(y.metin)) AS ozet, btrim(y.metin) AS metin,
            count(*)::int AS gonderi, min(y.kaynak_dil) AS kaynak_dil
     FROM yorumlar y
     WHERE y.metin IS NOT NULL AND length(btrim(y.metin)) > 2
       AND ($3::text IS NULL OR y.kaynak_dil = $3)
       AND y.kaynak_dil IS DISTINCT FROM $1
       AND NOT EXISTS (SELECT 1 FROM metin_cevirileri c
                       WHERE c.ozet = md5(btrim(y.metin)) AND c.dil = $1)
     GROUP BY 1, 2
     ORDER BY gonderi DESC, length(btrim(y.metin))
     LIMIT $2`,
    [dil, limit, kaynak],
  );
  res.json({ dil, adet: rows.length, metinler: rows });
}));

// Admin: toplu çeviri yükleme. Gövde: {ceviriler:[{ozet,dil,metin}, ...]}
app.post('/admin/ceviri', adminKisit, express.json({ limit: '8mb' }), sarici(async (req, res) => {
  const liste = Array.isArray(req.body?.ceviriler) ? req.body.ceviriler : [];
  if (!liste.length) return res.status(400).json({ hata: 'ceviriler dizisi gerekli' });
  const ozetler = [];
  const diller = [];
  const metinler = [];
  for (const c of liste) {
    if (!/^[0-9a-f]{32}$/.test(String(c?.ozet || '')) ||
        !/^[a-z]{2,3}$/.test(String(c?.dil || '')) ||
        typeof c?.metin !== 'string' || !c.metin.trim()) {
      return res.status(400).json({ hata: 'Geçersiz çeviri kaydı' });
    }
    ozetler.push(c.ozet); diller.push(c.dil); metinler.push(c.metin.trim().slice(0, 4000));
  }
  await havuz.query(
    `INSERT INTO metin_cevirileri (ozet, dil, metin)
     SELECT * FROM unnest($1::text[], $2::text[], $3::text[])
     ON CONFLICT (ozet, dil) DO UPDATE SET metin = EXCLUDED.metin, olusturma = now()`,
    [ozetler, diller, metinler],
  );
  res.json({ eklenen: liste.length });
}));

// Admin: kaynak_dil'i boş olan gönderilerin dilini tespit edip yazar.
app.post('/admin/dil-tespit', adminKisit, sarici(async (req, res) => {
  const limit = Math.min(parseInt(req.body?.limit, 10) || 5000, 20000);
  const { rows } = await havuz.query(
    `SELECT id, metin FROM yorumlar
     WHERE kaynak_dil IS NULL AND metin IS NOT NULL AND length(btrim(metin)) > 2
     LIMIT $1`,
    [limit],
  );
  const idler = [];
  const diller = [];
  for (const r of rows) {
    const d = dilTespit(r.metin);
    if (d) { idler.push(r.id); diller.push(d); }
  }
  if (idler.length) {
    await havuz.query(
      `UPDATE yorumlar y SET kaynak_dil = v.dil
       FROM (SELECT * FROM unnest($1::int[], $2::text[]) AS t(id, dil)) v
       WHERE y.id = v.id`,
      [idler, diller],
    );
  }
  res.json({ bakilan: rows.length, isaretlenen: idler.length });
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

// Paylaşım hedefleri: mesajlaştıkların ÖNCE, sonra takip ettiklerin, sonra
// takipçilerin (tekilleştirilmiş). Gönderiyi DM ile yollarken listelenir.
app.get('/paylas-hedefler', girisZorunlu, sarici(async (req, res) => {
  const benId = req.kullanici.id;
  const { rows } = await havuz.query(
    `WITH sohbet AS (
       SELECT DISTINCT ON (k.id) k.id, k.kullanici_adi, k.avatar, 0 AS oncelik, max(m.id) AS sira
       FROM mesajlar m
       JOIN kullanicilar k ON k.id = CASE WHEN m.gonderen_id=$1 THEN m.alici_id ELSE m.gonderen_id END
       WHERE (m.gonderen_id=$1 OR m.alici_id=$1) AND NOT k.yasakli
       GROUP BY k.id, k.kullanici_adi, k.avatar
     ), takip AS (
       SELECT k.id, k.kullanici_adi, k.avatar, 1 AS oncelik, 0 AS sira
       FROM takipler t JOIN kullanicilar k ON k.id=t.takip_edilen_id
       WHERE t.takip_eden_id=$1 AND NOT k.yasakli
     ), takipci AS (
       SELECT k.id, k.kullanici_adi, k.avatar, 2 AS oncelik, 0 AS sira
       FROM takipler t JOIN kullanicilar k ON k.id=t.takip_eden_id
       WHERE t.takip_edilen_id=$1 AND NOT k.yasakli
     ), hepsi AS (
       SELECT * FROM sohbet UNION ALL SELECT * FROM takip UNION ALL SELECT * FROM takipci
     )
     SELECT DISTINCT ON (id) id, kullanici_adi, avatar, oncelik
     FROM hepsi
     WHERE id <> $1
       AND id NOT IN (SELECT engellenen_id FROM engellemeler WHERE engelleyen_id=$1
                      UNION SELECT engelleyen_id FROM engellemeler WHERE engellenen_id=$1)
     ORDER BY id, oncelik, sira DESC`,
    [benId],
  );
  rows.sort((a, b) => a.oncelik - b.oncelik);
  res.json({ kullanicilar: rows.slice(0, 60) });
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
            m.yorum_id, m.okundu, m.iletildi, m.duzenlendi, m.yanit_id, m.tarih,
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
  const icerikler = await icerikBilgileri(anahtarlar);
  // Paylaşılan gönderilerin önizlemesi (sohbette kart olarak çizilir)
  const gonderiIdler = [...new Set(rows.filter((r) => r.yorum_id).map((r) => r.yorum_id))];
  const gonderiler = {};
  if (gonderiIdler.length) {
    const g = await havuz.query(
      `SELECT y.id, y.metin, y.medya, y.tur, y.tmdb_id, k.kullanici_adi, k.avatar
       FROM yorumlar y JOIN kullanicilar k ON k.id = y.kullanici_id
       WHERE y.id = ANY($1::int[])`,
      [gonderiIdler],
    );
    for (const r of g.rows) {
      gonderiler[r.id] = {
        id: r.id,
        kullanici_adi: r.kullanici_adi,
        avatar: r.avatar,
        metin: (r.metin || '').slice(0, 140),
        kapak: (r.medya || [])[0] || null,
        tur: r.tur,
        tmdb_id: r.tmdb_id,
      };
    }
  }
  havuz.query(
    `UPDATE mesajlar SET okundu=true, iletildi=true
     WHERE alici_id=$1 AND gonderen_id=$2 AND NOT okundu`,
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
    gonderiler,
    yaziyor:
      Date.now() - (yaziyorlar.get(`${partnerId}:${req.kullanici.id}`) || 0) <
      6000,
  });
}));

// Push alıcı cihaza ulaştı: gönderenin mesajları "iletildi" olur (çift tik).
// İstemci, 'mesaj' türü veri-push'u işlerken çağırır.
app.post('/mesajlar/iletildi', girisZorunlu, sarici(async (req, res) => {
  const ad = String(req.body?.kullanici_adi || '');
  if (!ad) return res.status(400).json({ hata: 'kullanici_adi gerekli' });
  await havuz.query(
    `UPDATE mesajlar SET iletildi=true
     WHERE alici_id=$1 AND NOT iletildi
       AND gonderen_id=(SELECT id FROM kullanicilar WHERE kullanici_adi=$2)`,
    [req.kullanici.id, ad],
  );
  res.json({ tamam: true });
}));

app.post('/mesajlar', girisZorunlu, mesajLimiti, sarici(async (req, res) => {
  const {
    kullanici_adi, metin, medya = null, ses_dalga = null,
    icerik_tur = null, icerik_id = null, yanit_id = null, yorum_id = null,
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
  // Gönderi paylaşımı: sohbette kart olur, dokununca Reels'te açılır
  if (yorum_id != null) {
    if (!Number.isInteger(yorum_id)) {
      return res.status(400).json({ hata: 'Geçersiz yorum_id' });
    }
    const v = await havuz.query('SELECT 1 FROM yorumlar WHERE id=$1', [yorum_id]);
    if (!v.rows.length) return res.status(404).json({ hata: 'Gönderi bulunamadı' });
  }
  if (!temiz && !medya && !icerikVar && yorum_id == null) {
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
                           icerik_tur, icerik_id, yanit_id, yorum_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id, tarih`,
    [req.kullanici.id, aliciId, temiz || null, medya, sesMi ? ses_dalga : null,
     icerikVar ? icerik_tur : null, icerikVar ? icerik_id : null, gecerliYanit,
     yorum_id ?? null],
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
  mailGonder({
    to: email,
    subject: 'dizi.jpg şifre sıfırlama kodun',
    text: `Şifre sıfırlama kodun: ${kod}\n\n15 dakika geçerlidir. Sen istemediysen bu e-postayı yok say.`,
  }, { tur: 'sifirlama', kullanici_id: rows[0].id })
    .catch((e) => console.error('sifirlama maili:', e.message));
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
  const spoiler = req.body?.spoiler === true;
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
  // 10: AI tanıtım gönderileri ve Instagram'dan aktarılan çoklu karolar zaten
  // 10 kareye kadar çıkıyor; galeri/Reels bileşenleri sayıya bağlı değil.
  if (!Array.isArray(medya) || medya.length > 10) {
    return res.status(400).json({ hata: 'En fazla 10 medya eklenebilir' });
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
    `INSERT INTO yorumlar (kullanici_id, tur, tmdb_id, sezon, bolum, metin, medya, ust_id, spoiler, kaynak_dil)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING id, tarih`,
    [req.kullanici.id, tur, tmdb_id, sezon, bolum, temiz, medya, gercekUst, spoiler,
     dilTespit(temiz)],
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
  // Yeni yorumdaki emojiler bir sonraki açılışta hızlı satırda görünsün
  emojiBenimOnbellek.delete(req.kullanici.id);
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
  // Silinen yorumun emojileri hızlı satırda kalmasın
  emojiBenimOnbellek.delete(req.kullanici.id);
  res.json({ tamam: true });
}));

// Yorumu PROFİL VİTRİNİNDEN çıkar / geri koy. SİLME DEĞİLDİR:
// dizi/film/bölüm sayfasındaki liste (`GET /yorumlar/:tur/:tmdbId`), akış,
// Reels, beğeniler ve yanıtlar HİÇ ETKİLENMEZ — yalnız
// `GET /profil/:kullaniciAdi` süzer. Geri alınabilir olduğu için istemcide
// onay istenmez, SnackBar + "Geri al" yeter.
app.post('/yorumlar/:id/profilde-gizle', girisZorunlu, sarici(async (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) return res.status(400).json({ hata: 'Geçersiz yorum' });
  const gizli = req.body?.gizli !== false; // eksik/true = gizle
  const { rows } = await havuz.query(
    `UPDATE yorumlar SET profilde_gizli=$3 WHERE id=$1 AND kullanici_id=$2
     RETURNING id, profilde_gizli`,
    [id, req.kullanici.id, gizli],
  );
  if (!rows.length) return res.status(404).json({ hata: 'Yorum bulunamadı' });
  res.json(rows[0]);
}));

// Ayarlar > Gizlilik > Gizlenen yorumlar: profil vitrininden çıkarılanlar.
// Yalnız kendi yorumların; içerik adı/posteri kart için birlikte döner.
app.get('/gizlenen-yorumlar', girisZorunlu, sarici(async (req, res) => {
  const { rows } = await havuz.query(
    `SELECT y.id, y.kullanici_id, y.tur, y.tmdb_id, y.sezon, y.bolum,
            y.metin, y.medya, y.tarih, y.ust_id, y.spoiler, y.kaynak_dil,
            (SELECT count(*)::int FROM yorum_begeniler b WHERE b.yorum_id=y.id) AS begeni
     FROM yorumlar y
     WHERE y.kullanici_id=$1 AND y.profilde_gizli
     ORDER BY y.tarih DESC LIMIT 100`,
    [req.kullanici.id],
  );
  const anahtarlar = [...new Set(rows.map((y) => `${y.tur}:${y.tmdb_id}`))];
  const icerikler = await icerikBilgileri(anahtarlar);
  res.json({ yorumlar: rows, icerikler });
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
// Arama sonuçlarını yerel başlık dizinine işler (yazım toleransının besini).
function icerikDizineEkle(liste) {
  const satirlar = (liste || []).filter((r) =>
    (r.media_type === 'tv' || r.media_type === 'movie') &&
    r.id && (r.name || r.title));
  if (!satirlar.length) return;
  havuz.query(
    `INSERT INTO icerik_dizini (tur, tmdb_id, ad, orijinal_ad, populerlik)
     SELECT * FROM unnest($1::text[], $2::int[], $3::text[], $4::text[], $5::real[])
     ON CONFLICT (tur, tmdb_id) DO UPDATE
       SET ad = EXCLUDED.ad, orijinal_ad = EXCLUDED.orijinal_ad,
           populerlik = GREATEST(icerik_dizini.populerlik, EXCLUDED.populerlik),
           guncelleme = now()`,
    [satirlar.map((r) => r.media_type), satirlar.map((r) => r.id),
     satirlar.map((r) => r.name || r.title),
     satirlar.map((r) => r.original_name || r.original_title || null),
     satirlar.map((r) => r.popularity || 0)],
  ).catch(() => {});
}

// Akıllı içerik araması: sorgu VARYANTLARI ("Black List" → "BlackList",
// "the"siz hali) TMDB'de paralel aranır, tekilleştirilip popülerliğe göre
// sıralanır. Düz /tmdb/search/multi tek yazımı bulamıyordu.
// Sonuç çıkmazsa YAZIM TOLERANSI: yerel başlık dizininde pg_trgm benzerliğiyle
// en yakın başlıklar bulunur ("brekaing bad" → Breaking Bad).
app.get('/ara', girisZorunlu, aramaLimiti, sarici(async (req, res) => {
  const q = String(req.query.q || '').trim();
  if (q.length < 2) return res.json({ results: [] });
  // Tabanlar: aynen + "the"siz; her taban için bir de boşluksuz hali
  // ("the black list" → "the black list", "theblacklist", "black list",
  // "blacklist"). Bitişik → boşluklu yönü belirsiz olduğundan denenmez.
  const varyantlar = new Set();
  for (const taban of [q, q.replace(/^the\s+/i, '')]) {
    varyantlar.add(taban);
    varyantlar.add(taban.replace(/\s+/g, ''));
  }
  const sonuclar = new Map();
  await Promise.all([...varyantlar].map(async (v) => {
    try {
      const d = await tmdbGetir(
        `/search/multi?query=${encodeURIComponent(v)}`,
        ONBELLEK_TTL_SN.varsayilan,
      );
      for (const r of (d.results || [])) {
        const k = `${r.media_type}:${r.id}`;
        if (!sonuclar.has(k)) sonuclar.set(k, r);
      }
    } catch { /* tek varyant hatası aramayı bozmasın */ }
  }));
  // Sıralama: başlık eşleşmesi popülerlikten önce gelir — yoksa "game of
  // thrones" aramasında House of the Dragon (daha popüler) üste çıkıyordu.
  const duz = (s) =>
    String(s || '').toLowerCase().replace(/\s+/g, '').replace(/^the/, '');
  const hedefler = [...varyantlar].map(duz);
  const puanla = (r) => {
    const pop = r.popularity || 0;
    const adlar = [r.name, r.title, r.original_name, r.original_title]
      .filter(Boolean)
      .map(duz);
    if (adlar.some((a) => hedefler.includes(a))) return 1e9 + pop; // birebir
    if (adlar.some((a) => hedefler.some((h) => a.startsWith(h)))) {
      return 1e6 + pop; // başlangıç eşleşmesi
    }
    return pop;
  };
  let results = [...sonuclar.values()]
    .sort((a, b) => puanla(b) - puanla(a))
    .slice(0, 30);
  icerikDizineEkle(results); // dizin her başarılı aramayla zenginleşir
  let duzeltme = null;
  if (!results.length) {
    try {
      const o = await havuz.query(
        `SELECT tur, tmdb_id, ad, populerlik,
                GREATEST(similarity(lower(ad), lower($1)),
                         similarity(lower(COALESCE(orijinal_ad,'')), lower($1)))
                  AS puan
         FROM icerik_dizini
         WHERE lower(ad) % lower($1)
            OR lower(COALESCE(orijinal_ad,'')) % lower($1)
         ORDER BY puan DESC, populerlik DESC LIMIT 5`,
        [q]);
      if (o.rows.length) {
        duzeltme = o.rows[0].ad;
        // Önerileri TMDB detayından tam sonuç satırına çevir (önbellekli)
        const ekler = [];
        await Promise.all(o.rows.map(async (r) => {
          try {
            const v = await tmdbGetir(`/${r.tur}/${r.tmdb_id}`, ONBELLEK_TTL_SN.uzun);
            ekler.push({
              media_type: r.tur,
              id: r.tmdb_id,
              name: v.name,
              title: v.title,
              original_name: v.original_name,
              original_title: v.original_title,
              poster_path: v.poster_path,
              popularity: v.popularity || r.populerlik,
              first_air_date: v.first_air_date,
              release_date: v.release_date,
            });
          } catch { /* tek öneri hatası aramayı bozmasın */ }
        }));
        results = ekler.sort((a, b) => (b.popularity || 0) - (a.popularity || 0));
      }
    } catch { /* dizin/uzantı yoksa arama düz davranır */ }
  }
  res.json(duzeltme ? { results, duzeltme } : { results });
}));

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
  await mailGonder({
    to: eposta,
    subject: 'dizi.jpg — Verilerin',
    text: 'Merhaba,\n\nTalep ettiğin dizi.jpg verilerin ekte ZIP olarak yer alıyor. '
      + 'Bu ZIP\'i uygulamada Ayarlar > Veri içe aktar ile geri yükleyebilirsin.\n\n'
      + 'Bu isteği sen yapmadıysan lütfen dikkate alma.\n\ndizi.jpg',
    attachments: [{ filename: `dizijpg-verilerim-${tarih}.zip`, content: zip }],
  }, { tur: 'disa_aktar', kullanici_id: req.kullanici.id });
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
    `SELECT id, kullanici_adi, avatar, kapak, bio, ulke, sosyal, olusturma,
            izlenenler_gizli, yorumlar_gizli, yanitlar_gizli
     FROM kullanicilar WHERE kullanici_adi=$1`,
    [req.params.kullaniciAdi],
  );
  if (!k.rows.length) return res.status(404).json({ hata: 'Kullanıcı bulunamadı' });
  const id = k.rows[0].id;
  const benId = req.kullanici?.id || 0;
  // Gizlilik: sahibi kendi profilinde her şeyi görür; başkaları için
  // içerik bazlı gizlenenler düşer, genel anahtarlar bölümü tamamen kapatır.
  const benMi = benId === id;
  const izlenenlerGizli = !benMi && k.rows[0].izlenenler_gizli === true;
  const yorumlarGizli = !benMi && k.rows[0].yorumlar_gizli === true;
  // "Yanıtlarımı gizle" YALNIZ BAŞKALARINI etkiler (izlenenler_gizli /
  // yorumlar_gizli ile aynı kapsam): sahibi kendi profilinde yanıtlarını
  // görmeye devam eder, yoksa uzun-basma menüsüyle onları yönetemez ve
  // ziyaretçinin ne gördüğünü kestiremezdi.
  const yanitlarGizli = !benMi && k.rows[0].yanitlar_gizli === true;
  // Tek tek "profilimde gizle" denen yorumlar SAHİBİNE DE gösterilmez:
  // profil kullanıcının kürasyonudur, gizlediğini orada görmeyi bekler.
  // Yönetimi Ayarlar > Gizlilik > Gizlenen yorumlar ekranında yapılır.
  const yorumSuzgec = `AND NOT y.profilde_gizli
    ${yanitlarGizli ? 'AND y.ust_id IS NULL' : ''}`;
  // Başkası bakıyorsa gizli içerikleri dışlayan SQL parçası ('' = filtre yok)
  const gizliFiltre = (tablo) => benMi ? '' :
    `AND NOT EXISTS (SELECT 1 FROM gizli_icerikler g
       WHERE g.kullanici_id=$1 AND g.tur=${tablo}.tur AND g.tmdb_id=${tablo}.tmdb_id)`;
  const [istatistik, listeler, sonIncelemeler, yorumlar, takip, izlenenler, rozetler] = await Promise.all([
    havuz.query(
      `SELECT
         (SELECT count(*)::int FROM izlemeler WHERE kullanici_id=$1 AND tur='tv') AS bolum,
         (SELECT count(*)::int FROM izlemeler WHERE kullanici_id=$1 AND tur='movie') AS film,
         (SELECT count(DISTINCT tmdb_id)::int FROM izlemeler WHERE kullanici_id=$1 AND tur='tv') AS dizi,
         (SELECT count(*)::int FROM takipler WHERE takip_edilen_id=$1) AS takipci,
         (SELECT count(*)::int FROM takipler WHERE takip_eden_id=$1) AS takip_edilen,
         -- Yorum sayacı LİSTEYLE AYNI süzgeçleri kullanır: profilde gizlenen
         -- yorumlar ve (ziyaretçi bakıyorsa) yanıtlar sayılmaz. Aksi hâlde
         -- "12 yorum" yazıp 11 tane listelerdi; aradaki fark gizlenmiş bir
         -- şey olduğunu da ele verirdi. toplam_begeni/goruntulenme birer
         -- ÖMÜR BOYU toplamı, listeye bağlı değil — onlar dokunulmadı.
         (SELECT count(*)::int FROM yorumlar y
          WHERE y.kullanici_id=$1 ${yorumSuzgec} ${gizliFiltre('y')}) AS yorum,
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
    yorumlarGizli
      ? Promise.resolve({ rows: [] })
      : havuz.query(
          `SELECT tur, tmdb_id, puan, yorum, tarih FROM puanlar
           WHERE kullanici_id=$1 AND yorum IS NOT NULL ${gizliFiltre('puanlar')}
           ORDER BY tarih DESC LIMIT 10`,
          [id]),
    // Kullanıcının yorumları, beğeni ve görüntülenme sayılarıyla
    yorumlarGizli
      ? Promise.resolve({ rows: [] })
      : havuz.query(
          // kullanici_id + begendim akış kartı (AkisKarti) için ZORUNLU:
          // olmazsa kart "@null" yazar, kalp hep boş görünür ve kendi
          // gönderinde "şikayet et" menüsü çıkar. kullanici_adi/avatar
          // aşağıda profil sahibinden eklenir (hepsi aynı kişinin yorumu).
          `SELECT y.id, y.kullanici_id, y.tur, y.tmdb_id, y.sezon, y.bolum,
                  y.metin, y.medya, y.ust_id,
                  y.goruntulenme, y.spoiler, y.tarih, y.kaynak_dil,
                  (SELECT c.metin FROM metin_cevirileri c
                     WHERE c.ozet = md5(btrim(y.metin)) AND c.dil = $2) AS ceviri_metin,
                  (SELECT count(*)::int FROM yorum_begeniler b WHERE b.yorum_id=y.id) AS begeni,
                  (SELECT count(*)::int FROM yorumlar c WHERE c.ust_id=y.id) AS yanit,
                  EXISTS(SELECT 1 FROM yorum_begeniler b
                         WHERE b.yorum_id=y.id AND b.kullanici_id=$3) AS begendim,
                  -- BAĞLAM: bu satır bir YANITSA yanıtlanan gönderinin özeti.
                  -- Tam kart değil ALINTI çizilecek: yalnız yazar + kısa metin
                  -- + medya/spoiler bayrağı yeter (metin 300 karaktere kırpılır,
                  -- alıntı zaten 2 satır gösterir). ust_id NULL ise NULL döner
                  -- ve istemci alıntı bloğunu HİÇ çizmez.
                  (SELECT json_build_object(
                            'id', u.id,
                            'metin', LEFT(u.metin, 300),
                            'kullanici_adi', uk.kullanici_adi,
                            'avatar', uk.avatar,
                            'spoiler', u.spoiler,
                            'medya_var', COALESCE(cardinality(u.medya), 0) > 0)
                     FROM yorumlar u JOIN kullanicilar uk ON uk.id = u.kullanici_id
                    WHERE u.id = y.ust_id) AS ust
           FROM yorumlar y
           WHERE y.kullanici_id=$1 ${yorumSuzgec} ${gizliFiltre('y')}
           ORDER BY y.tarih DESC LIMIT 20`,
          [id, istekBaglam.getStore()?.dil || 'tr', benId]),
    havuz.query(
      `SELECT EXISTS(SELECT 1 FROM takipler WHERE takip_eden_id=$1 AND takip_edilen_id=$2) AS var,
              EXISTS(SELECT 1 FROM engellemeler WHERE engelleyen_id=$1 AND engellenen_id=$2) AS engel`,
      [benId, id]),
    // Tür başına ayrı limit: yoksa son izlenen filmler dizileri listeden atıyor
    izlenenlerGizli
      ? Promise.resolve({ rows: [] })
      : havuz.query(
          `(SELECT tur, tmdb_id, count(*)::int AS sayi, max(tarih) AS son
            FROM izlemeler WHERE kullanici_id=$1 AND tur='tv' ${gizliFiltre('izlemeler')}
            GROUP BY tur, tmdb_id ORDER BY son DESC, tmdb_id DESC LIMIT 60)
           UNION ALL
           (SELECT tur, tmdb_id, count(*)::int AS sayi, max(tarih) AS son
            FROM izlemeler WHERE kullanici_id=$1 AND tur='movie' ${gizliFiltre('izlemeler')}
            GROUP BY tur, tmdb_id ORDER BY son DESC, tmdb_id DESC LIMIT 60)
           ORDER BY son DESC, tmdb_id DESC`,
          [id]),
    rozetleriHesapla(id),
  ]);
  // Uyum: giriş yapan başka bir kullanıcı bu profile bakıyorsa, ortak izlenen
  // içerik sayısı + puan uyumu (ikisinin de puanladığı içeriklerde puanların
  // yakınlığı; 1 puan farkı ~%11 düşürür). En az 1 ortak puan yoksa uyum=null.
  let uyum = null;
  if (benId && benId !== id) {
    const [ortak, puanUyum] = await Promise.all([
      havuz.query(
        `SELECT
           count(*) FILTER (WHERE tur='tv')::int   AS dizi,
           count(*) FILTER (WHERE tur='movie')::int AS film
         FROM (
           SELECT DISTINCT tur, tmdb_id FROM izlemeler WHERE kullanici_id=$1
           INTERSECT
           SELECT DISTINCT tur, tmdb_id FROM izlemeler WHERE kullanici_id=$2
         ) o`,
        [benId, id]),
      havuz.query(
        `SELECT round(avg(1 - abs(a.puan - b.puan) / 9.0) * 100)::int AS yuzde,
                count(*)::int AS ortak_puan
         FROM puanlar a JOIN puanlar b
           ON a.tur=b.tur AND a.tmdb_id=b.tmdb_id
         WHERE a.kullanici_id=$1 AND b.kullanici_id=$2
           AND a.puan IS NOT NULL AND b.puan IS NOT NULL`,
        [benId, id]),
    ]);
    uyum = {
      ortak_dizi: ortak.rows[0].dizi,
      ortak_film: ortak.rows[0].film,
      yuzde: puanUyum.rows[0].ortak_puan > 0 ? puanUyum.rows[0].yuzde : null,
      ortak_puan: puanUyum.rows[0].ortak_puan,
    };
  }
  // Yorum kartları için içerik adı + poster (önbellekli TMDB)
  const anahtarlar = [...new Set(yorumlar.rows.map((y) => `${y.tur}:${y.tmdb_id}`))];
  const icerikler = await icerikBilgileri(anahtarlar);
  res.json({
    ...k.rows[0],
    ben_mi: benId === id,
    takip_ediyorum: takip.rows[0].var,
    engelledim: takip.rows[0].engel,
    uyum,
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
    // Kart yazarı gösterir: satırlar zaten YALNIZ bu profilin yorumları,
    // o yüzden kullanıcı bilgisi JOIN yerine buradan eklenir.
    yorumlar: yorumlar.rows.map((y) => ({
      ...ceviriUygula(y),
      kullanici_adi: k.rows[0].kullanici_adi,
      avatar: k.rows[0].avatar,
    })),
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
  const { token, platform, dil, surum } = req.body || {};
  if (typeof token !== 'string' || token.length < 20 || token.length > 4096) {
    return res.status(400).json({ hata: 'Geçersiz token' });
  }
  // surum: her açılışta yenilendiği için sürüm dağılımının doğru kaynağı burası
  // (hatalar.surum yalnız HATA ALAN kullanıcıyı sayıyordu). Eski istemciler
  // göndermez → NULL kalır, panelde "bilinmiyor" görünür.
  await havuz.query(
    `INSERT INTO cihaz_tokenlari (token, kullanici_id, platform, dil, surum, guncelleme)
     VALUES ($1,$2,$3,$4,$5,now())
     ON CONFLICT (token) DO UPDATE
       SET kullanici_id=$2, platform=$3, dil=$4,
           surum=COALESCE($5, cihaz_tokenlari.surum), guncelleme=now()`,
    [token, req.kullanici.id, String(platform || '').slice(0, 20),
     String(dil || 'tr').slice(0, 10),
     surum ? String(surum).slice(0, 40) : null],
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
// Sabit zamanlı string karşılaştırma (token zamanlama sızıntısını önler).
function esitGizli(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  if (ab.length !== bb.length) return false;
  return crypto.timingSafeEqual(ab, bb);
}

// Erişim: gerçek IP ADMIN_IPLER listesinde VEYA ADMIN_TOKEN eşleşiyorsa.
// GÜVENLİK: token yalnız X-Admin-Token BAŞLIĞINDAN okunur (query string'den
// DEĞİL — query nginx/referer loglarına ve tarayıcı geçmişine sızardı) ve
// sabit-zamanlı karşılaştırılır. IP artık spoof edilemez (bkz. gercekIp).
function adminKisit(req, res, next) {
  const ip = gercekIp(req);
  const izinli = ADMIN_IPLER.split(',').map((s) => s.trim()).filter(Boolean);
  const tokenGecerli =
    !!ADMIN_TOKEN && esitGizli(req.headers['x-admin-token'] || '', ADMIN_TOKEN);
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

// ---------- mailler (gelen: Maildir · giden: `mailler` tablosu) ----------
app.get('/admin/mailler', adminKisit, sarici(async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit, 10) || 80, 300);
  const kutular = mailKutulari();
  const [gelen, giden] = await Promise.all([
    gelenMailler(limit),
    havuz.query(
      `SELECT m.id, m.kime, m.konu, LEFT(m.govde, 180) AS ozet, m.tur,
              m.ek_ad, m.ek_boyut, m.durum, m.hata, m.tarih, k.kullanici_adi
         FROM mailler m LEFT JOIN kullanicilar k ON k.id = m.kullanici_id
       ORDER BY m.id DESC LIMIT $1`, [limit],
    ),
  ]);
  res.json({
    gelen,
    giden: giden.rows.map((r) => ({
      ...r, yon: 'giden', kimden: MAIL_FROM, tarih: r.tarih,
      ek_sayi: r.ek_ad ? 1 : 0,
    })),
    kutular: kutular.map((k) => `${k.hesap}/${k.klasor}`),
    kutu_bagli: kutular.length > 0,
  });
}));

// Tek mailin tam gövdesi. HTML gövde panelde sandbox'lı iframe'de gösterilir;
// yine de script/olay öznitelikleri sökülür ve uzak görseller (izleme pikseli)
// yüklenmesin diye src pasifleştirilir.
// DİKKAT: parametre adı ':id' OLAMAZ — sayiParam('id') tüm :id'leri 1-9 haneli
// sayıya zorlar, gelen mailin base64url kimliği 400 alırdı (canlıda yakalandı).
app.get('/admin/mail/:yon/:kimlik', adminKisit, sarici(async (req, res) => {
  if (req.params.yon === 'giden') {
    const { rows } = await havuz.query(
      `SELECT m.*, k.kullanici_adi FROM mailler m
         LEFT JOIN kullanicilar k ON k.id = m.kullanici_id WHERE m.id=$1`,
      [parseInt(req.params.kimlik, 10) || 0]);
    if (!rows.length) return res.status(404).json({ hata: 'Mail bulunamadı' });
    return res.json({ ...rows[0], yon: 'giden', kimden: MAIL_FROM, metin: rows[0].govde });
  }
  const kayit = mailKimlikCoz(req.params.kimlik);
  if (!kayit) return res.status(404).json({ hata: 'Mail bulunamadı' });
  const m = await mailAyristir(kayit);
  res.json({
    ...m, yon: 'gelen', hesap: kayit.hesap, klasor: kayit.klasor,
    okunmadi: kayit.okunmadi, boyut: kayit.boyut,
    html: m.html ? htmlKisirlastir(m.html) : null,
  });
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
  if (!gecerliTmdb(id)) return res.status(400).json({ hata: 'Geçersiz id' });
  if (!['yeni', 'incelendi', 'kapatildi'].includes(durum)) {
    return res.status(400).json({ hata: 'Geçersiz durum' });
  }
  await havuz.query('UPDATE sikayetler SET durum=$1 WHERE id=$2', [durum, id]);
  res.json({ durum: 'ok' });
}));
app.post('/admin/yorum-sil', adminKisit, sarici(async (req, res) => {
  const id = req.body?.id;
  if (!gecerliTmdb(id)) return res.status(400).json({ hata: 'Geçersiz id' });
  await havuz.query('DELETE FROM yorumlar WHERE id=$1', [id]);
  res.json({ durum: 'ok' });
}));
// ---------- depolama & yedek ----------
const YEDEK_DIZIN = process.env.YEDEK_DIZIN || '/yedekler';
const YEDEK_GUNLUK = process.env.YEDEK_GUNLUK || '/yedekler/yedek.log';

// Diskteki medyanın DB'de referansı var mı? Referans veren TÜM sütunlar:
// yorumlar.medya[] (gönderi ekleri) + mesajlar.medya (DM) — avatar/kapak ise
// ayrı dizinde durur, ayrı toplanır.
async function medyaReferanslari() {
  const [y, m] = await Promise.all([
    havuz.query('SELECT unnest(medya) AS yol FROM yorumlar WHERE cardinality(medya) > 0'),
    havuz.query('SELECT medya AS yol FROM mesajlar WHERE medya IS NOT NULL'),
  ]);
  const kume = new Set();
  for (const r of [...y.rows, ...m.rows]) {
    if (!r.yol) continue;
    const ad = path.basename(String(r.yol));
    kume.add(ad);
    // TUZAK: video küçük resmi diskte `<video>.jpg` olarak durur ve DB'de
    // referansı YOKTUR (videoKaresiCikar üretir). Referans saymazsak öksüz
    // taraması tüm video kapaklarını siler ve Keşfet ızgarası çöker.
    kume.add(`${ad}.jpg`);
  }
  return kume;
}
async function avatarReferanslari() {
  const { rows } = await havuz.query(
    'SELECT avatar, kapak FROM kullanicilar WHERE avatar IS NOT NULL OR kapak IS NOT NULL');
  const kume = new Set();
  for (const r of rows) {
    if (r.avatar) kume.add(path.basename(String(r.avatar)));
    if (r.kapak) kume.add(path.basename(String(r.kapak)));
  }
  return kume;
}

// Medya dizininde 30 bin dosya var; her taramada dosya başına statSync
// çağrılıyor ve uç ~6 sn sürüyordu (panel açılışında da çağrılıyor). Sonuç
// 60 sn önbelleklenir — depolama rakamları saniyesi saniyesine olmak zorunda
// değil, `?tazele=1` ile atlanabilir.
let DEPO_ONBELLEK = { ts: 0, deger: null };
app.get('/admin/depolama', adminKisit, sarici(async (req, res) => {
  if (!req.query.tazele && DEPO_ONBELLEK.deger
      && Date.now() - DEPO_ONBELLEK.ts < 60000) {
    return res.json({ ...DEPO_ONBELLEK.deger, onbellekten: true });
  }
  let disk = null;
  try {
    const s = fs.statfsSync('/');
    disk = { toplam: s.blocks * s.bsize, bos: s.bfree * s.bsize };
  } catch { /* statfs yoksa atla */ }
  const [medya, avatarlar, dbBoyut, tablolar] = await Promise.all([
    Promise.resolve(dizinOzet(MEDYA_DIZIN)),
    Promise.resolve(dizinOzet(AVATAR_DIZIN, 5)),
    havuz.query('SELECT pg_database_size(current_database())::bigint AS b'),
    havuz.query(
      `SELECT relname AS tablo, pg_total_relation_size(c.oid)::bigint AS boyut
         FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname='public' AND c.relkind='r'
        ORDER BY 2 DESC LIMIT 12`),
  ]);
  const cevap = {
    disk,
    medya: { ...medya, tur_dagilimi: turDagilimi(MEDYA_DIZIN) },
    avatarlar,
    db: { boyut: Number(dbBoyut.rows[0].b), tablolar: tablolar.rows.map((t) => ({ ...t, boyut: Number(t.boyut) })) },
    yedek: yedekDurumu(YEDEK_DIZIN, YEDEK_GUNLUK),
  };
  DEPO_ONBELLEK = { ts: Date.now(), deger: cevap };
  res.json(cevap);
}));

// Öksüz tarama AYRI uçta: her panel açılışında tüm dizini + DB'yi taramak
// gereksiz yük, kullanıcı isteyince çalışsın.
app.get('/admin/oksuz-tara', adminKisit, sarici(async (_req, res) => {
  const [medyaRef, avatarRef] = await Promise.all([medyaReferanslari(), avatarReferanslari()]);
  res.json({
    medya: oksuzler(MEDYA_DIZIN, medyaRef),
    avatarlar: oksuzler(AVATAR_DIZIN, avatarRef),
    not: '24 saatten yeni dosyalar öksüz sayılmaz (yükleniyor olabilir)',
  });
}));

app.post('/admin/oksuz-sil', adminKisit, sarici(async (req, res) => {
  const nere = req.body?.nere === 'avatarlar' ? 'avatarlar' : 'medya';
  const adlar = Array.isArray(req.body?.adlar) ? req.body.adlar.slice(0, 5000) : null;
  const dizin = nere === 'avatarlar' ? AVATAR_DIZIN : MEDYA_DIZIN;
  // Referansları SİLMEDEN ÖNCE tekrar oku: tarama ile silme arasında yeni
  // yorum eklenmiş olabilir, o dosya artık öksüz değildir.
  const ref = nere === 'avatarlar' ? await avatarReferanslari() : await medyaReferanslari();
  const hedef = adlar || oksuzler(dizin, ref).adlar;
  const sonuc = oksuzSil(dizin, hedef, ref);
  console.log(`oksuz-sil (${nere}): ${sonuc.silinen} dosya, ${sonuc.boyut} bayt`);
  res.json({ durum: 'ok', ...sonuc });
}));

// Elle yedek: gecelik cron'un aynısını çalıştırır (aynı dizin, aynı ad kalıbı).
// SİLME YOK — bu uç yalnızca dosya EKLER.
app.post('/admin/yedek-al', adminKisit, sarici(async (_req, res) => {
  let u;
  try { u = new URL(DATABASE_URL); } catch { return res.status(500).json({ hata: 'DATABASE_URL okunamadı' }); }
  const ts = new Date().toISOString().slice(0, 16).replace(/[-:T]/g, '').replace(/(\d{8})(\d{4})/, '$1-$2');
  const dosya = path.join(YEDEK_DIZIN, `dizijpg-${ts}-elle.sql.gz`);
  await new Promise((coz, red) => {
    execFile('/bin/sh', ['-c',
      `pg_dump -h ${u.hostname} -p ${u.port || 5432} -U ${u.username} `
      + `${u.pathname.slice(1)} | gzip > '${dosya}'`],
    { env: { ...process.env, PGPASSWORD: decodeURIComponent(u.password) }, timeout: 240000 },
    (e, _so, se) => (e ? red(new Error(se || e.message)) : coz()));
  }).catch((e) => { throw Object.assign(new Error(e.message.slice(0, 300)), { status: 500 }); });
  let boyut = null;
  try { boyut = fs.statSync(dosya).size; } catch { /* yok */ }
  res.json({ durum: 'ok', dosya: path.basename(dosya), boyut });
}));

// ---------- TMDB önbelleği ----------
app.get('/admin/onbellek', adminKisit, sarici(async (_req, res) => {
  const [ozet, yollar] = await Promise.all([
    havuz.query(
      `SELECT count(*)::int adet,
              pg_total_relation_size('tmdb_onbellek')::bigint boyut,
              min(guncelleme) en_eski, max(guncelleme) en_yeni,
              count(*) FILTER (WHERE guncelleme < now() - interval '7 days')::int eski7
         FROM tmdb_onbellek`),
    havuz.query(
      `SELECT split_part(ltrim(anahtar,'/'),'/',1) AS grup, count(*)::int adet,
              sum(pg_column_size(veri))::bigint boyut
         FROM tmdb_onbellek GROUP BY 1 ORDER BY 3 DESC LIMIT 15`),
  ]);
  res.json({
    ...ozet.rows[0],
    boyut: Number(ozet.rows[0].boyut),
    gruplar: yollar.rows.map((g) => ({ ...g, boyut: Number(g.boyut) })),
  });
}));

app.post('/admin/onbellek-temizle', adminKisit, sarici(async (req, res) => {
  const kapsam = req.body?.kapsam;
  let sonuc;
  if (kapsam === 'hepsi') {
    sonuc = await havuz.query('DELETE FROM tmdb_onbellek');
  } else if (kapsam === 'grup') {
    const grup = String(req.body?.grup || '').replace(/[^a-z_]/gi, '').slice(0, 30);
    if (!grup) return res.status(400).json({ hata: 'Geçersiz grup' });
    sonuc = await havuz.query("DELETE FROM tmdb_onbellek WHERE anahtar LIKE $1", [`/${grup}/%`]);
  } else {
    // Varsayılan: 7 günden eski kayıtlar (TMDB verisi zaten tazelenir).
    sonuc = await havuz.query(
      "DELETE FROM tmdb_onbellek WHERE guncelleme < now() - interval '7 days'");
  }
  res.json({ durum: 'ok', silinen: sonuc.rowCount });
}));

// ---------- büyüme / analitik ----------
app.get('/admin/buyume', adminKisit, sarici(async (req, res) => {
  const gun = Math.min(Math.max(parseInt(req.query.gun, 10) || 30, 7), 180);
  const [kayitlar, aktifler, tutundurma, topIcerik, push, ozet] = await Promise.all([
    // Günlük kayıt (boş günler 0 ile dolsun: grafikte delik olmasın)
    havuz.query(
      `SELECT d::date AS gun, COALESCE(k.n,0)::int AS sayi
         FROM generate_series(now()::date - ($1::int - 1), now()::date, '1 day') d
         LEFT JOIN (SELECT olusturma::date g, count(*) n FROM kullanicilar
                     WHERE olusturma > now() - ($1::int || ' days')::interval
                     GROUP BY 1) k ON k.g = d::date
        ORDER BY 1`, [gun]),
    // Günlük EYLEM YAPAN kullanıcı (son_gorulme geçmişi tutulmadığı için
    // izleme/yorum/mesaj birleşimi vekil ölçüdür).
    havuz.query(
      `WITH eylem AS (
         SELECT kullanici_id, tarih::date g FROM izlemeler WHERE tarih > now() - ($1::int || ' days')::interval
         UNION ALL
         SELECT kullanici_id, tarih::date FROM yorumlar WHERE tarih > now() - ($1::int || ' days')::interval
         UNION ALL
         SELECT gonderen_id, tarih::date FROM mesajlar WHERE tarih > now() - ($1::int || ' days')::interval)
       SELECT d::date AS gun, COALESCE(e.n,0)::int AS sayi
         FROM generate_series(now()::date - ($1::int - 1), now()::date, '1 day') d
         LEFT JOIN (SELECT g, count(DISTINCT kullanici_id) n FROM eylem GROUP BY 1) e ON e.g = d::date
        ORDER BY 1`, [gun]),
    // Tutundurma: son 30 günün kohortları, kayıttan 1 ve 7 gün SONRA eylem
    havuz.query(
      `WITH kohort AS (
         SELECT id, olusturma::date g FROM kullanicilar
          WHERE NOT misafir AND olusturma > now() - interval '30 days'),
       eylem AS (
         SELECT kullanici_id, tarih::date g FROM izlemeler
         UNION SELECT kullanici_id, tarih::date FROM yorumlar
         UNION SELECT gonderen_id, tarih::date FROM mesajlar)
       SELECT k.g AS gun, count(*)::int AS kayit,
              count(*) FILTER (WHERE EXISTS (
                SELECT 1 FROM eylem e WHERE e.kullanici_id=k.id AND e.g = k.g + 1))::int AS d1,
              count(*) FILTER (WHERE EXISTS (
                SELECT 1 FROM eylem e WHERE e.kullanici_id=k.id AND e.g BETWEEN k.g + 6 AND k.g + 8))::int AS d7
         FROM kohort k GROUP BY 1 ORDER BY 1 DESC LIMIT 30`),
    havuz.query(
      `SELECT tur, tmdb_id, count(*)::int izleme, count(DISTINCT kullanici_id)::int kisi
         FROM izlemeler WHERE tarih > now() - ($1::int || ' days')::interval
        GROUP BY 1,2 ORDER BY kisi DESC, izleme DESC LIMIT 15`, [gun]),
    havuz.query(
      // Kapsama TOPLAM kullanıcıya göre: misafir hesapların da push token'ı
      // olabiliyor, "kayıtlı"ya bölünce oran %100'ü aşıyordu (21/18).
      `SELECT (SELECT count(*)::int FROM kullanicilar) AS toplam,
              (SELECT count(*)::int FROM kullanicilar WHERE NOT misafir) AS kayitli,
              (SELECT count(DISTINCT kullanici_id)::int FROM cihaz_tokenlari) AS pushlu,
              (SELECT count(*)::int FROM cihaz_tokenlari) AS cihaz`),
    havuz.query(
      `SELECT (SELECT count(*)::int FROM kullanicilar) AS kullanici,
              (SELECT count(*)::int FROM kullanicilar
                WHERE son_gorulme > now() - interval '7 days') AS aktif7,
              (SELECT count(*)::int FROM kullanicilar
                WHERE olusturma > now() - interval '7 days') AS yeni7,
              (SELECT count(*)::int FROM yorumlar) AS yorum,
              (SELECT count(*)::int FROM izlemeler) AS izleme`),
  ]);
  // İçerik adları (önbellekli TMDB)
  const adlar = {};
  const anahtarlar = topIcerik.rows.map((r) => `${r.tur}:${r.tmdb_id}`);
  for (let i = 0; i < anahtarlar.length; i += 8) {
    await Promise.all(anahtarlar.slice(i, i + 8).map(async (a) => {
      const [tur, id] = a.split(':');
      try {
        const v = await tmdbGetir(`/${tur}/${id}?language=tr-TR`, ONBELLEK_TTL_SN.uzun);
        adlar[a] = v.name || v.title || '?';
      } catch { adlar[a] = '?'; }
    }));
  }
  res.json({
    gun,
    kayitlar: kayitlar.rows,
    aktifler: aktifler.rows,
    tutundurma: tutundurma.rows,
    top_icerik: topIcerik.rows,
    icerik_adlari: adlar,
    push: push.rows[0],
    ozet: ozet.rows[0],
  });
}));

// ---------- sürüm dağılımı + ayarlar ----------
app.get('/admin/surumler', adminKisit, sarici(async (_req, res) => {
  const [cihaz, hata, ayar] = await Promise.all([
    havuz.query(
      `SELECT COALESCE(surum,'bilinmiyor') surum, COALESCE(platform,'?') platform,
              count(*)::int cihaz, count(DISTINCT kullanici_id)::int kisi,
              max(guncelleme) son
         FROM cihaz_tokenlari GROUP BY 1,2 ORDER BY son DESC NULLS LAST`),
    havuz.query(
      `SELECT COALESCE(surum,'bilinmiyor') surum, count(*)::int hata,
              max(tarih) son
         FROM hatalar WHERE tarih > now() - interval '30 days'
        GROUP BY 1 ORDER BY hata DESC LIMIT 20`),
    havuz.query('SELECT anahtar, deger FROM ayarlar'),
  ]);
  res.json({
    cihazlar: cihaz.rows,
    hatalar: hata.rows,
    ayarlar: Object.fromEntries(ayar.rows.map((a) => [a.anahtar, a.deger])),
  });
}));

// Panelden değiştirilebilen ayarlar — beyaz liste (rastgele anahtar yazılamaz).
const AYAR_ANAHTARLARI = [
  'min_derleme', 'onerilen_derleme', 'guncelleme_url', 'guncelleme_notu',
  'algoritma_acik', 'algoritma_akis_acik', 'algoritma_kesfet_acik',
  'algoritma_akis', 'algoritma_kesfet',
];
// Ağırlık seti JSON'u 500 karakteri aşıyor (ölçüm: ~420-520 bayt); kırpılırsa
// bozuk JSON kaydedilir ve ayar sessizce varsayılana düşerdi.
const AYAR_UZUN = new Set(['algoritma_akis', 'algoritma_kesfet']);
app.post('/admin/ayar', adminKisit, sarici(async (req, res) => {
  const { anahtar, deger } = req.body || {};
  if (!AYAR_ANAHTARLARI.includes(anahtar)) {
    return res.status(400).json({ hata: 'Bilinmeyen ayar' });
  }
  const sinir = AYAR_UZUN.has(anahtar) ? 4000 : 500;
  const d = deger === null || deger === '' ? null : String(deger).slice(0, sinir);
  if (['min_derleme', 'onerilen_derleme'].includes(anahtar) && d !== null && !/^\d{1,6}$/.test(d)) {
    return res.status(400).json({ hata: 'Derleme numarası sayı olmalı' });
  }
  await havuz.query(
    `INSERT INTO ayarlar (anahtar, deger, guncelleme) VALUES ($1,$2,now())
     ON CONFLICT (anahtar) DO UPDATE SET deger=$2, guncelleme=now()`, [anahtar, d]);
  AYAR_ONBELLEK = { ts: 0, deger: {} }; // /surum-kontrol anında yeni değeri görsün
  res.json({ durum: 'ok' });
}));

// ---------- sıralama algoritması paneli ----------
// GÜVENLİK: bu uçlar `/admin/...` altında olduğu için nginx'teki
// `location ^~ /api/admin` ÖNEK bloğu tarafından otomatik korunur (IP kısıtı +
// X-Admin-Token). Yeni nginx kuralı GEREKMEZ; `adminKisit` ikinci kapıdır.

// Bir yüzeyin ayarını + canlı hacim ölçümünü + hangi sinyalin sustuğunu döner.
function yuzeyOzeti(ayar, olcum) {
  const h = hacimUygula(ayar, olcum);
  return {
    ayar,
    pay: h.pay, // gerçek etki (yüzde) — slider ham sayı, bu normalize hali
    susan: h.susan,
    toplam: h.toplam,
  };
}

app.get('/admin/algoritma', adminKisit, sarici(async (_req, res) => {
  const [alg, olcum] = await Promise.all([algoritmaAyarlari(), algoritmaOlcumleri()]);
  res.json({
    acik: alg.acik,
    akis_acik: alg.akis_acik,
    kesfet_acik: alg.kesfet_acik,
    akis: yuzeyOzeti(alg.akis, olcum),
    kesfet: yuzeyOzeti(alg.kesfet, olcum),
    varsayilan: { akis: VARSAYILAN_AKIS, kesfet: VARSAYILAN_KESFET },
    agirliklar: AGIRLIK_ANAHTARLARI,
    sayim_sinyalleri: SAYIM_SINYALLERI,
    sinirlar: SAYI_ALANLARI,
    arsiv_yas_saat: ARSIV_YAS_SAAT,
    olcum, // panel rozetlerindeki BÜTÜN sayılar buradan — sabit yazılmaz
    tohum_oturum: tohumDeposu.boyut,
  });
}));

// Tüm set TEK POST ile kaydedilir: slider'lar tek tek kaydedilseydi yarı
// uygulanmış bir ayar canlıya çıkardı (bir ağırlık yeni, diğeri eski).
app.post('/admin/algoritma', adminKisit, sarici(async (req, res) => {
  const { yuzey, ayar, acik, akis_acik: akisAcik, kesfet_acik: kesfetAcik } = req.body || {};
  const yazilacak = [];
  if (acik !== undefined) yazilacak.push(['algoritma_acik', acik ? '1' : '0']);
  if (akisAcik !== undefined) yazilacak.push(['algoritma_akis_acik', akisAcik ? '1' : '0']);
  if (kesfetAcik !== undefined) yazilacak.push(['algoritma_kesfet_acik', kesfetAcik ? '1' : '0']);
  if (yuzey !== undefined) {
    if (yuzey !== 'akis' && yuzey !== 'kesfet') {
      return res.status(400).json({ hata: 'Bilinmeyen yüzey' });
    }
    const temiz = ayarBirlestir(ayar, yuzey);
    // En az bir ağırlık > 0 olmalı (plan §5.4). ayarBirlestir zaten varsayılana
    // düşürüyor; kullanıcıya sessiz kalmamak için burada da söylenir.
    if (AGIRLIK_ANAHTARLARI.every((a) => Number(ayar?.[a]) === 0)) {
      return res.status(400).json({ hata: 'En az bir ağırlık 0dan büyük olmalı' });
    }
    yazilacak.push([`algoritma_${yuzey}`, JSON.stringify(temiz)]);
  }
  if (!yazilacak.length) return res.status(400).json({ hata: 'Kaydedilecek bir şey yok' });
  for (const [anahtar, deger] of yazilacak) {
    await havuz.query(
      `INSERT INTO ayarlar (anahtar, deger, guncelleme) VALUES ($1,$2,now())
       ON CONFLICT (anahtar) DO UPDATE SET deger=$2, guncelleme=now()`, [anahtar, deger]);
  }
  AYAR_ONBELLEK = { ts: 0, deger: {} }; // sonraki istek yeni ağırlıklarla
  res.json({ durum: 'ok', yazilan: yazilacak.map(([a]) => a) });
}));

app.post('/admin/algoritma-varsayilan', adminKisit, sarici(async (req, res) => {
  const yuzey = req.body?.yuzey;
  const hedef = (yuzey === 'akis' || yuzey === 'kesfet') ? [yuzey] : ['akis', 'kesfet'];
  for (const y of hedef) {
    await havuz.query(
      `INSERT INTO ayarlar (anahtar, deger, guncelleme) VALUES ($1,$2,now())
       ON CONFLICT (anahtar) DO UPDATE SET deger=$2, guncelleme=now()`,
      [`algoritma_${y}`, JSON.stringify(y === 'kesfet' ? VARSAYILAN_KESFET : VARSAYILAN_AKIS)]);
  }
  AYAR_ONBELLEK = { ts: 0, deger: {} };
  res.json({ durum: 'ok', yuzeyler: hedef });
}));

// KAYDETMEDEN önizleme (Bakım sekmesindeki `surumOnizle` deseninin eşi).
// MAHREMİYET: yanıt gönderi METNİ ve MEDYASI DÖNDÜRMEZ (plan §5.2 uyarısı) —
// yalnız id, yazar adı, yapım anahtarı ve skor kırılımı. Varsayılan kullanıcı
// test hesabıdır; gerçek kullanıcının akışı panelde okunamaz.
app.get('/admin/algoritma-onizleme', adminKisit, sarici(async (req, res) => {
  const yuzey = req.query.yuzey === 'kesfet' ? 'kesfet' : 'akis';
  const kimId = parseInt(req.query.kullanici, 10) || 1;
  const adet = Math.min(50, Math.max(5, parseInt(req.query.adet, 10) || 20));
  let ham = null;
  if (req.query.agirliklar) {
    ham = jsonCoz(String(req.query.agirliklar));
    if (!ham) return res.status(400).json({ hata: 'Ağırlık JSONu çözülemedi' });
  } else {
    const alg = await algoritmaAyarlari();
    ham = alg[yuzey];
  }
  const ayar = ayarBirlestir(ham, yuzey);
  const olcum = await algoritmaOlcumleri();
  const hacim = hacimUygula(ayar, olcum);
  const t0 = Date.now();
  const adaylar = await adaylariGetir({
    benId: kimId, dil: 'tr', kadro: [], hacim,
    gorulenHaric: false, kat: hacim.pay.medya > 0,
  });
  const sqlMs = Date.now() - t0;
  const t1 = Date.now();
  const { idler, kirilim } = siralaVeKotala(adaylar, ayar, olcum, { kirilimAdet: adet });
  const skorMs = Date.now() - t1;
  // Yazar adı + yapım anahtarı (metin/medya YOK)
  const ust = idler.slice(0, adet);
  const { rows } = ust.length ? await havuz.query(
    `SELECT y.id, k.kullanici_adi, y.tur, y.tmdb_id
       FROM yorumlar y JOIN kullanicilar k ON k.id=y.kullanici_id
      WHERE y.id = ANY($1::int[])`, [ust]) : { rows: [] };
  const bilgi = new Map(rows.map((r) => [r.id, r]));
  const liste = kirilim.map((k, i) => ({ sira: i + 1, ...k, ...(bilgi.get(k.id) || {}) }));
  const yazarlar = {};
  for (const s of liste) yazarlar[s.kullanici_adi || '?'] = (yazarlar[s.kullanici_adi || '?'] || 0) + 1;
  res.json({
    yuzey,
    kullanici: kimId,
    aday: adaylar.length,
    susan: hacim.susan,
    pay: hacim.pay,
    liste,
    yazar_dagilimi: yazarlar,
    farkli_yazar: Object.keys(yazarlar).length,
    ai_orani: liste.length ? liste.filter((s) => s.ai).length / liste.length : 0,
    arsiv_orani: liste.length ? liste.filter((s) => s.arsiv).length / liste.length : 0,
    sure: { sql_ms: sqlMs, skor_ms: skorMs },
  });
}));

// ---------- çeviri kuyruğu durumu ----------
app.get('/admin/ceviri-durum', adminKisit, sarici(async (_req, res) => {
  const [ozet, diller, kaynak, bekleyen] = await Promise.all([
    havuz.query(
      `SELECT count(*)::int kayit, count(DISTINCT ozet)::int metin,
              pg_total_relation_size('metin_cevirileri')::bigint boyut,
              max(olusturma) son FROM metin_cevirileri`),
    havuz.query(
      'SELECT dil, count(*)::int adet FROM metin_cevirileri GROUP BY 1 ORDER BY 2 DESC LIMIT 30'),
    havuz.query(
      `SELECT COALESCE(kaynak_dil,'bilinmiyor') dil, count(*)::int adet
         FROM yorumlar GROUP BY 1 ORDER BY 2 DESC LIMIT 15`),
    // En çok istenen hedef dil (en) için çevrilmemiş metin sayısı
    havuz.query(
      `SELECT count(*)::int adet FROM (
         SELECT md5(btrim(metin)) o FROM yorumlar
          WHERE metin IS NOT NULL AND length(btrim(metin)) > 2
            AND kaynak_dil IS DISTINCT FROM 'en'
          GROUP BY 1) t
        WHERE NOT EXISTS (SELECT 1 FROM metin_cevirileri c WHERE c.ozet=t.o AND c.dil='en')`),
  ]);
  res.json({
    ...ozet.rows[0],
    boyut: Number(ozet.rows[0].boyut),
    diller: diller.rows,
    kaynak_diller: kaynak.rows,
    bekleyen_en: bekleyen.rows[0].adet,
  });
}));

// ---------- geri bildirimler ----------
const GB_DURUM = ['yeni', 'okundu', 'kapatildi'];

app.get('/admin/geri-bildirimler', adminKisit, sarici(async (req, res) => {
  const durum = GB_DURUM.includes(req.query.durum) ? req.query.durum : null;
  const { rows } = await havuz.query(
    `SELECT g.id, g.metin, g.surum, g.platform, g.durum, g.yanit_metni,
            g.yanit_tarihi, g.tarih, k.kullanici_adi, k.email, k.id AS kullanici_id
       FROM geri_bildirimler g JOIN kullanicilar k ON k.id = g.kullanici_id
     ${durum ? 'WHERE g.durum=$1' : ''} ORDER BY g.id DESC LIMIT 300`,
    durum ? [durum] : [],
  );
  const { rows: sayim } = await havuz.query(
    "SELECT count(*) FILTER (WHERE durum='yeni')::int yeni, count(*)::int toplam FROM geri_bildirimler");
  res.json({ geri_bildirimler: rows, ...sayim[0] });
}));

app.post('/admin/geri-bildirim-durum', adminKisit, sarici(async (req, res) => {
  const { id, durum } = req.body || {};
  if (!gecerliTmdb(id)) return res.status(400).json({ hata: 'Geçersiz id' });
  if (!GB_DURUM.includes(durum)) return res.status(400).json({ hata: 'Geçersiz durum' });
  await havuz.query('UPDATE geri_bildirimler SET durum=$1 WHERE id=$2', [durum, id]);
  res.json({ durum: 'ok' });
}));

// Geri bildirime e-postayla yanıt: mailGonder'den geçer, giden günlüğüne düşer.
app.post('/admin/geri-bildirim-yanit', adminKisit, sarici(async (req, res) => {
  const { id, metin } = req.body || {};
  if (!gecerliTmdb(id)) return res.status(400).json({ hata: 'Geçersiz id' });
  const govde = String(metin || '').trim();
  if (govde.length < 2 || govde.length > 5000) {
    return res.status(400).json({ hata: 'Yanıt 2-5000 karakter olmalı' });
  }
  const { rows } = await havuz.query(
    `SELECT g.metin, k.email, k.id AS kullanici_id FROM geri_bildirimler g
       JOIN kullanicilar k ON k.id = g.kullanici_id WHERE g.id=$1`, [id]);
  if (!rows.length) return res.status(404).json({ hata: 'Geri bildirim bulunamadı' });
  if (!rows[0].email) {
    return res.status(400).json({ hata: 'Kullanıcının e-postası yok (misafir hesap)' });
  }
  // Kullanıcının ne yazdığını alıntıla: aylar sonra gelen yanıtta bağlam kalsın.
  await mailGonder({
    to: rows[0].email,
    subject: 'dizi.jpg — geri bildirimin hakkında',
    text: `${govde}\n\n---\nSenin gönderdiğin geri bildirim:\n`
      + `${String(rows[0].metin).split('\n').map((s) => `> ${s}`).join('\n')}\n\ndizi.jpg`,
  }, { tur: 'geri_bildirim_yanit', kullanici_id: rows[0].kullanici_id });
  await havuz.query(
    `UPDATE geri_bildirimler SET yanit_metni=$1, yanit_tarihi=now(),
       durum=CASE WHEN durum='yeni' THEN 'okundu' ELSE durum END WHERE id=$2`,
    [govde, id]);
  res.json({ durum: 'ok', kime: rows[0].email });
}));

// ---------- kullanıcı listesi ----------
// Panelde kullanıcıya ancak adını BİLEREK ulaşılabiliyordu; gezilebilir liste.
const KULLANICI_SIRA = {
  son_gorulme: 'k.son_gorulme DESC NULLS LAST',
  kayit: 'k.id DESC',
  yorum: 'yorum DESC',
  izleme: 'izleme DESC',
  ad: 'k.kullanici_adi ASC',
};

app.get('/admin/kullanicilar', adminKisit, sarici(async (req, res) => {
  const sirala = KULLANICI_SIRA[req.query.sirala] || KULLANICI_SIRA.son_gorulme;
  const ara = String(req.query.ara || '').trim().slice(0, 60);
  const limit = Math.min(parseInt(req.query.limit, 10) || 100, 500);
  const kosullar = [];
  const parametreler = [];
  if (ara) {
    parametreler.push(`%${ara.toLowerCase()}%`);
    kosullar.push(`(lower(k.kullanici_adi) LIKE $${parametreler.length}
                    OR lower(k.email) LIKE $${parametreler.length})`);
  }
  if (req.query.suzgec === 'yasakli') kosullar.push('k.yasakli');
  if (req.query.suzgec === 'kayitli') kosullar.push('NOT k.misafir');
  if (req.query.suzgec === 'misafir') kosullar.push('k.misafir');
  parametreler.push(limit);
  const { rows } = await havuz.query(
    `SELECT k.id, k.kullanici_adi, k.email, k.misafir, k.yasakli, k.avatar,
            k.ulke, k.olusturma, k.son_gorulme,
            (SELECT count(*)::int FROM yorumlar y WHERE y.kullanici_id=k.id) AS yorum,
            (SELECT count(*)::int FROM izlemeler i WHERE i.kullanici_id=k.id) AS izleme,
            (SELECT count(*)::int FROM takipler t WHERE t.takip_edilen_id=k.id) AS takipci,
            (SELECT count(*)::int FROM cihaz_tokenlari c WHERE c.kullanici_id=k.id) AS cihaz
       FROM kullanicilar k
     ${kosullar.length ? 'WHERE ' + kosullar.join(' AND ') : ''}
     ORDER BY ${sirala} LIMIT $${parametreler.length}`,
    parametreler,
  );
  res.json({ kullanicilar: rows });
}));

// ---------- yorum moderasyonu ----------
// Şu ana kadar yalnız ŞİKAYET EDİLEN yorumlar görülebiliyordu; bu uç tümünde
// arama yapar (4800+ yorum), medya ve etkileşim sayılarıyla.
app.get('/admin/yorumlar', adminKisit, sarici(async (req, res) => {
  const ara = String(req.query.ara || '').trim().slice(0, 80);
  const limit = Math.min(parseInt(req.query.limit, 10) || 60, 200);
  const parametreler = [];
  const kosullar = [];
  if (ara) {
    parametreler.push(`%${ara.toLowerCase()}%`);
    kosullar.push(`(lower(y.metin) LIKE $${parametreler.length}
                    OR lower(k.kullanici_adi) LIKE $${parametreler.length})`);
  }
  if (req.query.suzgec === 'medyali') kosullar.push('cardinality(y.medya) > 0');
  if (req.query.suzgec === 'sikayetli') {
    kosullar.push("EXISTS (SELECT 1 FROM sikayetler s WHERE s.tur='yorum' AND s.hedef_id=y.id)");
  }
  // İngilizce ana hedef dil (4351 çeviriden en çoğu ona): "çevrilmemiş" =
  // İngilizce karşılığı olmayan, zaten İngilizce OLMAYAN gönderi.
  if (req.query.suzgec === 'cevrilmemis') {
    kosullar.push(`y.kaynak_dil IS DISTINCT FROM 'en' AND NOT EXISTS (
      SELECT 1 FROM metin_cevirileri c
       WHERE c.ozet = md5(btrim(y.metin)) AND c.dil = 'en')`);
  }
  parametreler.push(limit);
  const { rows } = await havuz.query(
    `SELECT y.id, y.tur, y.tmdb_id, y.sezon, y.bolum, LEFT(y.metin, 400) AS metin,
            y.medya, y.goruntulenme, y.tarih, y.ust_id, y.kaynak_dil,
            k.kullanici_adi, k.yasakli, k.id AS kullanici_id,
            (SELECT count(*)::int FROM yorum_begeniler b WHERE b.yorum_id=y.id) AS begeni,
            (SELECT count(*)::int FROM sikayetler s
              WHERE s.tur='yorum' AND s.hedef_id=y.id) AS sikayet,
            -- Çeviriler METNE bağlıdır (md5 özeti), gönderiye değil: aynı metni
            -- yazan iki gönderi tek çeviriyi paylaşır.
            (SELECT array_agg(c.dil ORDER BY c.dil) FROM metin_cevirileri c
              WHERE c.ozet = md5(btrim(y.metin))) AS ceviri_diller
       FROM yorumlar y JOIN kullanicilar k ON k.id = y.kullanici_id
     ${kosullar.length ? 'WHERE ' + kosullar.join(' AND ') : ''}
     ORDER BY y.id DESC LIMIT $${parametreler.length}`,
    parametreler,
  );
  // İçerik adları (önbellekli TMDB) — hangi dizi/filme yazıldığı okunur olsun.
  const anahtarlar = [...new Set(rows.map((r) => `${r.tur}:${r.tmdb_id}`))].slice(0, 60);
  const icerikler = {};
  for (let i = 0; i < anahtarlar.length; i += 8) {
    await Promise.all(anahtarlar.slice(i, i + 8).map(async (a) => {
      const [tur, id] = a.split(':');
      try {
        const v = await tmdbGetir(`/${tur}/${id}?language=tr-TR`, ONBELLEK_TTL_SN.uzun);
        icerikler[a] = v.name || v.title || '?';
      } catch { icerikler[a] = '?'; }
    }));
  }
  res.json({ yorumlar: rows, icerikler });
}));

// ---------- toplu duyuru (push) ----------
// Kaç cihaza gideceğini ÖNCE gösterir: geri alınamaz bir işlem, körlemesine
// gönderilmemeli.
app.get('/admin/duyuru-onizleme', adminKisit, sarici(async (_req, res) => {
  const [dagilim, gecmis] = await Promise.all([
    havuz.query(
      `SELECT COALESCE(platform,'bilinmiyor') platform,
              CASE WHEN dil='tr' THEN 'tr' ELSE 'diger' END dil_grup,
              count(*)::int sayi
         FROM cihaz_tokenlari GROUP BY 1,2 ORDER BY 3 DESC`),
    havuz.query('SELECT * FROM duyurular ORDER BY id DESC LIMIT 20'),
  ]);
  res.json({
    dagilim: dagilim.rows,
    toplam: dagilim.rows.reduce((t, r) => t + r.sayi, 0),
    fcm: fcmHazir,
    gecmis: gecmis.rows,
  });
}));

app.post('/admin/duyuru', adminKisit, sarici(async (req, res) => {
  if (!fcmHazir) return res.status(503).json({ hata: 'FCM kapalı (servis hesabı yok)' });
  const baslik = String(req.body?.baslik || '').trim().slice(0, 80);
  const metin = String(req.body?.metin || '').trim().slice(0, 400);
  const metinEn = String(req.body?.metin_en || '').trim().slice(0, 400);
  const platform = ['android', 'ios'].includes(req.body?.platform) ? req.body.platform : null;
  if (baslik.length < 2 || metin.length < 2) {
    return res.status(400).json({ hata: 'Başlık ve metin gerekli (en az 2 karakter)' });
  }
  const { rows: cihazlar } = await havuz.query(
    `SELECT token, COALESCE(dil,'tr') dil FROM cihaz_tokenlari
     ${platform ? 'WHERE platform=$1' : ''}`, platform ? [platform] : []);
  if (!cihazlar.length) return res.status(400).json({ hata: 'Hedefte kayıtlı cihaz yok' });

  // Türkçe cihazlara Türkçe, diğerlerine İngilizce (boşsa Türkçe) gövde.
  const gruplar = [
    { tokens: cihazlar.filter((c) => c.dil === 'tr').map((c) => c.token), govde: metin },
    { tokens: cihazlar.filter((c) => c.dil !== 'tr').map((c) => c.token), govde: metinEn || metin },
  ].filter((g) => g.tokens.length);

  let basarili = 0;
  let basarisiz = 0;
  const gecersiz = [];
  for (const grup of gruplar) {
    // FCM multicast tavanı 500 token.
    for (let i = 0; i < grup.tokens.length; i += 500) {
      const parca = grup.tokens.slice(i, i + 500);
      const yanit = await admin.messaging().sendEachForMulticast({
        tokens: parca,
        notification: { title: baslik, body: grup.govde },
        data: { tur: 'duyuru' },
        android: { priority: 'high', notification: { channelId: 'dizijpg_bildirim' } },
      });
      basarili += yanit.successCount;
      basarisiz += yanit.failureCount;
      yanit.responses.forEach((r, j) => {
        const kod = r.error?.code || '';
        if (!r.success && /not-registered|invalid-argument|invalid-registration/.test(kod)) {
          gecersiz.push(parca[j]);
        }
      });
    }
  }
  // Ölü tokenları temizle: bir dahaki duyuruda sayılar şişmesin.
  if (gecersiz.length) {
    await havuz.query('DELETE FROM cihaz_tokenlari WHERE token = ANY($1)', [gecersiz]);
  }
  const { rows } = await havuz.query(
    `INSERT INTO duyurular (baslik, metin, metin_en, platform, cihaz_sayi, basarili, basarisiz)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
    [baslik, metin, metinEn || null, platform, cihazlar.length, basarili, basarisiz]);
  res.json({ durum: 'ok', ...rows[0], temizlenen: gecersiz.length });
}));

app.post('/admin/kullanici-ban', adminKisit, sarici(async (req, res) => {
  const { id, yasakli } = req.body || {};
  if (!gecerliTmdb(id)) return res.status(400).json({ hata: 'Geçersiz id' });
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
