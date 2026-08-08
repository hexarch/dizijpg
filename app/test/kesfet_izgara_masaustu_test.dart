import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/ekranlar/ortak.dart'
    show IskeletKutu, posterKartHedefGenisligi;
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// KULLANICI İSTEĞİ (8 Ağu 2026): "masaüstü web görünüşte reels videolarının
/// bulunduğu ekranı da akış ve takvim gibi ortaya alacaktın almamışsın".
///
/// 7 Ağu'da akış, takvim ve Reels OYNATICISI ortalanmıştı; Keşfet'in GİRİŞ
/// IZGARASI atlanmıştı.
///
/// --- ÖNCE (bu dosyadaki ölçüm düzeneğiyle, düzeltmeden önce ölçüldü) ---
///   1440 dp : ızgara 1436 dp (sol 2 / sağ 2 — kenardan kenara), 5 sütun,
///             kart 285,6 × 432,7
///   1920 dp : ızgara 1916 dp, 5 sütun, kart 381,6 × 578,2
///   1568 dp : ızgara 1564 dp, 5 sütun, kart 311,2 × 471,5
///   390 dp  : 3 sütun, kart 127,3 × 192,9
///   360 dp  : 3 sütun, kart 117,3 × 177,8
///   Reels tuvali (1568×764): 430 dp; içine 16:9 medya oturunca yüksekliğin
///             yalnız %31,6'sı doluyordu (üstte+altta ~522 dp siyah boşluk).
///
/// --- SONRA ---
///   1440/1920/1568 : ızgara 716 dp (720'lik [masaustuKolonGenisligi] kolonu
///                    eksi 2+2 dolgu), ORTALANMIŞ, 4 sütun, kart 177,5 × 268,9
///   390/360        : BİREBİR AYNI (3 sütun, 127,3 / 117,3) — kısıt bağlamıyor
///   Reels tuvali   : oran ekrandaki medyayı izler; 16:9 medyada 1080 dp
///                    (tavan [reelsAzamiTuvalGenisligi]) → doluluk %79,6
///
/// Aşağıdaki iddiaların hepsi `tester.getRect` ile GERÇEK ölçümdür.

const double _g1440 = 1440, _y900 = 900;
const double _g1920 = 1920, _y1080 = 1080;
const double _g1568 = 1568, _y764 = 764; // kullanıcının canlıda ölçtüğü pencere
const double _g360 = 360, _g390 = 390, _yMobil = 800;

void _ekran(WidgetTester t, double g, double y) {
  t.view.physicalSize = Size(g, y);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

Map<String, dynamic> _gonderi(int id, {List<String> medya = const []}) => {
  'id': id,
  'kullanici_id': 42,
  'kullanici_adi': 'ayse',
  'avatar': null,
  'metin': 'Gönderi $id',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': medya,
  'begeni': 1,
  'begendim': false,
  'yanit': 0,
  'goruntulenme': 9,
  'spoiler': false,
  'videolu': false,
  'tarih': '2026-08-08T10:00:00Z',
};

// ------------------------------------------------------------------ ızgara

const int _adet = 30;

http.Client _istemci({bool bosVeri = false}) => MockClient((istek) async {
  Object govde = {};
  if (istek.url.path.startsWith('/api/kesfet-akis')) {
    govde = {
      'akis': bosVeri
          ? <dynamic>[]
          : [for (var i = 0; i < _adet; i++) _gonderi(i)],
      'icerikler': {
        'tv:100': {'ad': 'Test Dizi', 'poster': null},
      },
      'imlec': null,
    };
  }
  return http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

Future<void> _kesfet(WidgetTester t) async {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  Api.istemci = _istemci();
  await t.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: const KesfetAkisEkrani(),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Ekranda kurulmuş karoların dikdörtgenleri (karo anahtarı: kesfet-<sıra>-<id>).
List<Rect> _karolar(WidgetTester t) {
  final r = <Rect>[];
  for (var i = 0; i < _adet; i++) {
    final f = find.byKey(Key('kesfet-$i-$i'));
    if (f.evaluate().isEmpty) continue;
    r.add(t.getRect(f));
  }
  return r;
}

/// İlk satırdaki karolar (aynı üst kenar).
List<Rect> _ilkSatir(List<Rect> karolar) {
  final ust = karolar.first.top;
  return karolar.where((r) => (r.top - ust).abs() < 1).toList();
}

// ------------------------------------------------------------------- reels

Future<void> _reels(
  WidgetTester t, {
  List<String> medya = const [],
  double? olculenOran,
}) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  final varsayilanOlcer = reelsFotoOraniOlcer;
  addTearDown(() => reelsFotoOraniOlcer = varsayilanOlcer);
  reelsFotoOraniOlcer = (_) async => olculenOran;
  await t.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: ReelsGorunumu(
          liste: <dynamic>[
            _gonderi(1, medya: medya),
            _gonderi(2, medya: medya),
          ],
          icerikler: const {
            'tv:100': {'ad': 'Test Dizi', 'poster': null},
          },
          baslangic: 0,
        ),
      ),
    ),
  );
  // Ölçüm (mikro görev) → üst görünüme bildirim (kare sonrası) → 200 ms
  // genişlik animasyonu.
  await t.pump();
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

/// Tuvale sığdırılan [oran] oranlı medyanın DİKEY doluluk yüzdesi.
double _doluluk(double tuval, double ekranYuksekligi, double oran) =>
    (tuval / oran) / ekranYuksekligi * 100;

void main() {
  group('Keşfet ızgarası — MASAÜSTÜ', () {
    for (final o in [
      const Size(_g1440, _y900),
      const Size(_g1920, _y1080),
      const Size(_g1568, _y764),
    ]) {
      testWidgets('${o.width.toInt()} dp: ızgara SINIRLI ve ORTALANMIŞ', (
        t,
      ) async {
        _ekran(t, o.width, o.height);
        await _kesfet(t);

        final karolar = _karolar(t);
        expect(karolar, isNotEmpty, reason: 'karo bulunamadı');
        final sol = karolar.map((r) => r.left).reduce((a, b) => a < b ? a : b);
        final sag = karolar.map((r) => r.right).reduce((a, b) => a > b ? a : b);

        // 1) Izgara okuma kolonuna sığar (akış/takvim ile AYNI sınır).
        expect(
          sag - sol,
          lessThanOrEqualTo(masaustuKolonGenisligi),
          reason: 'ızgara ${sag - sol} dp — sınır $masaustuKolonGenisligi',
        );
        // 2) ORTALANMIŞ: sol boşluk = sağ boşluk, ve kenara DAYALI DEĞİL.
        expect(sol, closeTo(o.width - sag, 0.6));
        expect(sol, greaterThan(20), reason: 'ızgara hâlâ kenara dayalı');

        // 3) Sütun sayısı kolona göre yeniden hesaplandı: 5 sütun bu kolonda
        //    sıkışırdı (716/5 = 141 dp).
        final satir = _ilkSatir(karolar);
        expect(satir.length, kesfetSutunlari(masaustuKolonGenisligi));
        expect(satir.length, inInclusiveRange(3, 5));

        // 4) Kart genişliği makul: poster ızgaralarının hedefine (168) yakın.
        final kart = satir.first.width;
        expect(
          kart,
          inInclusiveRange(
            posterKartHedefGenisligi * 0.75,
            posterKartHedefGenisligi * 1.4,
          ),
          reason: 'kart $kart dp — hedef $posterKartHedefGenisligi',
        );
        // 5) Karolar TIKLANABİLİR kalır (dokunma hedefi ≥ 44 dp).
        expect(kart, greaterThanOrEqualTo(44));
        expect(satir.first.height, greaterThanOrEqualTo(44));
        // 6) Karo oranı korunur (0.66) — tasarım değişmedi, yalnız ölçek.
        expect(kart / satir.first.height, closeTo(kesfetKaroOrani, 0.01));
      });
    }

    testWidgets('İSKELET de aynı kolonda ve ORTALANMIŞ (içerik gelince zıplama '
        'olmasın)', (t) async {
      _ekran(t, _g1440, _y900);
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      SharedPreferences.setMockInitialValues({});
      await Api.tokenYukle();
      Api.istemci = _istemci();
      await t.pumpWidget(
        ChangeNotifierProvider<Oturum>.value(
          value: Oturum(),
          child: MaterialApp(
            theme: diziTema(acik: false),
            home: const KesfetAkisEkrani(),
          ),
        ),
      );
      // İlk kare: yanıt henüz gelmedi → iskelet ızgarası.
      final iskelet = t.getRect(find.byType(IskeletKutu).first);
      expect(iskelet.left, greaterThan(20), reason: 'iskelet kenara dayalı');
      final grid = t.getRect(find.byType(GridView));
      expect(grid.width, lessThanOrEqualTo(masaustuKolonGenisligi));
      expect(grid.left, closeTo(_g1440 - grid.right, 0.6));
      // İskelet ile gerçek ızgara AYNI sütun sayısını kullanır.
      await t.pump(const Duration(milliseconds: 50));
      await t.pump(const Duration(milliseconds: 50));
      expect(_ilkSatir(_karolar(t)).length, kesfetSutunlari(grid.width));
    });

    for (final g in [_g360, _g390]) {
      testWidgets('MOBİL REGRESYON: ${g.toInt()} dp ızgara DEĞİŞMEDİ', (
        t,
      ) async {
        _ekran(t, g, _yMobil);
        await _kesfet(t);

        final karolar = _karolar(t);
        final satir = _ilkSatir(karolar);
        // 3 sütun, tam genişlik, 2 dp dolgu — 8 Ağu öncesiyle BİREBİR aynı.
        expect(satir.length, 3);
        expect(karolar.first.left, closeTo(kesfetKaroBoslugu, 0.01));
        final beklenenKart =
            (g - kesfetKaroBoslugu * 2 - kesfetKaroBoslugu * 2) / 3;
        expect(satir.first.width, closeTo(beklenenKart, 0.01));
        expect(
          satir.first.height,
          closeTo(beklenenKart / kesfetKaroOrani, 0.01),
        );
        final sag = karolar.map((r) => r.right).reduce((a, b) => a > b ? a : b);
        expect(g - sag, closeTo(kesfetKaroBoslugu, 0.01));
      });
    }

    test('sütun sayısı ÖLÇÜLEN kolondan türer, ekrandan değil', () {
      // Telefon: hesap 2 çıkar, alt sınır 3'e sabitlenir → düzen değişmez.
      expect(kesfetSutunlari(_g360), 3);
      expect(kesfetSutunlari(_g390), 3);
      // 720'lik okuma kolonu: 5 sütun sıkışırdı, 4 sütun hedefe en yakın.
      expect(kesfetSutunlari(masaustuKolonGenisligi), 4);
      // Bozuk ölçüde çökmez.
      expect(kesfetSutunlari(0), 3);
      expect(kesfetSutunlari(double.nan), 3);
    });
  });

  group('Reels tuvali — YATAY MEDYADA BOŞLUK', () {
    test('tuval oranı medyayı izler; dikey medyada davranış AYNI', () {
      // Dikey (9:16) ve oransız çağrılar: 7 Ağu'daki değerlerin AYNISI.
      expect(reelsTuvalGenisligi(_g1920, _y1080), closeTo(607.5, 0.01));
      expect(reelsTuvalGenisligi(_g1440, _y900), closeTo(506.25, 0.01));
      expect(
        reelsTuvalGenisligi(_g1440, _y900, oran: 9 / 16),
        closeTo(506.25, 0.01),
      );
      expect(reelsTuvalGenisligi(_g360, _yMobil), _g360);
      expect(reelsTuvalGenisligi(_g360, 0), _g360);
      expect(reelsTuvalGenisligi(double.infinity, _yMobil), double.infinity);

      // 16:9 yatay medya: tuval genişler, tavan 1080.
      final yatay = reelsTuvalGenisligi(_g1568, _y764, oran: 16 / 9);
      expect(yatay, closeTo(reelsAzamiTuvalGenisligi, 0.01));
      // ÖNCE %31,6 → SONRA %79,6 (aynı pencere, aynı medya, kırpma YOK).
      expect(_doluluk(429.75, _y764, 16 / 9), closeTo(31.6, 0.1));
      expect(_doluluk(yatay, _y764, 16 / 9), closeTo(79.6, 0.1));

      // 4:3 fotoğraf: tuval tam oturur, siyah boşluk KALMAZ.
      final dortUc = reelsTuvalGenisligi(_g1568, _y764, oran: 4 / 3);
      expect(_doluluk(dortUc, _y764, 4 / 3), closeTo(100, 0.5));

      // Sinemaskop (2.35:1) oran tavanına kırpılır, tuval yine 1080'i aşmaz.
      expect(
        reelsTuvalGenisligi(_g1920, _y1080, oran: 2.35),
        lessThanOrEqualTo(reelsAzamiTuvalGenisligi),
      );
      // Bozuk oran güvenli: 9:16'ya düşer.
      expect(
        reelsTuvalGenisligi(_g1440, _y900, oran: double.nan),
        closeTo(506.25, 0.01),
      );
      expect(
        reelsTuvalGenisligi(_g1440, _y900, oran: 0),
        closeTo(506.25, 0.01),
      );
    });

    for (final o in [
      const Size(_g1568, _y764),
      const Size(_g1440, _y900),
      const Size(_g1920, _y1080),
    ]) {
      testWidgets('${o.width.toInt()} dp: 16:9 medyada tuval GENİŞLER', (
        t,
      ) async {
        _ekran(t, o.width, o.height);
        await _reels(t, medya: const ['/medya/kare0.jpg'], olculenOran: 16 / 9);

        final tuval = t.getRect(find.byType(PageView));
        expect(
          tuval.width,
          closeTo(reelsTuvalGenisligi(o.width, o.height, oran: 16 / 9), 0.5),
        );
        // Eski 9:16 tuvalden GENİŞ ama içerik kolonundan (1080) geniş DEĞİL.
        expect(tuval.width, greaterThan(o.height * reelsTuvalOrani));
        expect(tuval.width, lessThanOrEqualTo(reelsAzamiTuvalGenisligi));
        // Hâlâ ORTALANMIŞ ve ekranın tamamına yayılmıyor.
        expect(tuval.left, closeTo(o.width - tuval.right, 0.6));
        expect(tuval.left, greaterThan(0));
        // Bindirmeler tuvalin İÇİNDE kalır.
        final ad = t.getRect(find.text('@ayse').first);
        expect(ad.left, greaterThanOrEqualTo(tuval.left - 0.5));
        expect(ad.right, lessThanOrEqualTo(tuval.right + 0.5));
        final begeni = t.getRect(find.byIcon(Icons.favorite_border).first);
        expect(begeni.right, lessThanOrEqualTo(tuval.right + 0.5));
        // Web'de video üstünde dokunuş almak için ŞART.
        expect(find.byType(PointerInterceptor), findsWidgets);
      });
    }

    testWidgets('ölçüm gelmezse (görsel inmedi) tuval 9:16 KALIR', (t) async {
      _ekran(t, _g1568, _y764);
      await _reels(t, medya: const ['/medya/kare0.jpg'], olculenOran: null);
      expect(
        t.getRect(find.byType(PageView)).width,
        closeTo(_y764 * reelsTuvalOrani, 0.5),
      );
    });

    testWidgets('DİKEY medyada tuval 9:16 kalır (bugünkü çerçeve)', (t) async {
      _ekran(t, _g1568, _y764);
      await _reels(t, medya: const ['/medya/kare0.jpg'], olculenOran: 9 / 16);
      expect(
        t.getRect(find.byType(PageView)).width,
        closeTo(_y764 * reelsTuvalOrani, 0.5),
      );
    });

    for (final g in [_g360, _g390]) {
      testWidgets(
        'MOBİL REGRESYON: ${g.toInt()} dp 16:9 medyada bile TAM EKRAN',
        (t) async {
          _ekran(t, g, _yMobil);
          await _reels(
            t,
            medya: const ['/medya/kare0.jpg'],
            olculenOran: 16 / 9,
          );

          final tuval = t.getRect(find.byType(PageView));
          expect(tuval.left, 0);
          expect(tuval.width, g, reason: 'telefonda tuval daralmaz/genişlemez');
          expect(tuval.height, _yMobil);
          expect(find.byType(PointerInterceptor), findsWidgets);
        },
      );
    }
  });
}
