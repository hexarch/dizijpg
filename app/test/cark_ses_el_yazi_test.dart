// İzlem çarkı: ses, elle çevirme, liste büyüdükçe küçülen yazı.
//
// Kullanıcı (29 Ağu 2026): "oraya güzel bir çark sesi eklemelisin, dönerken
// hiç çark yok; ve elle de çevrilebilmeli, çevir butonu saçma; ve liste
// büyünce yazılar gözükmüyor, yazının fontu da küçülmeli."
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/cark_efekti.dart';
import 'package:dizijpg/ekranlar/izlem_carki.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Kart bilgisi sunucusu — çark adları buradan gelir, yoksa widget
/// "yükleniyor" durumunda kalır ve gövde hiç çizilmez.
void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (yol == '/icerikler') {
      final anahtarlar =
          (jsonDecode(istek.body) as Map<String, dynamic>)['anahtarlar']
              as List<dynamic>;
      return http.Response(
        jsonEncode({
          'icerikler': {
            for (final a in anahtarlar)
              a as String: {
                'id': int.parse(a.split(':')[1]),
                'title': 'İçerik $a',
                'poster_path': null,
                'vote_average': 7.5,
              },
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response(
      '{}',
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

void main() {
  group('yazı ölçüsü', () {
    test('punto liste büyüdükçe ASLA ARTMAZ, dar dilimde KÜÇÜLÜR', () {
      const yaricap = 180.0;
      // Monotonluk: hiçbir adımda büyümemeli.
      var onceki = carkYaziOlcusu(2, yaricap).punto;
      for (final n in [6, 12, 24, 32, 40, 60, 100]) {
        final p = carkYaziOlcusu(n, yaricap).punto;
        expect(p, lessThanOrEqualTo(onceki), reason: 'n=$n punto büyüdü');
        onceki = p;
      }
      // Dilim gerçekten daraldığında küçülme GÖRÜNÜR olmalı.
      expect(
        carkYaziOlcusu(60, yaricap).punto,
        lessThan(carkYaziOlcusu(24, yaricap).punto),
        reason: '60 dilimde yazı 24 dilimdekinden küçük olmalı',
      );
    });

    test('punto okunur bir tabanın ALTINA inmez', () {
      // 7 dp altı okunmuyor; o noktadan sonra kısaltma devreye girer.
      for (final n in [30, 60, 120, 400]) {
        expect(carkYaziOlcusu(n, 180).punto, greaterThanOrEqualTo(7.0));
      }
    });

    test('punto gereksiz BÜYÜMEZ (az dilimde tavan)', () {
      expect(carkYaziOlcusu(2, 400).punto, lessThanOrEqualTo(13.0));
    });

    test('harf sınırı her zaman okunur bir aralıkta', () {
      // Punto küçüldükçe AYNI yarıçapa daha çok harf sığar — sınır artar,
      // azalmaz. Önemli olan hiçbir durumda saçma bir değere düşmemesi.
      for (final n in [2, 6, 24, 60, 200]) {
        final h = carkYaziOlcusu(n, 180).azamiHarf;
        expect(h, greaterThanOrEqualTo(4), reason: 'n=$n çok az harf');
        expect(h, lessThanOrEqualTo(22), reason: 'n=$n sınır tavanı aştı');
      }
    });

    test('17+ dilimde de ölçü ÜRETİLİR (eski n<=16 kesmesi yok)', () {
      // Eskiden 17. yapımdan itibaren adlar HİÇ çizilmiyordu.
      for (final n in [16, 17, 25, 50]) {
        final o = carkYaziOlcusu(n, 180);
        expect(o.punto, greaterThan(0));
        expect(o.azamiHarf, greaterThan(0));
      }
    });
  });

  group('ses efekti', () {
    test('sessiz efekt tıkları SAYAR (testte ses çalınmaz)', () {
      final e = SessizCarkEfekti();
      expect(e.tikSayisi, 0);
      e.tik();
      e.tik();
      e.durdu();
      expect(e.tikSayisi, 2);
      expect(e.durduSayisi, 1);
    });
  });

  group('çark widget', () {
    final ogeler = [
      for (var i = 0; i < 8; i++)
        {'tur': 'movie', 'tmdb_id': 100 + i, 'ad': 'Film $i'},
    ];

    testWidgets('"Çarkı çevir" DÜĞMESİ YOK, yerine ipucu var', (tester) async {
      _sunucu();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IzlemCarki(ogeler: ogeler, efekt: SessizCarkEfekti()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('cark-cevir')),
        findsNothing,
        reason: 'düğme kaldırıldı — çarkın kendisi çevriliyor',
      );
      expect(find.byKey(const Key('cark-ipucu')), findsOneWidget);
    });

    testWidgets('SÜRÜKLEMEK çarkı döndürür ve TIK çalar', (tester) async {
      _sunucu();
      final efekt = SessizCarkEfekti();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IzlemCarki(ogeler: ogeler, efekt: efekt),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cark = find.byKey(const Key('izlem-carki-cark'));
      expect(cark, findsOneWidget);

      // Merkezin sağından yukarı doğru yay çiz: çarkı çevirir.
      final merkez = tester.getCenter(cark);
      final tut = await tester.startGesture(merkez + const Offset(90, 0));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tut.moveBy(const Offset(-6, -22));
      }
      await tut.up();
      await tester.pump();

      expect(
        efekt.tikSayisi,
        greaterThan(0),
        reason: 'elle çevirirken dilim geçilince tık çalmalı',
      );
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });
  });
}
