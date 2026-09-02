// İÇERİK SAYFASI — FAVORİ + PUANLA YIL SATIRININ ALTINDA (3 Eyl 2026).
//
// Kullanıcı: "favori ve yıldız vermeyi dizi ve filmlerde yapım yılı ve
// maliyetin altına al". İki düğme aksiyon satırından (İzledim / Listeye
// ekle'nin yanı) afişin sağındaki sütuna, yıl + bütçe/durum rozetinin
// hemen altına taşındı.
//
// Kilitlenen davranışlar (CLAUDE.md kural 7 — etkileşimli widget'a dokunuldu):
//  1) FİLMDE: favori ve puanla, bütçe rozetinin ALTINDA ve tür çiplerinin
//     ÜSTÜNDE; afişin sağındaki sütunda (x ≥ afişin sağ kenarı).
//  2) DİZİDE: aynı yer, durum rozetinin altında.
//  3) Sayfada her düğmeden TEK tane var (aksiyon satırındaki eski kopya
//     kaldırıldı).
//  4) Dokunma hedefi ≥ 44 px (kural: padding'le büyüt, ikonu değil).
//  5) Favori dokununca /favori/toggle'a, Puanla dokununca puan sheet'ine
//     gider — düğmeler taşınırken bağları kopmadı.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _favori = Key('favori-dugmesi');
const _puanla = Key('puanla-dugmesi');
const _para = Key('butce-rozeti');
const _durumRozeti = Key('durum-rozeti');
const _afis = Key('detay-afis');
const Size _ekran = Size(600, 1400);

Map<String, dynamic> _film() => {
  'id': 27205,
  'title': 'Başlangıç',
  'overview': 'Deneme özeti',
  'release_date': '2010-07-15',
  'vote_average': 8.4,
  'poster_path': '/afis.jpg',
  'backdrop_path': '/ana.jpg',
  'genres': const [
    {'id': 28, 'name': 'Aksiyon'},
  ],
  'seasons': const <dynamic>[],
  'budget': 160000000,
  'revenue': 839030630,
};

Map<String, dynamic> _dizi() => {
  'id': 1396,
  'name': 'Breaking Bad',
  'overview': 'Deneme özeti',
  'first_air_date': '2008-01-20',
  'number_of_seasons': 5,
  'vote_average': 8.9,
  'poster_path': '/afis.jpg',
  'backdrop_path': '/ana.jpg',
  'genres': const [
    {'id': 18, 'name': 'Drama'},
  ],
  'seasons': const <dynamic>[],
  'status': 'Ended',
};

final List<Uri> _istekler = [];

void _sunucu(Map<String, dynamic> icerik) {
  _istekler.clear();
  Api.istemci = MockClient((istek) async {
    _istekler.add(istek.url);
    final yol = istek.url.path.replaceFirst('/api', '');
    final govde = yol.startsWith('/tmdb/') ? jsonEncode(icerik) : '{}';
    return http.Response(
      govde,
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Future<void> _kur(
  WidgetTester tester, {
  required Map<String, dynamic> icerik,
  bool film = true,
}) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  _sunucu(icerik);
  await tester.binding.setSurfaceSize(_ekran);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final yonlendirici = GoRouter(
    initialLocation: film ? '/icerik/movie/27205' : '/icerik/tv/1396',
    routes: [
      GoRoute(
        path: '/icerik/:tur/:id',
        builder: (_, s) => DetayEkrani(
          tmdbId: int.parse(s.pathParameters['id']!),
          tur: s.pathParameters['tur']!,
        ),
      ),
      GoRoute(
        path: '/gozat',
        builder: (_, _) => const Scaffold(body: Text('gözat')),
      ),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp.router(
        theme: diziTema(acik: false),
        routerConfig: yonlendirici,
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Düğmelerin yıl rozetinin ALTINDA, tür çiplerinin ÜSTÜNDE ve afişin
/// SAĞINDA olduğunu ölçer.
void _yeriDogrula(WidgetTester tester, Key rozet, Key turCipi) {
  final rozetKutu = tester.getRect(find.byKey(rozet));
  final favoriKutu = tester.getRect(find.byKey(_favori));
  final puanKutu = tester.getRect(find.byKey(_puanla));
  final cipKutu = tester.getRect(find.byKey(turCipi));
  final afisKutu = tester.getRect(find.byKey(_afis));

  expect(favoriKutu.top, greaterThanOrEqualTo(rozetKutu.bottom - 1));
  expect(puanKutu.top, greaterThanOrEqualTo(rozetKutu.bottom - 1));
  expect(favoriKutu.bottom, lessThanOrEqualTo(cipKutu.top + 1));
  expect(afisKutu.right, lessThanOrEqualTo(favoriKutu.left));
  // Yan yana, favori solda.
  expect(favoriKutu.right, lessThanOrEqualTo(puanKutu.left + 1));
  // 44 px dokunma hedefi.
  expect(favoriKutu.height, greaterThanOrEqualTo(44));
  expect(favoriKutu.width, greaterThanOrEqualTo(44));
  expect(puanKutu.height, greaterThanOrEqualTo(44));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Ceviri.sec('tr'));

  testWidgets('FİLM: favori + puanla bütçe rozetinin altında, afişin sağında', (
    tester,
  ) async {
    await _kur(tester, icerik: _film());
    expect(find.byKey(_para), findsOneWidget);
    _yeriDogrula(tester, _para, const Key('tur-cip-28'));
  });

  testWidgets('DİZİ: favori + puanla durum rozetinin altında', (tester) async {
    await _kur(tester, icerik: _dizi(), film: false);
    expect(find.byKey(_durumRozeti), findsOneWidget);
    _yeriDogrula(tester, _durumRozeti, const Key('tur-cip-18'));
  });

  testWidgets('eski kopya yok: sayfada TEK favori, TEK puanla', (tester) async {
    await _kur(tester, icerik: _film());
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(find.byTooltip('Favori'), findsOneWidget);
    expect(find.byTooltip('Puanla'), findsOneWidget);
  });

  testWidgets('favoriye dokununca /favori/toggle istenir', (tester) async {
    await _kur(tester, icerik: _film());
    await tester.tap(find.byKey(_favori));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_istekler.any((u) => u.path.endsWith('/favori/toggle')), isTrue);
  });

  testWidgets('puanlaya dokununca puan sayfası açılır', (tester) async {
    await _kur(tester, icerik: _film());
    await tester.tap(find.byKey(_puanla));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Puan sheet'inde en az bir seçilebilir yıldız çıkar (5'li dizi).
    expect(find.byIcon(Icons.star_border), findsWidgets);
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
