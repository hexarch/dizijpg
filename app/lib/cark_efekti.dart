import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// İzlem çarkının ses ve titreşim efekti.
///
/// NEDEN SOYUT (aynı gerekçe `gorusme/arama_efekti.dart`ta da yazılı):
/// `audioplayers` ve `HapticFeedback` birer platform kanalıdır; testte
/// çağrılırsa ya patlar ya da sessizce MissingPluginException yutar. Arayüz
/// ayrılınca widget testi [SessizCarkEfekti] ile koşar, üretim
/// [CihazCarkEfekti] kullanır.
abstract class CarkEfekti {
  /// İbre bir dilim sınırını geçti — kısa "tık".
  void tik();

  /// Çark durdu — sonuç anı.
  void durdu();

  void kapat();
}

/// Testlerin ve sessiz ortamın kullandığı boş efekt. Kaç tık çalındığını
/// SAYAR: "ses çıktı mı" testte ancak böyle ölçülebilir.
class SessizCarkEfekti implements CarkEfekti {
  int tikSayisi = 0;
  int durduSayisi = 0;

  @override
  void tik() => tikSayisi++;

  @override
  void durdu() => durduSayisi++;

  @override
  void kapat() {}
}

/// Gerçek efekt: `assets/sesler/cark_tik.wav` + haptik.
///
/// TEK OYNATICI, `stop()`+`resume()` DEĞİL `seek(0)`+`resume()`: tıklar
/// hızlı dönerken 30 ms aralıkla gelebiliyor; her seferinde yeni oynatıcı
/// kurmak Android'de ses kuyruğunu tıkıyordu (`arama_efekti` aynı dersi
/// zil için almıştı). `ReleaseMode.stop` ile kaynak açık kalır.
///
/// SES YOKSA SESSİZ KALIR, PATLAMAZ: cihazda ses kanalı kurulamazsa
/// (emülatör, sessiz mod, eksik eklenti) tıklar sessizce düşer; haptik
/// bağımsız çalışmaya devam eder.
class CihazCarkEfekti implements CarkEfekti {
  final AudioPlayer _oynatici = AudioPlayer();
  bool _hazir = false;
  bool _kapandi = false;

  CihazCarkEfekti() {
    _hazirla();
  }

  Future<void> _hazirla() async {
    try {
      await _oynatici.setReleaseMode(ReleaseMode.stop);
      await _oynatici.setSource(AssetSource('sesler/cark_tik.wav'));
      // Çark sesi bildirim değil arayüz sesi: zil/alarm ses kanalını değil
      // medya kanalını kullanır ve sessiz moda saygı duyar.
      await _oynatici.setVolume(0.55);
      _hazir = !_kapandi;
    } catch (e) {
      // Sessiz düşüş bilinçli: ses çalışmıyor diye çark çalışmamazlık
      // etmemeli. Haptik yine devrede.
      debugPrint('cark_efekti: ses hazırlanamadı ($e)');
    }
  }

  @override
  void tik() {
    HapticFeedback.selectionClick();
    if (!_hazir || _kapandi) return;
    // `await` YOK: tık akışı animasyon karesinde çağrılıyor, beklemek
    // kareyi düşürürdü. Hata da yutulur — bkz. sınıf başlığı.
    _oynatici.seek(Duration.zero).then((_) => _oynatici.resume()).catchError((
      _,
    ) {});
  }

  @override
  void durdu() => HapticFeedback.mediumImpact();

  @override
  void kapat() {
    _kapandi = true;
    _hazir = false;
    _oynatici.dispose();
  }
}
