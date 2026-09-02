/**
 * Sohbet BELGE ekleri (2 Eyl 2026, Telegram düzeni): PDF, ZIP, DOCX… her tür.
 *
 * NEDEN `/medya`DAN AYRI BİR HAT:
 * `/medya` dosyayı UZANTISIYLA yazar ve nginx `icerikTuru(ad)` ile uzantıdan
 * Content-Type türetip inline servis eder. Belge hattında bu ÖLÜMCÜL olurdu:
 * yüklenen bir `.html`/`.svg` dizijpg.com kökeninde sayfa olarak açılır (XSS).
 * Bu yüzden belge diske DAİMA `.bin` uzantısıyla yazılır (`d<uid>-<16hex>.bin`),
 * özgün ad/MIME/boyut yalnız `mesajlar` satırında durur ve indirme ucu
 * `Content-Type: application/octet-stream` + `Content-Disposition: attachment`
 * + `X-Content-Type-Options: nosniff` ile cevap verir. Tarayıcı ne olursa
 * olsun DOSYA olarak indirir.
 *
 * GİZLİLİK: DM eki özeldir. Okuma uçları yolu İMZALI verir
 * (`/dosya/i/<exp36>/<imza>/<ad>`, medya imzasıyla aynı anahtar ve kova),
 * imzasız `/dosya/<ad>` 403. İmza HKDF alanı farklı ('dizijpg-dosya-imza'):
 * medya imzası belgeye, belge imzası medyaya geçmez.
 *
 * DB'ye HER ZAMAN imzasız yol yazılır (`/dosya/<ad>`); imza sunum detayıdır.
 */
import crypto from 'crypto';
import { kovaSonu, KOVA_MS, IMZA_ISARET, IMZA_BAYT } from './medya_imza.js';

/** Diskteki belge adı: `d<kullanıcı_id>-<16 hex>.bin` — uzantı SABİT. */
export const DOSYA_EK_KALIP = /^d[1-9][0-9]{0,9}-[0-9a-f]{16}\.bin$/;

/** Tek belge tavanı (istemci `dosyaAzamiBayt` ile BİREBİR). */
export const DOSYA_EK_AZAMI = 50 * 1024 * 1024;

/** Özgün ad tavanı (Windows 255, güvenli pay). */
export const DOSYA_AD_AZAMI = 180;

/** İstemcinin gönderdiği MIME için kabul edilen biçim (saklanır, servis edilmez). */
const MIME_KALIP = /^[a-z0-9!#$&^_.+-]{1,40}\/[a-z0-9!#$&^_.+-]{1,80}$/i;

/**
 * Özgün dosya adını temizler: yol ayracı, kontrol karakteri, önde/arkada
 * nokta-boşluk gider; boş kalırsa 'dosya'. Uzantı KORUNUR (alıcı ne
 * indirdiğini görsün) — servis edilirken kullanılmadığı için zararsız.
 */
export function dosyaAdiTemizle(ham) {
  let ad = String(ham ?? '');
  try { ad = decodeURIComponent(ad); } catch { /* ham kalsın */ }
  ad = ad
    .replace(/[\\/]+/g, '_')
    // eslint-disable-next-line no-control-regex
    .replace(/[\x00-\x1f\x7f]/g, '')
    .replace(/^[\s.]+|[\s.]+$/g, '')
    .trim();
  if (!ad) ad = 'dosya';
  if (ad.length > DOSYA_AD_AZAMI) {
    const nokta = ad.lastIndexOf('.');
    const uzanti = nokta > 0 && ad.length - nokta <= 12 ? ad.slice(nokta) : '';
    ad = ad.slice(0, DOSYA_AD_AZAMI - uzanti.length) + uzanti;
  }
  return ad;
}

/** İstemci MIME'ı: biçime uymuyorsa `application/octet-stream`. */
export function mimeTemizle(ham) {
  const m = String(ham ?? '').trim().toLowerCase();
  return MIME_KALIP.test(m) ? m : 'application/octet-stream';
}

/** Belge imza anahtarı: medya anahtarından AYRI alan. */
export function dosyaAnahtarTuret(sir) {
  if (typeof sir !== 'string' || sir.length === 0) {
    throw new Error('dosya imza anahtarı boş olamaz');
  }
  return crypto.createHmac('sha256', 'dizijpg-dosya-imza-v1').update(sir).digest();
}

function imzaUret(ad, expSn, anahtar) {
  return crypto.createHmac('sha256', anahtar)
    .update(`${ad}\n${expSn}`)
    .digest('hex')
    .slice(0, IMZA_BAYT * 2);
}

/** `/dosya/<ad>` → imzalı `/dosya/i/<exp36>/<imza>/<ad>`; kalıba uymayan yol aynen. */
export function dosyaImzali(yol, anahtar, simdiMs = Date.now(), kovaMs = KOVA_MS) {
  const ad = dosyaEkAdi(yol);
  if (ad == null) return yol;
  const exp = kovaSonu(simdiMs, kovaMs);
  return `/dosya/${IMZA_ISARET}/${exp.toString(36)}/${imzaUret(ad, exp, anahtar)}/${ad}`;
}

/** İmzasız `/dosya/<ad>` yolundan diskteki adı çıkarır; uymuyorsa null. */
export function dosyaEkAdi(yol) {
  if (typeof yol !== 'string' || !yol.startsWith('/dosya/')) return null;
  const kalan = yol.slice('/dosya/'.length);
  return DOSYA_EK_KALIP.test(kalan) ? kalan : null;
}

/**
 * `/dosya` kökünden SONRAKİ yolu doğrular (`/i/<exp36>/<imza>/<ad>`).
 * @returns {{gecerli:boolean, sebep:string|null, ad:string|null}}
 */
export function dosyaImzaDogrula(icYol, anahtar, simdiMs = Date.now()) {
  if (typeof icYol !== 'string') return { gecerli: false, sebep: 'yok', ad: null };
  const soru = icYol.indexOf('?');
  const temiz = soru === -1 ? icYol : icYol.slice(0, soru);
  const p = temiz.split('/');
  if (p.length !== 5 || p[0] !== '' || p[1] !== IMZA_ISARET) {
    return { gecerli: false, sebep: 'yok', ad: null };
  }
  const [, , exp36, imza, ad] = p;
  if (!/^[0-9a-z]{1,10}$/.test(exp36) || !DOSYA_EK_KALIP.test(ad)
      || !new RegExp(`^[0-9a-f]{${IMZA_BAYT * 2}}$`).test(imza)) {
    return { gecerli: false, sebep: 'yok', ad: null };
  }
  const exp = parseInt(exp36, 36);
  const beklenen = imzaUret(ad, exp, anahtar);
  const a = Buffer.from(imza, 'hex');
  const b = Buffer.from(beklenen, 'hex');
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    return { gecerli: false, sebep: 'imza_hatali', ad };
  }
  if (simdiMs / 1000 > exp) return { gecerli: false, sebep: 'suresi_doldu', ad };
  return { gecerli: true, sebep: null, ad };
}

/** İmzalı ya da imzasız belge yolunu kanonik `/dosya/<ad>` yapar. */
export function dosyaYoluNormalle(yol) {
  if (typeof yol !== 'string' || !yol.startsWith('/dosya/')) return yol;
  const p = String(yol.slice('/dosya'.length)).split('/');
  if (p.length === 5 && p[1] === IMZA_ISARET && DOSYA_EK_KALIP.test(p[4])) {
    return `/dosya/${p[4]}`;
  }
  return yol;
}

/**
 * `Content-Disposition` için RFC 5987 değeri: ASCII yedek + UTF-8 tam ad.
 * Tırnak/ters bölü/CR-LF yedekten atılır (başlık enjeksiyonu yok).
 */
export function ekBasligi(ad) {
  const ascii = ad.replace(/[^\x20-\x7e]/g, '_').replace(/["\\]/g, '_');
  return `attachment; filename="${ascii}"; filename*=UTF-8''${encodeURIComponent(ad)}`;
}
