// REELS'TE BASILI TUTARAK 2x (10 Eyl 2026)
//
// İstek: "Reels ekranındayken ekranın sağ tarafına basılı tutunca video 2x
// oynamalı." Kilitlenen davranış:
//   * Sağ yarıya uzun basınca hız 2.0 olur, "2x" rozeti çıkar.
//   * Parmak kalkınca hız 1.0'a döner, rozet kalkar.
//   * Uzun basma TEK DOKUNUŞ sayılmaz → video durmaz (pause çağrısı yok).
//   * Sol yarıda uzun basma hiçbir şey yapmaz.
//   * Fotoğraf sayfasında uzun basma oynatıcıya dokunmaz.
//
// Gerçek çözücü yok: VideoPlayerPlatform sahte, olaylar elle akıtılır
// (akis_video_kapak_test.dart ile aynı düzen).
import 'dart:async';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/video_konum.dart';
import 'package:flutter/gestures.dart'
    show kDoubleTapTimeout, kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _SahtePlatform extends VideoPlayerPlatform {
  final olaylar = StreamController<VideoEvent>.broadcast();
  final hizlar = <double>[];
  int oynat = 0;
  int durdur = 0;
  int kurulan = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      ++kurulan;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => olaylar.stream;

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async => oynat++;

  @override
  Future<void> pause(int playerId) async => durdur++;

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async =>
      hizlar.add(speed);

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

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

Map<String, dynamic> _gonderi({required String medya}) => {
  'id': 1,
  'kullanici_adi': 'dizi.jpg.ai',
  'metin': 'Test gönderisi',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': [medya],
  'begeni': 0,
  'goruntulenme': 0,
  'spoiler': false,
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
};

Future<_SahtePlatform> _kur(
  WidgetTester tester, {
  String medya = '/medya/klip.mp4',
}) async {
  final p = _SahtePlatform();
  VideoPlayerPlatform.instance = p;
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: ReelsGorunumu(
          liste: [_gonderi(medya: medya)],
          icerikler: _icerikler,
          baslangic: 0,
        ),
      ),
    ),
  );
  await tester.pump();
  if (medya.endsWith('.mp4')) {
    p.hazir();
    await tester.pump();
    await tester.pump();
  }
  // Kurulumun kendi çağrıları sayılmaz: video_player `initialize` bir kez
  // pause, `play()` ise hızı 1.0'a yazar. Testler bundan SONRASINI ölçer.
  p.hizlar.clear();
  p.oynat = 0;
  p.durdur = 0;
  return p;
}

/// Dokunuş katmanının ortası — ekranın sağ/sol yarısında, eylem sütunundan
/// ve üst düğmelerden uzak bir nokta.
Offset _nokta(WidgetTester tester, {required bool sag}) {
  final r = tester.getRect(find.byType(ReelsGorunumu));
  return Offset(
    sag ? r.left + r.width * 0.7 : r.left + r.width * 0.3,
    r.center.dy,
  );
}

Finder get _rozet => find.byKey(const Key('reels-2x'));

void main() {
  setUp(VideoKonumDefteri.temizle);

  testWidgets('sağ yarıya basılı tutunca 2x, bırakınca 1x', (tester) async {
    final p = await _kur(tester);
    expect(_rozet, findsNothing);

    final g = await tester.startGesture(_nokta(tester, sag: true));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(p.hizlar, [2.0]);
    expect(_rozet, findsOneWidget);
    expect(find.text('2x'), findsOneWidget);

    await g.up();
    await tester.pump();
    expect(p.hizlar, [2.0, 1.0]);
    expect(_rozet, findsNothing);
    // Uzun basma tek dokunuş sayılmadı: video durmadı.
    expect(p.durdur, 0);
  });

  testWidgets('sol yarıda basılı tutma hiçbir şey yapmaz', (tester) async {
    final p = await _kur(tester);
    final g = await tester.startGesture(_nokta(tester, sag: false));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(p.hizlar, isEmpty);
    expect(_rozet, findsNothing);
    await g.up();
    await tester.pump();
    expect(p.hizlar, isEmpty);
    expect(p.durdur, 0);
  });

  testWidgets('duraklatılmış videoda basılı tutma oynatıp 2x yapar', (
    tester,
  ) async {
    final p = await _kur(tester);
    await tester.tap(find.byType(ReelsGorunumu)); // tek dokunuş → durur
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    expect(p.durdur, 1);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    final g = await tester.startGesture(_nokta(tester, sag: true));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(p.hizlar, [2.0]);
    expect(p.oynat, 1, reason: 'duraklatılmışsa tekrar oynatılır');
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    await g.up();
    await tester.pump();
    expect(p.hizlar, [2.0, 1.0]);
  });

  testWidgets('fotoğraf sayfasında basılı tutma oynatıcıya dokunmaz', (
    tester,
  ) async {
    final p = await _kur(tester, medya: '/medya/kare.jpg');
    expect(p.kurulan, 0);
    final g = await tester.startGesture(_nokta(tester, sag: true));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(p.hizlar, isEmpty);
    expect(_rozet, findsNothing);
    await g.up();
    await tester.pump();
  });
}
