import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// KULLANICI İSTEĞİ (16 Ağu 2026): kullanılan yazı/ikon tema metni (koyu =
/// beyaz); PASİF (kapalı, ipucu, boş yer tutucu) gri (`metin38`) kalsın.
void main() {
  tearDown(() => DiziRenkler.acik = false);

  test('KOYU: kullanılan ikincil ton beyaz, pasif gri', () {
    DiziRenkler.acik = false;
    expect(DiziRenkler.metin, Colors.white);
    expect(DiziRenkler.metin70, DiziRenkler.metin);
    expect(DiziRenkler.metin54, DiziRenkler.metin);
    expect(DiziRenkler.metin38, Colors.white38);
    expect(DiziRenkler.metin38, isNot(DiziRenkler.metin));
  });

  test('AÇIK: kullanılan ikincil ton koyu, pasif gri', () {
    DiziRenkler.acik = true;
    expect(DiziRenkler.metin, const Color(0xFF17171A));
    expect(DiziRenkler.metin70, DiziRenkler.metin);
    expect(DiziRenkler.metin54, DiziRenkler.metin);
    expect(DiziRenkler.metin38, Colors.black38);
    expect(DiziRenkler.metin38, isNot(DiziRenkler.metin));
  });

  test('KOYU tema: kullanılan ikon beyaz, ipucu gri', () {
    DiziRenkler.acik = false;
    final tema = diziTema(acik: false);
    expect(tema.iconTheme.color, Colors.white);
    expect(tema.hintColor, Colors.white38);
    expect(tema.inputDecorationTheme.hintStyle?.color, Colors.white38);
    expect(tema.colorScheme.onSurfaceVariant, Colors.white);
    expect(tema.navigationBarTheme.iconTheme!.resolve({})!.color, Colors.white);
    expect(
      tema.navigationBarTheme.iconTheme!.resolve({WidgetState.selected})!.color,
      Colors.black,
    );
    expect(tema.listTileTheme.iconColor, Colors.white);
    expect(tema.tabBarTheme.unselectedLabelColor, Colors.white);
  });

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
    // 21 Ağu 2026: pusula (Keşfet) hedefi çubuktan çıktı; ölçüm seçili
    // OLMAYAN bir hedefe bakmalı — takvim hedefi (indeks 1) o rolü aldı.
    final baglam = tester.element(find.byIcon(Icons.calendar_month_outlined));
    expect(IconTheme.of(baglam).color, Colors.white);
    expect(tester.takeException(), isNull);
  });
}
