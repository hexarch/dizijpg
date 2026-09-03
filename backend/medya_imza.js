// ÖZEL (DM) MEDYA İÇİN İMZALI-SÜRELİ URL — SAF modül.
//
// `kripto.js` / `yasak.js` ile aynı kalıp: burada Express de, `pg` de,
// `process.env` de yok. İçe aktarma HİÇBİR yan etki yapmaz, böylece
// `test/medya_imza.test.js` gerçek fonksiyonları çağırıp davranışı ölçer.
//
// ---------------------------------------------------------------------------
// SORUN (GUVENLIK-DENETIMI-2026-08-07.md §2.1)
// ---------------------------------------------------------------------------
// `/medya` kimlik doğrulamasız servis ediliyor. Tek koruma dosya adındaki 64
// bit rastgelelik. Numaralandırma imkânsız ama URL bir kez sızarsa (ekran
// görüntüsü, tarayıcı geçmişi, üçüncü taraf log, Cloudflare edge önbelleği)
// DM fotoğrafı/sesi KALICI ve İPTALSİZ açığa çıkıyor.
//
// ---------------------------------------------------------------------------
// NEDEN QUERY DEĞİL, YOL İÇİNE GÖMÜLÜ İMZA
// ---------------------------------------------------------------------------
// İlk akla gelen `?exp=…&sig=…` biçimidir. Bu istemciyi KIRAR: yayındaki
// sürümlerde medya türü dosya YOLUNA bakılarak anlaşılıyor —
//   app/lib/ekranlar/sohbet.dart:1513  `yol.endsWith('.ogg') || …`
//   app/lib/ekranlar/sohbet.dart:1640  `medya.endsWith('.mp4')`
//   app/lib/ekranlar/medya_goster.dart:29 `url.endsWith('.mp4')`
// Query eklenince yol artık uzantıyla BİTMEZ; sesli mesaj fotoğraf sanılır,
// video kırık resim ikonuna düşer. Yayındaki APK'ları güncelleyemeyiz.
//
// Bu yüzden imza YOL SEGMENTİ olarak, dosya adının ÖNÜNE konur:
//
//     /medya/i/<exp36>/<imza>/m1-8cd6a45c0c5e643f.png
//     \_____/ | \____/ \____/ \________________________/
//        |    |    |      |               |
//        |    |    |      |               +-- gerçek dosya adı: uzantı SONDA
//        |    |    |      |                   kalır -> endsWith() çalışmaya
//        |    |    |      |                   devam eder, eski istemci kırılmaz
//        |    |    |      +-- HMAC-SHA256'nın ilk 16 baytı (32 hex = 128 bit)
//        |    |    +-- son kullanma, epoch SANİYE, base36 (kısa)
//        |    +-- "imza" işaretçisi. Tek başına geçerli bir dosya adı değildir
//        |        (gerçek adlar `m<id>-<hex>.<uzanti>` kalıbında), çakışmaz.
//        +-- mevcut kök; istemcinin `startsWith('/medya/')` kontrolü de sürer.
//
// ---------------------------------------------------------------------------
// NEDEN "KOVA"LI SON KULLANMA (exp her istekte DEĞİŞMEZ)
// ---------------------------------------------------------------------------
// Sohbet ekranı mesajları 5 saniyede bir yeniden çekiyor
// (app/lib/ekranlar/sohbet.dart:619). `exp = şimdi + 24s` deseydik URL her
// pollda değişirdi ve iki şey bozulurdu:
//   1) `CachedNetworkImage` önbellek anahtarı TAM URL'dir (kod tabanında hiç
//      `cacheKey:` yok) -> her 5 saniyede fotoğraf yeniden indirilir, titrer.
//   2) Sesli mesaj oynatıcısının kimliği `ValueKey('ses-$medya')`
//      (sohbet.dart:1733) -> URL değişince widget yok edilir ve ÇALAN SES
//      5 saniyede bir kesilir.
// Çözüm: `exp`i saate göre KOVA'ya yuvarla. Aynı kova içindeki tüm istekler
// BAYT BAYT AYNI URL'yi üretir. URL 24 saatte en çok iki kez değişir; bedeli
// resim başına günde iki yeniden indirme, kazancı sızan URL'nin ömrünün
// sonsuzdan <=24 saate inmesidir.
//
// ---------------------------------------------------------------------------
// NEYİ KORUR / NEYİ KORUMAZ (abartma — denetim raporundaki dille aynı)
// ---------------------------------------------------------------------------
// KORUR: sızmış bir DM medya URL'sinin SÜRESİZ kullanılmasını. Ekran
//        görüntüsüne düşen, loga yazılan, tarayıcı geçmişinde kalan bir URL
//        en geç bir kova süresi (24 saat) sonra 403 olur. Ayrıca özel medya
//        `Cache-Control: private, no-store` ile döner: Cloudflare edge'de
//        PUBLIC kopya birikmez (denetimdeki `cf-cache-status: HIT` durumu).
// KORUMAZ: (a) URL'yi PENCERE İÇİNDE ele geçireni — imza kimlik doğrulaması
//        değildir, `<img src>` Authorization başlığı gönderemediği için bu
//        bilinçli bir tasarım ödünüdür. (b) Alıcının kendisini: sohbete erişen
//        her zaman taze imza üretebilir; ekran görüntüsü alabilir. (c) Sunucu
//        ele geçirilmesini: anahtar süreç belleğindedir. (d) HALKA AÇIK yorum/
//        akış medyasını — o içerik zaten kamuya açıktır, bilerek kapsam dışı.

import crypto from 'node:crypto';

/** İmza sürümü. Biçim değişirse artar; eski imzalar doğrulanmaz olur. */
export const IMZA_SURUM = 'v1';

/** Yol içindeki imza işaretçisi: `/medya/i/<exp36>/<imza>/<dosya>` */
export const IMZA_ISARET = 'i';

/** HMAC'ten alınan bayt sayısı. 16 bayt = 128 bit; sahtecilik için fazlasıyla yeterli. */
export const IMZA_BAYT = 16;

/**
 * Kova uzunluğu (ms). 12 saat: URL günde en çok iki kez değişir, sızan URL en
 * geç 24 saat (iki kova) sonra ölür.
 */
export const KOVA_MS = 12 * 60 * 60 * 1000;

/**
 * Gerçek medya dosyası adı (+ video kapağı `.jpg`). İKİ ÖNEK:
 *
 *   `m<kullanıcı_id>-<16 hex>.<uzanti>`  — kullanıcı yüklemesi (`POST /medya`)
 *   `o<oda_id>-<16 hex>.<uzanti>`        — İZLEME ODASI videosu (3 Eyl 2026)
 *
 * ÖNEK NEDEN AYRI (ve neden oda videosu da `m` OLMADI): yorum eki sahipliği
 * `^/medya/m<benim_id>-…$` kalıbıyla doğrulanıyor (server.js, iki yerde).
 * Oda videosu `m<sahip_id>-…` diye adlandırılsaydı sahibi onu HALKA AÇIK bir
 * yoruma iliştirebilir, dosya `ozelMedyaYukle`daki `EXCEPT … yorumlar`
 * kuralına takılıp ÖZEL kümeden düşer ve herkese açılırdı. `o` öneki o
 * kalıba hiçbir kullanıcı için uymaz — izolasyon adın kendisinde.
 *
 * Kalıba UYMAYAN ad İMZALANMAZ (`imzali` yolu olduğu gibi döndürür) ve bu
 * SESSİZ bir hatadır: 3 Eyl 2026'da oda videosu tam da bu yüzden imzasız
 * yolla gitti, istemci 403 aldı ve video hiç açılmadı.
 */
export const DOSYA_KALIP =
  /^[mo][1-9][0-9]{0,9}-[0-9a-f]{16}\.(gif|png|jpg|jpeg|webp|mp4|webm|ogg|m4a|mp3|aac)(\.jpg)?$/;

/**
 * Anahtar türetme: ayrı bir sır YÖNETMEMEK için JWT sırrından HKDF benzeri
 * bir alan ayrımıyla türetilir. Aynı sır iki AMAÇ için kullanılsa da `info`
 * etiketi farklı olduğundan üretilen anahtarlar bağımsızdır; medya imzası
 * asla geçerli bir JWT'ye, JWT asla geçerli bir medya imzasına dönüşemez.
 *
 * Dağıtım kolaylığı bilinçli bir tercihtir: yeni bir `.env` değişkeni
 * gerekmediği için "kod gitti ama sır gitmedi" tuzağı oluşmaz. İstenirse
 * `MEDYA_IMZA_ANAHTARI` ile açıkça geçersiz kılınabilir.
 *
 * JWT sırrı döndürülürse (rotation) tüm medya URL'leri en geç bir kova
 * sonra kendiliğinden tazelenir — istemci zaten her açılışta yeniden çeker.
 *
 * @param {string} sir JWT sırrı ya da açık medya anahtarı
 * @returns {Buffer} 32 baytlık imzalama anahtarı
 */
export function anahtarTuret(sir) {
  if (typeof sir !== 'string' || sir.length === 0) {
    throw new Error('medya imza anahtarı boş olamaz');
  }
  return crypto.createHmac('sha256', sir)
    .update(`dizijpg-medya-imza-${IMZA_SURUM}`)
    .digest();
}

/**
 * Verilen anın ait olduğu kovanın BİTİŞİNDEN bir kova SONRASI.
 * Aynı kova içindeki her çağrı AYNI değeri döndürür (URL kararlılığı).
 * Geçerlilik penceresi böylece KOVA_MS ile 2*KOVA_MS arasındadır.
 * @param {number} simdiMs Date.now()
 * @returns {number} epoch SANİYE
 */
export function kovaSonu(simdiMs, kovaMs = KOVA_MS) {
  return Math.floor((Math.floor(simdiMs / kovaMs) + 2) * kovaMs / 1000);
}

/**
 * Ham imzayı üretir (hex).
 * `exp` imzaya GİRER: saldırgan son kullanmayı ileri alamaz.
 */
export function imzaUret(dosya, expSn, anahtar) {
  return crypto.createHmac('sha256', anahtar)
    .update(`${IMZA_SURUM}\n${dosya}\n${expSn}`)
    .digest()
    .subarray(0, IMZA_BAYT)
    .toString('hex');
}

/**
 * `/medya/<dosya>` -> `/medya/i/<exp36>/<imza>/<dosya>`
 * Zaten imzalıysa ya da tanınmayan bir yol ise AYNEN döndürür (çift imzalama
 * ve avatar/harici URL bozma yok).
 * @param {string|null} yol
 * @returns {string|null}
 */
export function imzali(yol, anahtar, simdiMs = Date.now(), kovaMs = KOVA_MS) {
  const dosya = dosyaAdi(yol);
  if (dosya == null) return yol;
  const exp = kovaSonu(simdiMs, kovaMs);
  const imza = imzaUret(dosya, exp, anahtar);
  return `/medya/${IMZA_ISARET}/${exp.toString(36)}/${imza}/${dosya}`;
}

/**
 * İmzasız `/medya/<dosya>` yolundan dosya adını çıkarır.
 * İmzalı yol, harici URL, avatar yolu ya da kalıba uymayan ad -> null.
 */
export function dosyaAdi(yol) {
  if (typeof yol !== 'string' || !yol.startsWith('/medya/')) return null;
  const kalan = yol.slice('/medya/'.length);
  if (!DOSYA_KALIP.test(kalan)) return null;
  return kalan;
}

/**
 * İmzalı yolu ayrıştırır. `/medya` KÖKÜNDEN SONRAKİ kısmı bekler
 * (Express `app.use('/medya', …)` içinde `req.url` böyledir):
 *   `/i/<exp36>/<imza>/<dosya>`
 * @returns {{exp:number, imza:string, dosya:string}|null}
 */
export function imzaAyristir(icYol) {
  if (typeof icYol !== 'string') return null;
  // Query varsa at: imza yolun içindedir, sorgu dizesi imzaya dahil değildir.
  const soru = icYol.indexOf('?');
  const temiz = soru === -1 ? icYol : icYol.slice(0, soru);
  const p = temiz.split('/');
  // ['', 'i', exp36, imza, dosya]
  if (p.length !== 5 || p[0] !== '' || p[1] !== IMZA_ISARET) return null;
  const [, , exp36, imza, dosyaHam] = p;
  if (!/^[0-9a-z]{1,10}$/.test(exp36)) return null;
  if (!new RegExp(`^[0-9a-f]{${IMZA_BAYT * 2}}$`).test(imza)) return null;
  let dosya;
  try { dosya = decodeURIComponent(dosyaHam); } catch { return null; }
  // Yol geçişi savunması: imza zaten adı kapsıyor ama kalıp ayrıca daraltır.
  if (!DOSYA_KALIP.test(dosya)) return null;
  const exp = parseInt(exp36, 36);
  if (!Number.isFinite(exp) || exp <= 0) return null;
  return { exp, imza, dosya };
}

/**
 * İmzayı doğrular. Zaman KARŞILAŞTIRMASI da burada.
 * @returns {{gecerli:boolean, sebep:'yok'|'suresi_doldu'|'imza_hatali'|null, dosya:string|null}}
 */
export function imzaDogrula(icYol, anahtar, simdiMs = Date.now()) {
  const p = imzaAyristir(icYol);
  if (!p) return { gecerli: false, sebep: 'yok', dosya: null };
  const beklenen = imzaUret(p.dosya, p.exp, anahtar);
  // Sabit zamanlı karşılaştırma: imza baytlarını zamanlama farkından sızdırma.
  const a = Buffer.from(p.imza, 'hex');
  const b = Buffer.from(beklenen, 'hex');
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    return { gecerli: false, sebep: 'imza_hatali', dosya: p.dosya };
  }
  // Süre kontrolü İMZADAN SONRA: geçersiz imzalı istekten süre bilgisi sızmasın.
  if (simdiMs / 1000 > p.exp) {
    return { gecerli: false, sebep: 'suresi_doldu', dosya: p.dosya };
  }
  return { gecerli: true, sebep: null, dosya: p.dosya };
}

/**
 * İmzalı YA DA imzasız bir `/medya/...` yolunu KANONİK `/medya/<dosya>`
 * biçimine indirger. İki yerde şart:
 *   1) DB'ye her zaman imzasız yol yazılır (imza bir SUNUM detayıdır; DB'ye
 *      yazılsaydı süresi dolduğunda kayıt kalıcı olarak bozulurdu).
 *   2) İstemci imzalı bir yolu geri gönderirse (`POST /mesajlar` `medya`
 *      alanı) sahiplik regex'i onu reddetmesin.
 * Tanınmayan girdi AYNEN döner.
 */
export function yoluNormalle(yol) {
  if (typeof yol !== 'string' || !yol.startsWith('/medya/')) return yol;
  const p = imzaAyristir(yol.slice('/medya'.length));
  return p ? `/medya/${p.dosya}` : yol;
}
