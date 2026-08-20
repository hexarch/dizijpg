import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kesfet.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KİŞİSELLEŞTİRİLMİŞ TEMATİK RAFLAR — ana sayfa (21 Ağu 2026)
///
/// KULLANICI İSTEĞİ: "Anasayfadaki Sana Özel / Haftanın Dizileri kısmında
/// listeler baya olmalı. İzlediği yönetmenden veya yapımcı firmadan liste yap
/// — Marvel izleyene Marvel dizileri, Marvel filmleri gibi. Kullanıcı baya
/// aşağı kaydırabilmeli."
///
/// KİLİTLENEN KARARLAR:
///   1) BAŞLIK NEDENİ SÖYLER ve TEK yer tutuculu anahtardan kurulur
///      (`{} dizileri` / `{} filmleri`) — 45 dil × N firma anahtarı YOK.
///   2) 1. SAYFA "Sana Özel"in hemen ALTINDA, sonraki sayfalar listenin
///      SONUNDA. Sona ekleme okunmakta olan içeriği yerinden oynatmaz.
///   3) DİKEY kaydırma sayfalar, YATAY afiş şeridi SAYFALAMAZ.
///   4) Boş sayfa gelirse atlanır (liste büyümezse tetikleyici bir daha
///      ateşlenmez ve sayfalama donardı).
///   5) SOĞUK BAŞLANGIÇ: raf yoksa hiçbir şey çizilmez, hata da basılmaz.
///   6) "Tümünü gör" YENİ ROTA açmaz: firma → `/sirket/:id`, yönetmen →
///      `/kisi/:id`.
http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _yapim(int id, String ad) => {
  'id': id,
  'title': ad,
  'name': ad,
  'poster_path': '/p$id.jpg',
  'vote_average': 7.5,
};

Map<String, dynamic> _raf(
  String tip,
  int id,
  String ad,
  String medya, {
  int adet = 6,
}) => {
  'tip': tip,
  'id': id,
  'ad': ad,
  'medya': medya,
  'icerikler': [for (var i = 0; i < adet; i++) _yapim(id * 100 + i, '$ad $i')],
};

/// Sayfa numarasına göre kişisel raf yanıtı üreten sahte sunucu.
MockClient _sunucu(
  Map<int, Map<String, dynamic>> kisiselSayfalar, {
  List<int>? istekGunlugu,
}) {
  return MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.startsWith('/api/kisisel-raflar')) {
      final sayfa =
          int.tryParse(istek.url.queryParameters['sayfa'] ?? '1') ?? 1;
      istekGunlugu?.add(sayfa);
      return _json(
        kisiselSayfalar[sayfa] ?? {'raflar': <dynamic>[], 'devam': false},
      );
    }
    if (yol.startsWith('/api/onerilen')) {
      return _json({
        'oneriler': [_yapim(1, 'Öneri')],
      });
    }
    if (yol.startsWith('/api/tmdb')) {
      return _json({
        'results': [_yapim(2, 'Katalog')],
      });
    }
    if (yol.startsWith('/api/sohbetler')) return _json({'okunmamis': 0});
    return _json(const <String, dynamic>{});
  });
}

/// [yukseklik]: `ListView` görünmeyen çocuğu HİÇ oluşturmaz (tembel sliver),
/// yani sıralamayı ölçen testin bütün blokları aynı anda görebilmesi için
/// uzun bir pencere gerekiyor. Sayfalama testleri GERÇEK telefon yüksekliğini
/// kullanır — orada listenin kaydırılabilir olması şart.
Future<void> _kur(WidgetTester tester, {double yukseklik = 844}) async {
  tester.view.physicalSize = Size(390, yukseklik);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: const KesfetEkrani(),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Ekrandaki raf başlıklarını YUKARIDAN AŞAĞIYA sırayla toplar.
List<String> _basliklar(WidgetTester tester) {
  final bulunan = <(double, String)>[];
  for (final e in tester.widgetList<PosterSeridi>(find.byType(PosterSeridi))) {
    final f = find.byWidget(e);
    if (!tester.any(f)) continue;
    bulunan.add((tester.getTopLeft(f).dy, e.baslik));
  }
  bulunan.sort((a, b) => a.$1.compareTo(b.$1));
  return bulunan.map((r) => r.$2).toList();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Api.tokenKaydet('test-token');
  });

  group('saf yardımcılar', () {
    test('başlık TEK yer tutuculu anahtardan kurulur, ad çevrilmez', () {
      expect(
        kisiselRafBasligi(const {'ad': 'Marvel Studios', 'medya': 'movie'}),
        'Marvel Studios filmleri',
      );
      expect(
        kisiselRafBasligi(const {'ad': 'Marvel Studios', 'medya': 'tv'}),
        'Marvel Studios dizileri',
      );
      // Ad eksikse çökmez (eski önbellek kopyası).
      expect(kisiselRafBasligi(const {'medya': 'tv'}), ' dizileri');
    });

    test('başlık dokunuşu VAR OLAN sayfalara gider', () {
      expect(kisiselRafYolu(const {'tip': 'firma', 'id': 420}), '/sirket/420');
      expect(kisiselRafYolu(const {'tip': 'yonetmen', 'id': 138}), '/kisi/138');
    });
  });

  group('ana sayfa yerleşimi', () {
    testWidgets(
      '1. sayfa "Sana Özel"in HEMEN ALTINDA, sabit rafların ÜSTÜNDE',
      (tester) async {
        Api.istemci = _sunucu({
          1: {
            'raflar': [
              _raf('firma', 420, 'Marvel Studios', 'movie'),
              _raf('firma', 420, 'Marvel Studios', 'tv'),
            ],
            'devam': true,
          },
        });
        await _kur(tester, yukseklik: 2600);

        final sira = _basliklar(tester);
        expect(sira.first, 'Sana Özel');
        expect(sira[1], 'Marvel Studios filmleri');
        expect(sira[2], 'Marvel Studios dizileri');
        expect(
          sira[3],
          'Haftanın Dizileri',
          reason: 'kişisel blok sabit rafların ÜSTÜNDE olmalı',
        );
      },
    );

    testWidgets('dibe kaydırınca 2. sayfa gelir ve SONA eklenir', (
      tester,
    ) async {
      final gunluk = <int>[];
      Api.istemci = _sunucu({
        1: {
          'raflar': [_raf('firma', 420, 'Marvel Studios', 'movie')],
          'devam': true,
        },
        2: {
          'raflar': [_raf('yonetmen', 138, 'Christopher Nolan', 'movie')],
          'devam': false,
        },
      }, istekGunlugu: gunluk);
      await _kur(tester);

      expect(gunluk, [1]);
      expect(find.text('Christopher Nolan filmleri'), findsNothing);

      await tester.drag(find.byType(ListView).first, const Offset(0, -20000));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(gunluk, [1, 2]);
      final sira = _basliklar(tester);
      expect(
        sira.last,
        'Christopher Nolan filmleri',
        reason: '2. sayfa listenin SONUNA eklenmeli (kaydırma sıçramasın)',
      );
    });

    testWidgets('YATAY şerit kaydırması sayfalamayı TETİKLEMEZ', (
      tester,
    ) async {
      final gunluk = <int>[];
      Api.istemci = _sunucu({
        1: {
          'raflar': [_raf('firma', 420, 'Marvel Studios', 'movie')],
          'devam': true,
        },
        2: {
          'raflar': [_raf('yonetmen', 138, 'Christopher Nolan', 'movie')],
          'devam': false,
        },
      }, istekGunlugu: gunluk);
      await _kur(tester);
      expect(gunluk, [1]);

      // GERÇEKTEN kayan bir şerit seç: "Sana Özel"de tek kart var, onu
      // sürüklemek hiçbir bildirim üretmez ve test boşuna yeşil olurdu.
      // Kişisel rafta 6 kart var, 390 dp pencereye sığmıyor.
      final serit = find.descendant(
        of: find.byType(PosterSeridi).at(1),
        matching: find.byType(Scrollable),
      );
      final konum = tester.state<ScrollableState>(serit.first).position;
      expect(
        konum.maxScrollExtent,
        greaterThan(0),
        reason: 'kurgu bozuk: şerit kaydırılabilir olmalı',
      );
      await tester.drag(serit.first, const Offset(-600, 0));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(konum.pixels, greaterThan(0.0), reason: 'şerit hiç kaymadı');
      expect(gunluk, [1], reason: 'yatay kaydırma sayfa istedi');
    });

    testWidgets('boş sayfa ATLANIR (sayfalama donmaz)', (tester) async {
      final gunluk = <int>[];
      Api.istemci = _sunucu({
        1: {
          'raflar': [_raf('firma', 420, 'Marvel Studios', 'movie')],
          'devam': true,
        },
        // 2. sayfanın raflarının hepsi sunucuda içerik eşiğini geçemedi.
        2: {'raflar': <dynamic>[], 'devam': true},
        3: {
          'raflar': [_raf('yonetmen', 138, 'Christopher Nolan', 'movie')],
          'devam': false,
        },
      }, istekGunlugu: gunluk);
      await _kur(tester);

      await tester.drag(find.byType(ListView).first, const Offset(0, -20000));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(gunluk, [1, 2, 3]);
      expect(find.text('Christopher Nolan filmleri'), findsOneWidget);
    });

    testWidgets('soğuk başlangıç: raf yoksa hiçbir şey çizilmez, hata yok', (
      tester,
    ) async {
      Api.istemci = _sunucu({});
      await _kur(tester);
      final sira = _basliklar(tester);
      expect(sira.first, 'Sana Özel');
      expect(sira[1], 'Haftanın Dizileri');
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('içeriği boş gelen raf ÇİZİLMEZ (eski önbellek kopyası)', (
      tester,
    ) async {
      Api.istemci = _sunucu({
        1: {
          'raflar': [
            {
              'tip': 'firma',
              'id': 1,
              'ad': 'Boş Firma',
              'medya': 'movie',
              'icerikler': <dynamic>[],
            },
            _raf('firma', 420, 'Marvel Studios', 'movie'),
          ],
          'devam': false,
        },
      });
      await _kur(tester);
      expect(find.text('Boş Firma filmleri'), findsNothing);
      expect(_basliklar(tester)[1], 'Marvel Studios filmleri');
    });

    testWidgets('önbellek bloğu ağdan BOŞ yanıt gelince SİLİNİR', (
      tester,
    ) async {
      // Önceki oturumun kopyası: kullanıcı o zamandan beri hepsini izledi.
      SharedPreferences.setMockInitialValues({
        'kesfet_kisisel': jsonEncode([
          _raf('firma', 420, 'Eski Firma', 'movie'),
        ]),
      });
      Api.istemci = _sunucu({});
      await _kur(tester);
      expect(
        find.text('Eski Firma filmleri'),
        findsNothing,
        reason: 'bayat kopya ağ yanıtından sonra ekranda kaldı',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kesfet_kisisel'), isNull);
    });

    testWidgets('oturumsuz ziyaretçi kişisel raf İSTEMEZ', (tester) async {
      await Api.cikis();
      final gunluk = <int>[];
      Api.istemci = _sunucu({
        1: {
          'raflar': [_raf('firma', 420, 'Marvel Studios', 'movie')],
          'devam': false,
        },
      }, istekGunlugu: gunluk);
      await _kur(tester);
      expect(gunluk, isEmpty);
      expect(find.text('Marvel Studios filmleri'), findsNothing);
    });
  });
}
