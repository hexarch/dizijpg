import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// KULLANICI İSTEĞİ (16 Ağu 2026): profildeki "Toplam İzleme Süresi"
/// yazısı gri (metin54) olmasın, koyu temada beyaz olsun.
http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    DiziRenkler.acik = false;
    SharedPreferences.setMockInitialValues({
      'token': 'sahte',
      'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'testkullanici'}),
    });
    await Api.tokenYukle();
    Api.istemci = MockClient((istek) async {
      final yol = istek.url.path.replaceFirst('/api', '');
      if (yol.startsWith('/istatistiklerim')) {
        return _json({'tahmini_dakika': 90, 'dizi': 0, 'film': 0});
      }
      if (yol.startsWith('/kitapligim')) {
        return _json({'durumlar': <dynamic>[]});
      }
      if (yol.startsWith('/listelerim')) {
        return _json({'listeler': <dynamic>[]});
      }
      if (yol.startsWith('/profilim')) {
        return _json({
          'id': 7,
          'kullanici_adi': 'testkullanici',
          'avatar': null,
          'kapak': null,
          'bio': null,
          'ulke': null,
          'sosyal': <dynamic>[],
        });
      }
      if (yol.startsWith('/izlediklerim')) {
        return _json({'ogeler': <dynamic>[]});
      }
      if (yol.startsWith('/rozetler')) {
        return _json({'rozetler': <dynamic>[]});
      }
      if (yol.startsWith('/profil/')) {
        return _json({
          'yorumlar': <dynamic>[],
          'icerikler': <String, dynamic>{},
        });
      }
      return _json(const {});
    });
  });

  tearDown(() => DiziRenkler.acik = false);

  testWidgets('KOYU tema: Toplam İzleme Süresi yazısı beyaz', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: Oturum(),
        child: MaterialApp(
          theme: diziTema(acik: false),
          home: const ProfilEkrani(),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final yazi = tester.widget<Text>(find.text('Toplam İzleme Süresi'));
    expect(yazi.style?.color, Colors.white);
    expect(tester.takeException(), isNull);
  });
}
