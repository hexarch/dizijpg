/// İZLEME ODASI — BAĞLANTI KAYNAĞI (saf, Flutter'sız, test edilebilir).
///
/// ===========================================================================
/// NEDEN BU DOSYA VAR
/// ===========================================================================
/// 7 Eyl 2026 kullanıcı isteği: *"bu birlikte izlemeye video upload yerine
/// kullanıcıya tarayıcı açabilir miyiz … youtube gibi tüm platformların url'ini
/// destekleyecek şekilde yapsak ve altına desteklenen siteler yazsak"*.
///
/// Yükleme DURUYOR; bu ikinci bir kaynak. Kullanıcı bir adres yapıştırır,
/// kimse 5 GB yüklemez, sunucu tek bayt taşımaz.
///
/// ===========================================================================
/// LİSTE NEDEN KISA — 7 Eyl 2026'da ÖLÇÜLDÜ, tahmin edilmedi
/// ===========================================================================
/// Senkron için oynatıcıyı KONTROL edebilmek şart (oynat/duraklat/sar).
/// Yalnız gömebildiğimiz ama kontrol edemediğimiz bir platform, sahip 10 sn
/// sardığında izleyicide HİÇBİR ŞEY yapmaz — yani odanın tek varlık sebebi
/// olan senkronu sessizce bozar. Bu yüzden "gömülüyor" yetmez, "cevap veriyor"
/// aranır.
///
/// Yerel bir sayfaya iframe'ler kurulup her platforma komut yollandı:
///
/// | Platform    | Ölçüm                                                    |
/// |-------------|----------------------------------------------------------|
/// | YouTube     | IFrame API — `seekTo`/`playVideo` çalışıyor (zaten kodda) |
/// | Vimeo       | `getDuration` → 62, `setCurrentTime` onaylandı            |
/// | Dailymotion | yeni `geo` oynatıcı YALNIZ `pes_listen_eid` yayıyor;      |
/// |             | play/command/func biçimlerinin hiçbirine yanıt YOK.       |
/// |             | Kontrol, hesap gerektiren SDK + player id istiyor.        |
/// | OK.ru       | `{"event":"inited"}` yayıyor, 8 komut biçimine (belgelenen |
/// |             | `{call:{func}}` dahil, `?api=1` ve `listening` el         |
/// |             | sıkışmasıyla) SIFIR yanıt. Protokol minified paketlerde.  |
/// | VK          | Dış gömme `hash` parametresi istiyor — kullanıcının       |
/// |             | yapıştırdığı `vk.com/video-1_2` adresinden ÜRETİLEMİYOR.  |
///
/// Üçü de bu yüzden listede YOK. (Dailymotion ve OK.ru ileride YALNIZ mobilde
/// mümkün: WebView'de sayfanın kendi `<video>` öğesine erişebiliyoruz. Ama o
/// zaman "web'den giren senkron olamaz" gibi platforma bağlı bir liste doğar;
/// ayrı bir turun konusu.)
///
/// Sunucudaki eşi: `backend/oda_baglanti.js`. **İkisi birlikte değişir** —
/// istemcinin ürettiği adrese asla güvenilmez, sunucu aynı çözümlemeyi
/// bağımsız yapar ve kaydettiği şey KENDİ sonucudur.
library;

/// Desteklenen kaynak türü.
enum OdaSaglayici {
  youtube,
  vimeo,

  /// Doğrudan video dosyası adresi (`.mp4` / `.webm` / `.m3u8`).
  /// Yüklenen videoyla AYNI oynatıcıyı kullanır — yeni oynatıcı kodu yok.
  dosya,
}

/// Çözümlenmiş bir bağlantı.
class OdaBaglanti {
  final OdaSaglayici saglayici;

  /// YouTube video id'si · Vimeo sayısal id · dosyada tam adres.
  final String kimlik;

  /// Vimeo'nun "gizli bağlantı" (unlisted) anahtarı — `player.vimeo.com`
  /// gömmesi bu olmadan 403 verir. Yalnız Vimeo'da dolu olur.
  final String? gizliAnahtar;

  /// Kullanıcının yapıştırdığı adresin normalleştirilmiş hâli. Odada
  /// "kaynak" satırında gösterilir ve dışarı açma düğmesi bunu kullanır.
  final String url;

  const OdaBaglanti({
    required this.saglayici,
    required this.kimlik,
    required this.url,
    this.gizliAnahtar,
  });

  /// Kendi oynatıcımızla mı oynayacak (yüklenen video yolu)?
  bool get dosyaMi => saglayici == OdaSaglayici.dosya;

  /// Gömme yüzeyi mi gerekiyor (iframe/WebView)?
  bool get gommeMi => !dosyaMi;

  /// HLS akışı: web'de yalnız Safari oynatır (Chrome/Firefox `<video>` ile
  /// m3u8 çözemez, hls.js gerekir). Kullanıcıya SEBEBİ söylenebilsin diye
  /// ayrı bir soru olarak duruyor.
  bool get hlsMi => dosyaMi && _uzanti(url) == 'm3u8';

  String get saglayiciAdi => switch (saglayici) {
    OdaSaglayici.youtube => 'YouTube',
    OdaSaglayici.vimeo => 'Vimeo',
    OdaSaglayici.dosya => 'Video',
  };

  /// Sunucuya/istemciye tek satırda taşınan biçim.
  Map<String, dynamic> json() => {
    'saglayici': saglayici.name,
    'kimlik': kimlik,
    'url': url,
    if (gizliAnahtar != null) 'gizli': gizliAnahtar,
  };

  static OdaBaglanti? jsonCoz(Map<String, dynamic>? d) {
    if (d == null) return null;
    final ad = d['saglayici'] as String?;
    final kimlik = d['kimlik'] as String?;
    if (ad == null || kimlik == null || kimlik.isEmpty) return null;
    final s = switch (ad) {
      'youtube' => OdaSaglayici.youtube,
      'vimeo' => OdaSaglayici.vimeo,
      'dosya' => OdaSaglayici.dosya,
      _ => null,
    };
    if (s == null) return null;
    return OdaBaglanti(
      saglayici: s,
      kimlik: kimlik,
      url: (d['url'] as String?) ?? kimlik,
      gizliAnahtar: d['gizli'] as String?,
    );
  }
}

/// Doğrudan oynatılabilir dosya uzantıları.
///
/// `.mkv` ve `.avi` BİLEREK yok: tarayıcı da telefon da onları `<video>` ile
/// açamaz. Yüklenen dosyada sunucu ffmpeg'le kabı çeviriyor (bkz.
/// `migrasyon-2026-09-04b.sql`); bağlantıda öyle bir şansımız yok — dosya
/// bizde değil. Kabul edip sonra "oynatılamadı" demek, en baştan
/// "desteklenmiyor" demekten daha kötü bir deneyim.
const Set<String> odaDosyaUzantilari = {'mp4', 'webm', 'm3u8', 'mov'};

/// "Desteklenen siteler" satırı — kullanıcı kutunun ALTINDA bunu okur.
/// Tek yerden gelir ki liste büyüdüğünde metin de kendiliğinden büyüsün.
const List<String> odaDesteklenenPlatformlar = ['YouTube', 'Vimeo'];

/// Bir adresi çözer; desteklenmiyorsa null döner.
///
/// **Şema zorunlu ve HTTPS**: `http://` bir adres sayfamızda karışık içerik
/// (mixed content) olur ve tarayıcı sessizce engeller — kullanıcı "video
/// açılmıyor" görür, sebebini asla bulamaz. Baştan reddetmek dürüst.
OdaBaglanti? odaBaglantiCoz(String ham) {
  final metin = ham.trim();
  if (metin.isEmpty) return null;
  // Kullanıcı çoğu zaman şemasız yapıştırır ("youtu.be/..."): şemasızı
  // reddetmek yerine https varsayıyoruz. `http://` AÇIKÇA yazıldıysa
  // reddedilir — sessiz karışık içerik hatasından iyi.
  final tam = metin.contains('://') ? metin : 'https://$metin';
  final u = Uri.tryParse(tam);
  if (u == null || u.host.isEmpty) return null;
  if (u.scheme.toLowerCase() != 'https') return null;

  final host = u.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  final yol = u.pathSegments.where((s) => s.isNotEmpty).toList();

  // --- YouTube ---------------------------------------------------------
  if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
    final id = _youtubeId(yol.isNotEmpty ? yol.first : '');
    if (id != null) {
      return OdaBaglanti(
        saglayici: OdaSaglayici.youtube,
        kimlik: id,
        url: 'https://youtu.be/$id',
      );
    }
    return null;
  }
  if (host == 'youtube.com' ||
      host == 'm.youtube.com' ||
      host == 'music.youtube.com' ||
      host == 'youtube-nocookie.com' ||
      host.endsWith('.youtube.com') ||
      host.endsWith('.youtube-nocookie.com')) {
    // /watch?v=ID · /embed/ID · /shorts/ID · /live/ID · /v/ID
    final q = _youtubeId(u.queryParameters['v'] ?? '');
    if (q != null) {
      return OdaBaglanti(
        saglayici: OdaSaglayici.youtube,
        kimlik: q,
        url: 'https://www.youtube.com/watch?v=$q',
      );
    }
    if (yol.length >= 2 &&
        const {'embed', 'shorts', 'live', 'v'}.contains(yol.first)) {
      final id = _youtubeId(yol[1]);
      if (id != null) {
        return OdaBaglanti(
          saglayici: OdaSaglayici.youtube,
          kimlik: id,
          url: 'https://www.youtube.com/watch?v=$id',
        );
      }
    }
    return null;
  }

  // --- Vimeo -----------------------------------------------------------
  if (host == 'vimeo.com' ||
      host == 'player.vimeo.com' ||
      host.endsWith('.vimeo.com')) {
    // player.vimeo.com/video/ID?h=HASH · vimeo.com/ID/HASH ·
    // vimeo.com/channels/x/ID · vimeo.com/groups/x/videos/ID
    final sayilar = yol.where((s) => RegExp(r'^\d{6,}$').hasMatch(s)).toList();
    if (sayilar.isNotEmpty) {
      final id = sayilar.last;
      // Gizli bağlantı anahtarı: id'den SONRA gelen onaltılık parça ya da
      // `h=` sorgusu. Yoksa null — herkese açık video demektir.
      final sira = yol.indexOf(id);
      String? gizli = u.queryParameters['h'];
      if (gizli == null &&
          sira >= 0 &&
          sira + 1 < yol.length &&
          RegExp(r'^[0-9a-f]{6,}$').hasMatch(yol[sira + 1])) {
        gizli = yol[sira + 1];
      }
      return OdaBaglanti(
        saglayici: OdaSaglayici.vimeo,
        kimlik: id,
        gizliAnahtar: gizli,
        url: gizli == null
            ? 'https://vimeo.com/$id'
            : 'https://vimeo.com/$id/$gizli',
      );
    }
    return null;
  }

  // --- Doğrudan dosya --------------------------------------------------
  final uz = _uzanti(tam);
  if (uz != null && odaDosyaUzantilari.contains(uz)) {
    // Sorgu dizesi KORUNUR: imzalı CDN adreslerinde (`?token=…`) atılırsa
    // adres 403 olur.
    return OdaBaglanti(saglayici: OdaSaglayici.dosya, kimlik: tam, url: tam);
  }
  return null;
}

/// 11 karakterlik YouTube kimliği; değilse null.
String? _youtubeId(String ham) {
  final id = ham.trim();
  return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) ? id : null;
}

/// Yoldaki son uzantı (sorgu ve çapa atılarak), küçük harf.
String? _uzanti(String url) {
  final u = Uri.tryParse(url);
  final yol = u?.path ?? url;
  final nokta = yol.lastIndexOf('.');
  if (nokta < 0 || nokta == yol.length - 1) return null;
  final uz = yol.substring(nokta + 1).toLowerCase();
  return RegExp(r'^[a-z0-9]{2,5}$').hasMatch(uz) ? uz : null;
}

/// Gömme yüzeyinin yükleyeceği adres.
///
/// [otomatik] SESSİZ autoplay değildir: odaya giren kişi zaten "katıl"a
/// dokunmuştur, yani jest vardır. Yine de tarayıcı politikası gereği
/// başlangıçta sessiz açılır ve sesi kullanıcı açar (bkz. `oda_gomme_*`).
String odaGommeUrl(
  OdaBaglanti b, {
  String? dil,
  bool otomatik = false,
  int baslangicSn = 0,
}) {
  switch (b.saglayici) {
    case OdaSaglayici.youtube:
      // `enablejsapi=1` + `controls=0`: YouTube kromu gizli, bizim çubuk
      // sürüyor. `origin` YouTube'un postMessage'ı kabul etmesi için şart.
      final q = StringBuffer(
        'https://www.youtube.com/embed/${b.kimlik}'
        '?rel=0&modestbranding=1&playsinline=1'
        '&controls=0&fs=0&iv_load_policy=3&disablekb=1'
        '&cc_load_policy=0&enablejsapi=1'
        '&origin=https://dizijpg.com'
        '&widget_referrer=https://dizijpg.com',
      );
      // `mute=1` OTOMATİK OYNATMANIN ÖN KOŞULU, süs değil (7 Eyl 2026'da
      // canlıda ölçüldü): sesli bir gömmede tarayıcı jest olmadan oynatmayı
      // engelliyor, YouTube `playerState: -1` (hiç başlamadı) ve
      // `currentTime: 0` bildiriyor, senkron düzelticisi de her saniye
      // ilerleyen bir hedefe boşuna sarıyordu (65,5 → 68,5 → 71,5 …).
      // Ses "Sesi aç" düğmesiyle geliyor; o dokunuş aynı zamanda jesti de
      // veriyor. Gerekçenin tamamı `OdaGommeDenetci` başlığında.
      if (otomatik) q.write('&autoplay=1&mute=1');
      if (baslangicSn > 0) q.write('&start=$baslangicSn');
      final hl = dil?.trim().toLowerCase() ?? '';
      if (RegExp(r'^[a-z]{2,3}$').hasMatch(hl)) q.write('&hl=$hl');
      return q.toString();
    case OdaSaglayici.vimeo:
      final q = StringBuffer('https://player.vimeo.com/video/${b.kimlik}?');
      if (b.gizliAnahtar != null) q.write('h=${b.gizliAnahtar}&');
      // `controls=0` Vimeo'da yalnız Plus hesaplarda çalışır; kromu
      // gizlemeye ÇALIŞMIYORUZ (denenip başarısız olan bir gizleme,
      // kullanıcının kendi çubuğuyla bizim çubuğun ÇAKIŞMASI demek olurdu).
      // Bunun yerine dokunmalar bizim katmanımızda yakalanıyor.
      q.write('badge=0&portrait=0&title=0&byline=0&dnt=1&playsinline=1');
      // YouTube ile aynı gerekçe: sessiz olmayan otomatik oynatma engellenir.
      if (otomatik) q.write('&autoplay=1&muted=1');
      if (baslangicSn > 0) q.write('#t=${baslangicSn}s');
      return q.toString();
    case OdaSaglayici.dosya:
      return b.url;
  }
}

/// Bu bağlantı BU platformda oynar mı; oynamıyorsa sebebi hangi anahtarla
/// anlatılır.
///
/// Yüklenen videodaki `uyumsuz` listesiyle aynı disiplin: kullanıcıya
/// "oynatılamıyor" demeden ÖNCE sebebini ve çıkış yolunu bilmemiz gerekiyor.
/// Boş string = sorun yok.
String odaBaglantiUyumsuzlugu(OdaBaglanti b, {required bool web}) {
  if (web && b.hlsMi) return 'HLS_WEB';
  return '';
}
