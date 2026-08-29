import 'dart:convert';
import 'dart:math' as math;

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/izlem_carki.dart';
import 'package:dizijpg/ekranlar/kitaplik_liste.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "NE İZLESEM ÇARKI" (23 Ağu 2026 isteği) kilitleri:
///   1. İzleyeceğim ekranının başlığında çark ikonu var; diğer kitaplık
///      listelerinde YOK.
///   2. Süzgeçler çarkı daraltır (Film → yalnız filmler); boş türe dokunmak
///      SnackBar açıklaması verir, süzgeci değiştirmez.
///   3. Seed'li Random ile çeviriş DETERMİNİSTİK: beklenen içerikte durur ve
///      sonuç kartı adı/puanı gösterir.
///   4. Bütçe satırı yalnız FİLMDE ve bütçe > 0 iken çizilir; dizide asla.
///   5. Sonuç kartına dokunmak /icerik rotasını açar.
///   6. "Tekrar çevir" çark görünümüne döner ve yeniden çevirir.
const double _g = 600, _y = 1200;

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Kart bilgisi (POST /icerikler) + tam detay (/tmdb/...) sunucusu.
void _sunucu({int filmButce = 185000000}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (yol == '/icerikler') {
      final anahtarlar =
          (jsonDecode(istek.body) as Map<String, dynamic>)['anahtarlar']
              as List<dynamic>;
      return _json({
        'icerikler': {
          for (final a in anahtarlar)
            a as String: {
              'id': int.parse(a.split(':')[1]),
              a.startsWith('tv') ? 'name' : 'title': 'İçerik $a',
              'poster_path': null,
              'vote_average': 7.5,
            },
        },
      });
    }
    if (yol.startsWith('/tmdb/movie/')) {
      return _json({
        'id': 550,
        'title': 'Seçilen Film',
        'overview': 'Film konusu burada.',
        'release_date': '1999-10-15',
        'vote_average': 8.4,
        'budget': filmButce,
      });
    }
    if (yol.startsWith('/tmdb/tv/')) {
      return _json({
        'id': 66732,
        'name': 'Seçilen Dizi',
        'overview': 'Dizi konusu burada.',
        'first_air_date': '2016-07-15',
        'vote_average': 8.6,
      });
    }
    if (yol == '/kitapligim') {
      return _json({
        'durumlar': [
          {'tur': 'tv', 'tmdb_id': 100, 'durum': 'izleyecegim'},
          {'tur': 'movie', 'tmdb_id': 200, 'durum': 'izleyecegim'},
        ],
        'favoriler': <dynamic>[],
      });
    }
    if (yol == '/izlediklerim') {
      return _json({'ogeler': <dynamic>[]});
    }
    return _json(const <String, dynamic>{});
  });
}

/// Çark sayfasını kabuksuz, doğrudan açan yardımcı (go_router'lı ki sonuç
/// kartındaki /icerik dokunuşu sınanabilsin).
Future<GoRouter> _carkiAc(
  WidgetTester tester,
  List<Map<String, dynamic>> ogeler, {
  required int seed,
}) async {
  final yonlendirici = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('ac'),
                onPressed: () => izlemCarkiniAc(
                  context,
                  ogeler,
                  rastgele: math.Random(seed),
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/icerik/:tur/:id',
        builder: (context, s) => Scaffold(
          body: Text(
            'detay:${s.pathParameters['tur']}:${s.pathParameters['id']}',
          ),
        ),
      ),
    ],
  );
  addTearDown(yonlendirici.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: yonlendirici,
      theme: diziTema(acik: false),
    ),
  );
  await tester.tap(find.byKey(const Key('ac')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400)); // sheet + kart partisi
  return yonlendirici;
}

/// Çevirme animasyonunu sonuna kadar oynatır
/// (5,2 sn dönüş + 320 ms geri oturma "tık"ı).
Future<void> _cevirVeBekle(WidgetTester tester) async {
  // 29 Ağu 2026: "Çarkı çevir" düğmesi KALDIRILDI (kullanıcı: "elle de
  // çevrilebilmeli, çevir butonu saçma"). Dokunma davranışı aynen duruyor,
  // hedef artık çarkın kendisi.
  await tester.tap(find.byKey(const Key('izlem-carki-cark')));
  for (var i = 0; i < 24; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pump(const Duration(milliseconds: 300)); // detay + geçiş
}

const _ogeler = [
  {'tur': 'tv', 'tmdb_id': 100},
  {'tur': 'movie', 'tmdb_id': 200},
  {'tur': 'tv', 'tmdb_id': 300},
  {'tur': 'movie', 'tmdb_id': 400},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('İzleyeceğim ekranında çark ikonu var, Bitirdim listesinde yok', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(_g, _y));
    _sunucu();
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: const KitaplikListesiEkrani(durum: 'izleyecegim'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('izlem-carki')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: const KitaplikListesiEkrani(durum: 'bitirdim'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('izlem-carki')), findsNothing);
  });

  testWidgets('çark açılır: süzgeçler, göbek sayısı ve çevir düğmesi', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(_g, _y));
    _sunucu();
    await _carkiAc(tester, _ogeler, seed: 1);
    expect(find.byKey(const Key('izlem-carki-cark')), findsOneWidget);
    expect(find.byKey(const Key('cark-suzgec-hepsi')), findsOneWidget);
    expect(find.byKey(const Key('cark-suzgec-tv')), findsOneWidget);
    expect(find.byKey(const Key('cark-suzgec-movie')), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // göbek: karışıkta 4 öğe
    await tester.tap(find.byKey(const Key('cark-suzgec-movie')));
    await tester.pump();
    expect(find.text('2'), findsOneWidget); // yalnız filmler
  });

  testWidgets('boş türe dokunmak SnackBar verir, süzgeci değiştirmez', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(_g, _y));
    _sunucu();
    await _carkiAc(tester, const [
      {'tur': 'tv', 'tmdb_id': 100},
      {'tur': 'tv', 'tmdb_id': 300},
    ], seed: 1);
    await tester.tap(find.byKey(const Key('cark-suzgec-movie')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Bu türde içerik yok'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // hâlâ karışık: 2 dizi
  });

  testWidgets(
    'seed\'li çeviriş filmde durur: sonuç kartı ad + puan + KONU + BÜTÇE',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(_g, _y));
      _sunucu();
      await _carkiAc(tester, _ogeler, seed: 7);
      // Film süzgeci: seçim {movie} evreninden gelir → /tmdb/movie yanıtı.
      await tester.tap(find.byKey(const Key('cark-suzgec-movie')));
      await tester.pump();
      await _cevirVeBekle(tester);
      expect(find.byKey(const Key('cark-sonuc')), findsOneWidget);
      expect(find.text('Seçilen Film'), findsOneWidget);
      expect(find.text('8.4'), findsOneWidget);
      expect(find.text('1999'), findsOneWidget);
      expect(find.text('Film konusu burada.'), findsOneWidget);
      expect(find.byKey(const Key('cark-butce')), findsOneWidget);
    },
  );

  testWidgets('dizide bütçe satırı YOK; bütçesiz filmde de yok', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(_g, _y));
    _sunucu();
    await _carkiAc(tester, const [
      {'tur': 'tv', 'tmdb_id': 100},
    ], seed: 3);
    await _cevirVeBekle(tester);
    expect(find.text('Seçilen Dizi'), findsOneWidget);
    expect(find.byKey(const Key('cark-butce')), findsNothing);

    // Bütçesi 0 (bilinmiyor) dönen film: rozet yine çizilmez.
    _sunucu(filmButce: 0);
    await _carkiAc(tester, const [
      {'tur': 'movie', 'tmdb_id': 200},
    ], seed: 3);
    await _cevirVeBekle(tester);
    expect(find.text('Seçilen Film'), findsOneWidget);
    expect(find.byKey(const Key('cark-butce')), findsNothing);
  });

  testWidgets('sonuç kartına dokunmak içeriğin sayfasını açar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(_g, _y));
    _sunucu();
    await _carkiAc(tester, const [
      {'tur': 'movie', 'tmdb_id': 200},
    ], seed: 5);
    await _cevirVeBekle(tester);
    await tester.tap(find.byKey(const Key('cark-sonuc-kart')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('detay:movie:200'), findsOneWidget);
  });

  testWidgets('"Tekrar çevir" çark görünümüne dönüp yeniden çevirir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(_g, _y));
    _sunucu();
    await _carkiAc(tester, _ogeler, seed: 11);
    await _cevirVeBekle(tester);
    expect(find.byKey(const Key('cark-sonuc')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cark-tekrar')));
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pump(const Duration(milliseconds: 300));
    // Yeni bir sonuç geldi (çark yeniden döndü ve durdu).
    expect(find.byKey(const Key('cark-sonuc')), findsOneWidget);
  });
}
