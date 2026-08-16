import 'package:dizijpg/ekranlar/fragman.dart';
import 'package:dizijpg/ekranlar/fragman_gom.dart';
import 'package:dizijpg/ekranlar/fragman_kontrol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  testWidgets('aktif false olunca gömme sökülmez', (tester) async {
    const anahtar = Key('fragman-koru');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FragmanOynatici(
            key: anahtar,
            youtubeId: 'officialTr1',
            aktif: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.byType(FragmanGomucu), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FragmanOynatici(
            key: anahtar,
            youtubeId: 'officialTr1',
            aktif: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(FragmanGomucu), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('kontrol çubuğu oynat/duraklat ve sessiz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var oynat = 0;
    var sessiz = 0;
    Duration? sarma;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FragmanKontrol(
            yukleniyor: false,
            oynuyor: true,
            sessiz: false,
            konum: const Duration(seconds: 12),
            sure: const Duration(seconds: 60),
            tampon: const Duration(seconds: 40),
            onOynatDuraklat: () => oynat++,
            onSessiz: () => sessiz++,
            onAltyazi: () {},
            onHiz: () {},
            onGeri10: () {},
            onIleri10: () {},
            onBasili2x: (_) {},
            onSarma: (s) => sarma = s,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('0:12 / 1:00'), findsOneWidget);
    await tester.tap(find.byTooltip('Duraklat'));
    await tester.tap(find.byTooltip('Sesi kapat'));
    await tester.pump();
    expect(oynat, 1);
    expect(sessiz, 1);
    expect(find.byType(Slider), findsNothing);
    final boya =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('fragman-ilerleme')),
                )
                .painter
            as FragmanIlerlemeBoyaci;
    expect(boya.oynanan, closeTo(12 / 60, 0.01));
    expect(boya.tampon, closeTo(40 / 60, 0.01));
    expect(boya.tampon, isNot(closeTo(boya.oynanan, 0.01)));

    final kutu = tester.getRect(find.byKey(const ValueKey('fragman-ilerleme')));
    await tester.tapAt(Offset(kutu.left + kutu.width * 0.5, kutu.center.dy));
    await tester.pump();
    expect(sarma, const Duration(seconds: 30));
  });

  testWidgets('sağ çift dokunuş +10, sol −10; tek dokunuş oynatır', (
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
            konum: const Duration(seconds: 20),
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

    final sag = find.bySemanticsLabel('10 saniye ileri');
    await tester.tap(sag);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(sag);
    await tester.pump();
    expect(ileri, 1);
    expect(find.text('+10'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(oynat, 0);

    final sol = find.bySemanticsLabel('10 saniye geri');
    await tester.tap(sol);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(sol);
    await tester.pump();
    expect(geri, 1);
    expect(find.text('−10'), findsOneWidget);

    await tester.tap(sag);
    await tester.pump(const Duration(milliseconds: 250));
    expect(oynat, 1);
  });

  testWidgets('altyazı ve 1×/2× düğmeleri', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var altyazi = 0;
    var hiz = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FragmanKontrol(
            yukleniyor: false,
            oynuyor: true,
            sessiz: false,
            konum: const Duration(seconds: 5),
            sure: const Duration(seconds: 60),
            onOynatDuraklat: () {},
            onSessiz: () {},
            onAltyazi: () => altyazi++,
            onHiz: () => hiz++,
            onGeri10: () {},
            onIleri10: () {},
            onBasili2x: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('fragman-altyazi')));
    await tester.tap(find.byKey(const ValueKey('fragman-hiz')));
    await tester.pump();
    expect(altyazi, 1);
    expect(hiz, 1);
    expect(find.byTooltip('Altyazıyı aç'), findsOneWidget);
    expect(find.text('1×'), findsOneWidget);
  });

  testWidgets('basılı tutunca 2×, bırakınca eski hız', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final hizlar = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FragmanKontrol(
            yukleniyor: false,
            oynuyor: true,
            sessiz: false,
            konum: const Duration(seconds: 5),
            sure: const Duration(seconds: 60),
            onOynatDuraklat: () {},
            onSessiz: () {},
            onAltyazi: () {},
            onHiz: () {},
            onGeri10: () {},
            onIleri10: () {},
            onBasili2x: hizlar.add,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.longPress(find.bySemanticsLabel('10 saniye ileri'));
    await tester.pump();
    expect(hizlar, [true, false]);
  });
}
