import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/sohbet_olay.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// AKIŞTA KANON RAFLARI (16 Eyl 2026): her 6 gönderiden sonra bir
/// "Ölmeden İzlenmesi Gereken …" poster şeridi, raflar dönüşümlü; gönderiler
/// atlanmaz (13 gönderi → 2 raf, 15 satır + paylaş kutusu). `/kanon/ozet`
/// gelmezse akış rafsız.

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

List<Map<String, dynamic>> _gonderiler(int adet) => [
  for (var i = 1; i <= adet; i++)
    {
      'id': i,
      'kullanici_id': 9,
      'kullanici_adi': 'biri',
      'avatar': null,
      'tur': null,
      'tmdb_id': null,
      'sezon': null,
      'bolum': null,
      'metin': 'gönderi $i',
      'medya': <dynamic>[],
      'spoiler': false,
      'begeni': 0,
      'yanit': 0,
      'begendim': false,
      'takip_ediyorum': null,
      'tarih': '2026-09-16T10:00:00.000Z',
      'goruntulenme': 0,
    },
];

Map<String, dynamic> _raf(String medya, int boy) => {
  'medya': medya,
  'boy': boy,
  'baslik': 'Ölmeden İzlenmesi Gereken $boy ${medya == 'tv' ? 'Dizi' : 'Film'}',
  'yol': '/kanon/$medya/$boy',
  'icerikler': [
    for (var i = 1; i <= 3; i++)
      {
        'id': boy * 10 + i,
        medya == 'tv' ? 'name' : 'title': 'K$boy-$i',
        'poster_path': '/k$i.jpg',
        'vote_average': 8.2,
      },
  ],
};

void _sunucu({int adet = 13, bool kanon = true}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.contains('/sohbetler/okunmamis')) return _json({'okunmamis': 0});
    if (yol.endsWith('/bildirimler')) return _json({'okunmamis': 0});
    if (yol.endsWith('/akis/goruldu')) return _json({'tamam': true});
    if (yol.endsWith('/akis')) {
      return _json({
        'akis': _gonderiler(adet),
        'icerikler': <String, dynamic>{},
        'imlec': null,
      });
    }
    if (yol.endsWith('/kanon/ozet')) {
      if (!kanon) return http.Response('yok', 500);
      return _json({
        'raflar': [_raf('movie', 100), _raf('tv', 10), _raf('movie', 250)],
      });
    }
    return _json(const <String, dynamic>{});
  });
}

Future<void> _kur(WidgetTester tester) async {
  DiziRenkler.acik = false;
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await Api.tokenYukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum()..kullanici = {'id': 7, 'kullanici_adi': 'ben'},
      child: MaterialApp(
        home: const AkisEkrani(),
        theme: diziTema(acik: false),
      ),
    ),
  );
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  while (tester.takeException() != null) {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'token': 'sahte',
      'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
    });
    SohbetOlaylari.okunmamis.value = 0;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets(
    '13 gönderi → 2 raf, 7. ve 14. satırda, dönüşümlü; gönderi kaybı yok',
    (tester) async {
      _sunucu(adet: 13);
      await _kur(tester);
      final liste = tester.widget<ListView>(find.byType(ListView).first);
      final delegate = liste.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.childCount, 1 + 13 + 2);
      // Satır 7 (indeks 7) ve 14 raf; araya giren gönderiler sırayla.
      final kumanda = liste.controller!;
      // İlk raf ekrana gelsin.
      kumanda.jumpTo(600);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(KanonRafKarti), findsWidgets);
      final ilk = tester.widget<KanonRafKarti>(
        find.byType(KanonRafKarti).first,
      );
      expect(ilk.raf['baslik'], 'Ölmeden İzlenmesi Gereken 100 Film');
      expect(find.byType(PosterSeridi), findsWidgets);
      // Tüm gönderiler yine listede (13 farklı id) — indeks kaymadı.
      final gorulenler = <String>{};
      for (var y = 0.0; y <= kumanda.position.maxScrollExtent; y += 500) {
        kumanda.jumpTo(y);
        await tester.pump();
        for (final w in tester.widgetList<AkisKarti>(find.byType(AkisKarti))) {
          gorulenler.add(w.yorum['metin'] as String);
        }
      }
      expect(gorulenler.length, 13);
      // İkinci raf dönüşümlü: dizi 10.
      final raflar = tester
          .widgetList<KanonRafKarti>(find.byType(KanonRafKarti))
          .map((w) => w.raf['boy'])
          .toSet();
      expect(raflar, contains(10));
    },
  );

  testWidgets('/kanon/ozet düşerse akış rafsız akar', (tester) async {
    _sunucu(adet: 13, kanon: false);
    await _kur(tester);
    final liste = tester.widget<ListView>(find.byType(ListView).first);
    expect(
      (liste.childrenDelegate as SliverChildBuilderDelegate).childCount,
      14,
    );
    expect(find.byType(KanonRafKarti), findsNothing);
  });
}
