import 'package:dizijpg/ekranlar/fragman_kontrol.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

    await tester.tap(find.bySemanticsLabel('10 saniye ileri'));
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
    await tester.tap(find.bySemanticsLabel('10 saniye ileri'));
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

    final sag = find.bySemanticsLabel('10 saniye ileri');
    await tester.tap(sag);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(sag);
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
}
