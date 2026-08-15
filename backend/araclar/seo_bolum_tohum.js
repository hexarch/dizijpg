#!/usr/bin/env node
/**
 * Popüler dizilerin bölümlerine dizi.jpg.ai yorumu yazar (sitemap + indexle).
 * Spoiler yok. Aynı kayıt varsa METNİ GÜNCELLER (kalite turu). alcelik yok.
 *
 *   docker cp araclar/seo_bolum_tohum.js dizijpg-api:/app/
 *   docker cp araclar/seo_bolum_tohum.json dizijpg-api:/app/
 *   docker exec -w /app dizijpg-api node seo_bolum_tohum.js
 */
import fs from 'fs';
import pg from 'pg';

const { DATABASE_URL } = process.env;
if (!DATABASE_URL) {
  console.error('DATABASE_URL gerekli');
  process.exit(1);
}

const AI = 'dizi.jpg.ai';
const ALCELIK = 3;
const MIN = 80;
const { Pool } = pg;
const havuz = new Pool({ connectionString: DATABASE_URL });

const ozUzunluk = (s) => String(s ?? '')
  .replace(/(#|@)[\p{L}\p{N}_]+|https?:\/\/\S+/gu, '')
  .trim().length;

async function ceviriYaz(kaynak, dil, metin) {
  if (!metin || !String(metin).trim()) return;
  await havuz.query(
    `INSERT INTO metin_cevirileri (ozet, dil, metin)
     VALUES (md5(btrim($1)), $2, $3)
     ON CONFLICT (ozet, dil) DO UPDATE SET metin = EXCLUDED.metin`,
    [kaynak, dil, metin],
  );
}

async function ana() {
  const ham = JSON.parse(fs.readFileSync(new URL('./seo_bolum_tohum.json', import.meta.url), 'utf8'));
  const { rows: ai } = await havuz.query(
    'SELECT id FROM kullanicilar WHERE kullanici_adi=$1', [AI]);
  if (!ai[0]?.id || ai[0].id === ALCELIK) throw new Error('AI hesap yok');
  const aiId = ai[0].id;

  let ek = 0;
  let guncel = 0;
  const simdi = Date.now();
  const liste = ham.ogeler || [];
  for (let i = 0; i < liste.length; i++) {
    const o = liste[i];
    if (ozUzunluk(o.tr) < MIN) throw new Error(`kısa metin ${o.tmdb_id} S${o.sezon}E${o.bolum}`);
    const varMi = await havuz.query(
      `SELECT id, metin FROM yorumlar
        WHERE kullanici_id=$1 AND tur='tv' AND tmdb_id=$2
          AND sezon=$3 AND bolum=$4 LIMIT 1`,
      [aiId, o.tmdb_id, o.sezon, o.bolum],
    );
    if (varMi.rows.length) {
      if (varMi.rows[0].metin !== o.tr) {
        await havuz.query(
          `UPDATE yorumlar SET metin=$1, spoiler=false, kaynak_dil='tr'
            WHERE id=$2 AND kullanici_id=$3`,
          [o.tr, varMi.rows[0].id, aiId],
        );
        guncel++;
        console.log(`~ tv:${o.tmdb_id} S${o.sezon}E${o.bolum}`);
      }
    } else {
      const tarih = new Date(simdi - (liste.length - i) * 36 * 3600 * 1000);
      await havuz.query(
        `INSERT INTO yorumlar
           (kullanici_id, tur, tmdb_id, sezon, bolum, metin, medya, spoiler, kaynak_dil, tarih)
         VALUES ($1,'tv',$2,$3,$4,$5,'{}',false,'tr',$6)`,
        [aiId, o.tmdb_id, o.sezon, o.bolum, o.tr, tarih],
      );
      ek++;
      console.log(`+ tv:${o.tmdb_id} S${o.sezon}E${o.bolum}`);
    }
    if (o.en) await ceviriYaz(o.tr, 'en', o.en);
  }
  const { rows: n } = await havuz.query(
    `SELECT count(*)::int AS n FROM (
       SELECT tmdb_id, sezon, bolum FROM yorumlar y
         JOIN kullanicilar k ON k.id=y.kullanici_id
        WHERE y.tur='tv' AND y.sezon IS NOT NULL AND NOT k.yasakli AND NOT y.spoiler
          AND length(btrim(y.metin)) >= $1
        GROUP BY 1,2,3) t`,
    [MIN],
  );
  const al = await havuz.query(
    'SELECT count(*)::int AS n FROM yorumlar WHERE kullanici_id=$1', [ALCELIK]);
  console.log(`eklenen ${ek} guncellenen ${guncel} bolum_sayfa~${n[0].n} alcelik_yorum ${al.rows[0].n}`);
  await havuz.end();
}

ana().catch((e) => {
  console.error(e);
  process.exit(1);
});
