import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/liste.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Liste paylaşımı (31 Ağu 2026 isteği: "profildeki listeler Spotify gibi
/// paylaşılabilsin"). Kilitler:
///   1. Tam sayfa listede (/listeler/:id) paylaş düğmesi var; dokununca
///      paylaşım sayfası (kişilere gönder + bağlantıyı kopyala) açılır.
///   2. Profil modalindeki listede ([ListeSheet]) de aynı düğme var.
///   3. GİZLİ (herkese_acik=false) listede düğme çizilmez: bağlantıyı alan
///      yabancı 404 görürdü.
http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _sunucu({bool herkeseAcik = true}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (yol == '/paylas-hedefler') return _json({'kullanicilar': []});
    if (yol.startsWith('/listeler/')) {
      return _json({
        'id': 8,
        'ad': 'Bilimkurgu',
        'kullanici_adi': 'melis',
        'herkese_acik': herkeseAcik,
        'sahibiyim': true,
        'ogeler': [
          {'tur': 'tv', 'tmdb_id': 100, 'gizli': false},
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
  testWidgets('tam sayfa listede paylaş düğmesi var ve sayfayı açar', (
    tester,
  ) async {
    _sunucu();
    await _kur(tester, const ListeEkrani(listeId: 8));
    expect(find.byKey(const Key('liste-paylas')), findsOneWidget);

    await tester.tap(find.byKey(const Key('liste-paylas')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Paylaşım sayfasının kanıtı dile bağlanmaz (test cihazın diliyle koşar):
    // "bağlantıyı kopyala" düğmesinin ikonu aranır.
    expect(find.byIcon(Icons.link), findsOneWidget);
  });

  testWidgets('liste modalinde de paylaş düğmesi var', (tester) async {
    _sunucu();
    await _kur(
      tester,
      const Scaffold(body: ListeSheet(listeId: 8, ad: 'Bilimkurgu')),
    );
    expect(find.byKey(const Key('liste-paylas')), findsOneWidget);
  });

  testWidgets('gizli listede paylaş düğmesi çizilmez', (tester) async {
    _sunucu(herkeseAcik: false);
    await _kur(tester, const ListeEkrani(listeId: 8));
    expect(find.byKey(const Key('liste-paylas')), findsNothing);
  });
}
