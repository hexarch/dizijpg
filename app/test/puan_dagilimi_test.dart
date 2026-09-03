// Madde 17 — PUAN DAĞILIMI (IMDb tarzı).
//
// Kilitlenen davranışlar (KANIT ZORUNLU, CLAUDE.md kural 7):
//   * Kovalama `yildiza` ile AYNI: kanonik 1-100 → yıldız 1-5 (sınırlar dahil).
//     Sunucu ham ölçek gönderiyor; buradaki eşleşme bozulursa grafik,
//     ekranda görünen yıldızdan farklı bir kovaya yazar.
//   * Grafik 5→1 SIRALI çizilir (değere göre değil — yıldız sıralı ölçek).
//   * Her çubuğun SAYISI yazılı (erişilebilirlik: uzunluk/renk tek başına
//     bilgi taşımaz) ve çubuk boyu en kalabalık kovaya göre orantılı.
//   * Kullanıcının kendi kovası renkten BAŞKA bir işaretle de belli
//     (kişi ikonu) — renk körlüğünde de ayırt edilir.
//   * Hareket azaltma açıkken çubuklar İLK KAREDE tam boyunda (animasyon yok).
//   * Puan yoksa alt sayfa HİÇ açılmaz (karşılıksız dokunuş olmaz).
//   * Detaydaki rozet dokunma hedefi ≥44 dp ve dokununca dağılımı açıyor.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:dizijpg/ekranlar/puan_dagilimi.dart';
import 'package:dizijpg/puan.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Sunucunun ham dağılım biçimi: `[{puan: 1-100, adet: n}]`.
List<Map<String, Object>> _ham(Map<int, int> puandanAdete) => [
  for (final g in puandanAdete.entries) {'puan': g.key, 'adet': g.value},
];

Widget _grafik({
  required Map<int, int> kovalar,
  int? benimDbPuani,
  bool hareketKapali = false,
}) => MaterialApp(
  theme: diziTema(acik: false),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: hareketKapali),
    child: Scaffold(
      body: SizedBox(
        width: 360,
        child: PuanDagilimiGrafigi(
          kovalar: kovalar,
          benimDbPuani: benimDbPuani,
        ),
      ),
    ),
  ),
);

/// i. çubuğun dolum oranı (5 yıldızdan 1'e doğru sırayla).
List<double> _oranlar(WidgetTester tester) => tester
    .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
    .map((w) => w.widthFactor ?? 0)
    .toList();

void main() {
  group('kovalama (puan.dart) — ölçek çevirisi tek kaynaktan', () {
    test('kanonik 1-100 kovaları `yildiza` ile BİREBİR aynı', () {
      for (var p = 1; p <= dbPuanAzami; p++) {
        final kovalar = yildizDagilimi(_ham({p: 1}));
        final beklenen = yildiza(p);
        expect(
          kovalar[beklenen],
          1,
          reason: 'DB $p puanı $beklenen yıldız kovasına düşmeliydi',
        );
        // Tek satır verildi: toplam da 1 olmalı (başka kovaya sızmadı).
        expect(kovalar.values.fold<int>(0, (t, a) => t + a), 1);
      }
    });

    test('sınırlar: 10-20 → 1 yıldız, 90-100 → 5 yıldız, 50 → 3 yıldız', () {
      final k = yildizDagilimi(_ham({10: 3, 20: 2, 50: 7, 90: 4, 100: 6}));
      expect(k[1], 5); // 1 ve 2 aynı kovada
      expect(k[3], 7); // 5 → 2.5 → yukarı yuvarlanır
      expect(k[5], 10); // 9 ve 10 aynı kovada
      expect(k[2], 0);
      expect(k[4], 0);
    });

    test('kovalar HER ZAMAN 1..5 ve toplam `adet` ile tutarlı', () {
      final k = yildizDagilimi(_ham({80: 12, 100: 30}));
      expect(k.keys.toList()..sort(), [1, 2, 3, 4, 5]);
      expect(k.values.fold<int>(0, (t, a) => t + a), 42);
    });

    test('bozuk/eksik veri sayfayı düşürmez: boş kovalar döner', () {
      for (final bozuk in [
        null,
        'metin',
        42,
        <dynamic>[],
        <dynamic>[null, 3],
      ]) {
        final k = yildizDagilimi(bozuk);
        expect(k.length, 5);
        expect(k.values.every((a) => a == 0), isTrue);
      }
      // puan alanı yoksa o satır sayılmaz (kova 0 = yıldızsız).
      expect(
        yildizDagilimi([
          {'adet': 5},
        ]).values.every((a) => a == 0),
        isTrue,
      );
    });
  });

  group('grafik', () {
    testWidgets('5→1 sırayla çizilir ve her çubuğun sayısı YAZILI', (
      tester,
    ) async {
      // Sayılar 1-5 ile çakışmasın diye bilerek büyük seçildi (aksi halde
      // find.text('5') hem yıldız etiketini hem sayıyı bulurdu).
      await tester.pumpWidget(
        _grafik(kovalar: {5: 64, 4: 32, 3: 16, 2: 9, 1: 7}),
      );
      await tester.pumpAndSettle();

      for (final sayi in ['64', '32', '16', '9', '7']) {
        expect(find.text(sayi), findsOneWidget, reason: '$sayi yazılı değil');
      }
      // Yıldız etiketleri yukarıdan aşağı 5,4,3,2,1
      final y = [
        for (final e in ['5', '4', '3', '2', '1'])
          tester.getRect(find.text(e)).top,
      ];
      for (var i = 1; i < y.length; i++) {
        expect(y[i], greaterThan(y[i - 1]), reason: 'sıra 5→1 değil');
      }
    });

    testWidgets('çubuk boyu EN KALABALIK kovaya göre orantılı', (tester) async {
      await tester.pumpWidget(
        _grafik(kovalar: {5: 100, 4: 50, 3: 25, 2: 0, 1: 0}),
      );
      await tester.pumpAndSettle();

      final oranlar = _oranlar(tester);
      expect(oranlar.length, 5);
      expect(oranlar[0], 1.0); // en kalabalık kova tam dolu
      expect(oranlar[1], closeTo(0.5, 0.001));
      expect(oranlar[2], closeTo(0.25, 0.001));
      expect(oranlar[3], 0.0); // boş kova çubuksuz
      expect(oranlar[4], 0.0);
    });

    testWidgets('hepsi boşken bölme hatası yok (0/0)', (tester) async {
      await tester.pumpWidget(_grafik(kovalar: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0}));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_oranlar(tester).every((o) => o == 0), isTrue);
    });

    testWidgets('kendi puanın renkten BAŞKA işaretle de belli', (tester) async {
      // DB 8 = 4 yıldız
      await tester.pumpWidget(
        _grafik(kovalar: {5: 10, 4: 20, 3: 5, 2: 1, 1: 1}, benimDbPuani: 80),
      );
      await tester.pumpAndSettle();

      final isaret = find.byIcon(Icons.person);
      expect(isaret, findsOneWidget);
      // İşaret 4 yıldız satırında: aynı dikey hizada olmalı (sayı '20').
      expect(
        tester.getCenter(isaret).dy,
        closeTo(tester.getCenter(find.text('20')).dy, 1),
      );
    });

    testWidgets('hareket azaltma açıkken çubuklar İLK KAREDE tam boyunda', (
      tester,
    ) async {
      await tester.pumpWidget(
        _grafik(kovalar: {5: 10, 4: 5, 3: 0, 2: 0, 1: 0}, hareketKapali: true),
      );
      await tester.pump(); // tek kare: animasyon olsaydı 0'dan başlardı
      expect(_oranlar(tester).first, 1.0);
    });

    // Karşı kanıt: yukarıdaki test animasyon HİÇ çalışmasa da yeşil kalırdı.
    // AYRI test olmak zorunda — aynı testte ikinci kez pumpWidget edilseydi
    // Flutter aynı elemanı geri dönüştürür, TweenAnimationBuilder biten
    // değerinde kalır ve "animasyon var" sanılırdı (md. 47 ailesi).
    testWidgets('hareket açıkken çubuk 0dan dolar (animasyon gerçekten var)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _grafik(kovalar: {5: 10, 4: 5, 3: 0, 2: 0, 1: 0}),
      );
      await tester.pump();
      expect(_oranlar(tester).first, lessThan(1.0));
      await tester.pumpAndSettle();
      expect(_oranlar(tester).first, 1.0);
    });
  });

  group('alt sayfa', () {
    testWidgets('puan yoksa HİÇ açılmaz', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: diziTema(acik: false),
          home: Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
      puanDagilimiAc(ctx, dagilim: <dynamic>[], ortalama: null);
      await tester.pumpAndSettle();
      expect(find.byType(PuanDagilimiSheet), findsNothing);
    });

    testWidgets('veri varken başlık, ortalama ve toplam görünür', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: diziTema(acik: false),
          home: Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
      puanDagilimiAc(
        ctx,
        dagilim: _ham({100: 8, 80: 4}),
        ortalama: 93, // kanonik ölçek → 4.7 yıldız (5'lik görünüm)
      );
      await tester.pumpAndSettle();

      expect(find.byType(PuanDagilimiSheet), findsOneWidget);
      expect(find.text('Puan dağılımı'), findsOneWidget);
      expect(find.text('4.7'), findsOneWidget);
      expect(find.text('12 kişi puanladı'), findsOneWidget);
    });
  });

  // -----------------------------------------------------------------------
  // Kullanıcı isteği 2026-08-14: "açılan div belirli oranda açılıyor ama
  // komple açılması gerekiyor."
  //
  // ESKİ HÂL: `showModalBottomSheet` varsayılanı sheet'i ekranın 9/16'sı
  // (~%56) ile SINIRLAR — içerik uzayınca alttan keser. Aşağıdaki testler
  // tam o tavanı ölçüp aştığımızı gösteriyor.
  // -----------------------------------------------------------------------
  group('alt sayfa yüksekliği', () {
    const ekran = Size(360, 480);

    /// Eski davranışın tavanı: `showModalBottomSheet` varsayılan kısıtı.
    const eskiTavan = 480 * 9 / 16; // 270 dp

    Future<double> ac(
      WidgetTester tester, {
      double yaziOlcegi = 1,
      double altPay = 0,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = ekran;
      tester.view.padding = FakeViewPadding(bottom: altPay);
      addTearDown(tester.view.reset);

      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: diziTema(acik: false),
          // `builder` Navigator'ın ÜSTÜNDE sarar → modal rota da bu
          // MediaQuery'i devralır (home'u sarmak yetmezdi).
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: TextScaler.linear(yaziOlcegi)),
            child: child!,
          ),
          home: Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
      puanDagilimiAc(
        ctx,
        dagilim: _ham({100: 64, 80: 32, 60: 16, 40: 9, 20: 7}),
        ortalama: 81,
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byType(PuanDagilimiSheet)).height;
    }

    testWidgets('içerik eski 9/16 tavanını aşınca sayfa KESİLMEZ', (
      tester,
    ) async {
      final yukseklik = await ac(tester, yaziOlcegi: 2);

      expect(
        yukseklik,
        greaterThan(eskiTavan),
        reason: 'sheet hâlâ eski tavanda takılı',
      );
      // Beş çubuğun HEPSİ çizili ve sonuncusu sheet'in İÇİNDE (kırpılmamış).
      final cubuklar = find.byType(FractionallySizedBox);
      expect(cubuklar, findsNWidgets(5));
      final sheet = tester.getRect(find.byType(PuanDagilimiSheet));
      expect(
        tester.getRect(cubuklar.last).bottom,
        lessThanOrEqualTo(sheet.bottom),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('kısa içerikte ekranı gereksiz kaplamaz (içeriğe göre boy)', (
      tester,
    ) async {
      final yukseklik = await ac(tester);
      // Sabit oranlı (0.85 gibi) bir sheet burada 408 dp açardı; içerik kadar
      // açılıyoruz. Yine de tüm çubuklar görünür.
      expect(yukseklik, lessThan(ekran.height * 0.9));
      expect(find.byType(FractionallySizedBox), findsNWidgets(5));
    });

    testWidgets('alt güvenli alan korunuyor (sistem çubuğu altında kalmaz)', (
      tester,
    ) async {
      await ac(tester, altPay: 34);

      final govde = tester.widget<Padding>(
        find.byKey(const Key('puan-dagilimi-govde')),
      );
      expect((govde.padding as EdgeInsets).bottom, 34 + 16);

      final sheet = tester.getRect(find.byType(PuanDagilimiSheet));
      final sonCubuk = tester.getRect(find.byType(FractionallySizedBox).last);
      expect(
        sheet.bottom - sonCubuk.bottom,
        greaterThanOrEqualTo(34),
        reason: 'son çubuk gezinme çubuğunun altında kalıyor',
      );
    });

    testWidgets('devasa yazı ölçeğinde tavana oturur ve KAYDIRILIR', (
      tester,
    ) async {
      final yukseklik = await ac(tester, yaziOlcegi: 4);
      expect(yukseklik, closeTo(ekran.height * 0.9, 0.5));
      expect(tester.takeException(), isNull, reason: 'taşma olmamalı');

      // Son çubuk (1 yıldız → 7 kişi) başlangıçta görüş alanının ALTINDA.
      // `findsOneWidget` yeterli KANIT DEĞİL: kaydırma kutusu görünmeyen
      // çocukları da kurar. Konumla ölçüyoruz.
      final sheet = tester.getRect(find.byType(PuanDagilimiSheet));
      final oncesi = tester.getRect(find.text('7')).top;
      expect(
        oncesi,
        greaterThan(sheet.bottom),
        reason: 'içerik zaten sığıyorsa bu test bir şey kanıtlamaz',
      );

      await tester.drag(find.byType(PuanDagilimiSheet), const Offset(0, -2000));
      await tester.pumpAndSettle();

      // Kaydırınca gerçekten yukarı geldi ve sheet'in İÇİNDE okunuyor.
      final sonrasi = tester.getRect(find.text('7'));
      expect(sonrasi.top, lessThan(oncesi));
      expect(sonrasi.bottom, lessThanOrEqualTo(sheet.bottom));
      expect(sonrasi.top, greaterThanOrEqualTo(sheet.top));
    });
  });

  group('detay sayfası rozeti', () {
    setUp(
      () =>
          VisibilityDetectorController.instance.updateInterval = Duration.zero,
    );
    setUp(() async {
      SharedPreferences.setMockInitialValues({'token': 'sahte'});
      await Api.tokenYukle();
      Api.istemci = MockClient((istek) async {
        final yol = istek.url.path.replaceFirst('/api', '');
        Object govde = <String, dynamic>{};
        if (yol.startsWith('/tmdb/')) {
          govde = {
            'id': 1396,
            'name': 'Breaking Bad',
            'overview': 'Deneme',
            'first_air_date': '2008-01-20',
            'vote_average': 8.9,
            'genres': <dynamic>[],
            'seasons': <dynamic>[],
          };
        } else if (yol.startsWith('/incelemeler/')) {
          govde = {
            'incelemeler': <dynamic>[],
            'ortalama': 84,
            'adet': 25,
            'dagilim': _ham({100: 10, 80: 9, 60: 4, 20: 2}),
          };
        } else if (yol.startsWith('/benim/')) {
          govde = {
            'puan': {'puan': 100},
          };
        }
        return http.Response(
          jsonEncode(govde),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
    });

    testWidgets('rozet ≥44 dp dokunma hedefi ve dokununca dağılım açılıyor', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ChangeNotifierProvider<Oturum>.value(
          value: Oturum(),
          child: const MaterialApp(home: DetayEkrani(tmdbId: 1396, tur: 'tv')),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final rozet = find.textContaining('dizi.jpg');
      expect(rozet, findsOneWidget);
      // 8.4 DB puanı ekranda 4.2 yıldız olarak yazar (puan.dart ölçeği)
      expect(find.textContaining('4.2'), findsOneWidget);

      final dokunmaAlani = find
          .ancestor(of: rozet, matching: find.byType(InkWell))
          .first;
      expect(
        tester.getSize(dokunmaAlani).height,
        greaterThanOrEqualTo(44),
        reason: 'dokunma hedefi 44 dp altında',
      );

      await tester.tap(rozet);
      await tester.pumpAndSettle();

      expect(find.byType(PuanDagilimiSheet), findsOneWidget);
      expect(find.text('25 kişi puanladı'), findsOneWidget);
      // Kendi puanı (kanonik 100 = 5 yıldız) işaretli.
      // SHEET İÇİNDE aranır: 3 Eyl 2026'dan beri sayfanın yorum bölümünde de
      // bir `Icons.person` var (paylaşım kutusunun avatar yedeği), sayfa
      // genelinde arayan eski hâli iki sonuç buluyordu.
      expect(
        find.descendant(
          of: find.byType(PuanDagilimiSheet),
          matching: find.byIcon(Icons.person),
        ),
        findsOneWidget,
      );
    });
  });
}
