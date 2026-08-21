import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Alt gezinme çubuğu hatası (2 Ağu): ilk sekmenin seçili ikonu PUSULA,
/// seçili olmayan ikonu EV idi — sekme değiştikçe ikon başka bir şeye
/// dönüşüyordu. Aynı hata "Keşfet" sekmesinde de vardı (pusula ↔ büyüteç).
/// Bu test her sekmenin seçili/seçili olmayan ikonunun aynı aileden
/// olduğunu ve etiketlerin (ekran okuyucu için) silinmediğini kilitler.
///
/// 21 Ağu 2026: Keşfet (pusula) hedefi çubuktan çıktı, yerine Mesajlar
/// (kâğıt uçak) geldi. Pusula ailesi listeden SİLİNDİ ki hedef geri
/// sızarsa test "bilinmeyen ikon" demesin — Keşfet artık Akış başlığındaki
/// görünüm seçicisinden açılıyor.

/// Seçili olmayan ikon → aynı ailenin dolu hâli.
final _aile = <IconData, IconData>{
  Icons.home_outlined: Icons.home,
  Icons.calendar_month_outlined: Icons.calendar_month,
  Icons.add_circle_outline: Icons.add_circle,
  Icons.near_me_outlined: Icons.near_me,
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
    // Seçili ilk sekme: dolu ev; kâğıt uçak boş hâlde durmalı.
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.near_me), findsNothing);
    expect(find.byIcon(Icons.near_me_outlined), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 21 Ağu 2026 — kullanıcı isteği: "Keşfet'i kaldır, oraya mesajlar ikonu koy"
  // -------------------------------------------------------------------------
  test('çubukta Keşfet (pusula) YOK, Mesajlar VAR — 4. sırada', () {
    final hedefler = kabukHedefleri();
    expect(hedefler.length, 5);
    final ikonlar = hedefler.map((h) => _ikon(h.icon)).toList();
    expect(
      ikonlar.contains(Icons.explore_outlined),
      isFalse,
      reason: 'Keşfet hedefi alt çubuğa geri sızmış',
    );
    expect(ikonlar[mesajIndeksi], Icons.near_me_outlined);
    expect(hedefler[mesajIndeksi].label, 'Mesajlar'.c);
  });

  test('mesaj hedefi mobilde de masaüstünde de AYNI listede', () {
    // 17 Ağu'daki `mesajlar:` bayrağı kalktı: tek liste, iki düzen.
    expect(kabukHedefleri().length, kabukHedefleri(okunmamis: 3).length);
  });

  test('okunmamış > 0 ise Mesajlar hedefinde rozet çizilir', () {
    final rozetsiz = kabukHedefleri().elementAt(mesajIndeksi);
    final rozetli = kabukHedefleri(okunmamis: 7).elementAt(mesajIndeksi);
    expect(rozetsiz.icon, isA<Icon>());
    expect(rozetli.icon, isA<Badge>());
    expect((rozetli.icon as Badge).label, isNotNull);
  });

  test('kabuk dalı → çubuk hedefi: Keşfet dalı Akış hedefini vurgular', () {
    // Çeviri olmasaydı /arama'dayken çubukta MESAJLAR seçili görünürdü.
    expect(hedefIndeksi(0), 0);
    expect(hedefIndeksi(1), 1);
    expect(hedefIndeksi(akisHedefi), akisHedefi);
    expect(hedefIndeksi(kesfetDali), akisHedefi);
    expect(hedefIndeksi(profilHedefi), profilHedefi);
  });

  test('hedef kökleri: 3. sıra artık /sohbetler', () {
    expect(kabukSekmeKokleri.length, 5);
    expect(kabukSekmeKokleri[mesajIndeksi], '/sohbetler');
    expect(kabukSekmeKokleri.contains('/arama'), isFalse);
  });
}
