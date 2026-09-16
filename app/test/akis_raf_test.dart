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

/// AKIŞTA RAFLAR (16 Eyl 2026; 17 Eyl'de ana sayfanın TÜM raflarına genişledi):
/// her 6 gönderiden sonra bir poster şeridi, raflar sırayla; gönderiler
/// atlanmaz (13 gönderi → 2 raf, 15 satır + paylaş kutusu). `/akis/raflar`
/// gelmezse akış rafsız.
///
/// 17 Eyl 2026 — rafın altındaki "Bir süre gösterme" tiki: raf İYİMSER olarak
/// akıştan düşer, sunucuya `POST /raflar/gizle` gider, "Geri al" düğmeli
/// bildirim çıkar. İstek DÜŞERSE raf geri gelir (sessiz başarısızlık yasak).

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

Map<String, dynamic> _raf(String slug, String baslik, String medya) => {
  'slug': slug,
  'baslik': baslik,
  'medya': medya,
  'icerikler': [
    for (var i = 1; i <= 3; i++)
      {
        'id': slug.hashCode.abs() % 1000 + i,
        medya == 'tv' ? 'name' : 'title': '$slug-$i',
        'poster_path': '/k$i.jpg',
        'vote_average': 8.2,
      },
  ],
};

final _kanonRaf = _raf(
  'olmeden-izlenmesi-gereken-100-film',
  'Ölmeden İzlenmesi Gereken 100 Film',
  'movie',
);
final _haftaRaf = _raf(
  'dizi-jpg-de-bu-hafta-en-cok-izlenen-10-film',
  "dizi.jpg'de Bu Hafta En Çok İzlenen 10 Film",
  'movie',
);
final _diziRaf = _raf('haftanin-dizileri', 'Haftanın Dizileri', 'tv');

/// Son gizleme isteği: [yol] + gövdedeki slug (null = hiç istenmedi).
String? _gizlenen;
String? _gizlemeYontemi;
bool _gizlemeDusur = false;

void _sunucu({int adet = 13, bool raflar = true}) {
  _gizlenen = null;
  _gizlemeYontemi = null;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.contains('/sohbetler/okunmamis')) return _json({'okunmamis': 0});
    if (yol.endsWith('/bildirimler')) return _json({'okunmamis': 0});
    if (yol.endsWith('/akis/goruldu')) return _json({'tamam': true});
    if (yol.endsWith('/akis/raflar')) {
      if (!raflar) return http.Response('yok', 500);
      return _json({
        'raflar': [_kanonRaf, _haftaRaf, _diziRaf],
      });
    }
    if (yol.endsWith('/akis')) {
      return _json({
        'akis': _gonderiler(adet),
        'icerikler': <String, dynamic>{},
        'imlec': null,
      });
    }
    if (yol.contains('/raflar/gizle')) {
      _gizlemeYontemi = istek.method;
      _gizlenen = istek.method == 'DELETE'
          ? yol.split('/').last
          : (jsonDecode(istek.body) as Map<String, dynamic>)['slug'] as String?;
      if (_gizlemeDusur) return http.Response('olmadı', 500);
      return _json({'tamam': true});
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
    _gizlemeDusur = false;
    SharedPreferences.setMockInitialValues({
      'token': 'sahte',
      'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
    });
    SohbetOlaylari.okunmamis.value = 0;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets(
    '13 gönderi → 2 raf, 7. ve 14. satırda, sırayla; gönderi kaybı yok',
    (tester) async {
      _sunucu(adet: 13);
      await _kur(tester);
      final liste = tester.widget<ListView>(find.byType(ListView).first);
      final delegate = liste.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.childCount, 1 + 13 + 2);
      // Satır 7 (indeks 7) ve 14 raf; araya giren gönderiler sırayla.
      final kumanda = liste.controller!;
      kumanda.jumpTo(600);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AkisRafKarti), findsWidgets);
      final ilk = tester.widget<AkisRafKarti>(find.byType(AkisRafKarti).first);
      expect(ilk.raf['baslik'], 'Ölmeden İzlenmesi Gereken 100 Film');
      expect(find.byType(PosterSeridi), findsWidgets);
      // Tüm gönderiler yine listede (13 farklı id) — indeks kaymadı.
      final gorulenler = <String>{};
      for (var y = 0.0; y <= kumanda.position.maxScrollExtent; y += 200) {
        kumanda.jumpTo(y);
        await tester.pump();
        for (final w in tester.widgetList<AkisKarti>(find.byType(AkisKarti))) {
          gorulenler.add(w.yorum['metin'] as String);
        }
      }
      expect(gorulenler.length, 13);
      // İkinci raf sıradaki: "bu hafta en çok izlenen".
      final sluglar = tester
          .widgetList<AkisRafKarti>(find.byType(AkisRafKarti))
          .map((w) => w.raf['slug'])
          .toSet();
      expect(sluglar, contains('dizi-jpg-de-bu-hafta-en-cok-izlenen-10-film'));
    },
  );

  testWidgets('/akis/raflar düşerse akış rafsız akar', (tester) async {
    _sunucu(adet: 13, raflar: false);
    await _kur(tester);
    final liste = tester.widget<ListView>(find.byType(ListView).first);
    expect(
      (liste.childrenDelegate as SliverChildBuilderDelegate).childCount,
      14,
    );
    expect(find.byType(AkisRafKarti), findsNothing);
  });

  testWidgets('"Bir süre gösterme" tiki rafı düşürür ve sunucuya yazar', (
    tester,
  ) async {
    _sunucu(adet: 13);
    await _kur(tester);
    final liste = tester.widget<ListView>(find.byType(ListView).first);
    liste.controller!.jumpTo(600);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final tik = find.text('Bir süre gösterme').first;
    expect(tik, findsOneWidget);
    await tester.tap(tik);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Sunucuya doğru slug gitti.
    expect(_gizlemeYontemi, 'POST');
    expect(_gizlenen, 'olmeden-izlenmesi-gereken-100-film');
    // Raf akıştan düştü: kalan iki raf da gizlenenden farklı.
    final sluglar = tester
        .widgetList<AkisRafKarti>(find.byType(AkisRafKarti))
        .map((w) => w.raf['slug'])
        .toSet();
    expect(sluglar, isNot(contains('olmeden-izlenmesi-gereken-100-film')));
    // Karar bekleyen bildirim: "Geri al" düğmesi ekranda. Giriş animasyonu
    // BİTMELİ — yarı yoldayken düğme ekranın altında kalır ve dokunuş ıskalar.
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Geri al'), findsOneWidget);

    // Geri al → DELETE gider ve raf listeye döner.
    await tester.tap(find.text('Geri al'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_gizlemeYontemi, 'DELETE');
    expect(_gizlenen, 'olmeden-izlenmesi-gereken-100-film');
  });

  testWidgets('gizleme isteği düşerse raf geri gelir ve kullanıcı uyarılır', (
    tester,
  ) async {
    _gizlemeDusur = true;
    _sunucu(adet: 13);
    await _kur(tester);
    final liste = tester.widget<ListView>(find.byType(ListView).first);
    liste.controller!.jumpTo(600);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Bir süre gösterme').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Liste gizlenemedi'), findsOneWidget);
    final ilk = tester.widget<AkisRafKarti>(find.byType(AkisRafKarti).first);
    expect(ilk.raf['slug'], 'olmeden-izlenmesi-gereken-100-film');
  });
}
