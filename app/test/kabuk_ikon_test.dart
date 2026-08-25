import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
///
/// 25 Ağu 2026: sağdaki Profil hedefi kişi ikonu değil yuvarlak avatar.
/// GIF [DaireGorsel]/[AgGorsel] ile oynar; CircleAvatar backgroundImage
/// ilk karede dondururdu.

/// Seçili olmayan ikon → aynı ailenin dolu hâli. Profil (avatar) bu
/// haritada yok: fotoğraf aynı daire, yedek ikon ayrı testte.
final _aile = <IconData, IconData>{
  Icons.home_outlined: Icons.home,
  Icons.calendar_month_outlined: Icons.calendar_month,
  Icons.add_circle_outline: Icons.add_circle,
  Icons.near_me_outlined: Icons.near_me,
};

IconData _ikon(Widget? w) => (w as Icon).icon!;

KabukProfilIkonu _profil(Widget? w) => w as KabukProfilIkonu;

void main() {
  test('her ikon sekmesinin seçili hali aynı aileden', () {
    final hedefler = kabukHedefleri();
    expect(hedefler.length, 5);
    for (var i = 0; i < hedefler.length; i++) {
      if (i == profilHedefi) continue;
      final h = hedefler[i];
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
    expect(hedefler[profilHedefi].icon, isA<KabukProfilIkonu>());
    final ikonlar = [
      for (var i = 0; i < mesajIndeksi + 1; i++) _ikon(hedefler[i].icon),
    ];
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

  // -------------------------------------------------------------------------
  // 25 Ağu 2026 — sağdaki hedef: kişi ikonu değil yuvarlak (GIF oynayan) avatar
  // -------------------------------------------------------------------------
  test('profil hedefi KabukProfilIkonu, kişi Icon widget\'ı değil', () {
    final profil = kabukHedefleri().elementAt(profilHedefi);
    expect(profil.icon, isA<KabukProfilIkonu>());
    expect(profil.selectedIcon, isA<KabukProfilIkonu>());
    expect(profil.icon, isNot(isA<Icon>()));
    expect(profil.label, 'Profil'.c);
  });

  test('yedek: fotoğraf yokken kişi ailesi (boş/dolu) durur', () {
    final profil = kabukHedefleri().elementAt(profilHedefi);
    expect(_profil(profil.icon).url, isNull);
    expect(_profil(profil.icon).secili, isFalse);
    expect(_profil(profil.selectedIcon).url, isNull);
    expect(_profil(profil.selectedIcon).secili, isTrue);
  });

  test('avatar URL her iki hâle de aynı adresi taşır', () {
    const url = 'https://dizijpg.com/api/avatarlar/x.gif';
    final profil = kabukHedefleri(avatarUrl: url).elementAt(profilHedefi);
    expect(_profil(profil.icon).url, url);
    expect(_profil(profil.selectedIcon).url, url);
  });

  testWidgets('fotoğraf yokken yedek kişi ikonu çizilir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: KabukProfilIkonu())),
      ),
    );
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byType(DaireGorsel), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('seçili yedek dolu kişi ikonu', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: KabukProfilIkonu(secili: true))),
      ),
    );
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
  });

  testWidgets('GIF avatar DaireGorsel + AgGorsel, CircleAvatar YOK', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: const Scaffold(
          body: Center(
            child: KabukProfilIkonu(url: 'https://ornek/avatar.gif'),
          ),
        ),
      ),
    );
    expect(find.byType(DaireGorsel), findsOneWidget);
    expect(find.byType(AgGorsel), findsOneWidget);
    expect(find.byType(ClipOval), findsWidgets);
    expect(find.byType(Image), findsWidgets);
    expect(find.byIcon(Icons.person_outline), findsNothing);
    expect(find.byIcon(Icons.person), findsNothing);
    for (final a in tester.widgetList<CircleAvatar>(
      find.byType(CircleAvatar),
    )) {
      expect(
        a.backgroundImage,
        isNull,
        reason: 'çubuk avatarında backgroundImage GIF\'i dondurur',
      );
    }
  });

  testWidgets('oturumdaki avatar çubuğa düşer, kişi ikonu kalkar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final oturum = Oturum()
      ..kullanici = {
        'id': 1,
        'kullanici_adi': 'testkullanici',
        'avatar': '/avatarlar/ben.gif',
      };

    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: oturum,
        child: MaterialApp(
          theme: diziTema(acik: false),
          home: Builder(
            builder: (c) => Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: kabukCubugu(c, secili: 0, onSec: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(KabukProfilIkonu), findsWidgets);
    expect(find.byType(DaireGorsel), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
    final gorunen = tester.widget<KabukProfilIkonu>(
      find.byType(KabukProfilIkonu).first,
    );
    expect(gorunen.url, dosyaUrl('/avatarlar/ben.gif'));
  });
}
