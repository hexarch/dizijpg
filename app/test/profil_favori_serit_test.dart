// Madde 16 — profildeki favori oyuncular "İzlediğim Diziler/Filmler" gibi
// şerit olsun: fotoğraf + altında isim. Kullanıcının sözü: "Kendi profilinde
// favori oyuncular, 'izlediğim dizi/film' gibi görünsün: resim + altında isim."
//
// Kilitlenen davranışlar (KANIT ZORUNLU, CLAUDE.md kural 7):
//   * favoriler DOLUYSA: başlık "(N)" sayacıyla + yatay şeritte kartlar
//   * karta dokununca /kisi/:id açılır
//   * "Tümünü gör" /favori-oyuncular ekranını açar
//   * favoriler BOŞSA: eski kompakt satır KALIR (keşfedilebilirlik) —
//     dokununca yine /favori-oyuncular (oradaki boş durum yol gösterir)
//   * uç HATA verirse: profil çökmez, kompakt satır kalır
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/favori_oyuncular.dart';
import 'package:dizijpg/ekranlar/kisi.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fotoğraf yolları NULL: CachedNetworkImage testte gerçek ağa çıkmasın.
List<Map<String, dynamic>> _favoriler(int adet) => [
  for (var i = 0; i < adet; i++)
    {'tmdb_id': 500 + i, 'ad': 'Oyuncu ${500 + i}', 'poster': null},
];

http.Client _sahteIstemci({
  required List<Map<String, dynamic>> favoriler,
  bool favoriHata = false,
}) => MockClient((istek) async {
  final yol = istek.url.path;
  http.Response cevap(Object govde, [int kod = 200]) => http.Response(
    jsonEncode(govde),
    kod,
    headers: {'content-type': 'application/json'},
  );

  if (yol == '/api/favori-kisiler') {
    if (favoriHata) return cevap({'hata': 'Sunucu patladı'}, 500);
    return cevap({'kisiler': favoriler});
  }
  if (yol == '/api/istatistiklerim') return cevap({'tahmini_dakika': 0});
  if (yol == '/api/kitapligim') return cevap({'durumlar': <dynamic>[]});
  if (yol == '/api/listelerim') return cevap({'listeler': <dynamic>[]});
  if (yol == '/api/profilim') {
    return cevap({
      'id': 1,
      'kullanici_adi': 'testkullanici',
      'avatar': null,
      'kapak': null,
      'bio': '',
      'ulke': null,
      'sosyal': <dynamic>[],
    });
  }
  if (yol == '/api/izlediklerim') return cevap({'ogeler': <dynamic>[]});
  if (yol == '/api/rozetler') return cevap({'rozetler': <dynamic>[]});
  if (yol == '/api/tmdb/person/500') {
    return cevap({'id': 500, 'name': 'Oyuncu 500', 'profile_path': null});
  }
  if (yol == '/api/tmdb/person/500/combined_credits') {
    return cevap({'cast': <dynamic>[]});
  }
  if (yol == '/api/kisi/500/izlenme') {
    return cevap({'izlenen': 0, 'toplam': 0, 'yapimlar': <dynamic>[]});
  }
  if (yol == '/api/incelemeler/person/500') {
    return cevap({'incelemeler': <dynamic>[], 'ortalama': null, 'adet': 0});
  }
  if (yol == '/api/benim/person/500') {
    return cevap({'puan': null, 'favori': false});
  }
  return cevap(<String, dynamic>{});
});

GoRouter? _yonlendirici;

Future<void> _kur(
  WidgetTester tester, {
  required List<Map<String, dynamic>> favoriler,
  bool favoriHata = false,
}) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  Api.istemci = _sahteIstemci(favoriler: favoriler, favoriHata: favoriHata);
  final oturum = Oturum();
  await oturum.yukle();
  _yonlendirici = yonlendiriciOlustur(oturum);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: _yonlendirici,
        theme: diziTema(acik: false),
      ),
    ),
  );
  await tester.pump();
  _yonlendirici!.go('/profil');
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Profil dikey listesinde [hedef]i görünür kılar. Favori şeridi sayfanın
/// altlarında; görünmeyen widget'a tap, boşluğa dokunmak demek.
Future<void> _gorunurKil(WidgetTester tester, Finder hedef) async {
  await tester.scrollUntilVisible(
    hedef,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  setUp(() {
    Oturum.karsilamaGerekli = false;
  });

  testWidgets(
    'favoriler doluysa şerit: sayaçlı başlık + fotoğraf-ad kartları',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _kur(tester, favoriler: _favoriler(2));
      await _gorunurKil(tester, find.text('Favori oyuncular (2)'));

      // Başlık "(2)" sayacıyla — kompakt satırın sayaçsız metni artık YOK.
      expect(find.text('Favori oyuncular (2)'), findsOneWidget);
      expect(find.text('Favori oyuncular'), findsNothing);
      // Kartlar favori_oyuncular.dart ile AYNI widget: fotoğraf + altında ad.
      expect(find.byType(FavoriOyuncuKarti), findsNWidgets(2));
      expect(find.text('Oyuncu 500'), findsOneWidget);
      expect(find.text('Oyuncu 501'), findsOneWidget);
      // Ad, fotoğrafın ALTINDA (kullanıcının istediği yerleşim).
      final avatar = tester.getRect(
        find.descendant(
          of: find.byType(FavoriOyuncuKarti).first,
          matching: find.byType(CircleAvatar),
        ),
      );
      final ad = tester.getRect(find.text('Oyuncu 500'));
      expect(ad.top, greaterThan(avatar.bottom - 1));
    },
  );

  testWidgets('şeritteki karta dokununca /kisi/:id açılır', (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, favoriler: _favoriler(2));
    await _gorunurKil(tester, find.byType(FavoriOyuncuKarti).first);
    await tester.tap(find.text('Oyuncu 500'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(find.byType(KisiEkrani), findsOneWidget);
  });

  testWidgets('"Tümünü gör" /favori-oyuncular ekranını açar', (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, favoriler: _favoriler(2));
    await _gorunurKil(tester, find.text('Favori oyuncular (2)'));
    await tester.tap(find.text('Tümünü gör').last);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(find.byType(FavoriOyuncularEkrani), findsOneWidget);
  });

  testWidgets(
    'şerit önizlemesi 30 kartla sınırlı, başlık GERÇEK toplamı yazar',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _kur(tester, favoriler: _favoriler(45));
      await _gorunurKil(tester, find.text('Favori oyuncular (45)'));

      expect(find.text('Favori oyuncular (45)'), findsOneWidget);
      // ListView tembel kurar; sınır iddiası "45 kart yok"tur (itemCount 30).
      // .first = EN YAKIN ata: dıştaki dikey profil listesi değil, şeridin
      // kendi yatay ListView'ı.
      final liste = tester.widget<ListView>(
        find
            .ancestor(
              of: find.byType(FavoriOyuncuKarti).first,
              matching: find.byType(ListView),
            )
            .first,
      );
      expect(liste.semanticChildCount, 30);
    },
  );

  testWidgets('favori yoksa kompakt satır kalır ve /favori-oyuncular açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, favoriler: const []);

    expect(find.byType(FavoriOyuncuKarti), findsNothing);
    final satir = find.text('Favori oyuncular');
    await _gorunurKil(tester, satir);
    expect(satir, findsOneWidget);
    await tester.tap(satir);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.byType(FavoriOyuncularEkrani), findsOneWidget);
  });

  testWidgets('uç hata verirse profil çökmez, kompakt satır kalır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, favoriler: const [], favoriHata: true);

    expect(tester.takeException(), isNull);
    expect(find.byType(FavoriOyuncuKarti), findsNothing);
    expect(find.text('Favori oyuncular'), findsOneWidget);
  });
}
