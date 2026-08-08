// `/listeler/:id` rotası — 7 Ağu 2026 SEO denetiminin bulduğu iki kırık.
//
// 1) Sunucu `/og/listeler/:id` için indekslenebilir SSR sayfası basıyor
//    (paylaşım kartı ve arama sonucu bu adrese götürüyor) ama uygulamada
//    böyle bir rota YOKTU: giriş yapmış kullanıcı bile "Bağlantı geçersiz"
//    görüyordu.
// 2) Oturumsuz açılınca `/giris?donus=/listeler/1`'e atıyordu — bot içerik,
//    insan giriş formu görüyor: CLOAKING.
//
// Bu testler rotanın VAR olduğunu, oturumsuz AÇILDIĞINI ve gizli/eksik
// listede boş beyaz ekran değil düzgün bir hâl çizildiğini kilitler.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 7 = herkese açık, 8 = sunucu arızası, 9 = gizli/yok (404).
const _acikListe = {
  'id': 7,
  'ad': 'En iyi 20 Türk dizisi',
  'aciklama': 'Deneme listesi',
  'herkese_acik': true,
  'kullanici_adi': 'testkullanici',
  'ogeler': [
    {'tmdb_id': 1396, 'tur': 'tv'},
    {'tmdb_id': 550, 'tur': 'movie'},
  ],
};

// Poster yolları NULL: CachedNetworkImage testte gerçek ağa çıkmasın.
const _icerikler = {
  '/api/tmdb/tv/1396': {
    'id': 1396,
    'name': 'Breaking Bad',
    'poster_path': null,
  },
  '/api/tmdb/movie/550': {
    'id': 550,
    'title': 'Fight Club',
    'poster_path': null,
  },
};

http.Client _sahteIstemci({List<String>? kayit}) => MockClient((istek) async {
  final yol = istek.url.path;
  kayit?.add(yol);
  http.Response cevap(Object govde, [int kod = 200]) => http.Response(
    jsonEncode(govde),
    kod,
    headers: {'content-type': 'application/json'},
  );

  if (yol == '/api/listeler/7') return cevap(_acikListe);
  if (yol == '/api/listeler/8') return cevap({'hata': 'Sunucu patladı'}, 500);
  if (yol == '/api/listeler/9') return cevap({'hata': 'Liste bulunamadı'}, 404);
  if (_icerikler.containsKey(yol)) return cevap(_icerikler[yol]!);
  return cevap(<String, dynamic>{});
});

class _Kurulum {
  _Kurulum(this.yonlendirici, this.oturum);
  final GoRouter yonlendirici;
  final Oturum oturum;
  String get konum =>
      yonlendirici.routerDelegate.currentConfiguration.uri.toString();
}

Future<_Kurulum> _kur(
  WidgetTester tester, {
  required String hedef,
  bool girisli = false,
  List<String>? kayit,
}) async {
  SharedPreferences.setMockInitialValues(girisli ? {'token': 'sahte'} : {});
  await Api.tokenYukle();
  Api.istemci = _sahteIstemci(kayit: kayit);
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = yonlendiriciOlustur(oturum);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: yonlendirici,
        theme: diziTema(acik: false),
      ),
    ),
  );
  await tester.pump();
  yonlendirici.go(hedef);
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  return _Kurulum(yonlendirici, oturum);
}

void main() {
  setUp(() {
    Oturum.karsilamaGerekli = false;
  });

  testWidgets('/listeler/:id rotası VAR — oturumsuz açılır, /giris e atmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final k = await _kur(tester, hedef: '/listeler/7');

    expect(k.oturum.girisli, isFalse);
    // Cloaking yok: bot ne görüyorsa ziyaretçi de o adreste kalıyor.
    expect(k.konum, '/listeler/7');
    expect(k.konum, isNot(startsWith('/giris')));
    // "Bağlantı geçersiz" DEĞİL, gerçek liste.
    expect(find.text('Bağlantı geçersiz veya sayfa bulunamadı'), findsNothing);
    expect(find.text('En iyi 20 Türk dizisi'), findsOneWidget);
    expect(find.text('@testkullanici'), findsOneWidget);
    // Liste öğeleri gerçekten çizildi (poster yoksa ad yazılır).
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('Fight Club'), findsOneWidget);
  });

  testWidgets('girişli kullanıcı için de aynı sayfa açılır', (tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final k = await _kur(tester, hedef: '/listeler/7', girisli: true);

    expect(k.oturum.girisli, isTrue);
    expect(k.konum, '/listeler/7');
    expect(find.text('En iyi 20 Türk dizisi'), findsOneWidget);
  });

  testWidgets('gizli / olmayan liste: boş ekran değil, nazik bulunamadı hâli', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/listeler/9');

    expect(
      find.text('Bağlantı geçersiz veya sayfa bulunamadı'),
      findsOneWidget,
    );
    expect(find.text('Keşfet\'e dön'), findsOneWidget);
    // 404 tekrar denemekle düzelmez: "Tekrar Dene" GÖSTERİLMEZ.
    expect(find.byType(HataGorunumu), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('sunucu arızasında hata + Tekrar Dene (beyaz ekran yok)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/listeler/8');

    expect(find.byType(HataGorunumu), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });

  testWidgets('bozuk id (/listeler/abc) hata ekranı değil nazik sayfa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/listeler/abc');

    expect(
      find.text('Bağlantı geçersiz veya sayfa bulunamadı'),
      findsOneWidget,
    );
  });

  test('liste yolu oturumsuz ziyaretçiye açık sayılıyor', () {
    // Beyaz liste ile nginx bot kuralı (`icerik|gonderi|kisi|dizi|listeler`)
    // aynı kapsamı görmeli; ayrışırlarsa cloaking geri gelir.
    expect(herkeseAcikMi('/listeler/1'), isTrue);
    expect(herkeseAcikMi('/listeler/1234'), isTrue);
    // Korumalı alan korumalı kalmalı.
    expect(herkeseAcikMi('/listelerim'), isFalse);
    expect(herkeseAcikMi('/takvim'), isFalse);
  });
}
