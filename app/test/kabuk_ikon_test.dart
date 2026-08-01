import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Alt gezinme çubuğu hatası (2 Ağu): ilk sekmenin seçili ikonu PUSULA,
/// seçili olmayan ikonu EV idi — sekme değiştikçe ikon başka bir şeye
/// dönüşüyordu. Aynı hata "Keşfet" sekmesinde de vardı (pusula ↔ büyüteç).
/// Bu test her sekmenin seçili/seçili olmayan ikonunun aynı aileden
/// olduğunu ve etiketlerin (ekran okuyucu için) silinmediğini kilitler.

/// Seçili olmayan ikon → aynı ailenin dolu hâli.
final _aile = <IconData, IconData>{
  Icons.home_outlined: Icons.home,
  Icons.calendar_month_outlined: Icons.calendar_month,
  Icons.add_circle_outline: Icons.add_circle,
  Icons.explore_outlined: Icons.explore,
  Icons.person_outline: Icons.person,
};

IconData _ikon(Widget? w) => (w as Icon).icon!;

void main() {
  test('her sekmenin seçili ikonu, seçili olmayanla aynı aileden', () {
    final hedefler = kabukHedefleri();
    expect(hedefler.length, 5);
    for (final h in hedefler) {
      final bos = _ikon(h.icon);
      expect(
        _aile.containsKey(bos),
        isTrue,
        reason: 'bilinmeyen seçili olmayan ikon: $bos',
      );
      expect(
        _ikon(h.selectedIcon),
        _aile[bos],
        reason: '"${h.label}" sekmesinin seçili ikonu farklı bir aileden',
      );
    }
  });

  test('ilk sekme ev ailesinden (pusula değil)', () {
    final ilk = kabukHedefleri().first;
    expect(_ikon(ilk.icon), Icons.home_outlined);
    expect(_ikon(ilk.selectedIcon), Icons.home);
  });

  test('etiketler silinmedi — ekran okuyucular kullanıyor', () {
    for (final h in kabukHedefleri()) {
      expect(h.label.trim(), isNotEmpty);
    }
  });

  testWidgets('etiketler gizli ama seçili sekmenin ikonu dolu hâle geçer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: NavigationBar(
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            selectedIndex: 0,
            destinations: kabukHedefleri(),
          ),
        ),
      ),
    );
    final cubuk = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(cubuk.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide);
    // Seçili ilk sekme: dolu ev; pusula hiçbir yerde dolu olarak görünmemeli.
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.explore), findsNothing);
    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
  });
}
