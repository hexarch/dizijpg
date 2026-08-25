#!/usr/bin/env node
// Mevcut yorum medyalarının piksel ölçülerini doldurur (medya_olculer).
//
//   docker exec dizijpg-api node araclar/medya_olcu_doldur.js
//
// Neden ayrı iş: yükleme anındaki `medyaBoyutOlc` yalnız YENİ dosyayı işler;
// eski gönderilerin kartı oransız kalır ve akışta yüklenince zıplamaya devam
// ederdi (migrasyon-2026-08-26.sql). Bu betik yorumlarda geçen ve henüz
// ölçüsü olmayan her görsel/videoyu ffprobe ile ölçüp tabloya yazar.
//
// Güvenlik: dosyaya DOKUNMAZ, yalnız okur. Hata olursa o dosya atlanır
// (bir dahaki koşuda yeniden denenir), diğerleri devam eder. Eşzaman = 4:
// ffprobe hafif ama disk G/Ç'sini altyazı işçisiyle paylaşıyor.

import fs from 'node:fs';
import path from 'node:path';
import pg from 'pg';
import { medyaBoyutOlc } from '../video_kare.js';

const { DATABASE_URL, MEDYA_DIZIN } = process.env;
if (!DATABASE_URL) {
  console.error('DATABASE_URL gerekli');
  process.exit(1);
}
const dizin = MEDYA_DIZIN || '/veri/medya';
const ESZAMAN = 4;
// Ses dosyaları BİLEREK dışarıda: v:0 akışı yok, oranın anlamı da yok.
const OLCULUR = /\.(jpe?g|png|gif|webp|mp4|webm)$/i;

const havuz = new pg.Pool({ connectionString: DATABASE_URL, max: 2 });

// DISTINCT unnest: aynı dosya birden çok gönderide geçebilir (Instagram
// aktarımı), bir kez ölçmek yeter. NOT EXISTS: iş yarıda kesilirse kaldığı
// yerden devam eder.
const { rows } = await havuz.query(`
  SELECT DISTINCT m AS medya
    FROM yorumlar y, unnest(y.medya) m
   WHERE m LIKE '/medya/%'
     AND NOT EXISTS (SELECT 1 FROM medya_olculer mo WHERE mo.medya = m)`);

const isler = rows.map((r) => r.medya).filter((m) => OLCULUR.test(m));
console.log(`medya ölçüsü doldurma: ${isler.length} dosya (aday ${rows.length})`);

let tamam = 0;
let yok = 0;
let hata = 0;
const bas = Date.now();

async function havuzla(liste, eszaman, isci) {
  let i = 0;
  const kosan = Array.from({ length: Math.min(eszaman, liste.length) }, async () => {
    while (i < liste.length) {
      const sira = i;
      i += 1;
      await isci(liste[sira]);
    }
  });
  await Promise.all(kosan);
}

await havuzla(isler, ESZAMAN, async (medya) => {
  // path.basename: '/medya/x.mp4' → diskteki gerçek ad. Yol birleştirmede
  // kullanıcı girdisi yok (değerler bizim yazdığımız yorumlar.medya'dan).
  const dosya = path.join(dizin, path.basename(medya));
  if (!fs.existsSync(dosya)) { yok += 1; return; }
  const b = await medyaBoyutOlc(dosya, { timeout: 20000 });
  if (!b) { hata += 1; return; }
  try {
    await havuz.query(
      `INSERT INTO medya_olculer (medya, en, boy) VALUES ($1, $2, $3)
       ON CONFLICT (medya) DO UPDATE SET en = EXCLUDED.en, boy = EXCLUDED.boy`,
      [medya, b.en, b.boy],
    );
    tamam += 1;
    if (tamam % 500 === 0) console.log(`  ${tamam}/${isler.length}...`);
  } catch (e) {
    hata += 1;
    console.error(`  yazılamadı ${medya}: ${e.message}`);
  }
});

console.log(`bitti: ${tamam} yazıldı, ${yok} dosya diskte yok, ${hata} hata `
  + `(${((Date.now() - bas) / 1000).toFixed(1)} sn)`);
await havuz.end();
