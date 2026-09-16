import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/izlem_carki.dart';
import 'package:dizijpg/ekranlar/katalog_liste.dart';
import 'package:dizijpg/ekranlar/kesfet.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// RAF SAYFASINDA ÇARK + KANON RAFLARI (16 Eyl 2026).
///   1. Ana sayfa raf tablosunda 8 kanon rafı (film 100/250/500/1000, dizi
///      10/25/50/100), sunucu başlığıyla birebir; slug'ları ayrışıyor.
///   2. Katalog sayfasında liste dolunca sağ üstte çark; kanon rafında çark
///      TÜM listeyi (`adet=1000`) ve girişliyse `/izlenen-idler`i çeker,
///      çark sayfası açılır, "izlediklerimi gösterme" anahtarı vardır.
///   3. TMDB rafında (Sana Özel gibi) çark yüklenen kartlarla açılır,
///      `adet=1000` istenmez.

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

late List<String> istekler;

Map<String, dynamic> _kart(int id, {String tur = 'movie'}) => {
  'id': id,
  tur == 'movie' ? 'title' : 'name': 'Yapım $id',
  'poster_path': '/p$id.jpg',
  'vote_average': 8.1,
  'media_type': tur,
  'tmdb_id': id,
  'tur': tur,
  'izlenen': id.isEven,
};

void _sunucu() {
  istekler = [];
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    istekler.add('$yol?${istek.url.query}');
    if (yol.startsWith('/kanon/movie/100')) {
      final adet = int.tryParse(istek.url.queryParameters['adet'] ?? '') ?? 20;
      return _json({
        'results': [
          for (var i = 1; i <= (adet >= 100 ? 100 : 20); i++) _kart(i),
        ],
        'toplam': 100,
        'devam': adet < 100,
      });
    }
    if (yol == '/onerilen') {
      // Yalnız 1. sayfa dolu; katalog 20 kart görene kadar sayfalar, boş
      // sayfada durur.
      final sayfa = istek.url.queryParameters['sayfa'];
      return _json({
        'oneriler': sayfa == '1'
            ? [for (var i = 1; i <= 6; i++) _kart(i, tur: 'tv')]
            : <dynamic>[],
      });
    }
    if (yol == '/izlenen-idler')
      return _json({
        'movie': [1, 3],
        'tv': [],
      });
    if (yol == '/icerikler') {
      final a =
          (jsonDecode(istek.body) as Map<String, dynamic>)['anahtarlar']
              as List<dynamic>;
      return _json({
        'icerikler': {
          for (final k in a)
            k as String: {'id': int.parse(k.split(':')[1]), 'title': k},
        },
      });
    }
    return _json(const <String, dynamic>{});
  });
}

Future<void> _kur(WidgetTester tester, Widget ekran) async {
  _sunucu();
  DiziRenkler.acik = false;
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(600, 1200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: ekran));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('ana sayfa tablosunda 8 kanon rafı, başlık sunucuyla birebir', () {
    final kanon = anaSayfaRaflari.where((r) => r.$2.startsWith('/kanon/'));
    expect(kanon.length, 8);
    expect(
      kanon.map((r) => r.$1),
      containsAll([
        'Ölmeden İzlenmesi Gereken 100 Film',
        'Ölmeden İzlenmesi Gereken 1000 Film',
        'Ölmeden İzlenmesi Gereken 10 Dizi',
        'Ölmeden İzlenmesi Gereken 100 Dizi',
      ]),
    );
    // Serpiştirilmiş: ilk kanon rafı listenin başında değil, sonunda da değil.
    final indeksler = [
      for (var i = 0; i < anaSayfaRaflari.length; i++)
        if (anaSayfaRaflari[i].$2.startsWith('/kanon/')) i,
    ];
    expect(indeksler.first, greaterThan(1));
    // 2027 rafları en altta KALIR (raf_2027_test). 17 Eyl 2026'da kanon ile
    // 2027'nin arasına yıllık "en çok izlenen" rafları girdi; iddia sıra
    // SAYISINA değil SIRALAMAYA bakıyor artık (araya raf eklemek testi
    // kırmadan geçsin, ama 2027 dibe çakılı kalsın).
    final ikiBinYirmiYedi = [
      for (var i = 0; i < anaSayfaRaflari.length; i++)
        if (anaSayfaRaflari[i].$1.startsWith('2027')) i,
    ];
    expect(ikiBinYirmiYedi.length, 2);
    expect(ikiBinYirmiYedi.last, anaSayfaRaflari.length - 1);
    expect(indeksler.last, lessThan(ikiBinYirmiYedi.first));
    for (final r in kanon) {
      expect(rafBul(rafSlug(r.$1))?.$2, r.$2, reason: 'slug geri çözülür');
    }
  });

  // 17 Eyl 2026 — sitenin kendi izleme verisinden 6 raf. Başlık SUNUCUDAKİ
  // `populerBasligi()` ile birebir aynı olmalı: akıştaki rafın başlığına
  // dokunmak `/raf/<slug>`e gidiyor ve slug bu tabloda aranıyor.
  test('ana sayfa tablosunda 6 "en çok izlenen" rafı, slug geri çözülür', () {
    final populer = anaSayfaRaflari.where((r) => r.$2.startsWith('/populer/'));
    expect(populer.length, 6);
    expect(
      populer.map((r) => r.$2),
      containsAll([
        '/populer/hafta/movie',
        '/populer/hafta/tv',
        '/populer/ay/movie',
        '/populer/ay/tv',
        '/populer/yil/movie',
        '/populer/yil/tv',
      ]),
    );
    expect(
      populer.map((r) => r.$1),
      containsAll([
        "dizi.jpg'de Bu Hafta En Çok İzlenen 10 Film",
        "dizi.jpg'de 2026'da En Çok İzlenen 50 Dizi",
      ]),
    );
    for (final r in populer) {
      expect(rafBul(rafSlug(r.$1))?.$2, r.$2, reason: 'slug geri çözülür');
    }
    // Haftalık raf, TMDB'nin "Haftanın …" raflarının hemen ardında olmalı:
    // ikisi de "bu hafta" diyor, fark ancak yan yana okununca anlaşılıyor.
    final haftalik = anaSayfaRaflari.indexWhere(
      (r) => r.$2 == '/populer/hafta/movie',
    );
    expect(haftalik, 2);
  });

  testWidgets('kanon rafında çark: tüm liste + izlenen idler, anahtar var', (
    tester,
  ) async {
    await _kur(
      tester,
      const KatalogListeEkrani(
        baslik: 'Ölmeden İzlenmesi Gereken 100 Film',
        yol: '/kanon/movie/100',
        tur: 'movie',
      ),
    );
    final dugme = find.byKey(const Key('katalog-izlem-carki'));
    expect(dugme, findsOneWidget);
    await tester.tap(dugme);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(istekler.any((i) => i.contains('adet=1000')), isTrue);
    expect(istekler.any((i) => i.startsWith('/izlenen-idler')), isTrue);
    expect(find.byType(IzlemCarki), findsOneWidget);
    final cark = tester.widget<IzlemCarki>(find.byType(IzlemCarki));
    expect(cark.ogeler.length, 100, reason: 'çark TÜM listeyi alır');
    // id 1: sunucu bayrağı false ama /izlenen-idler {1,3} → BİRLEŞİM true;
    // id 2: sunucu bayrağı true (çift) → true; id 5 → false.
    expect(cark.ogeler[0]['izlenen'], isTrue);
    expect(cark.ogeler[1]['izlenen'], isTrue);
    expect(cark.ogeler[4]['izlenen'], isFalse);
    expect(find.byKey(const Key('cark-izlenen-gizle')), findsOneWidget);
  });

  testWidgets('Sana Özel: çark yüklenen kartlarla açılır, adet=1000 yok', (
    tester,
  ) async {
    await _kur(
      tester,
      const KatalogListeEkrani(
        baslik: 'Sana Özel',
        yol: '/onerilen',
        sayfaParam: 'sayfa',
        sonucAnahtari: 'oneriler',
      ),
    );
    await tester.tap(find.byKey(const Key('katalog-izlem-carki')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(istekler.any((i) => i.contains('adet=1000')), isFalse);
    final cark = tester.widget<IzlemCarki>(find.byType(IzlemCarki));
    expect(cark.ogeler.length, 6);
    expect(cark.ogeler.first['tur'], 'tv');
  });
}
