// İstek başlığından KABA CİHAZ SINIFI türetme (admin paneli · cihaz dağılımı).
//
// ===========================================================================
// GİZLİLİK SÖZLEŞMESİ — BU DOSYANIN VAR OLMA SEBEBİ
// ===========================================================================
// Ham `User-Agent` HİÇBİR YERE YAZILMAZ. Ne veritabanına, ne günlüğe, ne
// belleğe (kalıcı olarak). Ham UA, sürüm numaraları + yama seviyesi + cihaz
// modeli + dil taşıdığı için tek başına bir PARMAK İZİDİR; IP ile eşlenince
// bir kişiyi takip etmeye yeter. Bu proje ban sisteminde bile donanımdan
// kimlik OKUMUYOR (bkz. `app/lib/cihaz_kimlik.dart` başlığı) — aynı çizgi
// burada da geçerlidir.
//
// Onun yerine UA, üç KAPALI SÖZLÜKTEN birer değere indirgenir:
//     tur      6 değer   (bot/uygulama/mobil/tablet/masaustu/diger)
//     os       7 değer   (android/ios/windows/macos/linux/chromeos/diger)
//     tarayici 8 değer   (chrome/safari/firefox/edge/opera/samsung/uygulama/diger)
// Üçlünün taşıdığı bilgi ~9 bit; bir GÜN içinde binlerce kişi aynı üçlüye
// düşer. Saklanan satır da kişi başına değil, (gün, tur, os, tarayici) başına
// TEK SAYAÇTIR — kullanıcı kimliği, IP, oturum, hiçbiri yoktur. Yani "kim
// hangi cihazı kullanıyor" sorusu bu veriden CEVAPLANAMAZ; yalnız "kaç istek
// hangi sınıftan geldi" cevaplanır.
//
// ===========================================================================
// SINIRLAR (panelde de yazıyor — yanlış okunmasın)
// ===========================================================================
//  * SAYAÇ İSTEK SAYAR, KİŞİ SAYMAZ. Çok gezen bir kullanıcı, az gezen ona
//    göre daha çok pay alır. Tekilleştirme için kişi/oturum başına bir anahtar
//    tutmak gerekirdi — o da tam olarak kaçındığımız şeydir. "Kişi" boyutu
//    `cihaz_tokenlari`ndan (push) okunur; ikisi panelde AYRI gösterilir.
//  * iPadOS 13+ masaüstü Safari UA'sı gönderir ("Macintosh; Intel Mac OS X").
//    Apple bunu bilerek yapıyor; ayırt EDİLEMEZ, macOS/masaüstü sayılır.
//  * Mobil uygulama (Flutter/dart:io) UA'sında işletim sistemi YOKTUR:
//    `Dart/3.5 (dart:io)`. Bu yüzden tur='uygulama', os='diger' döner —
//    uygulamanın Android/iOS kırılımı push tablosundan gelir.
//  * Marka/model (SM-G991B, Pixel 7…) OKUNMAZ ve saklanmaz.
//
// Fonksiyonlar SAF'tır (girdi → çıktı, yan etki yok) ve testlidir:
// `test/cihaz_dagilimi.test.js`.

/** Kapalı sözlükler — dışarı da veriliyor ki uç ve testler aynı listeyi görsün. */
export const TURLER = ['bot', 'uygulama', 'mobil', 'tablet', 'masaustu', 'diger'];
export const ISLETIM = ['android', 'ios', 'windows', 'macos', 'linux', 'chromeos', 'diger'];
export const TARAYICILAR = ['chrome', 'safari', 'firefox', 'edge', 'opera', 'samsung', 'uygulama', 'diger'];

// UA en fazla bu kadarı okunur: uzun bir başlık, catastrophic backtracking
// olmayan basit regexlerde bile boşuna CPU yakar (ve saldırgan denetiminde).
const AZAMI_UA = 400;

// Botlar: arama motoru, önizleme çekicisi, izleme/keşif aracı. AYRI tutulur
// çünkü "kullanıcıların cihaz dağılımı" sorusunun cevabını Googlebot bozar.
const BOT = /bot\b|bot\/|crawler|spider|slurp|facebookexternalhit|whatsapp|telegram|discord|preview|headless|lighthouse|pingdom|uptime|monitor|curl\/|wget\/|python-requests|libwww|scrapy|semrush|ahrefs|petal|yandex|bingpreview|applebot|gptbot|claudebot|ccbot/i;

// Kendi mobil uygulamamız (Flutter `package:http` → dart:io) ve genel HTTP
// istemcileri. Tarayıcı DEĞİL; masaüstü/mobil ayrımına da sokulmaz.
const UYGULAMA = /^dart\/|dart:io|flutter|okhttp|cronet|cfnetwork|darwin\//i;

/**
 * Ham User-Agent → kapalı sözlüklerden üçlü.
 * @param {unknown} ham İstek başlığı (yoksa/boşsa "diger" üçlüsü döner).
 * @returns {{tur:string, os:string, tarayici:string}}
 */
export function cihazSinifla(ham) {
  const ua = typeof ham === 'string' ? ham.slice(0, AZAMI_UA) : '';
  if (!ua.trim()) return { tur: 'diger', os: 'diger', tarayici: 'diger' };

  // 1) Bot her şeyden önce gelir: birçok bot kendini "Mozilla/5.0 ... Chrome"
  //    diye tanıtır; sıra ters olsaydı masaüstü Chrome sayılırlardı.
  if (BOT.test(ua)) return { tur: 'bot', os: isletimSistemi(ua), tarayici: 'diger' };

  // 2) Tarayıcı olmayan istemciler (kendi uygulamamız dahil).
  if (UYGULAMA.test(ua) && !/mozilla/i.test(ua)) {
    return { tur: 'uygulama', os: isletimSistemi(ua), tarayici: 'uygulama' };
  }

  const os = isletimSistemi(ua);
  return { tur: cihazTuru(ua, os), os, tarayici: tarayiciAdi(ua) };
}

/** İşletim sistemi ailesi. Sürüm/yama seviyesi OKUNMAZ. */
function isletimSistemi(ua) {
  // Android, "Linux; Android 14" yazdığı için linux'tan ÖNCE bakılmalı.
  if (/android/i.test(ua)) return 'android';
  if (/iphone|ipad|ipod|ios;|\bcriOS|fxios/i.test(ua)) return 'ios';
  // ChromeOS de "X11; CrOS x86_64" der → linux'tan önce.
  if (/\bcros\b/i.test(ua)) return 'chromeos';
  if (/windows nt|win64|windows phone|\bwin32\b/i.test(ua)) return 'windows';
  if (/mac os x|macintosh|darwin/i.test(ua)) return 'macos';
  if (/linux|x11|ubuntu|fedora|freebsd/i.test(ua)) return 'linux';
  return 'diger';
}

/** Masaüstü / mobil / tablet. */
function cihazTuru(ua, os) {
  if (os === 'android') {
    // Android'in KENDİ kuralı: telefon tarayıcısı "Mobile" yazar, tablet
    // yazmaz. Model adına bakmaya gerek yok (ve bakmak istemiyoruz).
    return /\bmobile\b/i.test(ua) ? 'mobil' : 'tablet';
  }
  if (os === 'ios') return /ipad/i.test(ua) ? 'tablet' : 'mobil';
  if (/\btablet\b|\bkindle\b|silk\//i.test(ua)) return 'tablet';
  if (/\bmobile\b|\bphone\b|iemobile|opera mini/i.test(ua)) return 'mobil';
  if (os === 'windows' || os === 'macos' || os === 'linux' || os === 'chromeos') return 'masaustu';
  return 'diger';
}

/**
 * Tarayıcı ailesi. SIRA KRİTİK: Edge/Opera/Samsung UA'ları "Chrome" ibaresini
 * de taşır, Chrome da "Safari" taşır. Genelden özele bakılsaydı her şey
 * Chrome/Safari görünürdü.
 */
function tarayiciAdi(ua) {
  if (/edg[ea]?\//i.test(ua)) return 'edge';
  if (/opr\/|opera|opios/i.test(ua)) return 'opera';
  if (/samsungbrowser/i.test(ua)) return 'samsung';
  if (/firefox\/|fxios/i.test(ua)) return 'firefox';
  if (/chrome\/|crios|chromium/i.test(ua)) return 'chrome';
  if (/safari\//i.test(ua)) return 'safari';
  return 'diger';
}

/**
 * Gün + sınıf başına SAYAÇ tamponu.
 *
 * Neden tampon: her istekte DB'ye UPDATE atmak, saniyede yüzlerce isteklik
 * bir uçta aynı satır üzerinde kilit kuyruğu yaratırdı. Bellekte toplanır,
 * dakikada bir tek turda UPSERT'lenir.
 *
 * Bellek sınırı KENDİLİĞİNDEN gelir: anahtar uzayı 6×7×8 = 336 kombinasyon ×
 * açık gün sayısıdır; sınırsız büyüyemez (kullanıcı/IP anahtarı YOK).
 */
export class CihazSayaci {
  constructor() {
    /** @type {Map<string, number>} `gun|tur|os|tarayici` → adet */
    this.tampon = new Map();
  }

  /** UA'yı sınıflandırıp sayacı bir artırır. Ham UA hiçbir yerde tutulmaz. */
  ekle(ua, gun = bugunUtc()) {
    const { tur, os, tarayici } = cihazSinifla(ua);
    const anahtar = `${gun}|${tur}|${os}|${tarayici}`;
    this.tampon.set(anahtar, (this.tampon.get(anahtar) || 0) + 1);
    return { tur, os, tarayici };
  }

  get boyut() { return this.tampon.size; }

  /** Tamponu boşaltıp `[gun, tur, os, tarayici, adet]` satırları döner. */
  bosalt() {
    const satirlar = [];
    for (const [anahtar, adet] of this.tampon) {
      const [gun, tur, os, tarayici] = anahtar.split('|');
      satirlar.push([gun, tur, os, tarayici, adet]);
    }
    this.tampon.clear();
    return satirlar;
  }
}

/** Sayaç günü UTC'dir: işçiler/konteynerler farklı TZ'de olsa da tek gün adı. */
export function bugunUtc(d = new Date()) {
  return d.toISOString().slice(0, 10);
}
