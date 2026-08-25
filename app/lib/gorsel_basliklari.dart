/// AĞDAN ÇEKİLEN GÖRSELLER İÇİN İSTEK BAŞLIKLARI — TEK KAYNAK.
///
/// Bu dosya, görsel indiren HER çağrı noktasının (`CachedNetworkImage`,
/// `CachedNetworkImageProvider`) kullandığı başlıkları tek yerde tutar.
/// Başlık değerleri SABİTTİR ve kullanıcı girdisinden TÜRETİLMEZ — böylece
/// başlık enjeksiyonu (satır sonu kaçırma) yapısal olarak imkânsızdır.
///
/// --- NEDEN: WEBP PAZARLIĞI (md. 50) ---
/// TMDB görselleri BunnyCDN üzerinden geliyor ve CDN, isteğin `Accept`
/// başlığına bakıp JPEG yerine WebP üretiyor. ÖLÇÜM (14 Ağu 2026, canlı CDN,
/// `w342/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg`):
///
///   Accept yok / `*/*`      → `content-type: image/jpeg`, 45.777 bayt
///   `Accept: image/webp,*/*`→ `content-type: image/webp`,  33.082 bayt
///
/// Yanıttaki `x-bo-compressionratio: 27.73%` başlığı da aynı oranı söylüyor:
/// poster başına ~%28 tasarruf, 30 posterlik bir ızgarada ~450 KB.
///
/// --- HANGİ PLATFORMDA GERÇEKTEN İŞE YARIYOR (dürüst sınır) ---
/// MOBİL (Android/iOS): `CachedNetworkImage` baytları `flutter_cache_manager`
/// üzerinden `http` paketiyle indirir ve o paket KENDİLİĞİNDEN `Accept`
/// göndermez → bugüne kadar JPEG iniyordu. Kazanç BURADA gerçekleşiyor ve en
/// değerli olduğu yer de burası (mobil veri).
///
/// WEB: `cached_network_image` varsayılan olarak
/// `ImageRenderMethodForWeb.HtmlImage` kullanır; o yol baytları `<img>`
/// öğesiyle indirir (`cached_network_image_web` içindeki
/// `_loadAsyncHtmlImage` başlıkları HİÇ almaz) ve tarayıcının KENDİ
/// `Accept: image/avif,image/webp,...` başlığı gider — yani web'de WebP zaten
/// pazarlanıyor. Buradaki başlık web'de sessizce yok sayılır; paket
/// varsayılanı `HttpGet`e dönerse (ya da bilinçli olarak çevirirsek) kazanç
/// kendiliğinden web'e de yayılır. Gerekçenin kaynak kanıtı:
/// `test/gif_animasyon_test.dart` (paket varsayılanını kilitleyen test).
///
/// --- KENDİ SUNUCUMUZ NEDEN LİSTEDE YOK ---
/// `/api/medya/` ve `/api/avatarlar/` altındaki dosyalar `backend/server.js`
/// içinde yüklendikleri baytlarla AYNEN diske yazılıyor (`fs.writeFileSync`,
/// hiçbir dönüştürme yok) ve `express.static` / `X-Accel-Redirect` ile
/// olduğu gibi servis ediliyor; `Content-Type` yalnızca DOSYA UZANTISINDAN
/// üretiliyor (`medya_xaccel.js` → `icerikTuru`). Sunucu içerik pazarlığı
/// YAPMADIĞI için oraya `Accept: image/webp` göndermek tek bayt kazandırmaz;
/// üstelik pazarlık yapılmayan bir yanıtta `Vary: Accept` de olmadığından
/// (nginx + Cloudflare önbelleği) yanlış varyantın paylaşımlı önbellekte
/// dolaşması riski doğardı. Bu yüzden karar: kendi sunucumuza EK BAŞLIK YOK.
library;

import 'package:flutter/painting.dart';

/// Kullanıcının yüklediği görsel (yorum, Reels, avatar, video kapağı)
/// ekranda kaynaktan büyük çizildiğinde kullanılan süzgeç.
///
/// `low` küçük Instagram karelerini 3× ekranda bulanıklaştırır. `high` kayıp
/// sıkıştırmayı GERİ GETİRMEZ — olmayan pikseli uydurmaz — ama kübik
/// örnekleme kenarı temiz tutar. TMDB poster ızgarası kart boyutuna zaten
/// oturduğu için bu sabit orada kullanılmaz.
const FilterQuality kullaniciGorselKalitesi = FilterQuality.high;

/// TMDB görsel CDN'inin adres ön eki. Katalog görselleri (poster, arka plan,
/// kişi fotoğrafı, firma logosu) yalnızca bu ön ekten gelir — `api.dart`
/// içindeki `posterUrl()` bunu üretir.
const String tmdbGorselOnEki = 'https://image.tmdb.org/';

/// "WebP alabilirim" diyen SABİT başlık kümesi.
///
/// Değer ölçümde kullanılan başlığın BİREBİR aynısıdır (bkz. dosya başlığı):
/// `image/webp` listede olduğu sürece CDN WebP üretiyor, `*/*` ise WebP
/// üretemediği durumlarda (ör. PNG şeffaflığı) özgün biçime dönmesine izin
/// verir — yani hiçbir görsel "kabul edilmedi" diye boş kalmaz.
const Map<String, String> webpKabulBasliklari = {'Accept': 'image/webp,*/*'};

/// [url] için gönderilecek görsel istek başlıkları; pazarlığın anlamı yoksa
/// `null` (bugünkü davranışın birebir aynısı).
///
/// Kararı TEK YERDE veriyor olmamız bilinçli: aynı görüntüleyici hem TMDB
/// arka planını hem kendi sunucumuzdaki yorum fotoğrafını çiziyor
/// (`medya_goster.dart`), dolayısıyla "bu çağrı noktası TMDB mi" sorusu
/// DERLEME ZAMANINDA cevaplanamaz. Adres ön ekiyle karşılaştırma, alan adının
/// benzerine (`image.tmdb.org.kotu.example`) kanmaz.
Map<String, String>? gorselBasliklari(String? url) =>
    (url != null && url.startsWith(tmdbGorselOnEki))
    ? webpKabulBasliklari
    : null;
