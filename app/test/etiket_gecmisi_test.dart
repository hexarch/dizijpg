import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/icerik_sec.dart';
import 'package:dizijpg/etiket_gecmisi.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 3 Eyl 2026 — KULLANICI İSTEĞİ, birebir:
///
///   "gönderi paylaşırken etiket ekle tıklayınca açılan yapım ara çok
///    yukarıya çıkıyor telefonun üstündeki barın içine kadar gidiyor, oraya
///    kadar çıkmasın; ve en son aradığım yapımlar listelensin arama yapmadan;
///    mesela breaking bad seçtim ekledim tekrar etiket ekle dediğimde geçmiş
///    arama kısmında breaking bad'in firması, yönetmeni, oyuncuları olsun"
///
/// Üç iddia:
///   1. klavye açıkken sheet durum çubuğuna GİRMEZ;
///   2. arama kutusu boşken geçmiş listelenir, yazınca sonuçlar gelir,
///      silince geçmiş geri gelir; geçmişten dokunuş seçim döndürür;
///   3. dizi seçilince firması / yaratıcısı / oyuncuları geçmişe ONUN
///      ARDINA eklenir ve "Breaking Bad · Oyuncu" diye etiketlenir.

http.Response _json(Object g) => http.Response(
  jsonEncode(g),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const Map<String, dynamic> _breakingBad = {
  'id': 1396,
  'media_type': 'tv',
  'name': 'Breaking Bad',
  'poster_path': '/bb.jpg',
};

Map<String, dynamic> _detay() => {
  'id': 1396,
  'name': 'Breaking Bad',
  'production_companies': [
    {'id': 11073, 'name': 'Sony Pictures Television', 'logo_path': '/s.png'},
    {'id': 2605, 'name': 'High Bridge', 'logo_path': null},
  ],
  'created_by': [
    {'id': 66633, 'name': 'Vince Gilligan', 'profile_path': '/v.jpg'},
  ],
  'credits': {
    'cast': [
      {'id': 17419, 'name': 'Bryan Cranston', 'order': 0},
      {'id': 84497, 'name': 'Aaron Paul', 'order': 1},
      {'id': 134531, 'name': 'Anna Gunn', 'order': 2},
      {'id': 84498, 'name': 'Dean Norris', 'order': 3},
      {'id': 84499, 'name': 'Betsy Brandt', 'order': 4},
      {'id': 84500, 'name': 'RJ Mitte', 'order': 5},
      {'id': 84501, 'name': 'Bob Odenkirk', 'order': 6},
    ],
    'crew': [
      {'id': 66633, 'name': 'Vince Gilligan', 'job': 'Executive Producer'},
      {'id': 999, 'name': 'Michelle MacLaren', 'job': 'Director'},
    ],
  },
};

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (RegExp(r'/tmdb/tv/1396$').hasMatch(yol)) return _json(_detay());
    if (yol.contains('/search/multi')) {
      return _json({
        'results': const [_breakingBad],
      });
    }
    if (yol.contains('/search/company')) return _json({'results': const []});
    return _json(const <String, dynamic>{});
  });
}

Future<List<Map<String, dynamic>>> _gecmis() => EtiketGecmisi.oku();

void main() {
  setUp(() {
    _sunucu();
    EtiketGecmisi.getir = Api.get;
    SharedPreferences.setMockInitialValues({});
    DiziRenkler.acik = false;
  });

  // -------------------------------------------------------------------------
  // 3) İLGİLİLER — saf mantık + depo
  // -------------------------------------------------------------------------
  group('EtiketGecmisi', () {
    test('ilgililer: firmalar → yaratıcı → yönetmen → ilk 5 oyuncu', () {
      final l = EtiketGecmisi.ilgililer(_detay(), 'tv', 'Breaking Bad');
      expect(l.map((r) => r['name']), [
        'Sony Pictures Television',
        'High Bridge',
        'Vince Gilligan',
        'Michelle MacLaren',
        'Bryan Cranston',
        'Aaron Paul',
        'Anna Gunn',
        'Dean Norris',
        'Betsy Brandt',
      ]);
      expect(l.first['media_type'], 'company');
      expect(l.first['logo_path'], '/s.png');
      expect(l[2]['media_type'], 'person');
      expect(l[2]['profile_path'], '/v.jpg');
      expect(l[2]['rol'], 'yaratici');
      expect(l[3]['rol'], 'yonetmen');
      expect(l[4]['rol'], 'oyuncu');
      // Hepsi ana yapıma bağlı.
      expect(l.every((r) => r['ilgili'] == 'Breaking Bad'), isTrue);
    });

    test('kaydet: seçim başa, ilgililer hemen ardına', () async {
      await EtiketGecmisi.kaydet(_breakingBad);
      final g = await _gecmis();
      expect(g.first['name'], 'Breaking Bad');
      expect(g.first['media_type'], 'tv');
      expect(g.first.containsKey('ilgili'), isFalse);
      expect(g[1]['name'], 'Sony Pictures Television');
      expect(g[3]['name'], 'Vince Gilligan');
      expect(g.length, 10);
    });

    test(
      'kaydet: aynı dizi yeniden seçilince çoğalmaz, başa taşınır',
      () async {
        await EtiketGecmisi.kaydet({
          'id': 5,
          'media_type': 'movie',
          'title': 'Heat',
        });
        await EtiketGecmisi.kaydet(_breakingBad);
        await EtiketGecmisi.kaydet({
          'id': 6,
          'media_type': 'movie',
          'title': 'Alien',
        });
        await EtiketGecmisi.kaydet(_breakingBad);
        final g = await _gecmis();
        expect(g.where((r) => r['name'] == 'Breaking Bad').length, 1);
        expect(g.where((r) => r['name'] == 'Bryan Cranston').length, 1);
        expect(g.first['name'], 'Breaking Bad');
        expect(g[1]['name'], 'Sony Pictures Television');
        expect(g.map((r) => r['name']), containsAll(['Alien', 'Heat']));
      },
    );

    test('detay isteği düşerse seçim yine kaydedilir', () async {
      EtiketGecmisi.getir = (_) async => throw Exception('ağ yok');
      await EtiketGecmisi.kaydet(_breakingBad);
      final g = await _gecmis();
      expect(g.map((r) => r['name']), ['Breaking Bad']);
    });
  });

  // -------------------------------------------------------------------------
  // 2) SEÇİCİ — geçmiş kipi
  // -------------------------------------------------------------------------
  group('seçici geçmişi', () {
    Future<void> ac(WidgetTester tester, {bool kisiVeFirma = true}) async {
      // Aynı ağaç yeniden pump edilince State KORUNUR (initState bir daha
      // koşmaz); geçmişin taze okunması için önce boşalt.
      await tester.pumpWidget(const SizedBox.shrink());
      // Uzun telefon: 1 ana + 9 ilgili satırın hepsi kaydırmadan görünsün
      // (ListView yalnız görüneni kurar, finder görünmeyeni bulamaz).
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: IcerikSecSheet(kisiVeFirma: kisiVeFirma)),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Finder satir(String ad) =>
        find.ancestor(of: find.text(ad), matching: find.byType(ListTile));

    testWidgets('boş kutu: geçmiş yok → eski ipucu; geçmiş var → liste', (
      tester,
    ) async {
      await ac(tester);
      expect(find.textContaining('yapım firması ara.'), findsOneWidget);
      expect(find.byKey(const Key('etiket-gecmisi')), findsNothing);

      await EtiketGecmisi.kaydet(_breakingBad);
      await ac(tester);
      expect(find.byKey(const Key('etiket-gecmisi')), findsOneWidget);
      expect(find.text('Son aramalar'), findsOneWidget);
      expect(satir('Breaking Bad'), findsOneWidget);
      // İlgililer ARAMA YAPMADAN listede ve neye ait olduğu yazıyor.
      expect(satir('Bryan Cranston'), findsOneWidget);
      expect(find.text('Breaking Bad · Oyuncu'), findsWidgets);
      expect(find.text('Breaking Bad · Yapım firması'), findsWidgets);
      expect(find.text('Breaking Bad · Yaratıcı'), findsOneWidget);
    });

    testWidgets('yazınca sonuçlar, silince geçmiş geri gelir', (tester) async {
      await EtiketGecmisi.kaydet({
        'id': 5,
        'media_type': 'movie',
        'title': 'Heat',
      });
      await ac(tester);
      expect(satir('Heat'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'breaking');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(satir('Breaking Bad'), findsOneWidget);
      expect(satir('Heat'), findsNothing);
      expect(find.byKey(const Key('etiket-gecmisi')), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.byKey(const Key('etiket-gecmisi')), findsOneWidget);
      expect(satir('Heat'), findsOneWidget);
      expect(satir('Breaking Bad'), findsNothing);
    });

    testWidgets('geçmişten dokunuş seçimi döndürür ve başa taşır', (
      tester,
    ) async {
      // Önce Breaking Bad (+9 ilgili), sonra Heat: Heat listenin BAŞINDA,
      // yani görünür alanda (ListView yalnız görüneni kurar).
      await EtiketGecmisi.kaydet(_breakingBad);
      await EtiketGecmisi.kaydet({
        'id': 5,
        'media_type': 'movie',
        'title': 'Heat',
      });
      Map<String, dynamic>? secim;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => secim = await icerikSecAc(context),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(satir('Heat'));
      await tester.pumpAndSettle();
      expect(secim?['id'], 5);
      expect(secim?['media_type'], 'movie');
      // `PaylasimEtiketi.tmdb` `title`/`name` ikisini de okur; geçmiş `name`
      // ile saklar.
      expect(secim?['name'], 'Heat');
      final g = await _gecmis();
      expect(g.first['name'], 'Heat');
      expect(g[1]['name'], 'Breaking Bad');
    });

    testWidgets('Temizle geçmişi siler', (tester) async {
      await EtiketGecmisi.kaydet(_breakingBad);
      await ac(tester);
      await tester.tap(find.byKey(const Key('etiket-gecmisi-temizle')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('etiket-gecmisi')), findsNothing);
      expect(find.textContaining('yapım firması ara.'), findsOneWidget);
      expect(await _gecmis(), isEmpty);
    });

    testWidgets('SOHBET seçicisi geçmişte kişi/firma GÖSTERMEZ', (
      tester,
    ) async {
      await EtiketGecmisi.kaydet(_breakingBad);
      await ac(tester, kisiVeFirma: false);
      expect(satir('Breaking Bad'), findsOneWidget);
      expect(satir('Bryan Cranston'), findsNothing);
      expect(satir('Sony Pictures Television'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 1) YÜKSEKLİK — klavye açıkken durum çubuğuna girmez
  // -------------------------------------------------------------------------
  group('sheet yüksekliği', () {
    const double g = 390, y = 844, ustPay = 47, klavye = 336;

    Future<void> acModal(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => icerikSecAc(context),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
    }

    testWidgets('klavye + durum çubuğu: sheet üst kenarı çubuğun ALTINDA', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(g, y);
      tester.view.padding = const FakeViewPadding(top: ustPay);
      tester.view.viewPadding = const FakeViewPadding(top: ustPay);
      tester.view.viewInsets = const FakeViewPadding(bottom: klavye);
      addTearDown(tester.view.reset);

      await acModal(tester);
      // Gövde: klavye payı (Padding) DIŞINDA kalan görünür kutu.
      final kutu = tester.getRect(find.byKey(const Key('icerik-sec-govde')));
      // ESKİ HATA: 0.75 × 844 = 633 dp + 336 klavye payı = 969 > 844 →
      // üst kenar eksiye, yani durum çubuğunun içine.
      expect(
        kutu.top,
        greaterThanOrEqualTo(ustPay),
        reason: 'sheet durum çubuğuna girdi (top=${kutu.top})',
      );
      // Ve liste klavyenin ÜSTÜNDE: alt kenar klavye sınırını aşmaz.
      expect(kutu.bottom, lessThanOrEqualTo(y - klavye + 0.5));
      // Yine de kullanışlı bir yükseklik kaldı.
      expect(kutu.height, greaterThanOrEqualTo(200));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('klavye kapalı: ekranın %75\'i (eski davranış korunur)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(g, y);
      tester.view.padding = const FakeViewPadding(top: ustPay);
      tester.view.viewPadding = const FakeViewPadding(top: ustPay);
      tester.view.viewInsets = FakeViewPadding.zero;
      addTearDown(tester.view.reset);

      await acModal(tester);
      final kutu = tester.getRect(find.byKey(const Key('icerik-sec-govde')));
      expect(kutu.height, closeTo(y * 0.75, 1));
      expect(kutu.top, greaterThanOrEqualTo(ustPay));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
