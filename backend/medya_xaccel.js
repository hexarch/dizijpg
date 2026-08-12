// D2 — MEDYA BAYTLARINI NGINX'E DEVRETME (X-Accel-Redirect).
//
// SORUN (yapilacaklar2 D2): her fotoğraf/video baytı Node olay döngüsünden
// geçiyor. nginx aynı işi `sendfile` ile çekirdekte yapar. Ama nginx'in
// dosyaları DOĞRUDAN servis etmesi güvenlik mantığını (imzalı URL, OZEL_MEDYA,
// yalnizGet) baypas ederdi. Doğru kalıp X-Accel-Redirect:
//
//   1) İstek nginx -> Node'a bugünkü gibi proxy'lenir.
//   2) Node TÜM kontrolleri yapar (imza kapısı, özel medya, GET/HEAD) ama
//      dosyayı OKUMAZ; yanıta yalnız `X-Accel-Redirect: /ic-dosya/...` +
//      Cache-Control/Content-Type koyar (bu katman).
//   3) nginx `location /ic-dosya/ { internal; alias <medya kökü>; }` ile
//      dosyayı sendfile'la yollar (Range/video seeking bedava).
//      Taslak: nginx-medya.conf.ornek
//
// NEDEN AYRI MODÜL: server.js içe aktarıldığı anda dinlemeye başlar, uçları
// test edilemez (kesfet_medya.test.js gerekçesi). Bu katman bağımlılıklarını
// parametre alır (dizin, özel küme, bayrak) — test gerçek fonksiyonu çalıştırır.
//
// BAŞLIK SÖZLEŞMESİ (nginx iç yönlendirmede üst yanıttan yalnız şu başlıkları
// taşır): Content-Type, Cache-Control, Expires, Content-Disposition,
// Set-Cookie + X-Accel-* ailesi. Bu yüzden:
//   - Cache-Control ve Content-Type BURADA basılır ve bugünkü express.static
//     çıktısıyla BAYT BAYT aynıdır (Cloudflare davranışı değişmesin diye):
//       genel:  `public, max-age=31536000, immutable`  (statikSecenek 365d)
//       özel :  `private, no-store, max-age=0`         (DM medyası CF'e girmez)
//   - X-Robots-Tag taşınMAZ; özel medya için nginx tarafında /ic-ozel
//     bloğundaki `add_header` yeniden ekler (yine de burada basılır ki nginx'siz
//     doğrudan yanıtta da dursun).
import fs from 'node:fs';
import path from 'node:path';
import express from 'express';

/** nginx'teki internal location ön ekleri (nginx-medya.conf.ornek ile eş). */
export const IC_ON_EK = '/ic-dosya';      // genel: /ic-dosya/<altDizin>/<ad>
export const IC_ON_EK_OZEL = '/ic-ozel';  // özel DM medyası: /ic-ozel/<ad>

/** Bugünkü express.static({maxAge:'365d', immutable:true}) çıktısıyla AYNI. */
export const GENEL_CACHE = 'public, max-age=31536000, immutable';
/** Bugünkü setHeaders kancasının özel medyaya yazdığıyla AYNI. */
export const OZEL_CACHE = 'private, no-store, max-age=0';

// Tek yol segmenti, nokta ile BAŞLAMAZ (dotfile), yalnız güvenli ASCII.
// Kalıba uymayan ad X-Accel'e verilmez; express.static'e düşer (bugünkü yol).
// Böylece hem yol geçişi (../) hem başlık enjeksiyonu imkânsız, hem de kalıp
// dışı eski bir dosya varsa davranışı DEĞİŞMEZ (Node servis etmeye devam eder).
export const GUVENLI_AD = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;

/**
 * `req.url`den (kök '/medya' | '/avatarlar' SONRASI iç yol) güvenli dosya adı.
 * Query atılır (express.static de yok sayar). Uymayan her şey -> null.
 */
export function guvenliAd(url) {
  if (typeof url !== 'string' || !url.startsWith('/')) return null;
  const soru = url.indexOf('?');
  const yol = soru === -1 ? url : url.slice(0, soru);
  let ad;
  try {
    ad = decodeURIComponent(yol.slice(1)); // static de %xx çözer; eş davran
  } catch {
    return null;
  }
  if (!GUVENLI_AD.test(ad)) return null;
  return ad;
}

/**
 * Bugünkü express.static'in basacağı Content-Type'ın AYNISI: aynı mime
 * tablosu kullanılır (express.static.mime === send'in mime'ı), charset kuralı
 * dahil (medya türlerinde charset çıkmaz ama kural yine de kopyalanır).
 */
export function icerikTuru(ad, mime = express.static.mime) {
  const tur = mime.lookup(ad);
  const kodlama = mime.charsets.lookup(tur);
  return kodlama ? `${tur}; charset=${kodlama}` : tur;
}

/**
 * X-Accel katmanı. İmza/özel-medya KAPISINDAN SONRA, express.static'ten ÖNCE
 * bağlanır: kapıdan geçemeyen istek buraya hiç ulaşmaz (403 kapıda döner),
 * buradan geçemeyen istek (bayrak kapalı, kalıp dışı ad, diskte yok, GET/HEAD
 * değil) express.static'e düşer — yani bugünkü davranış AYNEN korunur.
 *
 * @param {object} sec
 * @param {boolean} sec.acik    MEDYA_XACCEL bayrağı; kapalıyken katman saydam.
 * @param {string}  sec.dizin   Diskte kök (MEDYA_DIZIN / AVATAR_DIZIN).
 * @param {string}  sec.altDizin nginx iç yolundaki ad ('medya' | 'avatarlar').
 * @param {Set<string>|null} [sec.ozelKume] CANLI OZEL_MEDYA referansı (IPC ile
 *   beslenen Set aynen görülür); avatarlarda null.
 * @param {(y:string)=>boolean} [sec.varMi] test için enjekte edilebilir stat.
 */
export function xaccelKatman({ acik, dizin, altDizin, ozelKume = null, varMi = fs.existsSync }) {
  return (req, res, next) => {
    if (!acik) return next();
    // yalnizGet tuzağıyla aynı kural: POST /medya (yükleme ucu) YUTULMAZ.
    if (req.method !== 'GET' && req.method !== 'HEAD') return next();
    const ad = guvenliAd(req.url);
    if (ad == null) return next();
    // Diskte yoksa express.static'e bırak: 404 bugünkü gibi (fallthrough:false)
    // Express'ten döner, nginx'in html 404'üne düşülmez. Maliyet tek stat —
    // express.static de aynı stat'ı yapıyordu; bayt kopyalama yükü gidiyor.
    if (!varMi(path.join(dizin, ad))) return next();
    const ozel = ozelKume != null && ozelKume.has(ad);
    res.statusCode = 200;
    res.setHeader('X-Accel-Redirect',
      ozel ? `${IC_ON_EK_OZEL}/${ad}` : `${IC_ON_EK}/${altDizin}/${ad}`);
    res.setHeader('Content-Type', icerikTuru(ad));
    res.setHeader('Cache-Control', ozel ? OZEL_CACHE : GENEL_CACHE);
    if (ozel) res.setHeader('X-Robots-Tag', 'noindex, nofollow');
    // Gövde YOK: baytları nginx okur. Range başlığı da nginx'te işlenir.
    res.end();
  };
}
