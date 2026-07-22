// dizi.jpg API — auth, TMDB proxy (önbellekli), izleme/puan/liste/istatistik
import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import pg from 'pg';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import nodemailer from 'nodemailer';
import { disaAktar, iceAktar } from './veri_aktar.js';

const {
  DATABASE_URL,
  JWT_SECRET,
  TMDB_TOKEN,
  PORT = 8500,
} = process.env;

if (!DATABASE_URL || !JWT_SECRET || !TMDB_TOKEN) {
  console.error('Eksik ortam değişkeni (DATABASE_URL / JWT_SECRET / TMDB_TOKEN)');
  process.exit(1);
}

const havuz = new pg.Pool({ connectionString: DATABASE_URL });
const app = express();
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
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  // Yüklenen dosyalar tarayıcıda içerik koklamasıyla çalıştırılamasın.
  res.set('X-Content-Type-Options', 'nosniff');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

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

function jwtUret(kullanici) {
  return jwt.sign(
    { id: kullanici.id, kullanici_adi: kullanici.kullanici_adi },
    JWT_SECRET,
    { expiresIn: '90d' },
  );
}

function girisZorunlu(req, res, next) {
  const baslik = req.headers.authorization || '';
  const token = baslik.startsWith('Bearer ') ? baslik.slice(7) : null;
  if (!token) return res.status(401).json({ hata: 'Giriş gerekli' });
  try {
    req.kullanici = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ hata: 'Geçersiz oturum' });
  }
}

// Token varsa req.kullanici'yi doldurur; yoksa geçer (herkese açık uçlarda
// "giriş yapan kişi bunu takip ediyor mu / beğendi mi" bilgisi için).
function girisIsteğeBagli(req, _res, next) {
  const baslik = req.headers.authorization || '';
  const token = baslik.startsWith('Bearer ') ? baslik.slice(7) : null;
  if (token) {
    try { req.kullanici = jwt.verify(token, JWT_SECRET); } catch { /* anonim */ }
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

// Bildirim ekler; kendi eylemine bildirim düşmez, hata akışı bozmaz.
async function bildirimEkle(aliciId, tur, aktorId, yorumId = null) {
  if (!aliciId || aliciId === aktorId) return;
  await havuz.query(
    'INSERT INTO bildirimler (kullanici_id, tur, aktor_id, yorum_id) VALUES ($1,$2,$3,$4)',
    [aliciId, tur, aktorId, yorumId],
  ).catch(() => {});
}

// ---------- sağlık ----------
app.get('/saglik', sarici(async (_req, res) => {
  await havuz.query('SELECT 1');
  res.json({ durum: 'ok', servis: 'dizi.jpg API' });
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
    const ad = 'misafir_' + Math.random().toString(36).slice(2, 8);
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

// Dizi adından TMDB tv id'si (isimle arama; içe aktarım yedeği, önbellekli).
async function isimdenTmdbTv(isim) {
  const q = encodeURIComponent(String(isim).slice(0, 100));
  const veri = await tmdbGetir(
    `/search/tv?query=${q}&language=tr-TR`, ONBELLEK_TTL_SN.uzun);
  return veri?.results?.[0]?.id || null;
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
  return veri?.results?.[0]?.id || null;
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
    parametreler.set('append_to_response', 'credits,videos,recommendations,external_ids');
  }
  const tam = `${yol}?${parametreler.toString()}`;
  const uzunTtl = /^\/(tv|movie|person)\//.test(yol);
  res.json(await tmdbGetir(tam, uzunTtl ? ONBELLEK_TTL_SN.uzun : ONBELLEK_TTL_SN.varsayilan));
}));

// ---------- izleme ----------
app.post('/izleme/toggle', girisZorunlu, sarici(async (req, res) => {
  const { tmdb_id, tur, sezon = 0, bolum = 0 } = req.body || {};
  if (!Number.isInteger(tmdb_id) || !['tv', 'movie'].includes(tur) ||
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
  res.json({ izlendi: silindi.rowCount === 0 });
}));

// Bir sezonun tamamını işaretle/kaldır
app.post('/izleme/sezon', girisZorunlu, sarici(async (req, res) => {
  const { tmdb_id, sezon, bolum_sayisi, isaretle = true } = req.body || {};
  if (!tmdb_id || !sezon || !bolum_sayisi) {
    return res.status(400).json({ hata: 'tmdb_id, sezon, bolum_sayisi gerekli' });
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

// ---------- durum / puan / favori ----------
app.post('/durum', girisZorunlu, sarici(async (req, res) => {
  const { tmdb_id, tur, durum } = req.body || {};
  if (!['tv', 'movie'].includes(tur) || !Number.isInteger(tmdb_id)) {
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
  res.json({ durum });
}));

app.post('/puan', girisZorunlu, sarici(async (req, res) => {
  const { tmdb_id, tur, puan, yorum = null } = req.body || {};
  if (!['tv', 'movie', 'person'].includes(tur) || !Number.isInteger(tmdb_id)) {
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
  if (!['tv', 'movie'].includes(tur) || !Number.isInteger(tmdb_id)) {
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
  if (!['tv', 'movie'].includes(tur) || !Number.isInteger(tmdb_id)) return null;
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
  if (!['tv', 'movie'].includes(tur) || !Number.isInteger(tmdb_id)) {
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
  if (!['tv', 'movie'].includes(tur) || !Number.isInteger(tmdb_id)) {
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
    try { kimlik = token ? jwt.verify(token, JWT_SECRET) : null; } catch { /* gizli kalsın */ }
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
  const [bolum, film, dizi, yorum, sosyal] = await Promise.all([
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
  ]);
  res.json({
    izlenen_bolum: bolum.rows[0].adet,
    izlenen_film: film.rows[0].adet,
    takip_edilen_dizi: dizi.rows[0].adet,
    yorum_sayisi: yorum.rows[0].adet,
    takipci_sayisi: sosyal.rows[0].takipci,
    takip_sayisi: sosyal.rows[0].takip,
    // Yaklaşık süreler: bölüm ~42 dk, film ~110 dk
    tahmini_dakika: bolum.rows[0].adet * 42 + film.rows[0].adet * 110,
  });
}));

// Otomatik "İzlediklerim" listesi: izlenmiş filmler + en az bir bölümü
// izlenmiş diziler. En son izlenen önce gelir.
app.get('/izlediklerim', girisZorunlu, sarici(async (req, res) => {
  const { rows } = await havuz.query(
    `SELECT tur, tmdb_id, count(*)::int AS sayi, max(tarih) AS son
     FROM izlemeler WHERE kullanici_id=$1
     GROUP BY tur, tmdb_id
     ORDER BY son DESC LIMIT 200`,
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
  const { rows } = await havuz.query(
    `SELECT tmdb_id FROM durumlar
     WHERE kullanici_id=$1 AND tur='tv' AND durum IN ('izliyorum','izleyecegim')
     LIMIT 40`,
    [req.kullanici.id],
  );
  const izl = await havuz.query(
    `SELECT tmdb_id, sezon, bolum FROM izlemeler
     WHERE kullanici_id=$1 AND tur='tv'`,
    [req.kullanici.id],
  );
  const izlenen = new Set(izl.rows.map((r) => `${r.tmdb_id}:${r.sezon}:${r.bolum}`));
  const bugun = new Date().toISOString().slice(0, 10);
  const DIZI_BASI_SINIR = 15; // tek dizi takvimi boğmasın
  const sonuclar = [];
  // 8'li paralel öbekler: 40 dizi × 4 sezon çağrısı aynı anda patlamasın
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
      const sezonlar = (dizi.seasons || [])
        .filter((s) => s.season_number > 0 && s.season_number >= Math.max(maxS, 1))
        .slice(0, 4); // en fazla 4 sezon ileri bak
      let eklenen = 0;
      for (const s of sezonlar) {
        if (eklenen >= DIZI_BASI_SINIR) break;
        const sez = await tmdbGetir(
          `/tv/${tmdb_id}/season/${s.season_number}?language=tr-TR`,
          ONBELLEK_TTL_SN.varsayilan,
        );
        for (const b of (sez.episodes || [])) {
          const sn = s.season_number;
          const bn = b.episode_number;
          if (sn < maxS || (sn === maxS && bn <= maxB)) continue;
          if (izlenen.has(`${tmdb_id}:${sn}:${bn}`)) continue;
          if (!b.air_date) continue; // yayın tarihi belli olmayanlar gelmez
          if (maxS === 0 && b.air_date < bugun) continue; // başlanmamış dizi arşivi
          sonuclar.push({
            tmdb_id,
            dizi_adi: dizi.name,
            poster: dizi.poster_path,
            sezon: sn,
            bolum: bn,
            bolum_adi: b.name,
            tarih: b.air_date,
          });
          if (++eklenen >= DIZI_BASI_SINIR) break;
        }
      }
    } catch { /* tek dizi hatası takvimi bozmasın */ }
  };
  for (let i = 0; i < rows.length; i += 8) {
    await Promise.all(rows.slice(i, i + 8).map(diziIsle));
  }
  sonuclar.sort((a, b) => a.tarih.localeCompare(b.tarih));
  res.json({ yaklasan: sonuclar });
}));

// ---------- profilim ----------
app.get('/profilim', girisZorunlu, sarici(async (req, res) => {
  const { rows } = await havuz.query(
    `SELECT id, kullanici_adi, email, misafir, avatar, kapak, bio, ulke
     FROM kullanicilar WHERE id=$1`,
    [req.kullanici.id],
  );
  if (!rows.length) return res.status(404).json({ hata: 'Kullanıcı bulunamadı' });
  res.json(rows[0]);
}));

app.post('/profilim', girisZorunlu, sarici(async (req, res) => {
  const { bio, ulke } = req.body || {};
  if (bio != null && (typeof bio !== 'string' || bio.length > 300)) {
    return res.status(400).json({ hata: 'Bio en fazla 300 karakter olabilir' });
  }
  if (ulke != null && (typeof ulke !== 'string' || ulke.length > 60)) {
    return res.status(400).json({ hata: 'Geçersiz ülke' });
  }
  // Boş string alanı temizler; gönderilmeyen alan olduğu gibi kalır.
  const { rows } = await havuz.query(
    `UPDATE kullanicilar
     SET bio  = CASE WHEN $1 THEN NULLIF($2, '') ELSE bio  END,
         ulke = CASE WHEN $3 THEN NULLIF($4, '') ELSE ulke END
     WHERE id=$5
     RETURNING id, kullanici_adi, email, misafir, avatar, bio, ulke`,
    [bio !== undefined, bio ?? '', ulke !== undefined, ulke ?? '', req.kullanici.id],
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

// Yorum eki yükleme: ham gövde, fotoğraf veya video. Dönen yol yorumda kullanılır.
app.post('/medya',
  girisZorunlu,
  yuklemeLimiti,
  express.raw({ type: ['image/*', 'video/*', 'application/octet-stream'], limit: '30mb' }),
  sarici(async (req, res) => {
    const veri = req.body;
    if (!Buffer.isBuffer(veri) || veri.length < 12) {
      return res.status(400).json({ hata: 'Dosya verisi gerekli' });
    }
    const tur = [...RESIM_TURLERI, ...VIDEO_TURLERI].find((t) => t.kontrol(veri));
    if (!tur) {
      return res.status(400).json({ hata: 'Desteklenen türler: GIF, PNG, JPEG, WebP, MP4, WebM' });
    }
    // Dosya adı yükleyenin kimliğini taşır; yorum eklerken sahiplik bununla doğrulanır.
    const dosya = `m${req.kullanici.id}-${crypto.randomBytes(8).toString('hex')}.${tur.uzanti}`;
    fs.writeFileSync(path.join(MEDYA_DIZIN, dosya), veri);
    res.json({ yol: `/medya/${dosya}`, video: VIDEO_TURLERI.includes(tur) });
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
// Instagram tarzı akış: kitaplığındaki içeriklere BAŞKALARININ yorumları.
// Spoiler emniyeti:
//  - Bölüm yorumu yalnızca o bölümü izlediysen gelir.
//  - Film yorumu yalnızca filmi izlediysen gelir.
//  - Dizi geneli yorum yalnızca dizi kitaplığında izliyorum/bitirdim ise gelir.
app.get('/akis', girisZorunlu, akisLimiti, sarici(async (req, res) => {
  const once = parseInt(req.query.once, 10) || null; // sayfalama: bu id'den eskiler
  const benId = req.kullanici.id;
  const { rows } = await havuz.query(
    `SELECT y.id, y.kullanici_id, y.tur, y.tmdb_id, y.sezon, y.bolum,
            y.metin, y.medya, y.tarih, y.goruntulenme,
            k.kullanici_adi, k.avatar,
            (SELECT count(*)::int FROM yorum_begeniler b WHERE b.yorum_id=y.id) AS begeni,
            EXISTS(SELECT 1 FROM yorum_begeniler b
                   WHERE b.yorum_id=y.id AND b.kullanici_id=$1) AS begendim
     FROM yorumlar y JOIN kullanicilar k ON k.id = y.kullanici_id
     WHERE y.kullanici_id <> $1
       AND y.ust_id IS NULL
       AND ($2::int IS NULL OR y.id < $2)
       AND (
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
       )
     ORDER BY y.id DESC LIMIT 30`,
    [benId, once],
  );
  // Kart başlıkları için içerik adı + poster (önbellekli TMDB)
  const anahtarlar = [...new Set(rows.map((r) => `${r.tur}:${r.tmdb_id}`))];
  const icerikler = {};
  await Promise.all(anahtarlar.map(async (a) => {
    const [tur, id] = a.split(':');
    try {
      const v = await tmdbGetir(`/${tur}/${id}?language=tr-TR`, ONBELLEK_TTL_SN.uzun);
      icerikler[a] = { ad: v.name || v.title || '?', poster: v.poster_path || null };
    } catch {
      icerikler[a] = { ad: '?', poster: null };
    }
  }));
  res.json({ akis: rows, icerikler });
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
            m.id, m.metin, m.tarih, m.gonderen_id,
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
    'SELECT id, kullanici_adi, avatar FROM kullanicilar WHERE kullanici_adi=$1',
    [req.params.kullaniciAdi]);
  if (!k.rows.length) return res.status(404).json({ hata: 'Kullanıcı bulunamadı' });
  const partnerId = k.rows[0].id;
  const once = parseInt(req.query.once, 10) || null;
  const { rows } = await havuz.query(
    `SELECT id, gonderen_id, metin, medya, icerik_tur, icerik_id, okundu, tarih FROM mesajlar
     WHERE ((gonderen_id=$1 AND alici_id=$2) OR (gonderen_id=$2 AND alici_id=$1))
       AND ($3::int IS NULL OR id < $3)
     ORDER BY id DESC LIMIT 50`,
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
  const { kullanici_adi, metin, medya = null, icerik_tur = null, icerik_id = null } = req.body || {};
  const temiz = String(metin || '').trim();
  if (temiz.length > 2000) {
    return res.status(400).json({ hata: 'Mesaj en fazla 2000 karakter olabilir' });
  }
  // Medya: yalnızca bu kullanıcının yüklediği, bizim ürettiğimiz adlar
  if (medya != null &&
      (typeof medya !== 'string' ||
       !new RegExp(`^/medya/m${req.kullanici.id}-[0-9a-f]{16}\\.(gif|png|jpg|webp|mp4|webm)$`).test(medya) ||
       !fs.existsSync(path.join(MEDYA_DIZIN, path.basename(medya))))) {
    return res.status(400).json({ hata: 'Geçersiz medya' });
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
  const { rows } = await havuz.query(
    `INSERT INTO mesajlar (gonderen_id, alici_id, metin, medya, icerik_tur, icerik_id)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING id, tarih`,
    [req.kullanici.id, aliciId, temiz || null, medya,
     icerikVar ? icerik_tur : null, icerikVar ? icerik_id : null],
  );
  bildirimEkle(aliciId, 'mesaj', req.kullanici.id);
  res.json({ id: rows[0].id, tarih: rows[0].tarih });
}));

// ---------- şifre sıfırlama ----------
app.post('/auth/sifre-sifirla-istek', authLimiti, sarici(async (req, res) => {
  const { email } = req.body || {};
  // Hesap var/yok bilgisi sızdırılmaz: her durumda aynı cevap.
  const cevap = { mesaj: 'Hesap varsa sıfırlama kodu e-postana gönderildi' };
  const { rows } = await havuz.query(
    'SELECT id FROM kullanicilar WHERE email=$1 AND NOT misafir', [email]);
  if (!rows.length) return res.json(cevap);
  const kod = String(Math.floor(100000 + Math.random() * 900000));
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
  await havuz.query('UPDATE kullanicilar SET sifre_hash=$1 WHERE id=$2', [hash, kayit.id]);
  await havuz.query('DELETE FROM sifirlama_kodlari WHERE kullanici_id=$1', [kayit.id]);
  const kullanici = await havuz.query(
    'SELECT id, kullanici_adi, email, misafir, avatar FROM kullanicilar WHERE id=$1',
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
app.get('/rozetler', girisZorunlu, sarici(async (req, res) => {
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
    [req.kullanici.id]);
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
  res.json({
    rozetler: tanimlar.map(([kod, deger, esik]) => ({
      kod, esik, deger, kazanildi: deger >= esik,
    })),
  });
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

app.post('/yorumlar', girisZorunlu, sarici(async (req, res) => {
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
  if (!YORUM_TURLERI.includes(tur) || !Number.isInteger(tmdb_id)) {
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
        !new RegExp(`^/medya/m${req.kullanici.id}-[0-9a-f]{16}\\.(gif|png|jpg|webp|mp4|webm)$`).test(m) ||
        !fs.existsSync(path.join(MEDYA_DIZIN, path.basename(m)))) {
      return res.status(400).json({ hata: 'Geçersiz medya' });
    }
  }
  const { rows } = await havuz.query(
    `INSERT INTO yorumlar (kullanici_id, tur, tmdb_id, sezon, bolum, metin, medya, ust_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id, tarih`,
    [req.kullanici.id, tur, tmdb_id, sezon, bolum, temiz, medya, gercekUst],
  );
  if (gercekUst) {
    const sahip = await havuz.query(
      'SELECT kullanici_id FROM yorumlar WHERE id=$1', [gercekUst]);
    bildirimEkle(sahip.rows[0]?.kullanici_id, 'yanit', req.kullanici.id, rows[0].id);
  }
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
app.get('/kullanici-ara', sarici(async (req, res) => {
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
    'SELECT id, kullanici_adi, avatar, kapak, bio, ulke, olusturma FROM kullanicilar WHERE kullanici_adi=$1',
    [req.params.kullaniciAdi],
  );
  if (!k.rows.length) return res.status(404).json({ hata: 'Kullanıcı bulunamadı' });
  const id = k.rows[0].id;
  const benId = req.kullanici?.id || 0;
  const [istatistik, listeler, sonIncelemeler, yorumlar, takip, izlenenler] = await Promise.all([
    havuz.query(
      `SELECT
         (SELECT count(*)::int FROM izlemeler WHERE kullanici_id=$1 AND tur='tv') AS bolum,
         (SELECT count(*)::int FROM izlemeler WHERE kullanici_id=$1 AND tur='movie') AS film,
         (SELECT count(*)::int FROM takipler WHERE takip_edilen_id=$1) AS takipci,
         (SELECT count(*)::int FROM takipler WHERE takip_eden_id=$1) AS takip_edilen,
         (SELECT count(*)::int FROM yorumlar WHERE kullanici_id=$1) AS yorum`,
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
      'SELECT EXISTS(SELECT 1 FROM takipler WHERE takip_eden_id=$1 AND takip_edilen_id=$2) AS var',
      [benId, id]),
    havuz.query(
      `SELECT tur, tmdb_id, count(*)::int AS sayi, max(tarih) AS son
       FROM izlemeler WHERE kullanici_id=$1
       GROUP BY tur, tmdb_id ORDER BY son DESC LIMIT 60`,
      [id]),
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
    istatistik: istatistik.rows[0],
    listeler: listeler.rows,
    incelemeler: sonIncelemeler.rows,
    yorumlar: yorumlar.rows,
    icerikler,
    izlenenler: izlenenler.rows.map(({ tur, tmdb_id, sayi }) => ({ tur, tmdb_id, sayi })),
  });
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
