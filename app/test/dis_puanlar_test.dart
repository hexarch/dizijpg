// DIŞ PUANLAR — IMDb / Rotten Tomatoes / Metacritic rozetleri (6 Eyl 2026).
//
// Kullanıcı isteği: "IMDb, domates ve patlamış mısır puanlarını çekip
// dizi/filmlerde gösterelim". Kaynak MDBList (backend/dis_puan.js).
//
// Kilitlenen davranışlar:
//  1) Dört kaynak da geldiğinde dört rozet; sayılar yerel biçimde
//     (tr: "9,3" ve "%96"; en: "9.3" ve "96%").
//  2) Kaynağın puanı yoksa o rozet HİÇ çizilmez ("—" yok); hiçbiri yoksa
//     blok yok, sayfa çökmez.
//  3) Adresi olan rozet dokununca kaynağı DIŞ tarayıcıda açar
//     (`disBaglantiAc` ele geçirilir); adresi olmayan (Metacritic) düz metin.
//  4) Yazı etiketi YOK (kullanıcı: "sadece logoları olsun"); Eleştirmen/Seyirci
//     yalnız erişilebilirlik etiketinde, çevrili (en: Critics/Audience), 45 dilde VAR.
//  5) Taze (≥60 / fresh) domates kırmızı, çürük yeşil; seyirci patlamış mısır
//     simgesi (ikisi de kendi çizimimiz, logo değil).
//  6) İçerik sayfası: `/dis-puan` yanıtı gelince rozetler TMDB puanıyla AYNI
//     satırda, ondan sonra; uç `{dis: null}` dönerse rozet yok.
//  7) Dokunma hedefi 44 dp (görünen rozet küçük olsa da).
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/diller/diller.dart';
import 'package:dizijpg/dis_puanlar.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, dynamic> _tam = {
  'imdb': 9.3,
  'imdb_oy': 3233483,
  'imdb_url': 'https://www.imdb.com/title/tt0111161/',
  'rt_elestirmen': 89,
  'rt_taze': true,
  'rt_seyirci': 98,
  'rt_url': 'https://www.rottentomatoes.com/m/shawshank_redemption',
  'metacritic': 82,
};

Future<void> _yalniz(
  WidgetTester tester,
  Map<String, dynamic> dis, {
  String dil = 'tr',
}) async {
  await Ceviri.sec(dil);
  addTearDown(() => Ceviri.sec('tr'));
  await tester.pumpWidget(
    MaterialApp(
      theme: diziTema(acik: false),
      home: Scaffold(
        body: Center(child: DisPuanlar(dis: dis)),
      ),
    ),
  );
  await tester.pump();
}

/// Rozetin erişilebilirlik etiketi (Semantics widget'ından okunur).
String _semantik(WidgetTester tester, Key k) => tester
    .widgetList<Semantics>(
      find.descendant(of: find.byKey(k), matching: find.byType(Semantics)),
    )
    .map((w) => w.properties.label)
    .whereType<String>()
    .first;

String _metin(WidgetTester tester, Key k) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(k), matching: find.byType(Text)),
    )
    .map((t) => t.data)
    .join(' ');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('1) dört rozet, Türkçe biçim', (tester) async {
    await _yalniz(tester, _tam);
    expect(find.byKey(const Key('dis-imdb')), findsOneWidget);
    expect(find.byKey(const Key('dis-rt-elestirmen')), findsOneWidget);
    expect(find.byKey(const Key('dis-rt-seyirci')), findsOneWidget);
    expect(find.byKey(const Key('dis-metacritic')), findsOneWidget);
    expect(_metin(tester, const Key('dis-imdb')), 'IMDb 9,3');
    expect(_metin(tester, const Key('dis-rt-elestirmen')), '%89');
    expect(_metin(tester, const Key('dis-rt-seyirci')), '%98');
    expect(_metin(tester, const Key('dis-metacritic')), '82');
    // Yazı etiketi YOK (kullanıcı kararı); yalnız erişilebilirlik etiketinde
    expect(find.text('Eleştirmen'), findsNothing);
    expect(find.text('Seyirci'), findsNothing);
    expect(find.text('Metacritic'), findsNothing);
    expect(_semantik(tester, const Key('dis-rt-elestirmen')), 'Eleştirmen %89');
  });

  testWidgets('1/4) İngilizce biçim + çevrilmiş erişilebilirlik etiketi', (
    tester,
  ) async {
    await _yalniz(tester, _tam, dil: 'en');
    expect(_metin(tester, const Key('dis-imdb')), 'IMDb 9.3');
    expect(_metin(tester, const Key('dis-rt-elestirmen')), '89%');
    expect(_metin(tester, const Key('dis-rt-seyirci')), '98%');
    expect(_semantik(tester, const Key('dis-rt-elestirmen')), 'Critics 89%');
    expect(_semantik(tester, const Key('dis-rt-seyirci')), 'Audience 98%');
  });

  test('4) iki anahtar 45 dilde VAR', () {
    expect(tumCeviriler.length, 45);
    final eksik = <String>[];
    for (final g in tumCeviriler.entries) {
      for (final a in const ['Eleştirmen', 'Seyirci']) {
        if (!g.value.containsKey(a)) eksik.add('${g.key}: $a');
      }
    }
    expect(eksik, isEmpty, reason: eksik.join('\n'));
  });

  testWidgets('2) eksik kaynak → rozet yok; hiçbiri yoksa blok yok', (
    tester,
  ) async {
    await _yalniz(tester, const {'imdb': 7.1, 'rt_seyirci': 55});
    expect(find.byKey(const Key('dis-imdb')), findsOneWidget);
    expect(find.byKey(const Key('dis-rt-elestirmen')), findsNothing);
    expect(find.byKey(const Key('dis-rt-seyirci')), findsOneWidget);
    expect(find.byKey(const Key('dis-metacritic')), findsNothing);
    expect(find.textContaining('—'), findsNothing);

    expect(disPuanVar(null), isFalse);
    expect(disPuanVar(const {}), isFalse);
    expect(disPuanVar(const {'imdb_url': 'x'}), isFalse);
    expect(disPuanVar(const {'metacritic': 50}), isTrue);
    await _yalniz(tester, const {});
    expect(find.byKey(const Key('dis-puanlar')), findsNothing);
  });

  testWidgets('3) dokununca kaynak açılır; adressiz rozet düz metin', (
    tester,
  ) async {
    final acilan = <String>[];
    final eski = disBaglantiAc;
    disBaglantiAc = (u) async => acilan.add(u);
    addTearDown(() => disBaglantiAc = eski);
    await _yalniz(tester, _tam);
    await tester.tap(find.byKey(const Key('dis-imdb')));
    await tester.tap(find.byKey(const Key('dis-rt-seyirci')));
    await tester.tap(find.byKey(const Key('dis-metacritic')));
    await tester.pump();
    expect(acilan, [
      'https://www.imdb.com/title/tt0111161/',
      'https://www.rottentomatoes.com/m/shawshank_redemption',
    ]);
    expect(
      find.descendant(
        of: find.byKey(const Key('dis-metacritic')),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets(
    '5) taze domates kırmızı, çürük yeşil; seyircide patlamış mısır',
    (tester) async {
      await _yalniz(tester, const {'rt_elestirmen': 89, 'rt_taze': true});
      expect(find.byKey(const Key('domates-taze')), findsOneWidget);
      expect(find.byKey(const Key('domates-curuk')), findsNothing);
      await _yalniz(tester, const {'rt_elestirmen': 40, 'rt_taze': false});
      expect(find.byKey(const Key('domates-curuk')), findsOneWidget);
      // `rt_taze` gelmezse eşik 60
      await _yalniz(tester, const {'rt_elestirmen': 60});
      expect(find.byKey(const Key('domates-taze')), findsOneWidget);
      await _yalniz(tester, const {'rt_seyirci': 97});
      expect(find.byKey(const Key('patlamis-misir')), findsOneWidget);
      expect(find.byType(DomatesIkonu), findsNothing);
    },
  );

  testWidgets('7) dokunma hedefi 44 dp', (tester) async {
    await _yalniz(tester, _tam);
    final boy = tester.getSize(find.byKey(const Key('dis-imdb'))).height;
    expect(boy, greaterThanOrEqualTo(44));
  });

  group('6) içerik sayfası', () {
    Future<void> kur(WidgetTester tester, Object? dis) async {
      DiziRenkler.acik = false;
      Api.istemci = MockClient((istek) async {
        final yol = istek.url.path.replaceFirst('/api', '');
        String govde = '{}';
        if (yol.startsWith('/tmdb/')) {
          govde = jsonEncode({
            'id': 278,
            'title': 'Esaretin Bedeli',
            'overview': 'Deneme',
            'release_date': '1994-09-23',
            'vote_average': 8.7,
            'poster_path': '/afis.jpg',
            'genres': const <dynamic>[],
            'seasons': const <dynamic>[],
          });
        } else if (yol.startsWith('/dis-puan/')) {
          expect(yol, '/dis-puan/movie/278');
          govde = jsonEncode({'dis': dis});
        }
        return http.Response(
          govde,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final yonlendirici = GoRouter(
        initialLocation: '/icerik/movie/278',
        routes: [
          GoRoute(
            path: '/icerik/:tur/:id',
            builder: (_, s) => DetayEkrani(
              tmdbId: int.parse(s.pathParameters['id']!),
              tur: s.pathParameters['tur']!,
            ),
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

    testWidgets('yanıt gelince rozetler TMDB puanıyla AYNI satırda', (
      tester,
    ) async {
      await kur(tester, _tam);
      expect(find.byKey(const Key('dis-imdb')), findsOneWidget);
      // Ayrı alt blok YOK: rozetler TMDB Wrap'inin içinde
      expect(find.byKey(const Key('dis-puanlar')), findsNothing);
      final tmdb = tester.getCenter(find.textContaining('TMDB'));
      final imdb = tester.getCenter(find.byKey(const Key('dis-imdb')));
      expect((imdb.dy - tmdb.dy).abs(), lessThan(4), reason: 'aynı satır');
      expect(imdb.dx, greaterThan(tmdb.dx), reason: 'TMDB\'den sonra');
    });

    testWidgets('dis:null → rozet yok, sayfa açık', (tester) async {
      await kur(tester, null);
      expect(find.byKey(const Key('dis-imdb')), findsNothing);
      expect(find.text('Esaretin Bedeli'), findsWidgets);
    });
  });
}
