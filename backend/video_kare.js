// Video kapak karesi — Keşfet ızgarası ve akış bu JPEG'i video yerine gösterir.
//
// İLK RENKLİ KARE (3 Eyl 2026): kapak sabit 0,5 sn'den değil, ilk 10 sn'nin
// parlaklık taramasıyla seçilir — siyah açılışlı videoda kapak siyah çıkmaz.
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

/** Kapak için tarama penceresi (sn): ilk renkli kare bu aralıkta aranır. */
export const VIDEO_KARE_TARAMA_SN = 10;

/** Kapak sayılacak karenin en düşük ortalama parlaklığı (Y, 0–255). */
export const VIDEO_KARE_PARLAKLIK_ESIGI = 40;

/** Pencerenin en parlak karesine göre oran: fade-in'in ortasında değil sonuna yakın. */
export const VIDEO_KARE_PARLAKLIK_ORANI = 0.6;

/** Tarama başarısızsa (ffmpeg yok/zaman aşımı/boş çıktı) eski kural: 0,5 sn. */
export const VIDEO_KARE_VARSAYILAN_SN = 0.5;

/**
 * Parlaklık taraması argümanları. Videonun ilk [VIDEO_KARE_TARAMA_SN]
 * saniyesini 64 px'e küçültüp her karenin ortalama luma'sını (signalstats
 * YAVG) stdout'a döker; kare ÜRETMEZ (`-f null`).
 *
 * NEDEN (3 Eyl 2026, kullanıcı): "akışta videolarda siyah duruyor". Kapak
 * hep 0,5 sn'den alınıyordu; siyahtan açılan (fade-in) ya da siyah kartla
 * başlayan videolarda kapak SİYAH çıkıyordu. Şimdi ilk "renkli" kare seçilir.
 *
 * `-skip_frame noref`: referans olmayan kareler çözülmez (B-kareler) — ölçüm
 * için yeter, süre yarıya iner. Kapak karesinin kendisi ikinci geçişte tam
 * çözümle alınır.
 *
 * @param {string} dosyaYolu
 * @returns {string[]}
 */
export function videoKareTaramaArgs(dosyaYolu) {
  return [
    '-hide_banner', '-loglevel', 'error',
    '-skip_frame', 'noref',
    '-t', String(VIDEO_KARE_TARAMA_SN), '-i', dosyaYolu,
    '-vf', 'scale=64:-2,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-',
    '-an', '-f', 'null', '-',
  ];
}

/**
 * Tarama çıktısından kapak anını seçer. Saf.
 *
 * Kural: pencerenin en parlak karesi `tavan`; eşik = max(ESİK, ORAN×tavan).
 * Eşiği geçen İLK karenin zamanı döner (fade-in'de siyah kısım atlanır,
 * kesme varsa ilk renkli sahne). Hiçbir kare eşiği geçmiyorsa (baştan sona
 * karanlık video) en parlak kare — siyahtan iyidir. Çıktı boşsa `null`.
 *
 * Çıktı biçimi (ffmpeg metadata=print):
 *   frame:0    pts:0       pts_time:0
 *   lavfi.signalstats.YAVG=16
 *
 * @param {string} cikti
 * @returns {number|null} saniye
 */
export function kareAniSec(cikti) {
  const kareler = [];
  let zaman = null;
  for (const satir of String(cikti).split('\n')) {
    const z = satir.match(/pts_time:\s*(-?[\d.]+)/);
    if (z) { zaman = parseFloat(z[1]); continue; }
    const y = satir.match(/lavfi\.signalstats\.YAVG=([\d.]+)/);
    if (y && zaman != null && Number.isFinite(zaman)) {
      kareler.push({ zaman: Math.max(0, zaman), parlaklik: parseFloat(y[1]) });
      zaman = null;
    }
  }
  if (!kareler.length) return null;
  let enParlak = kareler[0];
  for (const k of kareler) if (k.parlaklik > enParlak.parlaklik) enParlak = k;
  const esik = Math.max(
    VIDEO_KARE_PARLAKLIK_ESIGI, VIDEO_KARE_PARLAKLIK_ORANI * enParlak.parlaklik,
  );
  const ilk = kareler.find((k) => k.parlaklik >= esik);
  return (ilk ?? enParlak).zaman;
}

/**
 * Kapak karesi ffmpeg argümanları. Saf: süreç açmaz, test edilebilir.
 *
 * @param {string} dosyaYolu Video dosyasının tam yolu.
 * @param {number} [an] Karenin alınacağı saniye (taramadan; yoksa 0,5).
 * @returns {string[]}
 */
export function videoKareFfmpegArgs(dosyaYolu, an = VIDEO_KARE_VARSAYILAN_SN) {
  // min(tavan, iw): büyütme yok. trunc(.../2)*2: JPEG için çift genişlik.
  // Virgül filtergraph ayırıcısı olduğu için min() ffmpeg'te tırnak içinde.
  const olcek =
    `scale='trunc(min(${VIDEO_KARE_UZUN_KENAR},iw)/2)*2':-2:flags=lanczos`;
  return [
    '-y', '-hide_banner', '-loglevel', 'error',
    '-ss', String(an), '-i', dosyaYolu,
    '-frames:v', '1',
    '-vf', olcek,
    '-q:v', String(VIDEO_KARE_JPEG_Q),
    videoKareHedef(dosyaYolu),
  ];
}

/**
 * Medyanın piksel boyutlarını ölçer — GÖRSEL ve VİDEO için aynı komut
 * (ffprobe her ikisini de okur; ses dosyasında v:0 akışı yoktur, null döner).
 *
 * NEDEN: akış kartı medya kutusunu 4:5 varsayımıyla kurup gerçek oranı medya
 * YÜKLENDİKTEN sonra öğreniyordu; kutu o anda boy değiştirip akışı
 * kaydırıyordu (kullanıcı bildirdi, 26 Ağu 2026). Oran artık yükleme anında
 * ölçülür, `medya_olculer` tablosuna yazılır ve /akis yanıtında `medya_oran`
 * olarak gider — kutu İLK KAREDEN doğru boyda kurulur, zıplama olmaz.
 *
 * @param {string} dosyaYolu
 * @param {{ timeout?: number }} [secenek]
 * @returns {Promise<{en: number, boy: number}|null>} Başarısızsa null.
 */
export function medyaBoyutOlc(dosyaYolu, secenek = {}) {
  const timeout = secenek.timeout ?? 10000;
  return new Promise((bitti) => {
    execFile(
      'ffprobe',
      ['-v', 'error', '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height', '-of', 'csv=s=x:p=0',
        dosyaYolu],
      { timeout },
      (hata, stdout) => {
        if (hata) return bitti(null);
        // Animasyonlu GIF birden çok satır dökebilir; ilki yeter.
        const e = String(stdout).trim().split('\n')[0].match(/^(\d+)x(\d+)/);
        if (!e) return bitti(null);
        const en = parseInt(e[1], 10);
        const boy = parseInt(e[2], 10);
        bitti(en > 0 && boy > 0 ? { en, boy } : null);
      },
    );
  });
}

/**
 * Videonun ilk renkli karesinin anını bulur. Başarısızsa (ffmpeg yok, zaman
 * aşımı, ölçüm yok) `null` — çağıran varsayılan 0,5 sn'ye düşer.
 *
 * @param {string} dosyaYolu
 * @param {{ timeout?: number }} [secenek]
 * @returns {Promise<number|null>}
 */
export function videoKareAniBul(dosyaYolu, secenek = {}) {
  const timeout = secenek.timeout ?? 20000;
  return new Promise((bitti) => {
    execFile(
      'ffmpeg',
      videoKareTaramaArgs(dosyaYolu),
      { timeout, maxBuffer: 16 * 1024 * 1024 },
      (hata, stdout) => bitti(hata ? null : kareAniSec(stdout)),
    );
  });
}

/**
 * Videodan kapak karesi üretir: önce ilk renkli karenin anı taranır, sonra o
 * kare yazılır. Başarısızsa `false` (yüklemeyi bozmaz).
 *
 * @param {string} dosyaYolu
 * @param {{ timeout?: number }} [secenek]
 * @returns {Promise<boolean>}
 */
export async function videoKareCikar(dosyaYolu, secenek = {}) {
  const timeout = secenek.timeout ?? 20000;
  const an = (await videoKareAniBul(dosyaYolu, { timeout })) ?? VIDEO_KARE_VARSAYILAN_SN;
  return new Promise((bitti) => {
    execFile(
      'ffmpeg',
      videoKareFfmpegArgs(dosyaYolu, an),
      { timeout },
      (hata) => bitti(!hata),
    );
  });
}
