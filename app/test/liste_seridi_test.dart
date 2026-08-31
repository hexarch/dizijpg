import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profildeki kullanıcı listeleri poster ŞERİDİ olarak (31 Ağu 2026 isteği:
/// "oluşturduğum liste de diğerleri gibi gözüksün"). Kilitler:
///   1. Şerit, liste adını + öğe sayısını basar ve öğeler için MiniIcerik çizer.
///   2. Başlığa dokunmak listeyi açar (onAc).
///   3. Silme düğmesi yalnız onSil verilince (kendi profili) çizilir.
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

const _liste = {
  'id': 8,
  'ad': 'Bilimkurgu',
  'oge_sayisi': 2,
  'ogeler': [
    {'tur': 'tv', 'tmdb_id': 100},
    {'tur': 'movie', 'tmdb_id': 200},
  ],
};

Future<void> _kur(WidgetTester tester, Widget cocuk) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: cocuk)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('şerit ad+sayı basar ve öğeler için MiniIcerik çizer', (
    tester,
  ) async {
    _sunucu();
    await _kur(tester, ListeSeridi(liste: _liste, onAc: () {}));
    expect(find.text('Bilimkurgu (2)'), findsOneWidget);
    expect(find.byType(MiniIcerik), findsNWidgets(2));
  });

  testWidgets('başlığa dokunmak listeyi açar', (tester) async {
    _sunucu();
    var acildi = 0;
    await _kur(tester, ListeSeridi(liste: _liste, onAc: () => acildi++));
    await tester.tap(find.byKey(const Key('liste-seridi-baslik')));
    expect(acildi, 1);
  });

  testWidgets('silme düğmesi yalnız onSil verilince çizilir', (tester) async {
    _sunucu();
    await _kur(tester, ListeSeridi(liste: _liste, onAc: () {}));
    expect(find.byKey(const Key('liste-seridi-sil')), findsNothing);

    var silindi = 0;
    await _kur(
      tester,
      ListeSeridi(liste: _liste, onAc: () {}, onSil: () => silindi++),
    );
    expect(find.byKey(const Key('liste-seridi-sil')), findsOneWidget);
    await tester.tap(find.byKey(const Key('liste-seridi-sil')));
    expect(silindi, 1);
  });

  testWidgets('boş listede şerit çizilmez, başlık kalır', (tester) async {
    _sunucu();
    await _kur(
      tester,
      ListeSeridi(
        liste: const {'id': 9, 'ad': 'Boş', 'oge_sayisi': 0, 'ogeler': []},
        onAc: () {},
      ),
    );
    expect(find.text('Boş (0)'), findsOneWidget);
    expect(find.byType(MiniIcerik), findsNothing);
  });
}
