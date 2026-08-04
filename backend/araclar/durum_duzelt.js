#!/usr/bin/env node
/**
 * Kitaplık durumu geriye dönük düzeltme — `durumlar` tablosunu bugünkü
 * kurallara göre hizalar. Kalıcı araçtır: kural değişince tekrar çalıştırılır.
 *
 * İKİ İŞ YAPAR
 *  A) FİLM: izleme kaydı olup `durumlar`da karşılığı olmayan filmlere
 *     durum='bitirdim' verir. (4 Ağu 2026 hatası: izlenen filmde göz rozeti
 *     yoktu, çünkü rozet `durumlar`dan okunuyor ama film izlemesi oraya hiç
 *     yazılmıyordu.) Mevcut durumu olan film ASLA değiştirilmez.
 *  B) DİZİ: bölüm takibi yapılan her (kullanıcı, dizi) çifti için
 *     `dizi_durum.js`teki SAF `hedefDurum` kararını uygular — yani uçların ve
 *     12 saatlik taramanın kullandığı kodun ta kendisini. "biraktim" durumuna
 *     dokunmaz (fonksiyonun kendisi null döner).
 *
 * GÜVENLİK
 *  - Varsayılan KURU çalışmadır: `--uygula` verilmedikçe TEK SATIR yazmaz.
 *  - `yorumlar`, `puanlar`, `izlemeler` tablolarına HİÇ dokunmaz; yalnız
 *    `durumlar` tablosuna yazar.
 *  - Yazmadan önce `durumlar` tablosunun tarihli yedeğini alır (--uygula ile).
 *
 * ÇALIŞTIRMA (sunucuda, API konteyneri içinden — DATABASE_URL + TMDB_TOKEN
 * oradan gelir):
 *    docker exec dizijpg-api node araclar/durum_duzelt.js            # kuru
 *    docker exec dizijpg-api node araclar/durum_duzelt.js --uygula
 *    docker exec dizijpg-api node araclar/durum_duzelt.js --kullanici 3
 */
import pg from 'pg';
import { hedefDurum } from '../dizi_durum.js';

const UYGULA = process.argv.includes('--uygula');
const kIdx = process.argv.indexOf('--kullanici');
const KULLANICI = kIdx > -1 ? parseInt(process.argv[kIdx + 1], 10) : null;

const { DATABASE_URL, TMDB_TOKEN } = process.env;
if (!DATABASE_URL || !TMDB_TOKEN) {
  console.error('DATABASE_URL / TMDB_TOKEN yok — konteyner içinde çalıştırın.');
  process.exit(1);
}
const havuz = new pg.Pool({ connectionString: DATABASE_URL });
const bugunIso = new Date().toISOString().slice(0, 10);

// TMDB: server.js'teki `tmdb_onbellek` tablosunu PAYLAŞIR. Böylece betik
// canlı önbelleği ısıtır, uçlar da aynı veriyi görür (iki ayrı gerçek olmaz).
const bellek = new Map();
async function diziGetir(tmdbId) {
  if (bellek.has(tmdbId)) return bellek.get(tmdbId);
  // Anahtar server.js'teki `tmdbGetir` ile BİREBİR aynı olmalı (yol = anahtar).
  const yol = `/tv/${tmdbId}?language=tr-TR`;
  const o = await havuz.query(
    `SELECT veri FROM tmdb_onbellek
     WHERE anahtar=$1 AND guncelleme > now() - interval '6 hours'`, [yol]);
  if (o.rows[0]) {
    const v = o.rows[0].veri;
    bellek.set(tmdbId, v);
    return v;
  }
  const c = await fetch(`https://api.themoviedb.org/3${yol}`, {
    headers: { Authorization: `Bearer ${TMDB_TOKEN}` },
  });
  if (!c.ok) throw new Error(`TMDB ${c.status}`);
  const v = await c.json();
  await havuz.query(
    `INSERT INTO tmdb_onbellek (anahtar, veri, guncelleme) VALUES ($1,$2,now())
     ON CONFLICT (anahtar) DO UPDATE SET veri=$2, guncelleme=now()`, [yol, v]);
  bellek.set(tmdbId, v);
  return v;
}

async function yedekAl() {
  const damga = new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-');
  const yol = `/yedekler/durumlar-${damga}.sql`;
  const { rows } = await havuz.query(
    `SELECT kullanici_id, tur, tmdb_id, durum, tekrar, guncelleme FROM durumlar
     ORDER BY kullanici_id, tur, tmdb_id`);
  const kacir = (s) => String(s).replace(/'/g, "''");
  const satirlar = rows.map((r) =>
    `INSERT INTO durumlar (kullanici_id,tur,tmdb_id,durum,tekrar,guncelleme) VALUES (`
    + `${r.kullanici_id},'${kacir(r.tur)}',${r.tmdb_id},'${kacir(r.durum)}',`
    + `${r.tekrar},'${r.guncelleme.toISOString()}');`);
  const { writeFileSync } = await import('fs');
  writeFileSync(yol, `-- durumlar yedegi ${damga} (${rows.length} satir)\n`
    + `-- Geri yukleme: TRUNCATE durumlar; sonra bu dosya.\n`
    + `${satirlar.join('\n')}\n`);
  console.log(`YEDEK: ${yol} (${rows.length} satır)`);
}

async function filmleriDuzelt() {
  const kosul = KULLANICI ? 'AND i.kullanici_id=$1' : '';
  const par = KULLANICI ? [KULLANICI] : [];
  const { rows } = await havuz.query(
    `SELECT i.kullanici_id, count(*)::int AS adet
     FROM izlemeler i
     LEFT JOIN durumlar d ON d.kullanici_id=i.kullanici_id
       AND d.tur='movie' AND d.tmdb_id=i.tmdb_id
     WHERE i.tur='movie' AND d.durum IS NULL ${kosul}
     GROUP BY 1 ORDER BY 2 DESC`, par);
  const toplam = rows.reduce((a, r) => a + r.adet, 0);
  console.log(`\n--- A) FİLM: durumu olmayan izleme kaydı: ${toplam} ---`);
  for (const r of rows) console.log(`  kullanici ${r.kullanici_id}: +${r.adet} bitirdim`);
  if (!UYGULA || toplam === 0) return toplam;
  const y = await havuz.query(
    `INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum, guncelleme)
     SELECT i.kullanici_id, 'movie', i.tmdb_id, 'bitirdim', now()
     FROM izlemeler i WHERE i.tur='movie' ${kosul}
     ON CONFLICT (kullanici_id, tur, tmdb_id) DO NOTHING`, par);
  console.log(`  YAZILDI: ${y.rowCount} satır`);
  return y.rowCount;
}

async function dizileriDuzelt() {
  const kosul = KULLANICI ? 'AND i.kullanici_id=$1' : '';
  const par = KULLANICI ? [KULLANICI] : [];
  const { rows } = await havuz.query(
    `SELECT i.kullanici_id, i.tmdb_id,
            array_agg(i.sezon) AS sezonlar, array_agg(i.bolum) AS bolumler,
            (SELECT d.durum FROM durumlar d
             WHERE d.kullanici_id=i.kullanici_id AND d.tur='tv'
               AND d.tmdb_id=i.tmdb_id) AS durum
     FROM izlemeler i
     WHERE i.tur='tv' AND i.sezon>=1 ${kosul}
     GROUP BY 1,2 ORDER BY 1,2`, par);
  console.log(`\n--- B) DİZİ: bölüm takibi yapılan çift: ${rows.length} ---`);
  const gecisler = new Map();
  const yazilacak = [];
  let hata = 0;
  for (let i = 0; i < rows.length; i += 8) {
    await Promise.all(rows.slice(i, i + 8).map(async (r) => {
      let dizi;
      try { dizi = await diziGetir(r.tmdb_id); } catch { hata++; return; }
      const izlenen = r.sezonlar.map((s, j) => [s, r.bolumler[j]]);
      const hedef = hedefDurum({
        dizi, izlenen, mevcutDurum: r.durum, bugunIso,
      });
      if (!hedef) return;
      const k = `${r.durum ?? 'durumsuz'} → ${hedef}`;
      gecisler.set(k, (gecisler.get(k) || 0) + 1);
      yazilacak.push([r.kullanici_id, r.tmdb_id, hedef]);
    }));
  }
  if (hata) console.log(`  TMDB hatası (atlandı): ${hata}`);
  if (gecisler.size === 0) console.log('  değişecek kayıt YOK');
  for (const [k, n] of [...gecisler].sort((a, b) => b[1] - a[1])) {
    console.log(`  ${k}: ${n}`);
  }
  console.log(`  TOPLAM değişecek: ${yazilacak.length}`);
  if (!UYGULA) return yazilacak.length;
  let n = 0;
  for (const [kid, tid, hedef] of yazilacak) {
    const y = await havuz.query(
      `INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum, guncelleme)
       VALUES ($1,'tv',$2,$3,now())
       ON CONFLICT (kullanici_id, tur, tmdb_id) DO UPDATE
       SET durum=$3, guncelleme=now()
       WHERE durumlar.durum <> 'biraktim' AND durumlar.durum <> $3`,
      [kid, tid, hedef]);
    n += y.rowCount;
  }
  console.log(`  YAZILDI: ${n} satır`);
  return n;
}

(async () => {
  console.log(UYGULA ? '### UYGULA modu (YAZAR) ###' : '### KURU çalışma (yazmaz) ###');
  if (KULLANICI) console.log(`### yalnız kullanıcı ${KULLANICI} ###`);
  if (UYGULA) await yedekAl();
  const a = await filmleriDuzelt();
  const b = await dizileriDuzelt();
  console.log(`\nÖZET: film ${a}, dizi ${b}`);
  await havuz.end();
})().catch((e) => { console.error(e); process.exit(1); });
