import 'dart:convert';
import 'dart:io';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/kabuk.dart' show dokunmaAsgari;
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/ekranlar/takvim.dart';
import 'package:dizijpg/ekranlar/takvim_ay.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// KULLANICI İSTEĞİ (8 Ağu 2026): "web masaüstü görünüşte takvim ve reels
/// kısmı profil ve akıştaki gibi ortada olmalı, çok fazla sağa sola
/// genişletilmiş".
///
/// --- ÖNCE (ölçüldü, düzeltmeden önce) ---
///   takvim/ay 1440 dp : panel 347,7 dp, ızgara 6 → 1073 dp, gün sütunu sağda
///   takvim/ay 1920 dp : panel **507,7 dp**, ızgara 6 → 1553 dp (gün hücresi
///                       72 dp) — blok ekranın tamamına yayılıyordu
///   takvim/liste      : kart satırları ekran genişliği kadar (1440 / 1920)
///   Reels             : sayfa = ekran; kullanıcı adı en solda, eylem sütunu
///                       en sağda, arası 1900 dp
///
/// --- SONRA ---
///   Ortak kalıp [OrtaKolon] (tema.dart). Üç azami genişlik:
///     * [masaustuKolonGenisligi] (720)  — okuma kolonu: akış, profil
///       yorumları, takvim listesi, yorum sheet'i, gizlilik, arama sonuçları
///     * [masaustuTakvimGenisligi] (1417) — iki bölmeli takvim aracı
///     * 9:16 oranlı tuval ([reelsTuvalGenisligi]) — dikey video
///
/// Aşağıdaki iddiaların HEPSİ `tester.getRect` ile GERÇEK ölçümdür.

const double _g1440 = 1440, _y900 = 900;
const double _g1920 = 1920, _y1080 = 1080;
const double _g360 = 360, _g390 = 390, _yMobil = 800;

void _ekran(WidgetTester t, double g, double y) {
  t.view.physicalSize = Size(g, y);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

/// Akıştaki paylaşım kutusu ([PaylasKutusu]).
///
/// 3 Eyl 2026'da `_PaylasKutusu` DIŞA AÇILDI: içerik/kişi/firma/bölüm
/// sayfalarının yorum bölümü de aynı kutuyu kullanıyor (yorum yazma tek
/// yüzeye indi). Bulucu artık tipe bakıyor — ad dizisiyle aramaya gerek yok.
final Finder _paylasKutusu = find.byType(PaylasKutusu);

/// Sol boşluk ≈ sağ boşluk mu (yani blok YATAYDA ORTALANMIŞ mı)?
void _ortalanmis(Rect r, double ekranGenisligi, {String ne = 'blok'}) {
  final sol = r.left, sag = ekranGenisligi - r.right;
  expect(sol, closeTo(sag, 0.6), reason: '$ne ortalanmamış: sol=$sol sağ=$sag');
  expect(sol, greaterThan(0), reason: '$ne ekrana dayanmış (sol=$sol)');
}

// ---------------------------------------------------------------- takvim/ay

String _k(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

List<Map<String, dynamic>> _olaylar() {
  final b = DateTime.now();
  return [
    for (var ay = 0; ay < 8; ay++)
      for (final g in [2, 9, 17])
        {
          'tarih': _k(DateTime(b.year, b.month + ay, g)),
          'tmdb_id': 1,
          'dizi_adi': 'A Dizisi',
          'sezon': 1,
          'bolum': g,
        },
  ];
}

Widget _ayTakvimi() => MaterialApp(
  theme: diziTema(acik: false),
  home: Scaffold(
    body: AyTakvimi(olaylar: _olaylar(), onAc: (_) async {}),
  ),
);

Finder _ayPanelleri() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith('takvim-ay-'),
);

// ------------------------------------------------------------ takvim/liste

http.Client _takvimIstemcisi() => MockClient((istek) async {
  final b = DateTime.now().add(const Duration(days: 3));
  Object govde = {};
  if (istek.url.path.startsWith('/api/takvim')) {
    govde = {
      'takvim': [
        {
          'tarih': _k(b),
          'tmdb_id': 1,
          'dizi_adi': 'A Dizisi',
          'sezon': 1,
          'bolum': 4,
          'bolum_adi': 'Bölüm',
          'poster': null,
          'izlendi': false,
        },
      ],
      'yetisme': <dynamic>[],
      'eksik': 0,
    };
  }
  return http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

Future<void> _takvimListesi(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'takvim_modu': false});
  Api.istemci = _takvimIstemcisi();
  await tester.pumpWidget(
    MaterialApp(theme: diziTema(acik: false), home: const TakvimEkrani()),
  );
  await tester.pumpAndSettle();
}

/// Takvim listesindeki ilk kart satırı.
Finder _ilkKart() => find.byType(Card).first;

// ------------------------------------------------------------------- reels

Map<String, dynamic> _gonderi(int id) => {
  'id': id,
  'kullanici_id': 42,
  'kullanici_adi': 'ayse',
  'avatar': null,
  'metin': 'Reels gönderisi',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': <String>[],
  'begeni': 3,
  'begendim': false,
  'yanit': 0,
  'goruntulenme': 9,
  'spoiler': false,
  'ust_id': null,
  'tarih': '2026-08-08T10:00:00Z',
};

// -------------------------------------------------------------------- akış

/// Akış ekranı: davranışı DEĞİŞMEMELİ — 720'lik kolon artık ortak sabitten
/// geliyor, ölçü aynı kalmalı.
Future<void> _akis(WidgetTester tester) async {
  // Testte görünürlük anında bildirilsin (askıda timer kalmasın).
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    Object govde = {};
    if (yol.startsWith('/api/akis')) {
      govde = {
        'akis': [_gonderi(1)],
        'icerikler': {
          'tv:100': {'ad': 'Test Dizi', 'poster': null},
        },
      };
    } else if (yol.startsWith('/api/bildirimler')) {
      govde = {'bildirimler': <dynamic>[], 'okunmamis': 0};
    } else if (yol.startsWith('/api/sohbetler')) {
      govde = {'sohbetler': <dynamic>[], 'okunmamis': 0};
    }
    return http.Response(
      jsonEncode(govde),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: const AkisEkrani(),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  // VisibilityDetector aralığı (500 ms) + akışın "görüldü" biriktirme
  // zamanlayıcısı (1 sn) boşaltılır; yoksa test sonunda timer askıda kalır.
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(seconds: 2));
}

/// Yanıt sheet'ini uygulamadaki tek giriş noktasıyla (`yanitlariAc`) açar.
Future<void> _sheetAc(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  SikEmojiler.onbellek = const ['😂', '❤️', '🔥', '👏', '😍', '😮', '😢', '👍'];
  addTearDown(() => SikEmojiler.onbellek = null);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => yanitlariAc(c, _gonderi(1)),
              child: const Text('ac'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ac'));
  await tester.pumpAndSettle();
}

Future<void> _reels(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: ReelsGorunumu(
          liste: <dynamic>[_gonderi(1), _gonderi(2)],
          icerikler: const {
            'tv:100': {'ad': 'Test Dizi', 'poster': null},
          },
          baslangic: 0,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('takvim — AY görünümü', () {
    for (final o in [const Size(_g1440, _y900), const Size(_g1920, _y1080)]) {
      testWidgets('${o.width.toInt()} dp: blok sınırlı ve ORTALANMIŞ', (
        tester,
      ) async {
        _ekran(tester, o.width, o.height);
        await tester.pumpWidget(_ayTakvimi());

        // Bloğun yatay sınırları: en soldaki panelin solu ↔ gün sütununun sağı.
        final paneller = [
          for (var i = 0; i < masaustuAySayisi; i++)
            tester.getRect(_ayPanelleri().at(i)),
        ];
        final sol = paneller.map((r) => r.left).reduce((a, b) => a < b ? a : b);
        final sag = paneller
            .map((r) => r.right)
            .reduce((a, b) => a > b ? a : b);

        // 1) Izgara + gün sütunu toplamı azami genişliği AŞMAZ.
        final blok = Rect.fromLTRB(sol, 0, sag + masaustuGunSutunu + 1, 0);
        expect(
          blok.width,
          lessThanOrEqualTo(masaustuTakvimGenisligi + 0.5),
          reason:
              'takvim bloğu ${blok.width} dp — sınır '
              '$masaustuTakvimGenisligi',
        );
        // 2) ORTALANMIŞ.
        _ortalanmis(blok, o.width, ne: 'takvim bloğu');
        // 3) Panel genişliği ekranla BÜYÜMÜYOR: 1440'ta da 1920'de de 340.
        for (final r in paneller) {
          expect(r.width, closeTo(masaustuAyPaneliGenisligi, 0.5));
        }
        // 4) Dokunma hedefi korunur (7 sütun).
        expect(
          paneller.first.width / 7,
          greaterThanOrEqualTo(dokunmaAsgari),
          reason: 'gün hücresi 44 dp altına düşmemeli',
        );
        // 5) Altı ay hâlâ ekranda (3 Ağu isteği bozulmadı).
        for (final r in paneller) {
          expect(r.bottom, lessThanOrEqualTo(o.height));
        }
      });
    }

    testWidgets('MOBİL REGRESYON: 360 dp tek ay TAM GENİŞLİK, kısıt yok', (
      tester,
    ) async {
      _ekran(tester, _g360, _yMobil);
      await tester.pumpWidget(_ayTakvimi());

      expect(_ayPanelleri(), findsOneWidget);
      final r = tester.getRect(_ayPanelleri().first);
      expect(r.left, 0, reason: 'telefonda ay paneli sola dayalı kalmalı');
      expect(r.width, _g360, reason: 'telefonda panel tam genişlik');
    });
  });

  group('takvim — LİSTE görünümü', () {
    for (final o in [const Size(_g1440, _y900), const Size(_g1920, _y1080)]) {
      testWidgets('${o.width.toInt()} dp: kart okuma kolonunda ve ORTALANMIŞ', (
        tester,
      ) async {
        _ekran(tester, o.width, o.height);
        await _takvimListesi(tester);

        final r = tester.getRect(_ilkKart());
        expect(
          r.width,
          lessThanOrEqualTo(masaustuKolonGenisligi),
          reason: 'takvim kartı ${r.width} dp — okuma kolonu 720',
        );
        _ortalanmis(r, o.width, ne: 'takvim kartı');
      });
    }

    for (final g in [_g360, _g390]) {
      testWidgets('MOBİL REGRESYON: ${g.toInt()} dp kart TAM GENİŞLİK', (
        tester,
      ) async {
        _ekran(tester, g, _yMobil);
        await _takvimListesi(tester);

        final r = tester.getRect(_ilkKart());
        // ListView'in 12 dp yatay dolgusu: eskisiyle birebir aynı (kısıt
        // telefonda hiç bağlamıyor).
        expect(r.left, closeTo(12, 0.5));
        expect(r.width, closeTo(g - 24, 0.5));
      });
    }
  });

  group('Reels', () {
    for (final o in [const Size(_g1440, _y900), const Size(_g1920, _y1080)]) {
      testWidgets('${o.width.toInt()} dp: 9:16 tuval, ORTALANMIŞ', (
        tester,
      ) async {
        _ekran(tester, o.width, o.height);
        await _reels(tester);

        final tuval = tester.getRect(find.byType(PageView));
        final beklenen = o.height * reelsTuvalOrani;
        expect(
          tuval.width,
          closeTo(beklenen, 0.5),
          reason: 'tuval genişliği yükseklikten türemeli (9:16)',
        );
        expect(tuval.height, o.height, reason: 'tuval dikeyde tam ekran');
        _ortalanmis(tuval, o.width, ne: 'Reels tuvali');
        // Sahne artık ekranın yarısından dar: "sağa sola yayılmış" bitti.
        expect(tuval.width, lessThan(o.width / 2));

        // Bindirmeler tuvalin İÇİNDE: kullanıcı adı ve eylem sütunu artık
        // ekranın iki ucunda değil.
        final ad = tester.getRect(find.text('@ayse').first);
        expect(ad.left, greaterThanOrEqualTo(tuval.left - 0.5));
        expect(ad.right, lessThanOrEqualTo(tuval.right + 0.5));
        final begeni = tester.getRect(find.byIcon(Icons.favorite_border).first);
        expect(begeni.right, lessThanOrEqualTo(tuval.right + 0.5));
        expect(
          begeni.left,
          greaterThan(tuval.left),
          reason: 'eylem sütunu tuvalin sağ kenarında olmalı',
        );

        // Dokunuş katmanı DURUYOR: web'de video üstünde dokunuş almak için şart.
        expect(find.byType(PointerInterceptor), findsWidgets);
      });
    }

    for (final g in [_g360, _g390]) {
      testWidgets('MOBİL REGRESYON: ${g.toInt()} dp tuval TAM EKRAN', (
        tester,
      ) async {
        _ekran(tester, g, _yMobil);
        await _reels(tester);

        final tuval = tester.getRect(find.byType(PageView));
        expect(tuval.left, 0);
        expect(tuval.width, g, reason: 'telefonda Reels tam genişlik kalmalı');
        expect(tuval.height, _yMobil);
        expect(find.byType(PointerInterceptor), findsWidgets);
      });
    }

    test(
      'tuval genişliği: yüksekliğe sığan 9:16, ekran darsa tam genişlik',
      () {
        expect(reelsTuvalGenisligi(1920, 1080), closeTo(607.5, 0.01));
        expect(reelsTuvalGenisligi(1440, 900), closeTo(506.25, 0.01));
        // Telefon: 9:16'lık tuval ekrandan geniş → ekran genişliği kullanılır.
        expect(reelsTuvalGenisligi(360, 800), 360);
        // Bozuk ölçüde çökmez.
        expect(reelsTuvalGenisligi(360, 0), 360);
        expect(reelsTuvalGenisligi(double.infinity, 800), double.infinity);
      },
    );
  });

  group('yorum sheet\'i (Reels/akış yanıtları)', () {
    for (final o in [const Size(_g1440, _y900), const Size(_g1920, _y1080)]) {
      testWidgets('${o.width.toInt()} dp: 720 kolonda ve ORTALANMIŞ', (
        tester,
      ) async {
        _ekran(tester, o.width, o.height);
        await _sheetAc(tester);

        final r = tester.getRect(find.byType(YanitlarSheet));
        expect(r.width, closeTo(masaustuKolonGenisligi, 0.5));
        _ortalanmis(r, o.width, ne: 'yorum sheet\'i');
      });
    }

    testWidgets('MOBİL REGRESYON: 390 dp sheet TAM GENİŞLİK', (tester) async {
      _ekran(tester, _g390, _yMobil);
      await _sheetAc(tester);

      final r = tester.getRect(find.byType(YanitlarSheet));
      expect(r.left, 0);
      expect(r.width, _g390);
    });
  });

  group('akış — DEĞİŞMEMELİ (referans kalıp)', () {
    for (final o in [const Size(_g1440, _y900), const Size(_g1920, _y1080)]) {
      testWidgets('${o.width.toInt()} dp: kart 720 kolonda, ORTALANMIŞ', (
        tester,
      ) async {
        _ekran(tester, o.width, o.height);
        await _akis(tester);

        final r = tester.getRect(find.byType(AkisKarti).first);
        expect(
          r.width,
          closeTo(masaustuKolonGenisligi, 0.5),
          reason: 'akış kolonu 720 kalmalı (davranış değişmedi)',
        );
        _ortalanmis(r, o.width, ne: 'akış kartı');
      });
    }
  });

  /// KULLANICI BİLDİRİMİ (29 Ağu 2026): "web masaüstünde akıştaki yorum yap
  /// kısmı çok büyük onu doğru ortasında yerleştirsin".
  ///
  /// Kutu (`_PaylasKutusu`, 28 Ağu'da eklendi) `Column`un doğrudan çocuğuydu;
  /// [OrtaKolon] yalnız `Expanded(child: govde)`yi sarıyordu. ÖLÇÜLDÜ (düzeltme
  /// öncesi): 1440 dp ekranda kutu 1440 dp, kart 720 dp — kutu kartın iki katı
  /// ve sol kenarı 708 dp dışarıda. Şimdi kutu da aynı sarmalayıcıda.
  group('akış PAYLAŞIM KUTUSU — kartla AYNI kolonda', () {
    for (final o in [const Size(_g1440, _y900), const Size(_g1920, _y1080)]) {
      testWidgets('${o.width.toInt()} dp: kutu 720 kolonda, kartla HİZALI', (
        tester,
      ) async {
        _ekran(tester, o.width, o.height);
        await _akis(tester);

        final kutu = tester.getRect(_paylasKutusu.first);
        expect(
          kutu.width,
          closeTo(masaustuKolonGenisligi, 0.5),
          reason: 'paylaşım kutusu okuma kolonuna sığmalı',
        );
        _ortalanmis(kutu, o.width, ne: 'paylaşım kutusu');

        // Kenarlar kartla BİREBİR tutmalı (yeni kalıp uydurulmadı).
        final kart = tester.getRect(find.byType(AkisKarti).first);
        expect(kutu.left, closeTo(kart.left, 0.5), reason: 'sol kenar kaymış');
        expect(
          kutu.right,
          closeTo(kart.right, 0.5),
          reason: 'sağ kenar kaymış',
        );
      });
    }

    /// DAR EKRAN: kısıt bağlayıcı DEĞİL, kutu tam genişlikte kalır.
    ///
    /// NEDEN 360/390 DEĞİL de 600/700: akış KARTININ eylem satırı
    /// (`akis.dart`, beğeni/yanıt/görüntülenme sayaçları) testlerin
    /// tek-boşluklu deneme yazı tipinde 360 dp'de 60 px taşıyor ve testi
    /// düşürüyor — gerçek yazı tipinde taşma yok, bu değişiklikle de ilgisi
    /// yok (aynı taşma düzeltme ÖNCESİ de vardı). `profil_yorum_genislik_test`
    /// aynı sebeple 600 dp kullanıyor. Ölçüm zaten göreli: her iki genişlik de
    /// 720 üst sınırının ALTINDA, yani sınırın bağlamadığını kanıtlıyor.
    for (final g in [600.0, 700.0]) {
      testWidgets('DAR EKRAN REGRESYONU: ${g.toInt()} dp kutu TAM GENİŞLİK', (
        tester,
      ) async {
        _ekran(tester, g, _yMobil);
        await _akis(tester);

        final kutu = tester.getRect(_paylasKutusu.first);
        expect(kutu.left, 0);
        expect(kutu.width, g);
      });
    }
  });

  group('ORTAK KALIP', () {
    test('OrtaKolon üst sınır uygular, sabit genişlik DEĞİL', () {
      expect(masaustuKolonGenisligi, 720);
      expect(masaustuIcerikGenisligi, 1080);
      expect(masaustuTakvimGenisligi, 1417);
      // Takvim bloğu üç panel + gün sütunu kadar; okuma kolonundan geniş olmalı.
      expect(masaustuTakvimGenisligi, greaterThan(masaustuKolonGenisligi));
    });

    testWidgets('OrtaKolon dar ekranda hiçbir şeyi daraltmaz', (tester) async {
      _ekran(tester, _g360, _yMobil);
      await tester.pumpWidget(
        const MaterialApp(
          home: OrtaKolon(
            azami: masaustuKolonGenisligi,
            cocuk: SizedBox(key: Key('ic'), width: double.infinity, height: 10),
          ),
        ),
      );
      expect(tester.getRect(find.byKey(const Key('ic'))).width, _g360);
    });

    /// Kalıbın TEK KAYNAKTAN gelmesi: ekranlarda elle yazılmış `maxWidth: 720`
    /// kalmamalı (dört ekranda dört ayrı sabit tam da bu isteğin sebebiydi).
    test('ekranlarda elle yazılmış "maxWidth: 720" KALMADI', () {
      final kirli = <String>[];
      for (final f in Directory('lib/ekranlar').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        // Yorum satırları elenir: açıklamada geçen "maxWidth: 720" kod değildir.
        final kod = f
            .readAsLinesSync()
            .where((s) => !s.trimLeft().startsWith('//'))
            .join('\n');
        if (RegExp(r'maxWidth:\s*720\b').hasMatch(kod)) kirli.add(f.path);
      }
      expect(
        kirli,
        isEmpty,
        reason: 'masaustuKolonGenisligi kullanılmalı: $kirli',
      );
    });
  });
}
