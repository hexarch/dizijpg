import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// KULLANICI İSTEĞİ (16 Ağu 2026): tüm sayfalardaki gri yazı ve ikonlar
/// tema metni olsun (koyu = beyaz, açık = koyu). İkincil ton token'ları
/// (`metin70/54/38`) [DiziRenkler.metin] ile aynı; tema varsayılanı da.
void main() {
  tearDown(() => DiziRenkler.acik = false);

  test('KOYU: metin70/54/38 tam beyaz metin', () {
    DiziRenkler.acik = false;
    expect(DiziRenkler.metin, Colors.white);
    expect(DiziRenkler.metin70, DiziRenkler.metin);
    expect(DiziRenkler.metin54, DiziRenkler.metin);
    expect(DiziRenkler.metin38, DiziRenkler.metin);
  });

  test('AÇIK: metin70/54/38 tam koyu metin', () {
    DiziRenkler.acik = true;
    expect(DiziRenkler.metin, const Color(0xFF17171A));
    expect(DiziRenkler.metin70, DiziRenkler.metin);
    expect(DiziRenkler.metin54, DiziRenkler.metin);
    expect(DiziRenkler.metin38, DiziRenkler.metin);
  });

  test(
    'KOYU tema: varsayılan ikon, ipucu ve seçili olmayan nav ikonu beyaz',
    () {
      DiziRenkler.acik = false;
      final tema = diziTema(acik: false);
      expect(tema.iconTheme.color, Colors.white);
      expect(tema.hintColor, Colors.white);
      expect(tema.inputDecorationTheme.hintStyle?.color, Colors.white);
      expect(tema.colorScheme.onSurfaceVariant, Colors.white);
      expect(
        tema.navigationBarTheme.iconTheme!.resolve({})!.color,
        Colors.white,
      );
      expect(
        tema.navigationBarTheme.iconTheme!.resolve({
          WidgetState.selected,
        })!.color,
        Colors.black,
      );
      expect(tema.listTileTheme.iconColor, Colors.white);
      expect(tema.tabBarTheme.unselectedLabelColor, Colors.white);
    },
  );

  testWidgets('KOYU: seçili olmayan alt çubuk ikonu beyaz çizilir', (
    tester,
  ) async {
    DiziRenkler.acik = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: Scaffold(
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            destinations: kabukHedefleri(),
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    final baglam = tester.element(find.byIcon(Icons.explore_outlined));
    expect(IconTheme.of(baglam).color, Colors.white);
    expect(tester.takeException(), isNull);
  });
}
