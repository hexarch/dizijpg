import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' show XFile;

/// Panodaki görsel/GIF/video — mobil sap. Sözleşme `pano_medya.dart`ta.
///
/// NATIVE TARAF DOSYAYA YAZAR, KANALDAN YOL GEÇER: baytı platform kanalından
/// geçirmek 20 MB'lık bir ekran görüntüsünde tüm kareyi bloklar (kanal ana
/// iş parçacığında kopyalar). Native kod önbellek dizinine yazıp yolu döner;
/// [XFile] onu tembel okur — seçiciden gelen dosyayla BİREBİR aynı nesne.
class PanoMedya {
  PanoMedya._();

  static const _kanal = MethodChannel('dizijpg/pano');

  /// Testler için: gerçek kanal yerine bunlar çağrılır (widget testinde
  /// kanalın karşılığı yoktur, `MissingPluginException` atar).
  @visibleForTesting
  static Future<bool> Function()? varMiSahte;

  /// Testler için: panodan dönecek dosyalar.
  @visibleForTesting
  static Future<List<XFile>> Function()? okuSahte;

  /// Yapıştır düğmesi çizilsin mi?
  ///
  /// MOBİLDE PANONUN İÇİNE BAKAR: pano boşken (ya da yalnız metin varken)
  /// düğme HİÇ çizilmez — basınca "panoda görsel yok" diyen bir düğme,
  /// çalışmayan bir düğmedir. Kanal yoksa (eski sürüm, masaüstü) sessizce
  /// false: özellik yokmuş gibi davranır, hata basmaz.
  static Future<bool> yapistirilabilir() async {
    final sahte = varMiSahte;
    if (sahte != null) return sahte();
    try {
      return await _kanal.invokeMethod<bool>('varMi') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Panodaki medyayı okur. Pano boşsa / okunamazsa **boş liste** — çağıran
  /// kullanıcıya tek cümleyle söyler (sessiz başarısızlık yok).
  static Future<List<XFile>> oku() async {
    final sahte = okuSahte;
    if (sahte != null) return sahte();
    try {
      final liste = await _kanal.invokeListMethod<Object?>('oku');
      if (liste == null) return const [];
      return [
        for (final ham in liste)
          if (ham is Map)
            XFile(
              ham['yol'] as String,
              mimeType: ham['tur'] as String?,
              name: ham['ad'] as String?,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Web'deki Ctrl+V dinleyicisinin mobil karşılığı YOK: panoya kopyalanan
  /// içerik kullanıcı düğmeye basınca okunur (iOS 16+ zaten izinsiz okumayı
  /// "Yapıştır?" diyaloğuyla karşılıyor — arka planda yoklamak her açılışta
  /// o diyaloğu çıkarırdı). Sökücü yine de döner: çağıran platform ayrımı
  /// yapmasın.
  static void Function() dinle(void Function(List<XFile>) geri) => () {};
}
