import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// EKRAN GÖRÜNTÜSÜ OLAYLARI (15 Eyl 2026 isteği: "sohbette ss alınca
/// Instagram'daki gibi ekran görüntüsü alındı yazısı olsun").
///
/// Native taraf ekran görüntüsü alındığında gövdesiz bir olay yollar:
///   · Android 14+ → `Activity.registerScreenCaptureCallback`
///     (MainActivity.kt, `DETECT_SCREEN_CAPTURE` izni)
///   · iOS → `UIApplication.userDidTakeScreenshotNotification`
///     (AppDelegate.swift)
///
/// TESPİT EDİLEMEYEN YÜZEYLER SESSİZ KALIR, hata vermez: web (tarayıcı
/// böyle bir olay yayınlamaz), Android 13 ve altı. [destekli] false döner,
/// [akis] hiç olay taşımaz — çağıran taraf platform ayrımı yapmak zorunda
/// kalmasın diye akış yine de kurulur.
class EkranGoruntusu {
  EkranGoruntusu._();

  static const _kanal = EventChannel('dizijpg/ekran_goruntusu');

  /// Bu platformda tespit denenir mi? (Kanalın karşılığı olmayan yüzeyde
  /// dinlemeye kalkmak `MissingPluginException` üretir.)
  static bool get destekli =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Stream<void>? _akis;

  /// Ekran görüntüsü alındığında tetiklenir. Tek akış paylaşılır
  /// (`broadcast`): iki ekran aynı anda dinleyebilir, biri kapanınca
  /// diğerinin aboneliği düşmez.
  static Stream<void> get akis {
    // Test akışı varsa platform kapısı atlanır (widget testinde
    // `defaultTargetPlatform` android'dir ama kanalın karşılığı yoktur).
    final hazir = _akis;
    if (hazir != null) return hazir;
    if (!destekli) return const Stream<void>.empty();
    return _akis ??= _kanal
        .receiveBroadcastStream()
        .map<void>((_) {})
        // Kanal kurulmamışsa (eski derleme, beklenmedik platform) uygulama
        // çökmesin: akış sessizce boşalır.
        .handleError((_) {})
        .asBroadcastStream();
  }

  /// YALNIZ TEST: gerçek kanal yerine verilen akışı kullandırır.
  @visibleForTesting
  static void testAkisi(Stream<void>? akis) => _akis = akis;
}
