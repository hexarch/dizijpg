import 'dart:convert';
import 'dart:math' as math;

import 'package:dizijpg/api.dart';
import 'package:dizijpg/cark_efekti.dart';
import 'package:dizijpg/ekranlar/izlem_carki.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ÇARKTA "İZLEDİKLERİMİ GÖSTERME" (16 Eyl 2026 isteği: "bu çark da şu
/// seçenekte olacak: izlediklerimi gösterme seçeneği").
///   1. Öğelerde `izlenen` bayrağı varsa anahtar görünür; açınca izlenenler
///      havuzdan düşer (görünen liste küçülür), kapatınca geri gelir.
///   2. Süzgeçle birlikte çalışır (Film seçili + gizle → yalnız izlenmemiş
///      filmler).
///   3. Hepsi izlenmişse anahtar AÇILMAZ, SnackBar uyarır.
///   4. Bayraksız öğelerde (İzleyeceğim çarkı) anahtar YOK — eski davranış.

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _sunucu() {
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
    return _json(const <String, dynamic>{});
  });
}

Map<String, dynamic> _oge(String tur, int id, {bool? izlenen}) => {
  'tur': tur,
  'tmdb_id': id,
  if (izlenen != null) 'izlenen': izlenen,
};

Future<dynamic> _kur(
  WidgetTester tester,
  List<Map<String, dynamic>> ogeler,
) async {
  _sunucu();
  DiziRenkler.acik = false;
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(600, 1200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: IzlemCarki(
          ogeler: ogeler,
          rastgele: math.Random(1),
          efekt: SessizCarkEfekti(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return tester.state(find.byType(IzlemCarki)) as dynamic;
}

void main() {
  testWidgets('bayrak varsa anahtar var; açınca izlenenler düşer', (
    tester,
  ) async {
    final s = await _kur(tester, [
      _oge('movie', 1, izlenen: true),
      _oge('movie', 2, izlenen: false),
      _oge('tv', 3, izlenen: true),
      _oge('tv', 4, izlenen: false),
    ]);
    final anahtar = find.byKey(const Key('cark-izlenen-gizle'));
    expect(anahtar, findsOneWidget);
    expect((s.gorunenListe as List).length, 4);
    await tester.tap(anahtar);
    await tester.pump();
    expect((s.gorunenListe as List).map((o) => o['tmdb_id']), [2, 4]);
    // Süzgeçle birlikte: yalnız izlenmemiş filmler.
    await tester.tap(find.byKey(const Key('cark-suzgec-movie')));
    await tester.pump();
    expect((s.gorunenListe as List).map((o) => o['tmdb_id']), [2]);
    // Kapatınca filmlerin hepsi geri gelir.
    await tester.tap(anahtar);
    await tester.pump();
    expect((s.gorunenListe as List).map((o) => o['tmdb_id']), [1, 2]);
  });

  testWidgets('hepsi izlenmişse anahtar açılmaz, SnackBar uyarır', (
    tester,
  ) async {
    final s = await _kur(tester, [
      _oge('movie', 1, izlenen: true),
      _oge('tv', 2, izlenen: true),
    ]);
    await tester.tap(find.byKey(const Key('cark-izlenen-gizle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bu listede izlemediğin yapım kalmamış'), findsOneWidget);
    expect((s.gorunenListe as List).length, 2, reason: 'havuz boşalmadı');
  });

  testWidgets('bayraksız öğelerde anahtar yok (İzleyeceğim çarkı aynı)', (
    tester,
  ) async {
    await _kur(tester, [_oge('movie', 1), _oge('tv', 2)]);
    expect(find.byKey(const Key('cark-izlenen-gizle')), findsNothing);
    expect(find.byKey(const Key('cark-suzgec-movie')), findsOneWidget);
  });
}
