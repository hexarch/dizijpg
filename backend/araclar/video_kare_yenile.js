#!/usr/bin/env node
// Mevcut videoların kapak JPEG'ini YENİDEN üretir. Video dosyasına DOKUNMAZ.
//
//   docker exec dizijpg-api node araclar/video_kare_yenile.js
//   MEDYA_DIZIN=/veri/medya node araclar/video_kare_yenile.js
//
// Neden ayrı iş: yükleme anındaki `videoKareCikar` yalnız YENİ dosyayı işler.
// Eski 480 px kapaklar Keşfet ızgarasında 2× büyütülünce bulanık kalır.
// Bu betik aynı ffmpeg komutunu (`video_kare.js`) her mp4/webm için koşar.
//
// Güvenlik: çıktı daima `<video>.jpg`. Kaynak video ezilmez. Hata olursa
// o dosya atlanır, diğerleri devam eder. Eşzaman = 2 (altyazı işçisiyle paylaşır).

import fs from 'node:fs';
import path from 'node:path';
import { videoKareCikar, videoKareHedef } from '../video_kare.js';

const dizin = process.env.MEDYA_DIZIN || './medya';
const ESZAMAN = 2;
const VIDEO_UZANTI = /\.(mp4|webm)$/i;

function videolariTopla(kok) {
  const adlar = fs.readdirSync(kok);
  return adlar
    .filter((a) => VIDEO_UZANTI.test(a) && !a.endsWith('.jpg'))
    .map((a) => path.join(kok, a));
}

async function havuzla(isler, eszaman, isci) {
  let i = 0;
  const kosan = Array.from({ length: Math.min(eszaman, isler.length) }, async () => {
    while (i < isler.length) {
      const sira = i;
      i += 1;
      await isci(isler[sira], sira);
    }
  });
  await Promise.all(kosan);
}

const videolar = videolariTopla(dizin);
let tamam = 0;
let hata = 0;
const bas = Date.now();
console.log(`video kapak yenileme: ${videolar.length} dosya, ${dizin}`);

await havuzla(videolar, ESZAMAN, async (dosya) => {
  const oldu = await videoKareCikar(dosya, { timeout: 40000 });
  if (oldu && fs.existsSync(videoKareHedef(dosya))) {
    tamam += 1;
  } else {
    hata += 1;
    console.error(`atlandi: ${path.basename(dosya)}`);
  }
});

console.log(
  `bitti: ${tamam} kapak, ${hata} hata, ${((Date.now() - bas) / 1000).toFixed(1)}s`,
);
process.exit(hata && tamam === 0 ? 1 : 0);
