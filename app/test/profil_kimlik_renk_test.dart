import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/bayrak.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// KULLANICI İSTEĞİ (16 Ağu 2026): profildeki kullanıcı adı ve gri
/// kullanılan etiketler (bio, ülke, takipçi/beğeni yazıları) koyu temada
/// beyaz olsun. `Colors.white` sabitlenmez — açık temada `metin` koyudur.
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
        return _json({
          'tahmini_dakika': 90,
          'dizi': 0,
          'film': 0,
          'takipci_sayisi': 3,
          'takip_sayisi': 1,
          'toplam_begeni': 4,
          'toplam_goruntulenme': 8,
          'izlenen_bolum': 0,
          'izlenen_film': 0,
          'takip_edilen_dizi': 0,
          'yorum_sayisi': 0,
        });
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
          'bio': 'dizileri izlerim',
          'ulke': 'Türkiye',
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

  testWidgets('KOYU tema: kullanıcı adı, bio ve ülke beyaz', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: Oturum()
          ..kullanici = {'id': 7, 'kullanici_adi': 'testkullanici'},
        child: MaterialApp(
          theme: diziTema(acik: false),
          home: const ProfilEkrani(),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final ad = find.descendant(
      of: find.byType(ProfilUstBolum),
      matching: find.text('@testkullanici'),
    );
    expect(ad, findsOneWidget);
    expect(
      tester.widget<Text>(ad).style?.color,
      DiziRenkler.metin,
      reason: 'kullanıcı adı koyu temada beyaz',
    );
    expect(
      tester.widget<Text>(find.text('dizileri izlerim')).style?.color,
      DiziRenkler.metin,
    );
    // 28 Ağu 2026: profilde ülke ADI artık METİN olarak çizilmiyor — bayrak
    // kullanıcı adının yanına taşındı, ad ipucuna geçti. Rengi ölçülecek bir
    // ülke metni kalmadı; bayrağın çizildiğini doğrulamak yeter (metin rengi
    // aşağıdaki `UlkeSatiri` testinde kilitli kalmaya devam ediyor).
    expect(find.byType(UlkeBayragi), findsOneWidget);
    expect(find.text('Türkiye'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KOYU tema: ülke satırı gri değil', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: const Scaffold(body: UlkeSatiri(ulke: 'Türkiye')),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Türkiye')).style?.color,
      DiziRenkler.metin,
    );
  });

  testWidgets('KOYU tema: beğeni/görüntülenme etiketleri beyaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: const Scaffold(
          body: EtkilesimSatiri(begeni: 12, goruntulenme: 34),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Beğeni')).style?.color,
      DiziRenkler.metin,
    );
    expect(
      tester.widget<Text>(find.text('Görüntülenme')).style?.color,
      DiziRenkler.metin,
    );
  });
}
