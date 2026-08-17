// DİSK EŞİĞİ KAPISI — SAF modül (güvenlik denetimi 2026-08-17 §3.1).
//
// `kripto.js` / `medya_imza.js` / `yasak.js` ile aynı kalıp: burada Express de,
// `pg` de, `process.env` de yok. İçe aktarma HİÇBİR yan etki yapmaz; ölçüm
// fonksiyonu parametre olarak enjekte edilir, böylece `test/disk.test.js`
// gerçek fonksiyonu diski doldurmadan çalıştırabilir.
//
// ---------------------------------------------------------------------------
// SORUN (GUVENLIK-DENETIMI-2026-08-17.md §3.1)
// ---------------------------------------------------------------------------
// Misafir hesap anında açılıyor (IP başına 30/saat, e-posta doğrulaması yok),
// her hesap 40 yükleme × 100 MB hakkına sahip. Tek IP'den saatlik tavan
// ~120 GB. Diskte 17 Ağu 2026 itibarıyla 21 GB boştu ve NE kota NE disk
// alarmı vardı: ~10 dakikada disk dolar.
//
// Disk `/` üzerinde ve makine PAYLAŞIMLI. Dolduğu anda yalnız dizi.jpg değil,
// host Postgres'teki diğer veritabanları, Postfix/Dovecot posta kabulü, nginx
// logu ve gece yedeği BİRLİKTE durur. Yani bu, tek bir uygulamanın
// erişilebilirlik sorunu değil, makine geneli bir kapıdır.
//
// ---------------------------------------------------------------------------
// NEDEN KOTA DEĞİL, ÖNCE EŞİK
// ---------------------------------------------------------------------------
// Kullanıcı başına toplam kota (`kullanicilar.medya_bayt` + migrasyon) DOĞRU
// çözümdür ve ayrıca yapılmalıdır. Ama eşik kapısı 30 dakikalık iştir, şema
// değişikliği İSTEMEZ ve EN KÖTÜ SONUCU (makinenin durması) tek başına
// kapatır: saldırgan diski %95'e kadar doldurabilse bile son GB'lar korunur,
// Postgres yazmaya, yedek alınmaya devam eder. Kota saldırıyı ucuzlatmayı,
// eşik ise felaketi önlemeyi hedefler — ikisi rakip değil, katman.
//
// ---------------------------------------------------------------------------
// NEDEN FAIL-OPEN (ölçüm hata verirse yükleme GEÇER)
// ---------------------------------------------------------------------------
// `statfs` bir sebeple patlarsa iki seçenek var: herkesin yüklemesini kesmek
// ya da bugünkü davranışa düşmek. Yanlış "kapat" kararı GERÇEK kullanıcıların
// fotoğraf/ses göndermesini keser — görünür, yaygın ve anlamsız bir bozulma.
// Yanlış "geçir" kararı ise en kötü ihtimalle 17 Ağu öncesi duruma döner.
// `hizLimitiMerkezi`nin merkez sayacı da AYNI gerekçeyle fail-open'dır.
//
// ---------------------------------------------------------------------------
// NEDEN TTL'Lİ ÖNBELLEK
// ---------------------------------------------------------------------------
// `statfs` ucuzdur ama bedava değildir ve yükleme uçları tek başına sıcak
// değildir. 5 saniyelik önbellek, saldırı hızında bile en fazla 5 saniyelik
// (bu uçlarda ~birkaç yüz MB) bir kaçak bırakır — eşik zaten 10 GB'lık bir
// pay ayırdığı için bu kaçak eşiğin İÇİNDE kalır.

// ---------------------------------------------------------------------------
// İKİNCİ KATMAN: IP BAŞINA SAATLİK YÜKLEME BAYTI (denetim §3.1'in kalanı)
// ---------------------------------------------------------------------------
// Eşik kapısı makinenin ölmesini engelliyor ama saldırgan eşiğe KADAR
// doldurup kapıyı kapatabilir; o andan sonra gerçek kullanıcılar da
// yükleyemez. Yani eşik "makine ayakta"yı, bu bütçe "hizmet kullanılabilir"i
// korur.
//
// NEDEN IP BAŞINA, HESAP BAŞINA DEĞİL: hesap BEDAVA ve saniyede açılıyor
// (misafir girişi, e-posta doğrulaması yok). Hesap başına konan her sınır,
// hesap sayısıyla çarpılarak aşılır. IP bedava değildir.
//
// NEDEN Content-Length (gövdeyi OKUMADAN): 100 MB'lık bir gövdeyi belleğe
// alıp sonra "bütçen bitti" demek, saldırganın istediği şeyi (bellek + CPU
// harcaması) zaten yapmak olurdu. nginx `proxy_request_buffering on` ile
// isteği tamponlayıp Node'a HER ZAMAN Content-Length ile verir, yani başlık
// pratikte hep vardır ve gövdeyle uyuşmak ZORUNDADIR (uyuşmazsa Node isteği
// zaten reddeder). Başlık yine de yoksa `bilinmeyen` kadar ücret keseriz —
// belirsizliği saldırganın değil bütçenin lehine yorumluyoruz.

/** IP başına saatlik yükleme bütçesi. 1 GB gerçek kullanımın çok üstünde. */
export const VARSAYILAN_IP_BAYT_SAAT = 1024 ** 3;

/** Bütçe penceresi (ms). `hizLimiti` ile aynı: sabit 1 saatlik kova. */
export const BUTCE_PENCERE_MS = 3600_000;

/**
 * Content-Length'i güvenli okur.
 * @returns {number|null} bayt; başlık yok/bozuk/negatifse null
 */
export function govdeUzunlugu(req) {
  const ham = req?.headers?.['content-length'];
  if (ham == null) return null;
  // BOŞ DİZE KONTROLÜ ŞART: `Number('')` 0'dır, yani `Content-Length:` (değeri
  // boş) gönderen istek "0 bayt" sayılıp bütçeden HİÇ ücret kesilmeden
  // geçerdi. Testi yazarken yakalandı; sessiz bir bütçe deliğiydi.
  const metin = String(ham).trim();
  if (metin === '') return null;
  const n = Number(metin);
  if (!Number.isFinite(n) || n < 0 || !Number.isInteger(n)) return null;
  return n;
}

/**
 * IP başına saatlik yükleme baytı bütçesi. `express.raw`tan ÖNCE bağlanır.
 *
 * @param {object} sec
 * @param {number} sec.butce        Pencere başına bayt tavanı. 0 -> devre dışı.
 * @param {(req)=>string} sec.anahtar  Bütçe anahtarı (IP).
 * @param {number} [sec.bilinmeyen] Content-Length yoksa kesilecek ücret.
 * @param {number} [sec.pencereMs]
 * @param {()=>number} [sec.simdi]
 * @param {string} [sec.mesaj]      Kullanıcıya dönen metin (çeviri anahtarı).
 */
export function baytButcesi({
  butce, anahtar, bilinmeyen = 100 * 1024 * 1024,
  pencereMs = BUTCE_PENCERE_MS, simdi = Date.now,
  mesaj = 'Çok fazla istek; biraz sonra tekrar dene',
}) {
  const sayaclar = new Map();
  const katman = (req, res, next) => {
    if (!butce) return next();
    const simdiMs = simdi();
    const k = anahtar(req);
    let kayit = sayaclar.get(k);
    if (!kayit || simdiMs > kayit.sifirlama) {
      kayit = { bayt: 0, sifirlama: simdiMs + pencereMs };
      sayaclar.set(k, kayit);
    }
    const uzunluk = govdeUzunlugu(req) ?? bilinmeyen;
    if (kayit.bayt + uzunluk > butce) {
      // 429: bu bir HIZ limitidir, depo tükenmesi (507) DEĞİL. İkisini tek
      // koda indirmek "diskim mi doldu, çok mu hızlıyım" ayrımını silerdi.
      // Metin BİLEREK mevcut hız limiti cümlesi: 45 dilde zaten çevrili.
      return res.status(429).json({ hata: mesaj, kod: 'YUKLEME_BUTCESI' });
    }
    kayit.bayt += uzunluk;
    // Bellek emniyeti: yalnız süresi DOLMUŞ kayıtları at. `clear()` herkesin
    // bütçesini sıfırlardı — hizLimiti'nde düzeltilen aynı hata.
    if (sayaclar.size > 10000) {
      for (const [ka, v] of sayaclar) if (simdiMs > v.sifirlama) sayaclar.delete(ka);
    }
    return next();
  };
  katman.durum = (k) => sayaclar.get(k) || null;
  return katman;
}

// ---------------------------------------------------------------------------
// ÜÇÜNCÜ KATMAN: KULLANICI BAŞINA TOPLAM KOTA (denetim §3.1)
// ---------------------------------------------------------------------------
// Eşik kapısı "makine ölmesin", bayt bütçesi "saatlik hız" derdinde. İkisi de
// ZAMANA bağlı; hiçbiri "tek hesap günler boyunca birikerek diski yer"
// durumunu kapatmıyor. Kota onu kapatır.
//
// ÖLÇÜLDÜ (17 Ağu, diskteki gerçek dağılım): gerçek bir insanın bir aylık
// kullanımı ~40 MB. Varsayılan 2 GB bunun ~50 katı.

/** Bağlı (e-postalı) hesap için varsayılan kota. */
export const VARSAYILAN_KOTA_BAYT = 2 * 1024 ** 3;
/** Misafir hesap için kota. Hesap bedava olduğu için bilerek düşük. */
export const MISAFIR_KOTA_BAYT = 200 * 1024 * 1024;

/** Kota aşımının makine kodu. */
export const KOTA_DOLU_KODU = 'KOTA_DOLU';
/**
 * Kullanıcıya dönen metin — AYNI ZAMANDA ÇEVİRİ ANAHTARIDIR (app/lib/api.dart
 * `mesaj.c`). Değişirse `lib/diller/dil_*.dart` içindeki 45 karşılık da AYNI
 * turda değişmeli.
 */
export const KOTA_DOLU_MESAJ = 'Medya alanın doldu; yer açmak için eski yüklemelerini sil';

/**
 * Dosya adından SAHİBİNİ çıkarır. Adlar sahibin id'sini taşır:
 *   medya  : `m<id>-<16hex>.<uzanti>` (+ video kapağı `.jpg`)
 *   avatar : `avatar<id>-<zaman>.<uzanti>`
 *   kapak  : `kapak<id>-<zaman>.<uzanti>`
 * Tanınmayan ad -> null (sayıma girmez; yanlış kullanıcıya fatura kesmeyiz).
 * @returns {number|null}
 */
export function medyaSahibi(ad) {
  if (typeof ad !== 'string') return null;
  const m = /^(?:m|avatar|kapak)([1-9][0-9]{0,9})-/.exec(ad);
  if (!m) return null;
  const id = Number(m[1]);
  return Number.isSafeInteger(id) && id > 0 ? id : null;
}

/**
 * Hesabın kotası (bayt). Öncelik: hesaba özel değer > tür varsayılanı.
 * `0` SINIRSIZ demektir (içerik/tohum hesapları için kaçış yolu) ve bu yüzden
 * `?? ` DEĞİL açık `null` kontrolü kullanılıyor — `0 ?? x` 0 döndürür ama
 * niyeti okuyanın kafasında `0 = kapalı` ile `0 = tanımsız` karışmasın.
 * @param {{medya_kota_bayt?: number|null}} kullanici
 * @param {boolean} misafirMi
 * @returns {number} 0 = sınırsız
 */
export function kotaBayt(kullanici, misafirMi) {
  const ozel = kullanici?.medya_kota_bayt;
  if (ozel !== null && ozel !== undefined) return Number(ozel);
  return misafirMi ? MISAFIR_KOTA_BAYT : VARSAYILAN_KOTA_BAYT;
}

/**
 * Dizindeki dosyaları sahibine göre toplar. GECE YENİDEN HESAPLAMA için:
 * muhasebe (yüklemede artır / silmede azalt) kaçınılmaz olarak kayar —
 * silme yollarından biri unutulur, tohum araçları diske doğrudan yazar,
 * elle dosya silinir. Diskten yeniden hesaplamak bu kaymayı KENDİLİĞİNDEN
 * düzeltir, yani muhasebenin kusursuz olması gerekmez.
 *
 * @param {Array<{ad:string, bayt:number}>} girdiler
 * @returns {Map<number, number>} sahip id -> toplam bayt
 */
export function kullanimTopla(girdiler) {
  const toplam = new Map();
  for (const g of girdiler || []) {
    const sahip = medyaSahibi(g?.ad);
    if (sahip == null) continue;
    const bayt = Number(g?.bayt);
    if (!Number.isFinite(bayt) || bayt < 0) continue;
    toplam.set(sahip, (toplam.get(sahip) || 0) + bayt);
  }
  return toplam;
}

/** Varsayılan eşik: bu kadar boş alan KALMADIYSA yükleme reddedilir. */
export const VARSAYILAN_ESIK_GB = 10;

/** Ölçüm önbelleği ömrü (ms). Bkz. dosya başındaki gerekçe. */
export const VARSAYILAN_TTL_MS = 5000;

/** Yanıtın MAKİNE kodu. İstemci buna karşılık kendi 45 dilli metnini basar. */
export const DEPO_DOLU_KODU = 'DEPO_DOLU';

/**
 * Kullanıcıya dönen metin. Bu dize AYNI ZAMANDA ÇEVİRİ ANAHTARIDIR:
 * `ApiHata.toString()` onu `mesaj.c` ile 45 dilli haritadan geçirir
 * (app/lib/api.dart:99). Değiştirilirse `lib/diller/dil_*.dart` içindeki 45
 * karşılık da AYNI turda güncellenmelidir.
 */
export const DEPO_DOLU_MESAJ = 'Sunucuda geçici olarak yer yok, birazdan tekrar dene';

/**
 * Eşiği ortam değişkeninden okur. Geçersiz/eksik değer varsayılana düşer —
 * `.env`'e yanlış bir şey yazmak kapıyı SESSİZCE kapatmasın ya da açmasın.
 * `0` BİLİNÇLİ kaçış yoludur: kapıyı tamamen devre dışı bırakır.
 * @param {object} env
 * @returns {number} bayt
 */
export function esikBayt(env = {}) {
  const ham = String(env.DISK_ESIK_GB ?? '').trim();
  const gb = ham === '' ? VARSAYILAN_ESIK_GB : Number(ham);
  if (!Number.isFinite(gb) || gb < 0) return VARSAYILAN_ESIK_GB * 1024 ** 3;
  return Math.round(gb * 1024 ** 3);
}

/**
 * `fs.statfsSync` çıktısından KULLANILABİLİR boş baytı hesaplar.
 *
 * `bavail` (ayrıcalıksız kullanıcıya kalan) kullanılır, `bfree` DEĞİL: ext4
 * diskin %5'ini root'a ayırır ve `bfree` onu da sayar. Konteyner bugün root
 * olarak çalıştığı için `bfree`ye bakmak "hâlâ 4 GB var" deyip tam da
 * korumak istediğimiz rezervi yedirirdi.
 * @returns {number|null} bayt; şekil tanınmazsa null (fail-open)
 */
export function bosBayt(s) {
  if (!s || typeof s !== 'object') return null;
  const { bavail, bsize } = s;
  if (!Number.isFinite(Number(bavail)) || !Number.isFinite(Number(bsize))) return null;
  return Number(bavail) * Number(bsize);
}

/**
 * Disk eşiği ara katmanı üretir.
 *
 * KONUM: gövde ayrıştırıcıdan (`express.raw`) ÖNCE bağlanmalı. Reddedeceğimiz
 * bir isteğin 100 MB'lık gövdesini belleğe almanın anlamı yok — üstelik
 * saldırgan tam da belleği/diski zorlamaya çalışıyor.
 *
 * @param {object} sec
 * @param {string} sec.dizin      Ölçülecek dizin (MEDYA_DIZIN gibi).
 * @param {number} sec.esik       Eşik (bayt). 0 -> kapı devre dışı.
 * @param {() => object} sec.olc  Ölçüm (varsayılan fs.statfsSync(dizin)).
 * @param {number} [sec.ttlMs]    Önbellek ömrü.
 * @param {() => number} [sec.simdi] Test için saat.
 * @param {(bilgi: object) => void} [sec.uyar] Eşik altına inince BİR KEZ çağrılır.
 */
export function diskKapisi({
  dizin, esik, olc, ttlMs = VARSAYILAN_TTL_MS, simdi = Date.now, uyar = null,
}) {
  let sonOlcum = 0;
  let sonBos = null;
  let uyarildi = false;

  const bosOku = () => {
    const t = simdi();
    if (sonBos !== null && t - sonOlcum < ttlMs) return sonBos;
    sonOlcum = t;
    try {
      sonBos = bosBayt(olc(dizin));
    } catch {
      // Fail-open: ölçemiyorsak bugünkü davranışa düş (dosya başındaki gerekçe).
      sonBos = null;
    }
    return sonBos;
  };

  const katman = (req, res, next) => {
    if (!esik) return next();
    const bos = bosOku();
    if (bos === null || bos >= esik) {
      uyarildi = false;
      return next();
    }
    if (!uyarildi) {
      uyarildi = true;
      if (uyar) uyar({ dizin, bos, esik });
    }
    // 507 Insufficient Storage: anlamı TAM olarak budur ve 503'ten ayrıdır —
    // 503 zarif kapanma kapısının dili (server.js başı), ikisini karıştırmak
    // "sunucu yeniden başlıyor" ile "disk doldu"yu tek sinyale indirirdi.
    return res.status(507).json({ hata: DEPO_DOLU_MESAJ, kod: DEPO_DOLU_KODU });
  };
  // Test ve admin özeti için: ölçümü dışarıdan okuyabilmek gerekiyor.
  katman.bos = bosOku;
  return katman;
}
