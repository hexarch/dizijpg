#!/usr/bin/env node
/**
 * Tohum hesapları güçlendirir: birbirini takip, gönderi beğenisi, yanıt,
 * uzun bio, ek izleme. Bildirim YAZMAZ (ham SQL). alcelik (id=3) yok.
 *
 * Tekrar çalışınca atlar (ON CONFLICT / aynı metin).
 *
 *   docker cp araclar/intl_guclendir.js dizijpg-api:/app/
 *   docker cp araclar/intl_guclendir.json dizijpg-api:/app/
 *   docker exec -w /app dizijpg-api node intl_guclendir.js
 */
import fs from 'fs';
import pg from 'pg';

const { DATABASE_URL, TMDB_TOKEN } = process.env;
if (!DATABASE_URL || !TMDB_TOKEN) {
  console.error('DATABASE_URL / TMDB_TOKEN gerekli');
  process.exit(1);
}

const ALCELIK = 3;
const RESMI = ['dizi.jpg', 'dizi.jpg.ai'];
const TOHUM_AD = [
  'miles.watches', 'lin.binge', 'aanya.screens', 'lucia.series',
  'camille.ecran', 'nour.yushahid', 'rafi.screen', 'sofia.seriesbr',
  'daria.serial', 'zara.dramay', 'dimas.nonton', 'lena.serie',
  'yuki.dorama', 'minh.phim', 'jiwon.drama',
];
const BOLUM_TAVAN = 80;

const { Pool } = pg;
const havuz = new Pool({ connectionString: DATABASE_URL });

const ham = JSON.parse(fs.readFileSync(new URL('./intl_guclendir.json', import.meta.url), 'utf8'));

async function tmdb(yol) {
  for (let d = 0; d < 4; d++) {
    const c = await fetch(`https://api.themoviedb.org/3${yol}`, {
      headers: { Authorization: `Bearer ${TMDB_TOKEN}` },
    });
    if (c.status === 429) {
      await new Promise((r) => setTimeout(r, 1500 * (d + 1)));
      continue;
    }
    if (c.status === 404) return null;
    if (!c.ok) throw new Error(`TMDB ${c.status} ${yol}`);
    return c.json();
  }
  throw new Error(`TMDB 429 ${yol}`);
}

async function ceviriYaz(kaynak, dil, metin) {
  if (!metin || !String(metin).trim()) return;
  await havuz.query(
    `INSERT INTO metin_cevirileri (ozet, dil, metin)
     VALUES (md5(btrim($1)), $2, $3)
     ON CONFLICT (ozet, dil) DO NOTHING`,
    [kaynak, dil, metin],
  );
}

async function izlemeleriYaz(kid, tur, tmdbId, oran, bitis) {
  if (!oran || oran <= 0) return 0;
  if (tur === 'movie') {
    await havuz.query(
      `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum, tarih)
       VALUES ($1,'movie',$2,0,0,$3)
       ON CONFLICT DO NOTHING`,
      [kid, tmdbId, bitis],
    );
    return 1;
  }
  const info = await tmdb(`/tv/${tmdbId}`);
  if (!info) return 0;
  const sezonlar = (info.seasons || [])
    .filter((s) => s.season_number > 0 && (s.episode_count || 0) > 0);
  const hepsi = [];
  for (const s of sezonlar) {
    for (let b = 1; b <= s.episode_count; b++) {
      hepsi.push([s.season_number, b]);
      if (hepsi.length >= BOLUM_TAVAN) break;
    }
    if (hepsi.length >= BOLUM_TAVAN) break;
  }
  if (!hepsi.length) return 0;
  const n = Math.max(1, Math.min(hepsi.length, Math.floor(hepsi.length * oran)));
  const degerler = [];
  const params = [];
  for (let i = 0; i < n; i++) {
    const [sezon, bolum] = hepsi[i];
    const tarih = new Date(bitis.getTime() - (n - 1 - i) * 6 * 3600 * 1000);
    const b = params.length;
    degerler.push(`($${b + 1},'tv',$${b + 2},$${b + 3},$${b + 4},$${b + 5})`);
    params.push(kid, tmdbId, sezon, bolum, tarih);
  }
  await havuz.query(
    `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum, tarih)
     VALUES ${degerler.join(',')}
     ON CONFLICT DO NOTHING`,
    params,
  );
  return n;
}

/** Deterministik 0..1 — beğeni kümesi her çalıştırmada aynı kalsın. */
function karis(a, b) {
  let h = 2166136261;
  const s = `${a}:${b}`;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return (h >>> 0) / 4294967296;
}

async function ana() {
  const { rows: tohumlar } = await havuz.query(
    `SELECT id, kullanici_adi FROM kullanicilar
      WHERE kullanici_adi = ANY($1::text[])
      ORDER BY id`,
    [TOHUM_AD],
  );
  if (tohumlar.some((r) => r.id === ALCELIK)) {
    throw new Error('alcelik koruması');
  }
  const idOf = Object.fromEntries(tohumlar.map((r) => [r.kullanici_adi, r.id]));
  const tohumId = tohumlar.map((r) => r.id);
  if (tohumId.length !== 15) {
    throw new Error(`tohum sayısı ${tohumId.length}, 15 beklenirdi`);
  }

  const resmiId = [];
  for (const ad of RESMI) {
    const { rows } = await havuz.query(
      'SELECT id FROM kullanicilar WHERE kullanici_adi=$1', [ad]);
    if (rows[0] && rows[0].id !== ALCELIK) resmiId.push(rows[0].id);
  }

  let takip = 0;
  const hedefler = [...tohumId, ...resmiId];
  for (const eden of tohumId) {
    for (const edilen of hedefler) {
      if (eden === edilen || edilen === ALCELIK) continue;
      const y = await havuz.query(
        `INSERT INTO takipler (takip_eden_id, takip_edilen_id, tarih)
         SELECT $1::int, $2::int, now() - (($1 + $2) % 40) * interval '1 day'
         WHERE $1 <> $2 AND $2 <> $3
         ON CONFLICT DO NOTHING`,
        [eden, edilen, ALCELIK],
      );
      takip += y.rowCount;
    }
  }
  console.log(`takip +${takip}`);

  for (const [ad, bio] of Object.entries(ham.bio || {})) {
    const id = idOf[ad];
    if (!id || id === ALCELIK) continue;
    await havuz.query(
      `UPDATE kullanicilar SET bio=$1, karsilama_bitti=true WHERE id=$2`,
      [bio, id],
    );
  }
  for (let i = 0; i < tohumlar.length; i++) {
    await havuz.query(
      `UPDATE kullanicilar SET son_gorulme=$1 WHERE id=$2`,
      [new Date(Date.now() - i * 2.1 * 3600 * 1000), tohumlar[i].id],
    );
  }
  console.log('bio / son_gorulme');

  const { rows: gonderiler } = await havuz.query(
    `SELECT id, kullanici_id, tarih FROM yorumlar
      WHERE kullanici_id = ANY($1::int[]) AND ust_id IS NULL`,
    [tohumId],
  );
  let begeni = 0;
  for (const g of gonderiler) {
    const aday = tohumId.filter((id) => id !== g.kullanici_id)
      .sort((a, b) => karis(g.id, a) - karis(g.id, b))
      .slice(0, 6);
    for (const kim of aday) {
      const saat = 4 + Math.floor(karis(g.id, kim) * 60);
      const tarih = new Date(new Date(g.tarih).getTime() + saat * 3600 * 1000);
      const y = await havuz.query(
        `INSERT INTO yorum_begeniler (yorum_id, kullanici_id, tarih)
         VALUES ($1,$2,$3)
         ON CONFLICT DO NOTHING`,
        [g.id, kim, tarih],
      );
      begeni += y.rowCount;
    }
  }
  console.log(`begeni +${begeni}`);

  let yanit = 0;
  let yanitAtla = 0;
  for (const y of ham.yanitlar || []) {
    const kimId = idOf[y.kim];
    const hedefId = idOf[y.hedef];
    if (!kimId || !hedefId || kimId === ALCELIK || hedefId === ALCELIK) {
      throw new Error(`yanıt kişi yok: ${y.kim} -> ${y.hedef}`);
    }
    const { rows: ust } = await havuz.query(
      `SELECT id, tur, tmdb_id, tarih FROM yorumlar
        WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3 AND ust_id IS NULL
        ORDER BY id LIMIT 1`,
      [hedefId, y.tur, y.tmdb_id],
    );
    if (!ust.length) {
      console.log(`yanıt hedef yok ${y.hedef} ${y.tur}:${y.tmdb_id}`);
      yanitAtla++;
      continue;
    }
    const varMi = await havuz.query(
      `SELECT 1 FROM yorumlar
        WHERE kullanici_id=$1 AND ust_id=$2 AND btrim(metin)=btrim($3)`,
      [kimId, ust[0].id, y.metin],
    );
    if (varMi.rows.length) {
      yanitAtla++;
      continue;
    }
    const gun = 1 + Math.floor(karis(ust[0].id, kimId) * 10);
    const tarih = new Date(new Date(ust[0].tarih).getTime() + gun * 86400 * 1000);
    const kaynakDil = {
      'yuki.dorama': 'ja', 'jiwon.drama': 'ko', 'miles.watches': 'en',
      'lin.binge': 'zh', 'aanya.screens': 'hi', 'lucia.series': 'es',
      'camille.ecran': 'fr', 'lena.serie': 'de', 'sofia.seriesbr': 'pt',
      'nour.yushahid': 'ar', 'rafi.screen': 'bn', 'daria.serial': 'ru',
      'zara.dramay': 'ur', 'dimas.nonton': 'id', 'minh.phim': 'vi',
    }[y.kim];
    await havuz.query(
      `INSERT INTO yorumlar
         (kullanici_id, tur, tmdb_id, metin, medya, ust_id, spoiler, kaynak_dil, tarih)
       VALUES ($1,$2,$3,$4,'{}',$5,false,$6,$7)`,
      [kimId, ust[0].tur, ust[0].tmdb_id, y.metin, ust[0].id, kaynakDil, tarih],
    );
    await ceviriYaz(y.metin, 'en', y.en);
    await ceviriYaz(y.metin, 'tr', y.tr);
    await ceviriYaz(y.metin, kaynakDil, y.metin);
    yanit++;
  }
  console.log(`yanit +${yanit} atla ${yanitAtla}`);

  let ekIzleme = 0;
  let ekAtla = 0;
  for (const e of ham.ek || []) {
    const id = idOf[e.ad];
    if (!id || id === ALCELIK) throw new Error(`ek kişi yok: ${e.ad}`);
    const bilgi = await tmdb(`/${e.tur}/${e.tmdb_id}`);
    if (!bilgi) {
      console.log(`TMDB yok ${e.tur}:${e.tmdb_id}`);
      ekAtla++;
      continue;
    }
    const tarih = new Date(Date.now() - 20 * 24 * 3600 * 1000);
    await havuz.query(
      `INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum, guncelleme)
       VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (kullanici_id, tur, tmdb_id)
       DO UPDATE SET durum=EXCLUDED.durum, guncelleme=EXCLUDED.guncelleme`,
      [id, e.tur, e.tmdb_id, e.durum, tarih],
    );
    if (e.durum !== 'izleyecegim') {
      ekIzleme += await izlemeleriYaz(id, e.tur, e.tmdb_id, e.oran ?? 1, tarih);
    }
    if (e.platform) {
      await havuz.query(
        `INSERT INTO izleme_kaynaklari (kullanici_id, tur, tmdb_id, platform, tarih)
         VALUES ($1,$2,$3,$4,$5)
         ON CONFLICT (kullanici_id, tur, tmdb_id)
         DO UPDATE SET platform=EXCLUDED.platform`,
        [id, e.tur, e.tmdb_id, String(e.platform).slice(0, 30), tarih],
      );
    }
    if (e.puan) {
      const varPuan = await havuz.query(
        `SELECT 1 FROM puanlar
          WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3 AND sezon IS NULL`,
        [id, e.tur, e.tmdb_id],
      );
      if (!varPuan.rows.length) {
        await havuz.query(
          `INSERT INTO puanlar (kullanici_id, tur, tmdb_id, puan, tarih)
           VALUES ($1,$2,$3,$4,$5)`,
          [id, e.tur, e.tmdb_id, e.puan, tarih],
        );
      }
    }
  }
  console.log(`ek izleme +${ekIzleme} tmdb-atla ${ekAtla}`);

  const { rows: kanit } = await havuz.query(
    `SELECT k.kullanici_adi,
            (SELECT count(*) FROM takipler t WHERE t.takip_edilen_id=k.id) AS takipci,
            (SELECT count(*) FROM yorumlar y WHERE y.kullanici_id=k.id AND y.ust_id IS NOT NULL) AS yanit,
            (SELECT count(*) FROM yorum_begeniler b
               JOIN yorumlar y ON y.id=b.yorum_id WHERE y.kullanici_id=k.id) AS begeni
       FROM kullanicilar k WHERE k.id = ANY($1::int[]) ORDER BY k.id`,
    [tohumId],
  );
  for (const r of kanit) {
    console.log(`  ${r.kullanici_adi} takipci=${r.takipci} yanit=${r.yanit} begeni=${r.begeni}`);
  }

  const alcelik = await havuz.query(
    `SELECT
       (SELECT count(*) FROM takipler WHERE takip_edilen_id=$1 AND takip_eden_id = ANY($2::int[])) AS takip,
       (SELECT count(*) FROM yorumlar WHERE kullanici_id=$1 AND id IN
         (SELECT ust_id FROM yorumlar WHERE kullanici_id = ANY($2::int[]) AND ust_id IS NOT NULL)) AS yanit,
       (SELECT count(*) FROM yorum_begeniler WHERE kullanici_id = ANY($2::int[]) AND yorum_id IN
         (SELECT id FROM yorumlar WHERE kullanici_id=$1)) AS begeni`,
    [ALCELIK, tohumId],
  );
  const a = alcelik.rows[0];
  if (Number(a.takip) || Number(a.yanit) || Number(a.begeni)) {
    throw new Error(`alcelik dokunuldu takip=${a.takip} yanit=${a.yanit} begeni=${a.begeni}`);
  }
  console.log('alcelik temiz');
  await havuz.end();
}

ana().catch((e) => {
  console.error(e);
  process.exit(1);
});
