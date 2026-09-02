// AKIŞ VİDEOSU KAPAK KATMANI (3 Eyl 2026)
//
// Şikâyet: "akışta gezerken videolarda siyah duruyor, oraya kaydırınca
// oynuyor". Oynatıcı kurulu ama hiç oynamamış kart, videonun ilk karesini
// (çoğu klipte siyah) ya da hiçbir şey göstermiyordu. Kilitlenen davranış:
//   * Oynatıcı HENÜZ KURULMADAN kapak (`<video>.jpg`) çizilir.
//   * Kuruldu, duraklatılmış, konum 0 → kapak ÜSTTE kalır.
//   * Konum ilerlemişse (Reels'ten dönüş, seekTo) kapak KALKAR: kullanıcı
//     kaldığı gerçek kareyi görmeli.
//   * Kurulum hata verirse kapak DEĞİL "kamera kapalı" simgesi (eski davranış).
//
// Gerçek çözücü yok: VideoPlayerPlatform sahte; olaylar elle akıtılır.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/video_konum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Olayları testin akıttığı sahte oynatıcı platformu.
class _SahtePlatform extends VideoPlayerPlatform {
  final olaylar = StreamController<VideoEvent>.broadcast();
  bool kurulumHatasi = false;
  Duration konum = Duration.zero;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    if (kurulumHatasi) throw StateError('kodek yok');
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => olaylar.stream;

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    konum = position;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => konum;

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool prevents,
  ) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.black);

  @override
  Widget buildView(int playerId) => const ColoredBox(color: Colors.black);

  void hazir() => olaylar.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 20),
      size: const Size(1080, 1920),
    ),
  );
}

const _url = 'https://ornek/medya/a.mp4';

Finder _kapak() => find.byWidgetPredicate(
  (w) => w is CachedNetworkImage && w.imageUrl == '$_url.jpg',
);

/// [gorunur] false: kart ekranın ALTINDA, yalnız üst 100 px'i görünür
/// (oran < 0,55) → akış onu oynatmaya SEÇMEZ; tam da şikâyetteki "henüz
/// kaydırılmamış" kart. true: kart merkezde, oynatılır.
Widget _agac({required bool gorunur}) => MaterialApp(
  theme: diziTema(acik: false),
  home: Scaffold(
    body: SizedBox(
      height: 600,
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: gorunur ? 0 : 500),
            const SizedBox(
              width: 360,
              height: 640,
              child: AkisVideo(url: _url),
            ),
          ],
        ),
      ),
    ),
  ),
);

Future<_SahtePlatform> _kur(
  WidgetTester tester, {
  bool gorunur = false,
  bool kurulumHatasi = false,
}) async {
  final p = _SahtePlatform()..kurulumHatasi = kurulumHatasi;
  VideoPlayerPlatform.instance = p;
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  await tester.pumpWidget(_agac(gorunur: gorunur));
  await tester.pump();
  return p;
}

void main() {
  setUp(VideoKonumDefteri.temizle);

  testWidgets('kurulmadan önce kapak (<video>.jpg) çizilir', (tester) async {
    await _kur(tester);
    expect(_kapak(), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
  });

  testWidgets('kurulu + oynatılmamış (ekran dışı) → kapak ÜSTTE kalır', (
    tester,
  ) async {
    final p = await _kur(tester);
    p.hazir();
    await tester.pump();
    await tester.pump();
    // Oynatıcı gerçekten kuruldu (sahte görünüm çizildi)…
    expect(find.byType(ColoredBox), findsWidgets);
    // …ama siyah ilk kare yerine kapak görünür.
    expect(_kapak(), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.videocam_off_outlined), findsNothing);
  });

  testWidgets('ekran ortasındaki kart OYNAR ve kapak kalkar', (tester) async {
    final p = await _kur(tester, gorunur: true);
    p.hazir();
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
    expect(_kapak(), findsNothing);
  });

  testWidgets('konum ilerlemişse (Reels\'ten dönüş) kapak KALKAR', (
    tester,
  ) async {
    // Defterde kayıt var: kurulunca oraya sarılır → konum > 0.
    VideoKonumDefteri.yaz(
      _url,
      const Duration(seconds: 7),
      const Duration(seconds: 20),
    );
    final p = await _kur(tester);
    p.hazir();
    await tester.pump();
    await tester.pump();
    expect(p.konum, const Duration(seconds: 7), reason: 'deftere sarılmadı');
    expect(_kapak(), findsNothing);
    // Duraklatılmış: oynat simgesi durur, kalınan kare görünür.
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
  });

  testWidgets('kurulum hatası: kapak değil "kamera kapalı" simgesi', (
    tester,
  ) async {
    await _kur(tester, kurulumHatasi: true);
    await tester.pump();
    expect(find.byIcon(Icons.videocam_off_outlined), findsOneWidget);
    expect(_kapak(), findsNothing);
  });
}
