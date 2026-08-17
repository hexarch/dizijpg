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
