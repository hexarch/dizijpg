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
            onOynatDuraklat: () => oynat++,
            onSessiz: () => sessiz++,
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
    expect(find.byType(Slider), findsOneWidget);
    // Sarma çubuğu var; değer 12/60.
    final cubuk = tester.widget<Slider>(find.byType(Slider));
    expect(cubuk.value, closeTo(12, 0.01));
    cubuk.onChanged?.call(30);
    expect(sarma, const Duration(seconds: 30));
  });
}
