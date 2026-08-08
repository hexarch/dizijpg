import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// KURULUM kimliği — cihaz banı ve çoklu hesap sinyali için.
///
/// ===========================================================================
/// NE OKUNUYOR, NE OKUNMUYOR (bu bölümü kısaltma; söz verdiğimizden fazlasını
/// vaat etmemek bu dosyanın asıl işi)
/// ===========================================================================
/// OKUNMUYOR: IMEI, MAC adresi, seri numarası, Android ID, reklam kimliği —
///   HİÇBİRİ. Google Play "Kullanıcı Verileri" politikası kalıcı donanım
///   tanımlayıcılarını kalıcı kimlik olarak kullanmayı YASAKLIYOR; ayrıca
///   modern Android bunların çoğunu zaten vermiyor.
/// OKUNAN: bu uygulamanın KENDİ ürettiği 16 rastgele bayt. İlk açılışta
///   üretilir, [SharedPreferences] içinde saklanır ve her isteğe `X-Cihaz`
///   başlığıyla eklenir.
///
/// BU YÜZDEN CİHAZ BANI BİR GARANTİ DEĞİLDİR:
///   * uygulama silinip yeniden kurulursa kimlik DEĞİŞİR,
///   * "uygulama verilerini temizle" denirse DEĞİŞİR,
///   * web istemcisinde tarayıcı depolaması silinirse DEĞİŞİR,
///   * başka bir cihaz/emülatör kullanılırsa FARKLIDIR.
/// Yani ban kaçağını KESMEZ, ZORLAŞTIRIR. Kullanıcıya görünen hiçbir metinde
/// "bir daha asla hesap açamazsın" denmiyor — çünkü tutamayacağımız bir söz.
///
/// Kimlik hiçbir kişisel veri taşımaz: rastgeledir, geri çevrilemez, başka
/// uygulamalarla paylaşılmaz ve yalnız moderasyon için kullanılır.
class CihazKimlik {
  static const _anahtar = 'cihaz_kimlik';

  /// Bellekte tutulan kopya: her istekte diske gitmemek için.
  static String? _kimlik;

  /// Yalnız test: belleği ve üretilen kimliği sıfırla.
  static void sifirla() => _kimlik = null;

  /// Şu anki kimlik (yüklenmediyse null). İstek başlığı bunu okur.
  static String? get kimlik => _kimlik;

  /// Sunucunun beklediği biçim: 32 hane küçük harf onaltılık.
  /// (Backend `yasak.js/cihazKimlikGecerli` ile BİREBİR aynı kural.)
  static bool gecerli(String? k) =>
      k != null && RegExp(r'^[0-9a-f]{32}$').hasMatch(k);

  /// 16 rastgele bayt → 32 haneli onaltılık.
  ///
  /// `Random.secure()` bazı web/eski platformlarda fırlatabiliyor; kimlik
  /// güvenlik sırrı DEĞİL (yalnız bir etiket), bu yüzden düşme durumunda
  /// sıradan [Random] ile devam edilir — açılışı çökertmek anlamsız olurdu.
  static String uret() {
    Random rasgele;
    try {
      rasgele = Random.secure();
    } catch (_) {
      rasgele = Random(DateTime.now().microsecondsSinceEpoch);
    }
    final tampon = StringBuffer();
    for (var i = 0; i < 16; i++) {
      tampon.write(rasgele.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return tampon.toString();
  }

  /// Açılışta bir kez çağrılır: varsa okur, yoksa üretip saklar.
  ///
  /// Depolama hatası uygulamayı ÇÖKERTMEZ — kimlik yoksa istek başlığı hiç
  /// eklenmez ve sunucu bunu normal karşılar (web istemcisi de böyle çalışır).
  static Future<String?> yukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mevcut = prefs.getString(_anahtar);
      if (gecerli(mevcut)) {
        _kimlik = mevcut;
        return _kimlik;
      }
      final yeni = uret();
      await prefs.setString(_anahtar, yeni);
      _kimlik = yeni;
      return _kimlik;
    } catch (_) {
      return null;
    }
  }
}
