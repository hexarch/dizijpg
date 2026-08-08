// `/kisi/:id` DOĞRUDAN açılışı — beyaz ekran nöbetçisi.
//
// 7 Ağu 2026'da `https://dizijpg.com/kisi/6193` doğrudan açılınca bembeyaz
// sayfa bildirildi. Canlıda (girişli/oturumsuz, soğuk/sıcak) yeniden
// üretilemedi — RAPORA bak. Bu testler yine de asıl riski kilitler: rota
// doğrudan girildiğinde ekran GERÇEKTEN çiziliyor mu, veri gelmezse beyaz
// yerine hata + "Tekrar Dene" mi görünüyor.
//
// `initialLocation` yolu ayrıca ölçülür: uygulama içinden gelmek ile URL'yi
// yazıp girmek FARKLI kodlardan geçer (bkz. yonlendirme.dart baslangic).
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kisi.dart';
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

const _kisi = {
  'id': 6193,
  'name': 'Leonardo DiCaprio',
  'biography': 'Amerikalı oyuncu ve yapımcı.',
  'birthday': '1974-11-11',
  'place_of_birth': 'Los Angeles, California, USA',
  'profile_path': null,
};

const _krediler = {
  'cast': [
    {
      'id': 27205,
      'title': 'Inception',
      'poster_path': '/x.jpg',
      'vote_count': 30000,
      'vote_average': 8.4,
      'media_type': 'movie',
    },
  ],
  'crew': <dynamic>[],
};

http.Client _sahteIstemci({
  bool kisiPatlasin = false,
  List<String>? kayit,
}) => MockClient((istek) async {
  final yol = istek.url.path;
  kayit?.add(yol);
  http.Response cevap(Object govde, [int kod = 200]) => http.Response(
    jsonEncode(govde),
    kod,
    headers: {'content-type': 'application/json'},
  );

  if (yol.startsWith('/api/benim/')) {
    return cevap({'hata': 'Giriş gerekli'}, 401);
  }
  if (yol == '/api/tmdb/person/6193') {
    return kisiPatlasin ? cevap({'hata': 'Sunucu hatası'}, 500) : cevap(_kisi);
  }
  if (yol == '/api/tmdb/person/6193/combined_credits') {
    return kisiPatlasin
        ? cevap({'hata': 'Sunucu hatası'}, 500)
        : cevap(_krediler);
  }
  if (yol.startsWith('/api/incelemeler/')) {
    return cevap({'incelemeler': <dynamic>[], 'ortalama': null});
  }
  if (yol.startsWith('/api/yorumlar/')) return cevap({'yorumlar': <dynamic>[]});
  if (yol.startsWith('/api/tepkiler/')) {
    return cevap({'sayilar': <String, dynamic>{}, 'benim': null});
  }
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
  bool kisiPatlasin = false,
  List<String>? kayit,
}) async {
  SharedPreferences.setMockInitialValues(girisli ? {'token': 'sahte'} : {});
  await Api.tokenYukle();
  Api.istemci = _sahteIstemci(kisiPatlasin: kisiPatlasin, kayit: kayit);
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
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  return _Kurulum(yonlendirici, oturum);
}

void main() {
  setUp(() {
    Oturum.karsilamaGerekli = false;
  });

  testWidgets('oturumsuz /kisi/6193 doğrudan açılışta ÇİZİLİR', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final kayit = <String>[];
    final k = await _kur(tester, hedef: '/kisi/6193', kayit: kayit);

    expect(k.konum, '/kisi/6193');
    expect(k.konum, isNot(startsWith('/giris')));
    expect(find.byType(KisiEkrani), findsOneWidget);
    // Boş/beyaz değil: gerçek içerik var.
    expect(find.text('Leonardo DiCaprio'), findsWidgets);
    expect(find.text('Amerikalı oyuncu ve yapımcı.'), findsOneWidget);
    expect(find.byType(HataGorunumu), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Kişisel uç oturumsuzda HİÇ çağrılmaz (401 sayfayı düşürürdü).
    expect(kayit.any((y) => y.startsWith('/api/benim/')), isFalse);
  });

  testWidgets('girişli kullanıcıda da /kisi/6193 çizilir', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final k = await _kur(tester, hedef: '/kisi/6193', girisli: true);

    expect(k.konum, '/kisi/6193');
    expect(find.byType(KisiEkrani), findsOneWidget);
    expect(find.text('Leonardo DiCaprio'), findsWidgets);
  });

  testWidgets('veri gelmezse BEYAZ değil: hata + Tekrar Dene', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/kisi/6193', kisiPatlasin: true);

    expect(find.byType(HataGorunumu), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    // Sonsuz spinner da yok.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('dar telefonda (360 dp) bilgi satırı TAŞMAZ', (tester) async {
    // Uzun doğum yeri satırı 74 px taşıyıp sarı-siyah şerit çiziyordu.
    // Taşma testte istisna atar; bu test o istisnanın geri gelmesini yakalar.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/kisi/6193');

    expect(find.byType(KisiEkrani), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('/kisi/ yolu oturumsuz ziyaretçiye açık', () {
    expect(herkeseAcikMi('/kisi/6193'), isTrue);
  });
}
