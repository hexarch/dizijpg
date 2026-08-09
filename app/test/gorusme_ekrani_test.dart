// ARAMA EKRANLARI — üç hâl, dokunma hedefleri, ÖLÇÜLMÜŞ kontrast.
//
// Sözleşme §14.5: "Üç hal zorunlu: çalıyor → bağlanıyor (spinner) → bağlandı"
// ve "Kilit ekranı: koyu zeminde Reddet kontrastı >=4.5:1 ÖLÇÜLMELİ".
// Kontrast burada gözle değil WCAG formülüyle HESAPLANIYOR — Material'ın
// hazır kırmızısı (#E53935) bu eşiği geçmiyordu (4,23:1).
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dizijpg/api.dart';
import 'package:dizijpg/gorusme/arama_servisi.dart';
import 'package:dizijpg/gorusme/gelen_arama_ekrani.dart';
import 'package:dizijpg/gorusme/gorusme_api.dart';
import 'package:dizijpg/gorusme/gorusme_denetci.dart';
import 'package:dizijpg/gorusme/gorusme_ekrani.dart';
import 'package:dizijpg/gorusme/gorusme_surucu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sahte_gorusme_surucu.dart';

// ---------------------------------------------------------------------------
// WCAG 2.1 kontrast hesabı
// ---------------------------------------------------------------------------
double _kanal(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _parlaklik(Color renk) =>
    0.2126 * _kanal(renk.r) + 0.7152 * _kanal(renk.g) + 0.0722 * _kanal(renk.b);

double kontrast(Color a, Color b) {
  final la = _parlaklik(a);
  final lb = _parlaklik(b);
  final yuksek = math.max(la, lb);
  final dusuk = math.min(la, lb);
  return (yuksek + 0.05) / (dusuk + 0.05);
}

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

BuzAyari _buz() => BuzAyari(
  sunucular: const [],
  gecerlilikSn: 43200,
  aramaAcik: true,
  goruntuluAcik: true,
  calmaSaniye: 45,
  alindi: DateTime.now(),
);

/// Ekranı gerçek bir yönlendirici içinde kurar (context.pop çalışsın).
Widget _rota(Widget cocuk) => MaterialApp.router(
  routerConfig: GoRouter(
    initialLocation: '/baslangic',
    routes: [
      GoRoute(
        path: '/baslangic',
        builder: (_, _) => const Scaffold(body: Text('baslangic')),
        routes: [GoRoute(path: 'arama', builder: (_, _) => cocuk)],
      ),
    ],
  ),
);

GorusmeDenetci _denetci(SahteSurucu s, {String tur = 'ses'}) =>
    GorusmeDenetci(surucu: s, karsiTaraf: 'alcelik', tur: tur, gelen: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'token': 't'});
    AramaServisi.webMi = false;
    AramaServisi.ayariKur(_buz());
    Api.istemci = MockClient(
      (istek) async => istek.url.path.endsWith('/arama/baslat')
          ? _json({
              'arama_id': 'a1',
              'durum': 'caliyor',
              'sona_erme': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 45,
              'tur': 'ses',
            })
          : _json({'durum': 'caliyor', 'sdp': null, 'adaylar': <dynamic>[]}),
    );
  });

  tearDown(() => AramaServisi.ayariKur(null));

  group('kontrast — ÖLÇÜM (sözleşme §14.5)', () {
    test('Reddet/Kapat kırmızısı üstünde BEYAZ yazı >= 4.5:1', () {
      final o = kontrast(aramaKirmizi, Colors.white);
      expect(
        o,
        greaterThanOrEqualTo(4.5),
        reason: 'ölçülen ${o.toStringAsFixed(2)}:1',
      );
    });

    test('Cevapla yeşili üstünde BEYAZ yazı >= 4.5:1', () {
      final o = kontrast(aramaYesil, Colors.white);
      expect(
        o,
        greaterThanOrEqualTo(4.5),
        reason: 'ölçülen ${o.toStringAsFixed(2)}:1',
      );
    });

    test('düğme dolgusu koyu zeminden ayrışır (grafik eşiği 3:1)', () {
      expect(kontrast(aramaKirmizi, aramaZemin), greaterThanOrEqualTo(3.0));
      expect(kontrast(aramaYesil, aramaZemin), greaterThanOrEqualTo(3.0));
    });

    test('koyu zeminde birincil metin (beyaz) >= 4.5:1', () {
      expect(kontrast(aramaZemin, Colors.white), greaterThanOrEqualTo(4.5));
    });

    test('REGRESYON: Material varsayılan kırmızısı eşiği GEÇMEZ', () {
      // Bu test, "neden özel renk?" sorusunun cevabını kodda tutuyor.
      expect(kontrast(const Color(0xFFE53935), Colors.white), lessThan(4.5));
    });
  });

  group('gelen arama ekranı', () {
    Future<void> kur(WidgetTester t, {String tur = 'ses'}) async {
      await t.pumpWidget(
        _rota(
          GelenAramaSayfasi(
            surucuUret: SahteSurucu.new,
            gelenGetir: () async => {
              'arama_id': 'x1',
              'tur': tur,
              'arayan': {'kullanici_adi': 'alcelik', 'avatar': null},
              'sdp': 'v=0\r\nteklif',
              'sona_erme': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 45,
            },
          ),
        ),
      );
      // GoRouter alt rotaya it
      final ctx = t.element(find.text('baslangic'));
      GoRouter.of(ctx).push('/baslangic/arama');
      await t.pumpAndSettle();
    }

    testWidgets('Cevapla ve Reddet düğmeleri METİN ETİKETLİ', (t) async {
      await kur(t);
      expect(find.byKey(const Key('arama-cevapla')), findsOneWidget);
      expect(find.byKey(const Key('arama-reddet')), findsOneWidget);
      // İkon-tek düğme yasak: etiket GÖRÜNÜR olmalı.
      expect(find.text('Cevapla'), findsOneWidget);
      expect(find.text('Reddet'), findsOneWidget);
    });

    testWidgets('dokunma hedefleri >= 44 dp', (t) async {
      await kur(t);
      for (final k in ['arama-cevapla', 'arama-reddet']) {
        final ink = find.descendant(
          of: find.byKey(Key(k)),
          matching: find.byType(InkWell),
        );
        final boyut = t.getSize(ink);
        expect(boyut.width, greaterThanOrEqualTo(44), reason: k);
        expect(boyut.height, greaterThanOrEqualTo(44), reason: k);
      }
    });

    testWidgets('arayanın adı ve arama türü görünür', (t) async {
      await kur(t, tur: 'goruntu');
      expect(find.text('@alcelik'), findsOneWidget);
      expect(find.text('Görüntülü arama'), findsOneWidget);
    });

    testWidgets('arama sona ermişse ekran kapanır, mesaj çıkar', (t) async {
      await t.pumpWidget(
        _rota(
          GelenAramaSayfasi(
            surucuUret: SahteSurucu.new,
            gelenGetir: () async => null,
          ),
        ),
      );
      final ctx = t.element(find.text('baslangic'));
      GoRouter.of(ctx).push('/baslangic/arama');
      await t.pumpAndSettle();
      expect(find.text('Arama sona erdi'), findsOneWidget);
      expect(find.byKey(const Key('arama-cevapla')), findsNothing);
    });
  });

  group('arama ekranı — ÜÇ HÂL', () {
    testWidgets('1) hazırlanırken spinner + "Bağlanıyor..."', (t) async {
      final s = SahteSurucu();
      final d = _denetci(s);
      // Akışı ASKIDA tut: ekran `hazirlaniyor` hâlinde kalsın.
      final askida = Completer<AramaHatasi?>();
      await t.pumpWidget(
        _rota(GorusmeEkrani(denetci: d, baslat: (_) => askida.future)),
      );
      final ctx = t.element(find.text('baslangic'));
      GoRouter.of(ctx).push('/baslangic/arama');
      await t.pump();
      await t.pump();

      expect(find.text('Bağlanıyor...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      askida.complete(null);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });

    testWidgets('2) çalarken "Çalıyor...", 3) bağlanınca süre sayacı', (
      t,
    ) async {
      final s = SahteSurucu();
      final d = _denetci(s);
      await t.pumpWidget(
        _rota(GorusmeEkrani(denetci: d, baslat: d.aramaBaslat)),
      );
      final ctx = t.element(find.text('baslangic'));
      GoRouter.of(ctx).push('/baslangic/arama');
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      await t.pump(const Duration(milliseconds: 50));

      expect(find.text('Çalıyor...'), findsOneWidget);
      expect(find.text('@alcelik'), findsOneWidget);

      s.hal(BaglantiHali.bagli);
      await t.pump(const Duration(milliseconds: 50));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('Çalıyor...'), findsNothing);

      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });

    testWidgets('SESLİ aramada kamera düğmeleri YOK', (t) async {
      final s = SahteSurucu();
      final d = _denetci(s);
      await t.pumpWidget(
        _rota(GorusmeEkrani(denetci: d, baslat: d.aramaBaslat)),
      );
      final ctx = t.element(find.text('baslangic'));
      GoRouter.of(ctx).push('/baslangic/arama');
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('arama-sessize')), findsOneWidget);
      expect(find.byKey(const Key('arama-hoparlor')), findsOneWidget);
      expect(find.byKey(const Key('arama-kapat')), findsOneWidget);
      expect(find.byKey(const Key('arama-kamera')), findsNothing);
      expect(find.byKey(const Key('arama-kamera-cevir')), findsNothing);

      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });

    testWidgets('GÖRÜNTÜLÜ aramada kamera düğmeleri VAR ve hepsi >=44 dp', (
      t,
    ) async {
      final s = SahteSurucu();
      final d = _denetci(s, tur: 'goruntu');
      await t.pumpWidget(
        _rota(GorusmeEkrani(denetci: d, baslat: d.aramaBaslat)),
      );
      final ctx = t.element(find.text('baslangic'));
      GoRouter.of(ctx).push('/baslangic/arama');
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));

      const anahtarlar = [
        'arama-sessize',
        'arama-hoparlor',
        'arama-kamera',
        'arama-kamera-cevir',
        'arama-kapat',
      ];
      for (final k in anahtarlar) {
        final ink = find.descendant(
          of: find.byKey(Key(k)),
          matching: find.byType(InkWell),
        );
        expect(ink, findsOneWidget, reason: k);
        final boyut = t.getSize(ink);
        expect(boyut.width, greaterThanOrEqualTo(44), reason: k);
        expect(boyut.height, greaterThanOrEqualTo(44), reason: k);
      }

      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });

    testWidgets('KAPAT düğmesi kırmızı ve etiketli', (t) async {
      final s = SahteSurucu();
      final d = _denetci(s);
      await t.pumpWidget(
        _rota(GorusmeEkrani(denetci: d, baslat: d.aramaBaslat)),
      );
      final ctx = t.element(find.text('baslangic'));
      GoRouter.of(ctx).push('/baslangic/arama');
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));

      expect(find.text('Kapat'), findsOneWidget);
      final mat = t.widget<Material>(
        find.descendant(
          of: find.byKey(const Key('arama-kapat')),
          matching: find.byType(Material),
        ),
      );
      expect(mat.color, aramaKirmizi);

      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });

    testWidgets('360 dp dar ekranda kontroller TAŞMAZ', (t) async {
      t.view.physicalSize = const Size(360 * 3, 640 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);

      final s = SahteSurucu();
      final d = _denetci(s, tur: 'goruntu');
      await t.pumpWidget(
        _rota(GorusmeEkrani(denetci: d, baslat: d.aramaBaslat)),
      );
      final ctx = t.element(find.text('baslangic'));
      GoRouter.of(ctx).push('/baslangic/arama');
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));

      expect(taskmaVar(t), isFalse);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
  });

  group('süre biçimi', () {
    test('dakika:saniye', () {
      expect(aramaSuresiMetni(Duration.zero), '0:00');
      expect(aramaSuresiMetni(const Duration(seconds: 9)), '0:09');
      expect(
        aramaSuresiMetni(const Duration(minutes: 12, seconds: 5)),
        '12:05',
      );
    });

    test('bir saati geçince saat:dakika:saniye', () {
      expect(
        aramaSuresiMetni(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });
  });

  group('4 saatlik sert üst sınır (sözleşme §13.2)', () {
    test(
      'sabit 4 saat',
      () => expect(azamiAramaSuresi, const Duration(hours: 4)),
    );

    test('uyarı penceresi bitişten önce açılır', () {
      expect(aramaSuresiUyarisi.inMinutes, greaterThan(0));
      expect(aramaSuresiUyarisi, lessThan(azamiAramaSuresi));
    });
  });
}

/// Çerçevede taşma hatası olup olmadığını söyler.
bool taskmaVar(WidgetTester t) => t.takeException() is FlutterError;
