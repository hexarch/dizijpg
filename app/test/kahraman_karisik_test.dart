import 'package:dizijpg/ekranlar/fragman.dart';
import 'package:dizijpg/ekranlar/fragman_gom.dart';
import 'package:dizijpg/ekranlar/kahraman_karisik.dart';
import 'package:dizijpg/tmdb_fragman.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Tek karede video/foto karışık kaydırma.
const Size _ekran = Size(400, 800);

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  testWidgets('sıra video-foto-video; kaydırınca sayaç ilerler', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(_ekran);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KahramanKarisik(
            ogeler: [
              KahramanOge.video('officialTr1'),
              KahramanOge.foto('https://example.test/a.jpg'),
              KahramanOge.video('teaserKey12'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1/3'), findsOneWidget);
    expect(find.byType(FragmanOynatici), findsOneWidget);
    expect(
      tester.widget<FragmanOynatici>(find.byType(FragmanOynatici)).youtubeId,
      'officialTr1',
    );

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);
    expect(
      tester.widget<FragmanOynatici>(find.byType(FragmanOynatici)).youtubeId,
      'teaserKey12',
    );
  });

  testWidgets('oynarken kaydırınca gömme sökülür', (tester) async {
    await tester.binding.setSurfaceSize(_ekran);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KahramanKarisik(
            ogeler: [
              KahramanOge.video('officialTr1'),
              KahramanOge.foto('https://example.test/a.jpg'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.byType(FragmanGomucu), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump();
    expect(find.byType(FragmanGomucu), findsNothing);
  });
}
