import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Durum geçişlerinde çalınacak haptik (dokunsal) darbe türü.
///
/// NEDEN: iki gerçek telefonda yapılan testte "çalışmıyor" hissinin bir kaynağı
/// durum geçişlerinin SESSİZ ve HAREKETSİZ olmasıydı — "çalıyor → bağlandı"
/// hissedilmiyordu. Haptik, sesin duyulmadığı (sessiz mod, gürültülü ortam)
/// durumda geçişi bildiren tek kanaldır.
enum AramaHaptik {
  /// Giden arama karşıya ulaştı, çalmaya başladı.
  caliyor,

  /// Medya aktı; iki taraf konuşabiliyor.
  baglandi,

  /// Arama kapandı.
  kapandi,
}

/// Aramanın SES ve DOKUNSAL geri bildirimi — zil (ringback) + haptik.
///
/// NEDEN SOYUT: `audioplayers` ve `HapticFeedback` birer eklenti/platform
/// kanalıdır; `flutter test` VM'de koşar ve eklenti kanalı yoktur. `GorusmeSurucu`
/// ile aynı gerekçe: efekt kararlarının (zil ne zaman başlar/susar) doğru olması
/// gerekiyor ve bu ancak sahte bir efektle uçtan uca test edilebilir. Denetçi
/// varsayılan olarak [SessizEfekti] kullanır (testlerde ve efektsiz akışta
/// güvenli); ekranlar gerçek [CihazEfekti]'ni takar.
abstract class AramaEfekti {
  /// Zili (ringback) döngüde çalmaya başlatır. **İdempotent** — zaten çalıyorsa
  /// yeniden başlatmaz.
  Future<void> zilCal();

  /// Zili susturur. **İdempotent** — çalmıyorsa hiçbir şey yapmaz.
  /// Bağlanınca/kapanınca ÇAĞRILMASI ZORUNLU: susmayan bir zil, hiç olmayan bir
  /// zilden beterdir.
  Future<void> zilDurdur();

  /// Durum geçişinde kısa bir haptik darbe.
  Future<void> haptik(AramaHaptik tip);

  /// Kaynakları bırakır (oynatıcıyı kapatır). Arama ekranı kapanınca çağrılır.
  Future<void> bosalt();
}

/// Hiçbir şey yapmayan efekt — testlerin ve efekt istemeyen akışların
/// varsayılanı. `const` olduğu için denetçi kurucusunda bedava varsayılan.
class SessizEfekti implements AramaEfekti {
  const SessizEfekti();

  @override
  Future<void> zilCal() async {}

  @override
  Future<void> zilDurdur() async {}

  @override
  Future<void> haptik(AramaHaptik tip) async {}

  @override
  Future<void> bosalt() async {}
}

/// `audioplayers` + `HapticFeedback` tabanlı gerçek efekt.
///
/// Zil varlığı `assets/sesler/zil.wav` (450 Hz, 2 sn çal / 4 sn sus, mono 8 kHz).
/// `ReleaseMode.loop` ile döngüye alınınca "çal… (4 sn sessizlik) …çal" ritmi
/// çıkar — telefon çalıyormuş hissi. YENİ PAKET EKLENMEDİ: `audioplayers`
/// projede zaten sesli mesaj oynatımında (`ekranlar/ses.dart`) kullanılıyor.
class CihazEfekti implements AramaEfekti {
  CihazEfekti();

  final AudioPlayer _oynatici = AudioPlayer();
  bool _caliyor = false;
  bool _bosaltildi = false;

  @override
  Future<void> zilCal() async {
    if (_caliyor || _bosaltildi || kIsWeb) return;
    _caliyor = true;
    try {
      await _oynatici.setReleaseMode(ReleaseMode.loop);
      // Çağrı sesi ses akışı: sistem bunu bildirim değil arama sesi olarak
      // yönlendirir; sesli aramada AHİZE, görüntülüde HOPARLÖR kararı
      // sürücüdedir, zil onu ezmez.
      await _oynatici.play(AssetSource('sesler/zil.wav'), volume: 0.6);
    } catch (_) {
      // Zil çalınamazsa arama yine kurulmalı: sessiz kalır, akış bozulmaz.
      _caliyor = false;
    }
  }

  @override
  Future<void> zilDurdur() async {
    if (!_caliyor) return;
    _caliyor = false;
    try {
      await _oynatici.stop();
    } catch (_) {}
  }

  @override
  Future<void> haptik(AramaHaptik tip) async {
    if (kIsWeb) return;
    try {
      switch (tip) {
        case AramaHaptik.caliyor:
          await HapticFeedback.mediumImpact();
        case AramaHaptik.baglandi:
          await HapticFeedback.heavyImpact();
        case AramaHaptik.kapandi:
          await HapticFeedback.selectionClick();
      }
    } catch (_) {
      // Haptik desteklenmiyorsa (bazı cihaz/emülatör) sessizce geç.
    }
  }

  @override
  Future<void> bosalt() async {
    _bosaltildi = true;
    _caliyor = false;
    try {
      await _oynatici.stop();
      await _oynatici.dispose();
    } catch (_) {}
  }
}
