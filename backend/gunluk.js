// dizi.jpg — yapılandırılmış (JSON) log + SIZINTI SÜZGECİ.
//
// SAF MODÜL: Express, pg ve `process.env` bilmez; içe aktarmanın yan etkisi
// yoktur (yasak.js / arama.js ile aynı disiplin). Böylece sızıntı testleri
// sunucu ayağa kalkmadan, saniyeler içinde çalışır.
//
// =============================================================================
// NEDEN KÜTÜPHANE YOK (pino / winston DEĞİL) — bilinçli karar
// =============================================================================
// pino'nun kazandırdığı iki şey var: (1) çok yüksek hacimde asenkron yazma
// hızı, (2) hazır `redact` yolları. İkisi de bize UYMUYOR:
//   1) Hacim: burada YALNIZ hata ve yaşam döngüsü olayları loglanıyor —
//      istek başına satır YOK (onu zaten nginx tutuyor). Günde birkaç yüz
//      satırda serileştirme hızı ölçülemez bir kazançtır.
//   2) Redaksiyon: pino'nun `redact` özelliği ÖNCEDEN BİLİNEN YOLLARI siler
//      (`req.headers.authorization` gibi). Bizim asıl sızıntı kaynağımız
//      bu değil — `err.message` ve `err.stack` İÇİNDEKİ serbest metindir
//      (pg hata mesajı parametre değerini basar, doğrulama hatası e-postayı
//      basar). Onu yol tabanlı redaksiyon YAKALAYAMAZ; desen tabanlı bir
//      süzgeç yazmak zorundayız. Yazdıktan sonra pino'nun eklediği şey,
//      imaja giren bir bağımlılık ağacından ibaret kalıyor.
// Ayrıca her yeni bağımlılık, gece yarısı çıkan bir CVE'de yamalanacak bir
// yüzey demektir. `console.error(JSON.stringify(...))` bu iki maddeyi de
// bedavaya çözüyor: Docker `json-file` sürücüsü stderr'i zaten satır satır
// topluyor, `docker logs | jq` ile aranabiliyor.
//
// =============================================================================
// İKİ KATMANLI KORUMA — hangisi asıl savunma?
// =============================================================================
// KATMAN 1 (ASIL): BEYAZ LİSTE. `istekBaglami()` istekten YALNIZCA sabit bir
//   alan kümesini çıkarır. `req.body`, `req.headers` ve sorgu DEĞERLERİ
//   hiçbir koşulda kayda girmez. Sızdırmamanın tek güvenilir yolu, hassas
//   veriyi hiç ALMAMAKTIR.
// KATMAN 2 (AĞ): `temizle()`. Kayıt serileştirilmeden önce tüm dize
//   değerleri desenlerden geçer. Bu katman beyaz listeyi DEĞİL, beyaz
//   listenin kontrol edemediği yerleri (hata mesajı, yığın izi) korur.
//
// Katman 1 delinirse katman 2 çoğu şeyi yakalar; ikisi de test/gunluk.test.js
// tarafından kilitlenmiştir. Yeni bir alan eklerken TESTİ ÖNCE YAZ.

import fs from 'fs';

/** Tek bir dize değerinin azami uzunluğu. Uzun gövdeler loga akmasın. */
export const AZAMI_METIN = 400;
/** Yığın izinden tutulacak kare sayısı. Hata noktasını bulmaya fazlasıyla yeter. */
export const AZAMI_YIGIN = 12;
/** Nesne gezinme derinliği (döngüsel/derin yapılarda kilitlenmeyi önler). */
export const AZAMI_DERINLIK = 4;
/** Bir nesneden alınacak azami anahtar sayısı. */
export const AZAMI_ANAHTAR = 40;

/** Değeri silinip `[gizli]` yazılacak anahtar adları — ADIN İÇİNDE geçmesi yeter. */
export const GIZLI_ICEREN = Object.freeze([
  'sifre', 'parola', 'password', 'passwd', 'pwd', 'token', 'jwt',
  'authorization', 'yetkilendirme', 'secret', 'anahtar', 'apikey', 'api_key',
  'cookie', 'session', 'oturum', 'sdp', 'candidate', 'credential',
  'mesaj', 'metin', 'icerik', 'govde', 'email', 'eposta', 'e-posta', 'bearer',
]);
/** Kısa oldukları için TAM eşleşme aranan anahtarlar (`sir` `siralama`yı,
 *  `key` `monkey`i yakalamasın diye ayrı tutuldu). */
export const GIZLI_TAM = Object.freeze([
  'sir', 'key', 'ice', 'aday', 'adaylar', 'pin', 'mail', 'body', 'auth',
  'imza', 'otp', 'kod', 'hash',
]);

/** Anahtar adı hassas mı? Karşılaştırma harfe ve ayraçlara duyarsızdır. */
export function gizliAnahtarMi(ad) {
  const k = String(ad ?? '').toLowerCase();
  const sade = k.replace(/[^a-z]/g, '');
  if (GIZLI_TAM.includes(k) || GIZLI_TAM.includes(sade)) return true;
  return GIZLI_ICEREN.some((p) => k.includes(p));
}

// --- Serbest metin desenleri -------------------------------------------------
// SIRA ÖNEMLİ: SDP/ICE kontrolü en başta, çünkü tüm dizeyi tek başına yutar.

/** SDP ya da ICE adayı görüntüsü veren dize — TAMAMI atılır, parçası değil.
 *  Gerekçe: SDP çok satırlı ve her satırı hassas (fingerprint, ufrag, IP).
 *  Parçalayıp maskelemek kaçak bırakır; tamamını atmak kaçak bırakmaz. */
export const SDP_BELIRTECI =
  /(^|[\r\n])v=0(\r?\n|$)|[\r\n]m=(audio|video)\s|a=(fingerprint|ice-ufrag|ice-pwd|crypto|setup):|(^|\s)candidate:\d|a=candidate:/i;

const DESENLER = Object.freeze([
  // JWT — üç base64url parçası. Authorization başlığından ya da hata
  // mesajından sızabilir ("invalid token eyJhbG...").
  [/\beyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]*/g, '[token]'],
  // `Bearer <şey>` — token bozuk/JWT olmasa bile.
  [/\bBearer\s+[A-Za-z0-9._~+/-]+=*/gi, 'Bearer [token]'],
  // E-posta adresi. Yol parçasında bile geçse maskelenir (/sifirla/a@b.com).
  [/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, '[e-posta]'],
  // bcrypt hash'i — yedek dökümünden ya da bir hata mesajından düşebilir.
  [/\$2[aby]\$\d{2}\$[./A-Za-z0-9]{53}/g, '[hash]'],
  // 40+ karakterlik kesintisiz base64url/hex bloğu: anahtar, token, imza,
  // özet. `/` ve `.` BİLEREK dışarıda — yoksa uzun dosya yolları ve
  // `node_modules` zincirleri maskelenir ve yığın izi okunamaz hâle gelir.
  [/\b[A-Za-z0-9_-]{40,}\b/g, '[blob]'],
]);

/** Serbest metni temizler. `null`/tanımsız girdi boş dizeye düşmez, aynen döner. */
export function metniTemizle(ham) {
  if (typeof ham !== 'string') return ham;
  if (SDP_BELIRTECI.test(ham)) return '[sdp/ice]';
  let s = ham;
  for (const [desen, yerine] of DESENLER) s = s.replace(desen, yerine);
  if (s.length > AZAMI_METIN) s = `${s.slice(0, AZAMI_METIN)}…(${s.length})`;
  return s;
}

/**
 * Kaydı derinlemesine temizler: hassas anahtarların DEĞERİ atılır, kalan
 * dizeler desenlerden geçer, derinlik/boyut sınırlanır.
 * Döngüsel referans güvenlidir (`[dongusel]`).
 */
export function temizle(deger, derinlik = 0, gorulen = new WeakSet()) {
  if (deger === null || deger === undefined) return deger;
  const tip = typeof deger;
  if (tip === 'string') return metniTemizle(deger);
  if (tip === 'number' || tip === 'boolean') return deger;
  if (tip === 'bigint') return String(deger);
  if (tip === 'function' || tip === 'symbol') return `[${tip}]`;
  if (deger instanceof Date) return deger.toISOString();
  if (deger instanceof Error) return hataOzeti(deger);
  if (derinlik >= AZAMI_DERINLIK) return '[derin]';
  if (gorulen.has(deger)) return '[dongusel]';
  gorulen.add(deger);
  if (Array.isArray(deger)) {
    return deger.slice(0, AZAMI_ANAHTAR).map((d) => temizle(d, derinlik + 1, gorulen));
  }
  const cikti = {};
  for (const [k, v] of Object.entries(deger).slice(0, AZAMI_ANAHTAR)) {
    cikti[k] = gizliAnahtarMi(k) ? '[gizli]' : temizle(v, derinlik + 1, gorulen);
  }
  return cikti;
}

/**
 * Hatayı loglanabilir özete çevirir.
 * `mesaj` VE `yigin` ikisi de süzgeçten geçer — asıl sızıntı kapısı burasıdır:
 * pg sürücüsü hata mesajında parametre değerini, doğrulama hataları
 * e-postayı basabilir.
 */
export function hataOzeti(hata) {
  if (!(hata instanceof Error)) {
    // `throw 'metin'` ya da `Promise.reject(42)` — Error olmayan reddetmeler.
    return { ad: typeof hata, mesaj: metniTemizle(String(hata)), yigin: [] };
  }
  const yigin = String(hata.stack || '')
    .split('\n')
    .slice(1, AZAMI_YIGIN + 1)
    .map((s) => metniTemizle(s.trim()))
    .filter(Boolean);
  const ozet = { ad: hata.name || 'Error', mesaj: metniTemizle(hata.message), yigin };
  // pg hataları: `code` (ör. 23505 tekil ihlali) teşhiste altın değerinde ve
  // hassas değil. `detail`/`where` ise DEĞER BASAR — bilerek alınmıyor.
  if (hata.code) ozet.pg_kod = metniTemizle(String(hata.code));
  if (hata.status || hata.statusCode) ozet.durum = Number(hata.status || hata.statusCode);
  if (hata.cause instanceof Error) ozet.neden = hataOzeti(hata.cause);
  return ozet;
}

/**
 * İstekten loglanabilir bağlamı çıkarır — BEYAZ LİSTE (katman 1).
 *
 * *** BURAYA `req.body`, `req.headers` YA DA SORGU DEĞERİ EKLENMEYECEK. ***
 * Sorgudan yalnız ANAHTAR ADLARI alınır: `?imza=...`, `?token=...` gibi
 * parametrelerin varlığı teşhiste işe yarar, DEĞERİ ise tam olarak
 * sızdırmamamız gereken şeydir. Aynı sebeple `req.originalUrl` DEĞİL
 * `req.path` kullanılır (originalUrl sorgu dizesini taşır).
 */
export function istekBaglami(req) {
  if (!req) return {};
  const b = {};
  if (req.istekId) b.istek = String(req.istekId);
  if (req.path) b.yol = metniTemizle(String(req.path));
  if (req.method) b.metot = String(req.method).slice(0, 12);
  if (req.kullanici?.id != null) b.kullanici = req.kullanici.id;
  const sorgu = req.query && typeof req.query === 'object' ? Object.keys(req.query) : [];
  if (sorgu.length) b.sorgu = sorgu.slice(0, 20).map((k) => metniTemizle(String(k)));
  // Gövde ALAN ADLARI (değerleri değil): "hangi şekildeki istek patladı"
  // sorusunu cevaplar. Adlar istemci denetiminde olduğu için yine süzgeçten
  // geçer ve 20 ile sınırlanır.
  const alanlar = req.body && typeof req.body === 'object' && !Array.isArray(req.body)
    ? Object.keys(req.body) : [];
  if (alanlar.length) b.alanlar = alanlar.slice(0, 20).map((k) => metniTemizle(String(k)));
  return b;
}

/** Tek satırlık JSON kaydı üretir (yazmaz — test bunu doğrudan çağırır). */
export function kayitYap({ seviye = 'hata', olay, hata, req, ...ek } = {}) {
  const kayit = {
    ts: new Date().toISOString(),
    seviye,
    olay: String(olay || 'bilinmeyen'),
    ...istekBaglami(req),
    ...temizle(ek),
  };
  if (hata !== undefined) kayit.hata = hataOzeti(hata);
  return kayit;
}

/** JSON satırı (sonunda \n YOK). `JSON.stringify` patlarsa asla fırlatmaz. */
export function satir(kayit) {
  try {
    return JSON.stringify(kayit);
  } catch {
    return JSON.stringify({
      ts: new Date().toISOString(), seviye: 'hata', olay: 'log_serilestirilemedi',
    });
  }
}

/**
 * Normal yol: stderr'e asenkron yazar. Süreç yaşamaya devam ettiği için
 * tampon er geç boşalır.
 */
export function yaz(alanlar) {
  const s = satir(kayitYap(alanlar));
  console.error(s);
  return s;
}

/**
 * ÖLÜMCÜL yol: stderr'e SENKRON yazar.
 *
 * NEDEN `console.error` DEĞİL: Docker'da stderr bir BORUDUR ve Node borulara
 * ASENKRON yazar. `console.error(...)` hemen ardından `process.exit()`
 * gelirse satır tamponda kalır ve ASLA GÖRÜNMEZ — yani çökme kalkanı
 * kurulmuş olur ama çöktüğünde elimizde hiçbir kayıt olmaz. Tam da işe
 * yaraması gereken anda sessiz kalır. `fs.writeSync(2, ...)` bunu kapatır.
 */
export function olumcul(alanlar) {
  const s = satir(kayitYap({ seviye: 'olumcul', ...alanlar }));
  try {
    fs.writeSync(2, `${s}\n`);
  } catch {
    // stderr kapalıysa (nadir) son çare: kaybetmektense konsola dene.
    try { console.error(s); } catch { /* yapacak bir şey kalmadı */ }
  }
  return s;
}
