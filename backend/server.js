// dizi.jpg API — auth, TMDB proxy (önbellekli), izleme/puan/liste/istatistik
import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import pg from 'pg';

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
app.use(express.json({ limit: '1mb' }));

// CORS: web sürümü (dizijpg.com) tarayıcıdan istek atabilsin.
app.use((req, res, next) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
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

  // Geçici ağ hatalarına karşı bir kez yeniden dene.
  let cevap;
  for (let deneme = 0; ; deneme++) {
    try {
      cevap = await fetch(`${TMDB}${yol}`, {
        headers: { Authorization: `Bearer ${TMDB_TOKEN}` },
        signal: AbortSignal.timeout(15000),
      });
      break;
    } catch (e) {
      if (deneme >= 1) throw Object.assign(new Error('TMDB erişilemedi'), { status: 502 });
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

const sarici = (fn) => (req, res) =>
  fn(req, res).catch((e) => {
    console.error(req.path, e.message);
    res.status(e.status || 500).json({ hata: e.status ? e.message : 'Sunucu hatası' });
  });

// ---------- sağlık ----------
app.get('/saglik', sarici(async (_req, res) => {
  await havuz.query('SELECT 1');
  res.json({ durum: 'ok', servis: 'dizi.jpg API' });
}));

// ---------- auth ----------
app.post('/auth/kayit', sarici(async (req, res) => {
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
       VALUES (lower($1), $2, $3) RETURNING id, kullanici_adi, email`,
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

app.post('/auth/giris', sarici(async (req, res) => {
  const { email, sifre } = req.body || {};
  const { rows } = await havuz.query(
    'SELECT * FROM kullanicilar WHERE email = lower($1) OR kullanici_adi = $1',
    [email || ''],
  );
  if (!rows.length || !(await bcrypt.compare(sifre || '', rows[0].sifre_hash))) {
    return res.status(401).json({ hata: 'E-posta/kullanıcı adı veya şifre hatalı' });
  }
  const { id, kullanici_adi, email: eposta } = rows[0];
  res.json({ token: jwtUret(rows[0]), kullanici: { id, kullanici_adi, email: eposta } });
}));

// ---------- TMDB proxy (beyaz listeli) ----------
const TMDB_IZINLI = [
  /^\/trending\/(tv|movie|all)\/(day|week)$/,
  /^\/search\/(tv|movie|multi|person)$/,
  /^\/discover\/(tv|movie)$/,
  /^\/(tv|movie)\/\d+$/,
  /^\/tv\/\d+\/season\/\d+$/,
  /^\/(tv|movie)\/\d+\/(credits|videos|recommendations|similar|watch\/providers)$/,
  /^\/person\/\d+$/,
  /^\/person\/\d+\/combined_credits$/,
  /^\/genre\/(tv|movie)\/list$/,
];

app.get('/tmdb/*', sarici(async (req, res) => {
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
  if (!tmdb_id || !['tv', 'movie'].includes(tur)) {
    return res.status(400).json({ hata: 'tmdb_id ve tur gerekli' });
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
  const [izleme, durum, puan, favori] = await Promise.all([
    havuz.query('SELECT sezon, bolum FROM izlemeler WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('SELECT durum FROM durumlar WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('SELECT puan, yorum FROM puanlar WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
    havuz.query('SELECT 1 FROM favoriler WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3', p),
  ]);
  res.json({
    izlenenler: izleme.rows,
    durum: durum.rows[0]?.durum || null,
    puan: puan.rows[0] || null,
    favori: favori.rows.length > 0,
  });
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
  if (!ad) return res.status(400).json({ hata: 'Liste adı gerekli' });
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
  const [bolum, film, dizi] = await Promise.all([
    havuz.query(
      `SELECT count(*)::int AS adet FROM izlemeler WHERE kullanici_id=$1 AND tur='tv'`,
      [req.kullanici.id]),
    havuz.query(
      `SELECT count(*)::int AS adet FROM izlemeler WHERE kullanici_id=$1 AND tur='movie'`,
      [req.kullanici.id]),
    havuz.query(
      `SELECT count(DISTINCT tmdb_id)::int AS adet FROM izlemeler WHERE kullanici_id=$1 AND tur='tv'`,
      [req.kullanici.id]),
  ]);
  res.json({
    izlenen_bolum: bolum.rows[0].adet,
    izlenen_film: film.rows[0].adet,
    takip_edilen_dizi: dizi.rows[0].adet,
    // Yaklaşık süreler: bölüm ~42 dk, film ~110 dk
    tahmini_dakika: bolum.rows[0].adet * 42 + film.rows[0].adet * 110,
  });
}));

// İzlediğim dizilerin yaklaşan bölümleri
app.get('/takvim', girisZorunlu, sarici(async (req, res) => {
  const { rows } = await havuz.query(
    `SELECT tmdb_id FROM durumlar
     WHERE kullanici_id=$1 AND tur='tv' AND durum IN ('izliyorum','izleyecegim')
     LIMIT 40`,
    [req.kullanici.id],
  );
  const sonuclar = [];
  await Promise.all(rows.map(async ({ tmdb_id }) => {
    try {
      const dizi = await tmdbGetir(`/tv/${tmdb_id}?language=tr-TR`, ONBELLEK_TTL_SN.varsayilan);
      const sonraki = dizi.next_episode_to_air;
      if (sonraki?.air_date) {
        sonuclar.push({
          tmdb_id,
          dizi_adi: dizi.name,
          poster: dizi.poster_path,
          sezon: sonraki.season_number,
          bolum: sonraki.episode_number,
          bolum_adi: sonraki.name,
          tarih: sonraki.air_date,
        });
      }
    } catch { /* tek dizi hatası takvimi bozmasın */ }
  }));
  sonuclar.sort((a, b) => a.tarih.localeCompare(b.tarih));
  res.json({ yaklasan: sonuclar });
}));

// ---------- herkese açık profil ----------
app.get('/profil/:kullaniciAdi', sarici(async (req, res) => {
  const k = await havuz.query(
    'SELECT id, kullanici_adi, avatar, olusturma FROM kullanicilar WHERE kullanici_adi=$1',
    [req.params.kullaniciAdi],
  );
  if (!k.rows.length) return res.status(404).json({ hata: 'Kullanıcı bulunamadı' });
  const id = k.rows[0].id;
  const [istatistik, listeler, sonIncelemeler] = await Promise.all([
    havuz.query(
      `SELECT
         (SELECT count(*)::int FROM izlemeler WHERE kullanici_id=$1 AND tur='tv') AS bolum,
         (SELECT count(*)::int FROM izlemeler WHERE kullanici_id=$1 AND tur='movie') AS film`,
      [id]),
    havuz.query(
      `SELECT id, ad, aciklama FROM listeler WHERE kullanici_id=$1 AND herkese_acik=true`,
      [id]),
    havuz.query(
      `SELECT tur, tmdb_id, puan, yorum, tarih FROM puanlar
       WHERE kullanici_id=$1 AND yorum IS NOT NULL ORDER BY tarih DESC LIMIT 10`,
      [id]),
  ]);
  res.json({
    ...k.rows[0],
    istatistik: istatistik.rows[0],
    listeler: listeler.rows,
    incelemeler: sonIncelemeler.rows,
  });
}));

app.listen(PORT, '0.0.0.0', () => console.log(`dizi.jpg API ${PORT} portunda`));
