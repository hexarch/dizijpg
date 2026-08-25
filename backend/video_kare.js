// Video kapak karesi — Keşfet ızgarası ve akış bu JPEG'i video yerine gösterir.
//
// NEDEN AYRI MODÜL: yükleme ucu (`server.js`) ile toplu yenileme betiği
// (`araclar/video_kare_yenile.js`) AYNI ffmpeg komutunu kullanmalı. Aksi halde
// yeni yüklenen 720'lik, eskiler 480'lik kalır ve "hepsini elden geçir"
// işi bir hafta sonra sessizce iki standarda bölünür.
//
// BÜYÜTME YOK (madde 35a): kaynak 480 px ise kapak 480 kalır. 1080p kaynaktan
// 480'e indirmek (eski kural) ızgarada 2× büyütülünce bulanıklaşıyordu; tavan
// 720, kaynak daha küçükse kaynak boyutu. Lanczos — bilinear'den temiz iner.
//
// AI UPSCALE BİLEREK YOK: Real-ESRGAN / Topaz GPU ister, bu VPS'te yok;
// CPU'da dakika/saat sürer ve olmayan detayı uydurur. MEDYA-EDITOR-PLANI §8
// aynı gerekçeyle "HİÇ" demişti. Kapak karesi kaynaktan ALINIR, icat edilmez.

import { execFile } from 'node:child_process';

/** Kapak uzun kenar tavanı (px). Kaynak bundan küçükse büyütülmez. */
export const VIDEO_KARE_UZUN_KENAR = 720;

/** JPEG kalite (ffmpeg `-q:v`, 2–5 aralığı; düşük sayı = daha az kayıp). */
export const VIDEO_KARE_JPEG_Q = 2;

/** ffmpeg'in yazacağı yol: video.mp4 → video.mp4.jpg */
export function videoKareHedef(dosyaYolu) {
  return `${dosyaYolu}.jpg`;
}

/**
 * Kapak karesi ffmpeg argümanları. Saf: süreç açmaz, test edilebilir.
 *
 * @param {string} dosyaYolu Video dosyasının tam yolu.
 * @returns {string[]}
 */
export function videoKareFfmpegArgs(dosyaYolu) {
  // min(tavan, iw): büyütme yok. trunc(.../2)*2: JPEG için çift genişlik.
  // Virgül filtergraph ayırıcısı olduğu için min() ffmpeg'te tırnak içinde.
  const olcek =
    `scale='trunc(min(${VIDEO_KARE_UZUN_KENAR},iw)/2)*2':-2:flags=lanczos`;
  return [
    '-y', '-hide_banner', '-loglevel', 'error',
    '-ss', '0.5', '-i', dosyaYolu,
    '-frames:v', '1',
    '-vf', olcek,
    '-q:v', String(VIDEO_KARE_JPEG_Q),
    videoKareHedef(dosyaYolu),
  ];
}

/**
 * Videodan kapak karesi üretir. Başarısızsa `false` (yüklemeyi bozmaz).
 *
 * @param {string} dosyaYolu
 * @param {{ timeout?: number }} [secenek]
 * @returns {Promise<boolean>}
 */
export function videoKareCikar(dosyaYolu, secenek = {}) {
  const timeout = secenek.timeout ?? 20000;
  return new Promise((bitti) => {
    execFile(
      'ffmpeg',
      videoKareFfmpegArgs(dosyaYolu),
      { timeout },
      (hata) => bitti(!hata),
    );
  });
}
