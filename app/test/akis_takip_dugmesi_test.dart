import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Akış kartındaki "Takip Et" düğmesi (31 Ağu 2026: dolu blok "çok büyük"
/// bulundu, ince çerçeveli hapa çevrildi). Kilitler:
///   1. Takip edilmeyen yabancının kartında düğme ÇERÇEVELİ (OutlinedButton)
///      olarak çizilir — dolu FilledButton'a geri dönülmesin.
///   2. Dokununca takip isteği atılır ve düğme kaybolur (iyimser).
///   3. Zaten takip edilen kişinin kartında düğme yoktur.
Map<String, dynamic> _gonderi({bool? takipEdiyorum = false}) => {
  'id': 55,
  'kullanici_id': 42,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'metin': 'Test gönderisi',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': const <String>[],
  'begeni': 3,
  'begendim': false,
  'yanit': 0,
  'goruntulenme': 9,
  'spoiler': false,
  'tarih': '2026-08-03T10:00:00Z',
  'kaynak_dil': 'tr',
  'ceviri_var': false,
  'cevrildi': false,
  'takip_ediyorum': takipEdiyorum,
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
};

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

var _takipIstekleri = 0;

void _sunucu() {
  _takipIstekleri = 0;
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.contains('/takip/')) {
      _takipIstekleri++;
      return _json({'takip': true});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<void> _kartKur(WidgetTester tester, Map<String, dynamic> yorum) async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(800, 900);
  addTearDown(tester.view.reset);
  final oturum = Oturum();
  await oturum.yukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AkisKarti(yorum: yorum, icerikler: _icerikler),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('yabancının kartında çerçeveli Takip Et hapı çizilir', (
    tester,
  ) async {
    _sunucu();
    await _kartKur(tester, _gonderi());
    final dugme = find.widgetWithText(OutlinedButton, 'Takip Et');
    expect(dugme, findsOneWidget);
    // Dolu bloğa geri dönüş regresyonu: FilledButton OLMAMALI.
    expect(find.widgetWithText(FilledButton, 'Takip Et'), findsNothing);

    await tester.tap(dugme);
    await tester.pumpAndSettle();
    expect(_takipIstekleri, 1);
    expect(find.widgetWithText(OutlinedButton, 'Takip Et'), findsNothing);
  });

  testWidgets('takip edilen kişinin kartında düğme yok', (tester) async {
    _sunucu();
    await _kartKur(tester, _gonderi(takipEdiyorum: true));
    expect(find.text('Takip Et'), findsNothing);
  });
}
