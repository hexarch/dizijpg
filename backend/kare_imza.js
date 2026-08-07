// Sahne karelerinde ALGISAL TEKRAR süzgeci.
//
// Neden üç ölçüt: TMDB aynı görseli birden çok "ayrı" backdrop olarak sunuyor
// ve varyantlar üç farklı biçimde ayrışıyor. 2026-08-06'da AI hesabının 22.856
// karesi (99.742 yorum içi çift) taranıp bantlar GÖZLE denetlendi; her ölçütün
// eşiği o denetime göre konuldu:
//
//   1. dHash <= 10       birebir/çok yakın varyant. (Eski tek ölçüt buydu;
//                        99.742 çiftin yalnız 136'sını yakalıyordu.)
//   2. pHash <= 12       aynı görsel + üstüne basılmış yazı/logo/dil farkı.
//                        dHash bunu kaçırıyor çünkü yazı kenar yapısını bozuyor.
//                        Örnek bantlar: pHash 0-8 → 10/10 tekrar, 9-12 → 8/8.
//   3. hizalı >= 0.85    aynı görselin KIRPIMI / yakınlaştırması / renk
//                        derecelendirmesi. Kareler griye çevrilip 64x64'e
//                        indirgenir; bir dizi kırpım penceresi 16x16'ya
//                        düşürülüp ortalaması sıfır - normu bir yapılır (bu
//                        normalizasyon parlaklık/kontrast farkını eler), en
//                        yüksek iç çarpım skordur. Bantlar: 0.88+ → 12/12
//                        tekrar, 0.85-0.88 → 10/12, 0.78-0.82 → 3/12 (yani
//                        eşiğin altı çoğunlukla gerçekten farklı görsel).
//
// Tek ölçütle yetinilemez: 2026-08-06 taramasında atılan 1.335 karenin 114'ü
// dHash, 102'si pHash, 1.119'u yalnız hizalı ölçütle yakalandı.
//
// ffmpeg konteynerde kurulu (Dockerfile'da video küçük resmi için var).
import { spawn } from 'child_process';

export const ESIK_DHASH = 10;
export const ESIK_PHASH = 12;
export const ESIK_HIZALI = 0.85;

const N = 64;  // imza kenarı (ffmpeg'den bu boyutta ham gri alınır)
const K = 16;  // karşılaştırma kenarı
const KK = K * K;

// Kırpım penceresi kümesi: tam kare + 6 ölçek x 5x5 konum ızgarası.
// Yoğun tarama şart: seyrek ızgarada (3x3, 2 ölçek) ağır kırpımların skoru
// eşiğin altına düşüyor ve gerçek tekrarlar kaçıyordu.
const KIRPIMLAR = [[0, 0, 1]];
for (const s of [0.92, 0.85, 0.78, 0.70, 0.62, 0.55]) {
  const adim = (1 - s) / 4;
  for (let iy = 0; iy < 5; iy++) {
    for (let ix = 0; ix < 5; ix++) KIRPIMLAR.push([ix * adim, iy * adim, s]);
  }
}

// ffmpeg ile NxN ham gri al. Başarısızsa null (kare kaybedilmesin diye
// çağıran taraf null'ı "elenemez" sayar).
function hamGri(dosyaYolu) {
  return new Promise((coz) => {
    const p = spawn('ffmpeg', ['-v', 'error', '-i', dosyaYolu,
      '-vf', `scale=${N}:${N},format=gray`, '-f', 'rawvideo', '-']);
    const parcalar = [];
    p.stdout.on('data', (d) => parcalar.push(d));
    p.on('error', () => coz(null));
    p.on('close', () => {
      const b = Buffer.concat(parcalar);
      coz(b.length >= N * N ? b : null);
    });
  });
}

// NxN'den WxH kutu ortalaması
function kucult(g, W, H) {
  const o = new Float64Array(W * H);
  for (let y = 0; y < H; y++) {
    const ya = Math.floor((y * N) / H), yb = Math.max(ya + 1, Math.floor(((y + 1) * N) / H));
    for (let x = 0; x < W; x++) {
      const xa = Math.floor((x * N) / W), xb = Math.max(xa + 1, Math.floor(((x + 1) * N) / W));
      let t = 0, n = 0;
      for (let j = ya; j < yb; j++) for (let i = xa; i < xb; i++) { t += g[j * N + i]; n++; }
      o[y * W + x] = t / n;
    }
  }
  return o;
}

function dhashBit(g) {
  const s = kucult(g, 9, 8);
  let b = 0n;
  for (let y = 0; y < 8; y++) {
    for (let x = 0; x < 8; x++) b = (b << 1n) | (s[y * 9 + x] > s[y * 9 + x + 1] ? 1n : 0n);
  }
  return b;
}

const KOS = (() => {
  const t = [];
  for (let u = 0; u < 8; u++) {
    const r = new Float64Array(32);
    for (let x = 0; x < 32; x++) r[x] = Math.cos(((2 * x + 1) * u * Math.PI) / 64);
    t.push(r);
  }
  return t;
})();

// 32x32 DCT'nin sol üst 8x8'i (DC hariç) medyana göre eşiklenir → 64 bit
function phashBit(g) {
  const g32 = kucult(g, 32, 32);
  const ara = new Float64Array(8 * 32);
  for (let y = 0; y < 32; y++) {
    for (let u = 0; u < 8; u++) {
      let s = 0;
      for (let x = 0; x < 32; x++) s += g32[y * 32 + x] * KOS[u][x];
      ara[y * 8 + u] = s;
    }
  }
  const d = new Float64Array(64);
  for (let v = 0; v < 8; v++) {
    for (let u = 0; u < 8; u++) {
      let s = 0;
      for (let y = 0; y < 32; y++) s += ara[y * 8 + u] * KOS[v][y];
      d[v * 8 + u] = s;
    }
  }
  const kop = Array.from(d.slice(1)).sort((a, b) => a - b);
  const ort = (kop[30] + kop[31]) / 2;
  let b = 0n;
  for (let i = 0; i < 64; i++) b = (b << 1n) | (d[i] > ort ? 1n : 0n);
  return b;
}

// [ox,oy,s] penceresini KxK'ya indirger, ortalamasını sıfırlar, normunu birler
function kirpNormal(g, ox, oy, s) {
  const v = new Float32Array(KK);
  const x0 = ox * N, y0 = oy * N, w = s * N;
  for (let y = 0; y < K; y++) {
    const ya = Math.floor(y0 + (y * w) / K), yb = Math.max(ya + 1, Math.floor(y0 + ((y + 1) * w) / K));
    for (let x = 0; x < K; x++) {
      const xa = Math.floor(x0 + (x * w) / K), xb = Math.max(xa + 1, Math.floor(x0 + ((x + 1) * w) / K));
      let t = 0, n = 0;
      for (let j = ya; j < yb && j < N; j++) for (let i = xa; i < xb && i < N; i++) { t += g[j * N + i]; n++; }
      v[y * K + x] = n ? t / n : 0;
    }
  }
  let ort = 0;
  for (let i = 0; i < KK; i++) ort += v[i];
  ort /= KK;
  let kare = 0;
  for (let i = 0; i < KK; i++) { v[i] -= ort; kare += v[i] * v[i]; }
  const norm = Math.sqrt(kare) || 1;
  for (let i = 0; i < KK; i++) v[i] /= norm;
  return v;
}

/** Bir kare dosyasının imzası; ffmpeg okuyamazsa null. */
export async function imzaCikar(dosyaYolu) {
  const ham = await hamGri(dosyaYolu);
  if (!ham) return null;
  const g = new Float32Array(N * N);
  for (let i = 0; i < N * N; i++) g[i] = ham[i];
  const kirp = new Float32Array(KIRPIMLAR.length * KK);
  KIRPIMLAR.forEach(([ox, oy, s], i) => kirp.set(kirpNormal(g, ox, oy, s), i * KK));
  return { dh: dhashBit(g), ph: phashBit(g), kirp };
}

const mesafe = (a, b) => { let x = a ^ b, n = 0; while (x) { n += Number(x & 1n); x >>= 1n; } return n; };

/** İki imzanın hizalı benzerlik skoru (1.0 = aynı yapı). */
export function hizaliSkor(A, B) {
  let en = -1;
  const bt = B.kirp.subarray(0, KK), at = A.kirp.subarray(0, KK);
  for (let i = 0; i < KIRPIMLAR.length; i++) {
    const o = i * KK;
    let s1 = 0, s2 = 0;
    for (let j = 0; j < KK; j++) { s1 += A.kirp[o + j] * bt[j]; s2 += B.kirp[o + j] * at[j]; }
    if (s1 > en) en = s1;
    if (s2 > en) en = s2;
  }
  return en;
}

/** Aynı görsel mi? Değilse null, öyleyse yakalayan ölçütün adı. */
export function ayniGorsel(A, B) {
  if (!A || !B) return null;
  if (mesafe(A.dh, B.dh) <= ESIK_DHASH) return 'dhash';
  if (mesafe(A.ph, B.ph) <= ESIK_PHASH) return 'phash';
  return hizaliSkor(A, B) >= ESIK_HIZALI ? 'hizali' : null;
}
