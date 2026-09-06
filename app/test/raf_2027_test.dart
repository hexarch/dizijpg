import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/katalog_liste.dart';
import 'package:dizijpg/ekranlar/kesfet.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "2027'de vizyona girecek filmler ve diziler" rafları (6 Eyl 2026).
///
/// KULLANICI İSTEĞİ: "2027 vizyona girecek filmler ve diziler listesi yap ana
/// sayfada aşağılara ekle."
///
/// Bu testin kilitlediği üç karar:
///  1. Raflar Ana Sayfa'nın EN ALTINDA (istek "aşağılara ekle" idi),
///  2. Sorguda OY EŞİĞİ YOK — vizyona girmemiş yapımın oyu da yoktur,
///     `vote_count.gte` eklemek iki rafı da BOŞALTIRDI,
///  3. Afişsiz kayıtlar şeride girmez (`posterliSuz`): 2027 kataloğunda
///     afişsiz kayıt oranı yüksek ve gri kutu "veri gelmedi" gibi okunuyor.

Map<String, dynamic> _yapim(int id, {String? afis = '/p.jpg'}) => {
  'id': id,
  'name': 'Yapım $id',
  'title': 'Yapım $id',
  'poster_path': afis,
  'vote_average': 0.0,
  'vote_count': 0,
};

/// Keşfet'in çektiği her yolu karşılayan sahte istemci.
///
/// `afissizAdet` kadar kayıt AFİŞSİZ döner: süzgecin gerçekten çalıştığı
/// yalnız böyle kanıtlanır.
http.Client _sahteIstemci({int adet = 6, int afissizAdet = 0}) =>
    MockClient((istek) async {
      final yol = istek.url.path;
      Object govde = <String, dynamic>{};
      if (yol.startsWith('/api/tmdb/')) {
        govde = {
          'results': [
            for (var i = 0; i < adet; i++)
              _yapim(i + 1, afis: i < afissizAdet ? null : '/p$i.jpg'),
          ],
        };
      } else if (yol.endsWith('/onerilen')) {
        govde = {'oneriler': <dynamic>[]};
      }
      return http.Response(
        jsonEncode(govde),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.sec('tr');
  });

  tearDown(() {
    Api.istemci = http.Client();
  });

  test('2027 rafları listede VAR ve EN ALTTA (istek: "aşağılara ekle")', () {
    final basliklar = anaSayfaRaflari.map((r) => r.$1).toList();
    expect(basliklar, contains("2027'de Vizyona Girecek Filmler"));
    expect(basliklar, contains("2027'de Başlayacak Diziler"));
    expect(
      basliklar.sublist(basliklar.length - 2),
      ["2027'de Vizyona Girecek Filmler", "2027'de Başlayacak Diziler"],
      reason: 'raflar Ana Sayfa nın en altında olmalı',
    );
  });

  test('2027 sorgusu: yıl aralığı var, OY EŞİĞİ YOK', () {
    final film = anaSayfaRaflari.firstWhere(
      (r) => r.$1 == "2027'de Vizyona Girecek Filmler",
    );
    final dizi = anaSayfaRaflari.firstWhere(
      (r) => r.$1 == "2027'de Başlayacak Diziler",
    );

    expect(film.$3, 'movie');
    expect(film.$2, contains('primary_release_date.gte=2027-01-01'));
    expect(film.$2, contains('primary_release_date.lte=2027-12-31'));

    expect(dizi.$3, 'tv');
    expect(dizi.$2, contains('first_air_date.gte=2027-01-01'));
    expect(dizi.$2, contains('first_air_date.lte=2027-12-31'));

    for (final r in [film, dizi]) {
      expect(
        r.$2.contains('vote_count.gte'),
        isFalse,
        reason:
            '${r.$1}: vizyona girmemiş yapımın oyu yoktur — eşik rafı boşaltır',
      );
      expect(
        r.$2,
        contains('sort_by=popularity.desc'),
        reason: '${r.$1}: tarih sıralaması duyurulmamış yapımları öne alıyor',
      );
    }
  });

  test('rafların slug u kalıcı adres üretiyor', () {
    expect(
      rafSlug("2027'de Vizyona Girecek Filmler"),
      '2027-de-vizyona-girecek-filmler',
    );
    expect(rafSlug("2027'de Başlayacak Diziler"), '2027-de-baslayacak-diziler');
    expect(
      rafBul('2027-de-vizyona-girecek-filmler')?.$1,
      "2027'de Vizyona Girecek Filmler",
    );
    expect(
      rafBul('2027-de-baslayacak-diziler')?.$1,
      "2027'de Başlayacak Diziler",
    );
  });

  test('başlıklar 45 dilin hepsinde çevrilmiş (Türkçe ye düşmüyor)', () async {
    for (final kod in Ceviri.diller.keys.where((k) => k != 'tr')) {
      await Ceviri.sec(kod);
      for (final anahtar in [
        "2027'de Vizyona Girecek Filmler",
        "2027'de Başlayacak Diziler",
      ]) {
        expect(
          anahtar.c,
          isNot(anahtar),
          reason: '$kod: "$anahtar" çevirisi eksik, Türkçe basılıyor',
        );
        expect(
          anahtar.c.contains('2027'),
          isTrue,
          reason: '$kod: yıl kaybolmuş',
        );
      }
    }
  });

  testWidgets(
    'katalog: süzgeçten sonra ekran boş kalırsa sonraki sayfa KENDİ İSTENİR',
    (tester) async {
      // Canlı 2027 dizileri: 20 kayıttan yalnız 7'si afişli. Eskiden ızgara
      // ekranı dolduramadığı için kaydırma doğmuyor, 2. sayfa hiç istenmiyordu.
      final istekler = <String>[];
      Api.istemci = MockClient((istek) async {
        istekler.add('${istek.url.path}?${istek.url.query}');
        return http.Response(
          jsonEncode({
            'results': [
              for (var i = 0; i < 20; i++)
                _yapim(i + 1, afis: i < 13 ? null : '/p$i.jpg'),
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: KatalogListeEkrani(
            baslik: "2027'de Başlayacak Diziler",
            yol: '/tmdb/discover/tv?sort_by=popularity.desc',
            tur: 'tv',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        istekler.where((y) => y.contains('page=2')).length,
        1,
        reason: '2. sayfa istenmedi — kullanıcı 7 kartta sıkışırdı',
      );
    },
  );

  testWidgets('afişsiz yapım şeride girmez, afişli olanlar kalır', (
    tester,
  ) async {
    Api.istemci = _sahteIstemci(adet: 6, afissizAdet: 2);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: KesfetEkrani())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final serit = tester.widget<PosterSeridi>(find.byType(PosterSeridi).first);
    expect(serit.icerikler.length, 4, reason: 'afişsiz 2 kayıt süzülmeliydi');
    expect(
      serit.icerikler.every((i) => (i as Map)['poster_path'] != null),
      isTrue,
    );
  });
}
