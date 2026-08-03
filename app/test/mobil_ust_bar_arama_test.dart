import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/arama_cubugu.dart';
import 'package:dizijpg/ekranlar/kesfet.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 3 Ağu isteği (birebir):
///   1) "ana sayfadaki arama çubuğu mobilde hâlâ aynı yerde, neden versiyon ve
///      kare görünümün ortasında değil"
///   2) "tıklanınca genişleyip o ekranı komple kaplamalı"
///
/// Yani masaüstünde yapılanın (arama en üstte) MOBİL karşılığı: kapalı kutu üst
/// bar satırında, marka bloğu (logo + sürüm) ile eylem ikonlarının (Gözat =
/// "kare görünüm", Mesajlar) TAM ARASINDA; dokununca TAM EKRAN arama açılıyor.
///
/// "Var mı" YETMEZ: aşağıdaki testler `tester.getRect` ile GERÇEK konum ve
/// ölçü iddia eder.

const double _darG = 360, _darY = 800;

void _ekran(WidgetTester tester, double genislik, double yukseklik) {
  tester.view.physicalSize = Size(genislik, yukseklik);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Raflar boş döner (düzen ölçümü için içerik gerekmez); arama sorgusu
/// [aramaSonuclari] ile beslenir.
http.Client _sahteIstemci({
  List<Map<String, dynamic>> aramaSonuclari = const [],
  bool aramaHata = false,
}) => MockClient((istek) async {
  final yol = istek.url.path;
  if (yol.startsWith('/api/ara')) {
    if (aramaHata) return http.Response('bozuk', 500);
    return http.Response(
      jsonEncode({'results': aramaSonuclari}),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
  if (yol.startsWith('/api/kullanici-ara')) {
    return http.Response(
      jsonEncode({'kullanicilar': <dynamic>[]}),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
  return http.Response(
    jsonEncode({'results': <dynamic>[], 'oneriler': <dynamic>[]}),
    200,
    headers: {'content-type': 'application/json'},
  );
});

Map<String, dynamic> _dizi(String ad) => {
  'id': 42,
  'media_type': 'tv',
  'name': ad,
  'poster_path': '/p.jpg',
  'first_air_date': '2019-01-01',
};

/// Ana Sayfa TEK BAŞINA (yönlendirme olmadan) — düzen/ölçü testleri için.
Widget _anaSayfa() =>
    MaterialApp(theme: diziTema(acik: false), home: const KesfetEkrani());

/// Ana Sayfa GERÇEK yönlendiriciyle — tam ekran arama kök rotası ve geri
/// tuşu ancak burada gerçekçi ölçülür.
Widget _yonlendirmeli() {
  final r = GoRouter(
    initialLocation: '/kesfet',
    routes: [
      GoRoute(path: '/kesfet', builder: (_, _) => const KesfetEkrani()),
      GoRoute(
        path: tamAramaYolu,
        pageBuilder: (_, s) => CustomTransitionPage(
          key: s.pageKey,
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 160),
          transitionsBuilder: (_, a, _, c) =>
              FadeTransition(opacity: a, child: c),
          child: const TamEkranAramaSayfasi(),
        ),
      ),
    ],
  );
  addTearDown(r.dispose);
  return MaterialApp.router(theme: diziTema(acik: false), routerConfig: r);
}

Future<void> _kur(WidgetTester tester, Widget agac) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(agac);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Marka bloğunun SAĞ kenarı = sürüm metninin sağ kenarı.
double _markaSagi(WidgetTester tester) =>
    tester.getRect(find.textContaining('v${Api.surum.split('+').first}')).right;

/// İlk eylem ikonunun (Gözat = "kare görünüm") SOL kenarı.
double _gozatSolu(WidgetTester tester) =>
    tester.getRect(find.byIcon(Icons.grid_view_outlined)).left;

void main() {
  setUp(() => Api.istemci = _sahteIstemci());

  group('1) kapalı kutu üst BAR SATIRINDA, marka ile eylemlerin ARASINDA', () {
    testWidgets('360 dp: kutu sürümün SAĞINDA, Gözat ikonunun SOLUNDA', (
      tester,
    ) async {
      _ekran(tester, _darG, _darY);
      await _kur(tester, _anaSayfa());

      final appBar = tester.getRect(find.byType(AppBar));
      final kutu = tester.getRect(find.byKey(const Key('arama-ac')));
      final markaSag = _markaSagi(tester);
      final gozatSol = _gozatSolu(tester);

      // ARADA: sol kenarı marka bloğunun sağından büyük, sağ kenarı ilk
      // eylem ikonunun solundan küçük.
      expect(
        kutu.left,
        greaterThan(markaSag),
        reason: 'kutu (${kutu.left}) sürüm metninin ($markaSag) SAĞINDA olmalı',
      );
      expect(
        kutu.right,
        lessThanOrEqualTo(gozatSol),
        reason:
            'kutu (${kutu.right}) Gözat ikonunun ($gozatSol) SOLUNDA olmalı',
      );
      // ÜST BAR SATIRINDA: kutu tamamen AppBar'ın içinde (altında değil).
      expect(appBar.height, 56);
      expect(kutu.top, greaterThanOrEqualTo(appBar.top));
      expect(
        kutu.bottom,
        lessThanOrEqualTo(appBar.bottom),
        reason: 'kutu AppBar satırının içinde kalmalı (alt=${kutu.bottom})',
      );
      // Kullanılabilir genişlik: büyüteç + ipucu rahat sığar.
      expect(
        kutu.width,
        greaterThan(100),
        reason: 'kapalı kutu okunabilir kalmalı (genişlik=${kutu.width})',
      );
      // Dokunma hedefi (ui-ux-pro-max "Touch Target Size", asgari 44).
      expect(kutu.height, AramaAcmaKutusu.dokunmaYuksekligi);
      expect(kutu.height, greaterThanOrEqualTo(44));
    });

    testWidgets('360 dp: TAŞMA YOK ve ipucu metni kırpılmıyor', (tester) async {
      _ekran(tester, _darG, _darY);
      await _kur(tester, _anaSayfa());

      expect(tester.takeException(), isNull);

      // İpucu metni üç noktaya düşmemeli: çizilen genişlik, metnin doğal
      // genişliğine eşit (kırpılsaydı daha dar çizilirdi).
      final ipucuMetni = find.descendant(
        of: find.byKey(const Key('arama-ac')),
        matching: find.text('Arama'),
      );
      expect(ipucuMetni, findsOneWidget);
      final ipucu = tester.renderObject<RenderParagraph>(
        find.descendant(of: ipucuMetni, matching: find.byType(RichText)),
      );
      expect(ipucu.didExceedMaxLines, isFalse);
      expect(
        ipucu.size.width,
        greaterThanOrEqualTo(ipucu.getMinIntrinsicWidth(double.infinity)),
        reason: 'ipucu metni kırpılmamalı',
      );
    });

    testWidgets('sürüm metni DURUYOR (kullanıcının referansı), BETA gizli', (
      tester,
    ) async {
      _ekran(tester, _darG, _darY);
      await _kur(tester, _anaSayfa());

      final surum = 'v${Api.surum.split('+').first}';
      expect(find.text(surum), findsOneWidget);
      // Rozet dar ekranda yer açmak için gizli; beta bilgisi sürümün
      // ipucunda/erişilebilirlik etiketinde erişilebilir kalıyor.
      expect(find.text('BETA'), findsNothing);
      expect(find.byTooltip('BETA $surum'), findsOneWidget);
    });

    testWidgets('430 dp telefonda da düzen aynı (kutu daha da geniş)', (
      tester,
    ) async {
      _ekran(tester, 430, 932);
      await _kur(tester, _anaSayfa());
      final kutu = tester.getRect(find.byKey(const Key('arama-ac')));
      expect(kutu.left, greaterThan(_markaSagi(tester)));
      expect(kutu.right, lessThanOrEqualTo(_gozatSolu(tester)));
      expect(kutu.width, greaterThan(100));
      expect(tester.takeException(), isNull);
    });
  });

  group('2) dokununca TAM EKRAN arama', () {
    testWidgets('kutuya dokununca açılan sayfa EKRANI KOMPLE KAPLIYOR', (
      tester,
    ) async {
      _ekran(tester, _darG, _darY);
      await _kur(tester, _yonlendirmeli());

      expect(find.byKey(const Key('tam-ekran-arama')), findsNothing);
      await tester.tap(find.byKey(const Key('arama-ac')));
      await tester.pumpAndSettle();

      final sayfa = tester.getRect(find.byKey(const Key('tam-ekran-arama')));
      expect(sayfa.size, const Size(_darG, _darY), reason: 'tam ekran');
      expect(sayfa.topLeft, Offset.zero);
      // Yazmaya hazır: kutu odakta (klavye açılır) ve Ana Sayfa üst barı gitti.
      final alan = tester.widget<TextField>(find.byType(TextField));
      expect(alan.autofocus, isTrue);
      expect(find.byIcon(Icons.grid_view_outlined), findsNothing);
      // Boş sorgu hâli: ne sonuç ne hata, yönlendirici ipucu var.
      expect(find.text('Dizi, film veya kişi ara...'), findsWidgets);
    });

    testWidgets('geri oku ile ESKİ HÂLE dönüyor', (tester) async {
      _ekran(tester, _darG, _darY);
      await _kur(tester, _yonlendirmeli());

      await tester.tap(find.byKey(const Key('arama-ac')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tam-ekran-arama')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tam-ekran-arama')), findsNothing);
      // Ana Sayfa üst barı geri geldi, kapalı kutu yine yerinde.
      expect(find.byKey(const Key('arama-ac')), findsOneWidget);
      expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);
    });

    testWidgets('SİSTEM GERİ TUŞU aramayı kapatır, sayfadan çıkarmaz', (
      tester,
    ) async {
      _ekran(tester, _darG, _darY);
      await _kur(tester, _yonlendirmeli());

      await tester.tap(find.byKey(const Key('arama-ac')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tam-ekran-arama')), findsOneWidget);

      // Android geri tuşu.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tam-ekran-arama')), findsNothing);
      expect(find.byKey(const Key('arama-ac')), findsOneWidget);
    });

    testWidgets('tam ekranda yazınca SONUÇLAR geliyor', (tester) async {
      Api.istemci = _sahteIstemci(aramaSonuclari: [_dizi('Breaking Bad')]);
      _ekran(tester, _darG, _darY);
      await _kur(tester, _yonlendirmeli());

      await tester.tap(find.byKey(const Key('arama-ac')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'breaking');
      await tester.pump(); // yükleniyor hâli (sorgu >= 2, istek gecikmede)
      await tester.pump(const Duration(milliseconds: 500)); // gecikme dolsun
      await tester.pump(const Duration(milliseconds: 100)); // yanıt işlensin

      expect(find.text('Breaking Bad'), findsOneWidget);
      expect(find.text('Dizi ve Filmler'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sonuç yok / hata hâlleri gösteriliyor', (tester) async {
      _ekran(tester, _darG, _darY);
      await _kur(tester, _yonlendirmeli());
      await tester.tap(find.byKey(const Key('arama-ac')));
      await tester.pumpAndSettle();

      // Boş sonuç kümesi → "Sonuç bulunamadı".
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Sonuç bulunamadı'), findsOneWidget);

      // Sunucu 500 → hata hâli + Tekrar Dene (sessiz başarısızlık yok).
      Api.istemci = _sahteIstemci(aramaHata: true);
      await tester.enterText(find.byType(TextField), 'yyyy');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Arama başarısız'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);
    });

    testWidgets('klavye açıkken sonuç listesi klavyenin ALTINDA kalmıyor', (
      tester,
    ) async {
      Api.istemci = _sahteIstemci(aramaSonuclari: [_dizi('Breaking Bad')]);
      _ekran(tester, _darG, _darY);
      await _kur(tester, _yonlendirmeli());
      await tester.tap(find.byKey(const Key('arama-ac')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'breaking');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      // 300 dp'lik klavye açıldı.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() => tester.view.resetViewInsets());
      await tester.pump();

      final liste = tester.getRect(find.byType(ListView));
      expect(
        liste.bottom,
        lessThanOrEqualTo(_darY - 300),
        reason: 'liste klavyenin üstünde kalmalı (alt=${liste.bottom})',
      );
      expect(find.text('Breaking Bad'), findsOneWidget);
    });
  });

  group('3) tam ekran arama rotası UYGULAMANIN yönlendiricisinde KAYITLI', () {
    test(
      'kök seviyede (kabuğun dışında) — alt çubuk görünmez, geri kapatır',
      () {
        final r = yonlendiriciOlustur(Oturum());
        addTearDown(r.dispose);
        final kokYollar = r.configuration.routes
            .whereType<GoRoute>()
            .map((y) => y.path)
            .toList();
        expect(
          kokYollar,
          contains(tamAramaYolu),
          reason: 'rota kabuğun İÇİNE konsaydı alt gezinme çubuğu kalırdı',
        );
      },
    );
  });

  group('4) MASAÜSTÜ REGRESYONU', () {
    testWidgets('1440 dp: AppBar YOK, arama en üstte ve BETA rozeti duruyor', (
      tester,
    ) async {
      _ekran(tester, 1440, 900);
      await _kur(tester, _anaSayfa());

      // Masaüstünde eski düzen: AppBar yok, kapalı kutu yok, satır-içi
      // TextField en üstte ve BETA rozeti görünür.
      expect(find.byType(AppBar), findsNothing);
      expect(find.byKey(const Key('arama-ac')), findsNothing);
      expect(find.text('BETA'), findsOneWidget);

      final kutu = tester.getRect(find.byType(TextField));
      expect(kutu.width, masaustuAramaGenisligi);
      expect(kutu.left, closeTo(1440 - kutu.right, 0.5));
      expect(kutu.top, lessThan(12));
      expect(tester.takeException(), isNull);
    });
  });
}
