import 'package:dizijpg/ekranlar/fragman_kontrol.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fragman kromu: otomatik gizlenme, dokunuşla geri gelme, fare desteği,
/// duraklatınca sabit kalma ve ortak hata ekranı.
void main() {
  Widget kur({
    bool oynuyor = true,
    VoidCallback? onOynatDuraklat,
    VoidCallback? onIleri10,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: FragmanKontrol(
          yukleniyor: false,
          oynuyor: oynuyor,
          sessiz: false,
          konum: const Duration(seconds: 10),
          sure: const Duration(seconds: 60),
          onOynatDuraklat: onOynatDuraklat ?? () {},
          onSessiz: () {},
          onAltyazi: () {},
          onHiz: () {},
          onGeri10: () {},
          onIleri10: onIleri10 ?? () {},
          onBasili2x: (_) {},
        ),
      ),
    );
  }

  /// Yarımın ortası artık −10/+10 kümesine denk gelir; yarımın kendisine
  /// (kümenin üstünde, başlık şeridinin altında) dokunmak için nokta.
  Offset yanNokta(WidgetTester tester, String etiket) {
    final kutu = tester.getRect(find.bySemanticsLabel(etiket));
    return Offset(kutu.center.dx, kutu.top + 120);
  }

  double kromOpaklik(WidgetTester tester) {
    return tester
        .widget<AnimatedOpacity>(find.byKey(const ValueKey('fragman-krom')))
        .opacity;
  }

  testWidgets('oynarken krom 3 sn sonra gizlenir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(kur());
    await tester.pump();
    expect(kromOpaklik(tester), 1);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));
    expect(kromOpaklik(tester), 0);
  });

  testWidgets('gizliyken tek dokunuş kromu açar, oynatmayı DEĞİŞTİRMEZ', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var oynat = 0;
    await tester.pumpWidget(kur(onOynatDuraklat: () => oynat++));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));
    expect(kromOpaklik(tester), 0);

    await tester.tapAt(yanNokta(tester, '10 saniye ileri'));
    // Tek dokunuş 240 ms bekledikten sonra karar verir (çift dokunuş payı).
    await tester.pump(const Duration(milliseconds: 300));
    expect(kromOpaklik(tester), 1);
    expect(oynat, 0);
  });

  testWidgets('krom açıkken tek dokunuş oynat/duraklat çağırır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var oynat = 0;
    await tester.pumpWidget(kur(onOynatDuraklat: () => oynat++));
    await tester.pump();
    await tester.tapAt(yanNokta(tester, '10 saniye ileri'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(oynat, 1);
  });

  testWidgets('gizliyken çift dokunuş sarar ve kromu açmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var ileri = 0;
    await tester.pumpWidget(kur(onIleri10: () => ileri++));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));
    expect(kromOpaklik(tester), 0);

    final sag = yanNokta(tester, '10 saniye ileri');
    await tester.tapAt(sag);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(sag);
    await tester.pump(const Duration(milliseconds: 400));
    expect(ileri, 1);
    expect(kromOpaklik(tester), 0);
  });

  testWidgets('duraklatılmışken krom gizlenmez ve sarı oynat rozeti görünür', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(kur(oynuyor: false));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 250));
    expect(kromOpaklik(tester), 1);
    // Ortadaki sarı oynat rozeti görünür durumda (opaklık 1).
    final rozet = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byIcon(Icons.play_arrow).last,
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(rozet.opacity, 1);
  });

  testWidgets('fare kıpırdayınca gizli krom geri gelir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(kur());
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));
    expect(kromOpaklik(tester), 0);

    final fare = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await fare.addPointer(location: Offset.zero);
    addTearDown(fare.removePointer);
    await fare.moveTo(tester.getCenter(find.byType(FragmanKontrol)));
    await tester.pump(const Duration(milliseconds: 250));
    expect(kromOpaklik(tester), 1);
  });

  testWidgets('hata ekranı: mesaj + Tekrar dene', (tester) async {
    var tekrar = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FragmanHata(onTekrar: () => tekrar++)),
      ),
    );
    expect(find.text('Bir şeyler ters gitti'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pump();
    expect(tekrar, 1);
  });

  testWidgets('üst şerit: FRAGMAN rozeti + fragman adı', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FragmanKontrol(
            yukleniyor: false,
            oynuyor: true,
            sessiz: false,
            baslik: 'Silo — Season 3 Official Trailer',
            konum: const Duration(seconds: 10),
            sure: const Duration(seconds: 60),
            onOynatDuraklat: () {},
            onSessiz: () {},
            onAltyazi: () {},
            onHiz: () {},
            onGeri10: () {},
            onIleri10: () {},
            onBasili2x: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('FRAGMAN'), findsOneWidget);
    expect(find.text('Silo — Season 3 Official Trailer'), findsOneWidget);
    // Krom gizlenince şerit de kaybolur.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));
    final ust = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('fragman-ust')),
    );
    expect(ust.opacity, 0);
  });

  testWidgets('orta küme: büyük düğme oynat/duraklat, yanlar ±10', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var oynat = 0;
    var ileri = 0;
    var geri = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FragmanKontrol(
            yukleniyor: false,
            oynuyor: true,
            sessiz: false,
            konum: const Duration(seconds: 10),
            sure: const Duration(seconds: 60),
            onOynatDuraklat: () => oynat++,
            onSessiz: () {},
            onAltyazi: () {},
            onHiz: () {},
            onGeri10: () => geri++,
            onIleri10: () => ileri++,
            onBasili2x: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('fragman-buyuk')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(oynat, 1);
    await tester.tap(find.byIcon(Icons.forward_10));
    await tester.tap(find.byIcon(Icons.replay_10));
    await tester.pump();
    expect(ileri, 1);
    expect(geri, 1);
    // Küme kromla birlikte gizlenir.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));
    final kume = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('fragman-kume')),
    );
    expect(kume.opacity, 0);
  });

  testWidgets('bitince Tekrar oynat + krom sabit; tam ekran düğmesi', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var tamEkran = 0;
    var oynat = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FragmanKontrol(
            yukleniyor: false,
            oynuyor: false,
            bitti: true,
            sessiz: false,
            konum: const Duration(seconds: 60),
            sure: const Duration(seconds: 60),
            onOynatDuraklat: () => oynat++,
            onSessiz: () {},
            onAltyazi: () {},
            onHiz: () {},
            onGeri10: () {},
            onIleri10: () {},
            onBasili2x: (_) {},
            onTamEkran: () => tamEkran++,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.replay), findsNWidgets(2));
    expect(find.byTooltip('Tekrar oynat'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 250));
    expect(kromOpaklik(tester), 1);

    await tester.tap(find.byTooltip('Tekrar oynat'));
    await tester.pump();
    expect(oynat, 1);

    await tester.tap(find.byKey(const ValueKey('fragman-tam-ekran')));
    await tester.pump();
    expect(tamEkran, 1);
    expect(find.byTooltip('Tam ekran'), findsOneWidget);
  });

  testWidgets(
    'tam ekran içinde düğme "Tam ekrandan çık"; onTamEkran yoksa düğme yok',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FragmanKontrol(
              yukleniyor: false,
              oynuyor: true,
              tamEkran: true,
              sessiz: false,
              konum: const Duration(seconds: 1),
              sure: const Duration(seconds: 60),
              onOynatDuraklat: () {},
              onSessiz: () {},
              onAltyazi: () {},
              onHiz: () {},
              onGeri10: () {},
              onIleri10: () {},
              onBasili2x: (_) {},
              onTamEkran: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byTooltip('Tam ekrandan çık'), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);

      await tester.pumpWidget(kur());
      await tester.pump();
      expect(find.byKey(const ValueKey('fragman-tam-ekran')), findsNothing);
    },
  );

  testWidgets('klavye: boşluk oynat/duraklat, → +10, ← −10, M ses', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var oynat = 0;
    var ileri = 0;
    var geri = 0;
    var ses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FragmanKontrol(
            yukleniyor: false,
            oynuyor: true,
            sessiz: false,
            konum: const Duration(seconds: 10),
            sure: const Duration(seconds: 60),
            onOynatDuraklat: () => oynat++,
            onSessiz: () => ses++,
            onAltyazi: () {},
            onHiz: () {},
            onGeri10: () => geri++,
            onIleri10: () => ileri++,
            onBasili2x: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    // Odak dokunuşla alınır (klavye başka alanı ele geçirmesin).
    await tester.tapAt(yanNokta(tester, '10 saniye ileri'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(oynat, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(oynat, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    expect(ileri, 1);
    expect(geri, 1);
    expect(ses, 1);
  });

  testWidgets('yüklenirken: kapak + sarı halka, krom ve küme yok', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FragmanKontrol(
            yukleniyor: true,
            oynuyor: true,
            sessiz: false,
            baslik: 'Teaser',
            konum: Duration.zero,
            sure: Duration.zero,
            onOynatDuraklat: () {},
            onSessiz: () {},
            onAltyazi: () {},
            onHiz: () {},
            onGeri10: () {},
            onIleri10: () {},
            onBasili2x: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('FRAGMAN'), findsOneWidget);
    expect(find.text('Teaser'), findsOneWidget);
    expect(find.byKey(const ValueKey('fragman-krom')), findsNothing);
    expect(find.byKey(const ValueKey('fragman-kume')), findsNothing);
  });

  testWidgets(
    'KOMPAKT (telefon kahramanı 360×202): küme, çubuk ve şerit çakışmaz',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 202));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FragmanKontrol(
              yukleniyor: false,
              oynuyor: true,
              sessiz: false,
              baslik: 'Silo — Season 3 Official Trailer | Apple TV',
              altBosluk: 44,
              konum: const Duration(seconds: 10),
              sure: const Duration(seconds: 60),
              onOynatDuraklat: () {},
              onSessiz: () {},
              onAltyazi: () {},
              onHiz: () {},
              onGeri10: () {},
              onIleri10: () {},
              onBasili2x: (_) {},
              onTamEkran: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final serit = tester.getRect(find.byType(FragmanBaslikSeridi));
      final buyuk = tester.getRect(find.byKey(const ValueKey('fragman-buyuk')));
      final cubuk = tester.getRect(
        find.byKey(const ValueKey('fragman-ilerleme')),
      );
      final tamEkran = tester.getRect(
        find.byKey(const ValueKey('fragman-tam-ekran')),
      );
      // Küme şeridin altında, çubuğun üstünde.
      expect(buyuk.top, greaterThanOrEqualTo(serit.bottom - 8));
      expect(buyuk.bottom, lessThanOrEqualTo(cubuk.top));
      // Düğme satırı noktaların (alttan 16-28 dp) üstünde kalır.
      expect(tamEkran.bottom, lessThanOrEqualTo(202 - 26 + 0.5));
      // Dokunma hedefleri kompaktta da ≥ 40 dp.
      expect(tamEkran.height, greaterThanOrEqualTo(40));
      expect(tamEkran.width, greaterThanOrEqualTo(40));
      // Çubuk ekranı taşmıyor, her şey kare içinde.
      expect(cubuk.bottom, lessThan(202));
      expect(find.byTooltip('Tam ekran'), findsOneWidget);
    },
  );

  testWidgets('GENİŞ (720×405): küme tam ortada', (tester) async {
    await tester.binding.setSurfaceSize(const Size(720, 405));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(kur());
    await tester.pump();
    final buyuk = tester.getRect(find.byKey(const ValueKey('fragman-buyuk')));
    expect(buyuk.center.dy, closeTo(405 / 2, 1));
    expect(buyuk.height, 64);
  });
}
