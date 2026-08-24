import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/izlem_carki.dart';
import 'package:dizijpg/ekranlar/liste.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Çark kullanıcı listelerinde de (24 Ağu 2026 isteği: "web'de kendi
/// oluşturduğum listemde neden çark yok?"). Kilitler:
///   1. Tam sayfa listede (/listeler/:id) öğeler yüklenince çark düğmesi
///      belirir; dokununca çark açılır.
///   2. Profil modalindeki listede ([ListeSheet]) de aynı düğme var.
///   3. Boş listede düğme çizilmez.
http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _sunucu({List<Map<String, dynamic>>? ogeler}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (yol.startsWith('/listeler/')) {
      return _json({
        'id': 8,
        'ad': 'Bilimkurgu',
        'kullanici_adi': 'melis',
        'sahibiyim': true,
        'ogeler':
            ogeler ??
            [
              {'tur': 'tv', 'tmdb_id': 100, 'gizli': false},
              {'tur': 'movie', 'tmdb_id': 200, 'gizli': false},
            ],
      });
    }
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
    return _json(const <String, dynamic>{});
  });
}

Future<void> _kur(WidgetTester tester, Widget ekran) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/e',
        routes: [GoRoute(path: '/e', builder: (_, _) => ekran)],
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('tam sayfa listede çark düğmesi var ve çarkı açar', (
    tester,
  ) async {
    _sunucu();
    await _kur(tester, const ListeEkrani(listeId: 8));
    expect(find.byKey(const Key('liste-izlem-carki')), findsOneWidget);

    await tester.tap(find.byKey(const Key('liste-izlem-carki')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(IzlemCarki), findsOneWidget);
  });

  testWidgets('liste modalinde de çark düğmesi var', (tester) async {
    _sunucu();
    // Modal gerçekte showModalBottomSheet içinde açılır (Material atası
    // oradan gelir); testte aynı zemini Scaffold sağlar.
    await _kur(
      tester,
      const Scaffold(body: ListeSheet(listeId: 8, ad: 'Bilimkurgu')),
    );
    expect(find.byKey(const Key('liste-sheet-izlem-carki')), findsOneWidget);
  });

  testWidgets('boş listede çark düğmesi çizilmez', (tester) async {
    _sunucu(ogeler: const []);
    await _kur(tester, const ListeEkrani(listeId: 8));
    expect(find.byKey(const Key('liste-izlem-carki')), findsNothing);
  });
}
