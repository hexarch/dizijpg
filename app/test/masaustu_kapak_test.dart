import 'package:cached_network_image/cached_network_image.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// MASAÜSTÜNDE KAPAK GÖRSELLERİ (6 Ağu 2026 şikâyeti):
/// "masaüstü görünüşte film dizi kapak görselleri çok kötü duruyor".
///
/// CANLI ÖLÇÜM (dizijpg.com, pencere 1512 dp, devicePixelRatio 2):
///   * Ağ isteklerinin TAMAMI `image.tmdb.org/t/p/w342/...` — kart genişliği ne
///     olursa olsun sabit 342 px.
///   * Kitaplık/izlediklerim/arama/kişi ızgaraları `crossAxisCount: 3`e
///     sabitlenmişti → kart ~486 dp → 2x ekranda 972 fiziksel piksel gerekir,
///     342 px görsel 2,84 KAT büyütülüyordu.
///   * /gozat 6 sütunda kart 241 dp → 482 px gerek, 342 px çekiliyordu (1,41x).
///   * `childAspectRatio: 0.5` sabiti yüzünden hücre yüksekliği kart
///     genişliğinin 2 katıydı; poster (1,5x) + başlık toplamı bunu doldurmuyor,
///     241 dp'lik kartta satır altında ~80 dp ÖLÜ BOŞLUK kalıyordu.
///
/// Bu dosya düzeltmenin üç ayağını da GERÇEK ÖLÇÜMLE kilitler
/// (`tester.getRect`, sabit varsayım yok):
///   1. TMDB boyutu kart genişliği x devicePixelRatio ile ölçeklenir.
///   2. Poster en-boy oranı her genişlikte 2:3 kalır, hücrede ölü boşluk yok.
///   3. Sütun sayısı/kart genişliği kırılım noktalarına uyar.
///   4. Görselsiz içerikte yedek gösterim çizilir.
/// MOBİL REGRESYON: 360/390 dp'de sütun sayısı, kart genişliği ve çekilen
/// boyut BİREBİR eskisi gibi kalır — masaüstü için büyütülen görseller mobil
/// veriyi yakmasın.

const String _posterYolu = '/abcDEF123.jpg';

/// Mantıksal genişlik + piksel yoğunluğu birlikte kurulur: `physicalSize`
/// FİZİKSEL pikseldir, mantıksal genişlik = fiziksel / dpr.
void _ekran(WidgetTester tester, double genislikDp, double dpr) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(genislikDp * dpr, 1000 * dpr);
  addTearDown(tester.view.reset);
}

Map<String, dynamic> _icerik(int id, {String? poster = _posterYolu}) => {
  'id': id,
  'title': 'Uzun Bir Dizi Adı Örneği',
  'poster_path': poster,
  'vote_average': 8.1,
};

/// Ekranlardaki ızgaraların AYNISI: 16 dp yatay dolgu + [PosterIzgarasi].
Widget _izgara({int adet = 24, String? poster = _posterYolu}) => MaterialApp(
  theme: diziTema(acik: false),
  home: Scaffold(
    body: GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      gridDelegate: const PosterIzgarasi(satirBoslugu: 14, bosluk: 10),
      itemCount: adet,
      itemBuilder: (_, i) =>
          PosterKarti(icerik: _icerik(100 + i, poster: poster)),
    ),
  ),
);

Widget _serit() => MaterialApp(
  theme: diziTema(acik: false),
  home: Scaffold(
    body: PosterSeridi(
      baslik: 'Haftanın Dizileri',
      icerikler: [for (var i = 0; i < 8; i++) _icerik(200 + i)],
    ),
  ),
);

/// i. poster kartının ÖLÇÜLEN dikdörtgeni.
Rect _kart(WidgetTester tester, int i) =>
    tester.getRect(find.byType(PosterKarti).at(i));

/// i. kartın poster görselinin ÖLÇÜLEN dikdörtgeni (2:3 kutusu).
Rect _posterKutusu(WidgetTester tester, int i) => tester.getRect(
  find.descendant(
    of: find.byType(PosterKarti).at(i),
    matching: find.byType(AspectRatio),
  ),
);

/// i. kartın istediği TMDB adresi.
String _url(WidgetTester tester, int i) => tester
    .widget<CachedNetworkImage>(
      find.descendant(
        of: find.byType(PosterKarti).at(i),
        matching: find.byType(CachedNetworkImage),
      ),
    )
    .imageUrl;

/// Aynı satırdaki kaç kart var: ilk kartla aynı `top` değerine sahip olanlar.
/// Tembel ızgara ekrana sığandan fazlasını kurmaz — KURULMUŞ kart sayısı
/// üzerinden gezilir, sabit sayı varsayılmaz.
int _sutunSayisi(WidgetTester tester) {
  final kurulan = find.byType(PosterKarti).evaluate().length;
  expect(kurulan, greaterThan(0), reason: 'hiç poster kartı çizilmedi');
  final ust = _kart(tester, 0).top;
  var n = 0;
  for (var i = 0; i < kurulan; i++) {
    if ((_kart(tester, i).top - ust).abs() < 0.5) n++;
  }
  return n;
}

void main() {
  // -------------------------------------------------------------------------
  // 1) TMDB boyut seçimi — saf işlev, kart genişliği x piksel yoğunluğu
  // -------------------------------------------------------------------------
  group('posterBoyutu', () {
    test(
      'BUGÜNKÜ HATA: 3 sütunlu 1440 dp ekranda kart 469 dp → w342 YETMEZ',
      () {
        // (1440 - 32 dolgu - 20 boşluk) / 3 = 462.67 dp; 2x ekranda 925 piksel.
        expect(posterBoyutu(462.67, 2), 'w780');
        // 6 sütunlu /gozat: 241 dp → 482 piksel; w342 %41 büyütme demekti.
        expect(posterBoyutu(241, 2), 'w500');
      },
    );

    test('232 dp kart x dpr 2 = 464 piksel → w500', () {
      expect(posterBoyutu(232, 2), 'w500');
    });

    test('hedef bant (168 dp) x dpr 2 = 336 piksel → w342 (büyütme YOK)', () {
      expect(posterBoyutu(posterKartHedefGenisligi, 2), 'w342');
      expect(posterKartHedefGenisligi * 2, lessThanOrEqualTo(342));
    });

    test('aynı kart 3x yoğunlukta 504 piksel ister → w500', () {
      expect(posterBoyutu(posterKartHedefGenisligi, 3), 'w500');
    });

    test('MOBİL DEĞİŞMEDİ: 118 dp kart 2x ve 3x ekranda hâlâ w342', () {
      // 118*3 = 354 px; w342 yalnız %3,5 büyütülür, w500 boşuna 2 kat bayt.
      expect(posterBoyutu(seritKartGenisligi, 2), 'w342');
      expect(posterBoyutu(seritKartGenisligi, 3), 'w342');
      expect(posterBoyutu(105, 2), 'w342'); // MiniIcerik varsayılanı
    });

    test('tavan w780 — "original" ASLA istenmez', () {
      expect(posterBoyutu(2000, 3), 'w780');
      expect(posterBoyutu(486, 2), 'w780');
    });

    test('ölçülemeyen genişlikte tabana düşer (çökmez)', () {
      expect(posterBoyutu(double.infinity, 2), 'w342');
      expect(posterBoyutu(0, 2), 'w342');
      expect(posterBoyutu(-5, 2), 'w342');
      expect(posterBoyutu(168, 0), 'w342');
    });
  });

  // -------------------------------------------------------------------------
  // 2) Sütun sayısı ve kart genişliği — kırılım noktaları
  // -------------------------------------------------------------------------
  group('ızgara kırılım noktaları', () {
    testWidgets('1440 dp: 3 sütun DEĞİL, kart hedef bantta', (tester) async {
      _ekran(tester, 1440, 2);
      await tester.pumpWidget(_izgara());

      final sutun = _sutunSayisi(tester);
      expect(
        sutun,
        greaterThan(3),
        reason: 'masaüstünde 3 sütun kaldı → kart 460+ dp, bulanık ve devasa',
      );
      final kart = _kart(tester, 0);
      expect(
        kart.width,
        inInclusiveRange(140, 200),
        reason: 'kart genişliği ${kart.width} dp hedef bandın dışında',
      );
      // 8 sütun x 167.25 dp + 7 x 10 boşluk = 1408 = 1440 - 32 dolgu.
      expect(sutun, 8);
      expect(kart.width, closeTo(167.25, 0.1));
    });

    testWidgets('1920 dp: sütun sayısı artar, kart genişliği sabit kalır', (
      tester,
    ) async {
      _ekran(tester, 1920, 2);
      await tester.pumpWidget(_izgara(adet: 36));

      expect(_sutunSayisi(tester), 11);
      expect(_kart(tester, 0).width, closeTo(162.5, 0.1));
    });

    testWidgets('MOBİL REGRESYON: 360 dp hâlâ 3 sütun, kart eskisi gibi', (
      tester,
    ) async {
      _ekran(tester, 360, 2);
      await tester.pumpWidget(_izgara());

      expect(_sutunSayisi(tester), 3, reason: 'telefonda 3 sütun şart');
      // (360 - 32 dolgu - 20 boşluk) / 3 = 102.67 — eski düzenle aynı.
      expect(_kart(tester, 0).width, closeTo(102.67, 0.05));
    });

    testWidgets('MOBİL REGRESYON: 390 dp de 3 sütun', (tester) async {
      _ekran(tester, 390, 3);
      await tester.pumpWidget(_izgara());
      expect(_sutunSayisi(tester), 3);
    });

    test('saf işlev: alt sınır 3, telefon genişlikleri değişmez', () {
      for (final telefon in [360.0, 390.0, 412.0, 430.0]) {
        expect(posterSutunlari(telefon - 32), 3, reason: '$telefon dp');
      }
      expect(posterSutunlari(1440 - 32), 8);
      expect(posterSutunlari(1920 - 32), 11);
      expect(posterSutunlari(double.infinity), 3);
      expect(posterSutunlari(0), 3);
    });
  });

  // -------------------------------------------------------------------------
  // 3) Poster oranı 2:3 ve hücrede ölü boşluk yok
  // -------------------------------------------------------------------------
  group('poster oranı ve hücre yüksekliği', () {
    testWidgets('poster 2:3 — 1440 dp masaüstünde', (tester) async {
      _ekran(tester, 1440, 2);
      await tester.pumpWidget(_izgara());

      final p = _posterKutusu(tester, 0);
      expect(
        p.width / p.height,
        closeTo(2 / 3, 0.001),
        reason: 'poster ${p.width}x${p.height} → oran bozuk',
      );
    });

    testWidgets('poster 2:3 — 360 dp telefonda da aynı', (tester) async {
      _ekran(tester, 360, 2);
      await tester.pumpWidget(_izgara());

      final p = _posterKutusu(tester, 0);
      expect(p.width / p.height, closeTo(2 / 3, 0.001));
    });

    testWidgets('hücrede ölü boşluk yok: yükseklik = poster + başlık payı', (
      tester,
    ) async {
      _ekran(tester, 1440, 2);
      await tester.pumpWidget(_izgara());

      final kart = _kart(tester, 0);
      final beklenen = kart.width * 1.5 + posterBaslikYuksekligi;
      expect(
        kart.height,
        closeTo(beklenen, 0.01),
        reason: 'hücre ${kart.height}, gereken $beklenen',
      );
      // ESKİ DAVRANIŞ (childAspectRatio 0.5) bu genişlikte 334.5 dp verirdi:
      // poster 250.9 + başlık ~42 = 293 → 41 dp ölü boşluk.
      expect(
        kart.height,
        lessThan(kart.width * 2),
        reason: 'childAspectRatio 0.5 sabiti geri gelmiş',
      );
      // Başlık payı gerçekten yetiyor mu: taşma istisnası olmamalı.
      expect(tester.takeException(), isNull);
    });

    testWidgets('satır aralığı da orantılı (satırlar arası boşluk 14)', (
      tester,
    ) async {
      _ekran(tester, 1440, 2);
      await tester.pumpWidget(_izgara());

      final ilkSatir = _kart(tester, 0);
      final ikinciSatir = _kart(tester, 8); // 8 sütun → 9. kart alt satırda
      expect(
        ikinciSatir.top - ilkSatir.top,
        closeTo(ilkSatir.height + 14, 0.1),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 4) ÖLÇÜLEN genişliğe göre TMDB boyutu — asıl kanıt
  // -------------------------------------------------------------------------
  group('çekilen TMDB boyutu ölçülen karta uyuyor', () {
    testWidgets('1440 dp / dpr 3: kart 167 dp → 502 piksel → w500 çekilir', (
      tester,
    ) async {
      _ekran(tester, 1440, 3);
      await tester.pumpWidget(_izgara());

      final kart = _kart(tester, 0);
      final gereken = kart.width * 3;
      expect(gereken, greaterThan(342));
      expect(
        _url(tester, 0),
        contains('/w500$_posterYolu'),
        reason:
            'kart ${kart.width} dp x dpr 3 = $gereken piksel istiyor; '
            'sabit w342 %${((gereken / 342 - 1) * 100).round()} büyütme demek',
      );
    });

    testWidgets('1440 dp / dpr 2: kart 167 dp → 334 piksel → w342 yeter', (
      tester,
    ) async {
      _ekran(tester, 1440, 2);
      await tester.pumpWidget(_izgara());

      final kart = _kart(tester, 0);
      expect(kart.width * 2, lessThanOrEqualTo(342));
      expect(_url(tester, 0), contains('/w342$_posterYolu'));
    });

    testWidgets('DAR HÜCRE: 3 sütun zorlanırsa kart 460 dp → w780 çekilir', (
      tester,
    ) async {
      // Eski ızgara davranışının canlandırılması: kart gerçekten büyükse
      // seçim de büyümeli (yardımcı yalnız sütun sayısına bağlı değil).
      _ekran(tester, 1440, 2);
      await tester.pumpWidget(
        MaterialApp(
          theme: diziTema(acik: false),
          home: Scaffold(
            body: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                childAspectRatio: 0.5,
              ),
              itemCount: 3,
              itemBuilder: (_, i) => PosterKarti(icerik: _icerik(300 + i)),
            ),
          ),
        ),
      );

      final kart = _kart(tester, 0);
      expect(kart.width, closeTo(462.67, 0.1));
      expect(_url(tester, 0), contains('/w780$_posterYolu'));
    });

    testWidgets('MOBİL REGRESYON: 360 dp / dpr 3 hâlâ w342 (veri yakılmaz)', (
      tester,
    ) async {
      _ekran(tester, 360, 3);
      await tester.pumpWidget(_izgara());

      expect(
        _url(tester, 0),
        contains('/w342$_posterYolu'),
        reason: 'telefonda daha büyük görsel çekilirse mobil veri boşa gider',
      );
    });

    testWidgets('aynı kart aynı adresi ister (gereksiz ikinci indirme yok)', (
      tester,
    ) async {
      _ekran(tester, 1440, 2);
      await tester.pumpWidget(_izgara());

      // Aynı satırdaki tüm kartlar aynı genişlikte → hepsi AYNI boyutu ister.
      // Sütun sütun farklı boyut istenirse TMDB/Cloudflare önbelleği bölünür.
      final ilk = _url(tester, 0).split('/').reversed.elementAt(1);
      for (var i = 1; i < 8; i++) {
        expect(_url(tester, i).split('/').reversed.elementAt(1), ilk);
      }
    });
  });

  // -------------------------------------------------------------------------
  // 5) Görselsiz içerik + şerit
  // -------------------------------------------------------------------------
  group('yedek gösterim ve yatay şerit', () {
    testWidgets('poster_path null → yedek ikon çizilir, oran yine 2:3', (
      tester,
    ) async {
      _ekran(tester, 1440, 2);
      await tester.pumpWidget(_izgara(adet: 3, poster: null));

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(
        find.descendant(
          of: find.byType(PosterKarti).at(0),
          matching: find.byIcon(Icons.movie),
        ),
        findsOneWidget,
        reason: 'görselsiz içerikte boş kutu değil, yedek ikon görünmeli',
      );
      final p = _posterKutusu(tester, 0);
      expect(
        p.width / p.height,
        closeTo(2 / 3, 0.001),
        reason: 'yedek kutu da poster oranında olmalı (yerleşim kaymasın)',
      );
    });

    testWidgets('şerit masaüstünde büyür (118 dp pul kartlar kalmaz)', (
      tester,
    ) async {
      _ekran(tester, 1440, 2);
      await tester.pumpWidget(_serit());

      final kart = _kart(tester, 0);
      expect(kart.width, posterKartHedefGenisligi);
      expect(kart.width, greaterThan(seritKartGenisligi));
    });

    testWidgets('MOBİL REGRESYON: şerit 360 dp\'de birebir 118 x 236', (
      tester,
    ) async {
      _ekran(tester, 360, 2);
      await tester.pumpWidget(_serit());

      expect(_kart(tester, 0).width, seritKartGenisligi);
      expect(_kart(tester, 0).width, 118);
      // Şerit yüksekliği: 118 * 1.5 + 59 = 236 (bugünkü sabit).
      expect(seritKartGenisligi * 1.5 + seritBaslikPayi, 236);
    });

    testWidgets(
      'iskelet ile gerçek kart AYNI ölçüde (içerik gelince zıplamaz)',
      (tester) async {
        // Keşfet iskelet rafı da [seritKartiGenisligi] kullanır; iki düzende de
        // yüklenen şeritle aynı genişliği vermeli.
        for (final genislik in [360.0, 1440.0]) {
          late double iskelet;
          await tester.pumpWidget(
            MaterialApp(
              theme: diziTema(acik: false),
              home: Builder(
                builder: (c) {
                  iskelet = seritKartiGenisligi(c);
                  return const Scaffold(body: SizedBox.expand());
                },
              ),
            ),
          );
          _ekran(tester, genislik, 2);
          await tester.pumpWidget(_serit());
          await tester.pumpWidget(
            MaterialApp(
              theme: diziTema(acik: false),
              home: Builder(
                builder: (c) {
                  iskelet = seritKartiGenisligi(c);
                  return const Scaffold(body: SizedBox.expand());
                },
              ),
            ),
          );
          await tester.pumpWidget(_serit());
          expect(
            _kart(tester, 0).width,
            iskelet,
            reason: '$genislik dp: iskelet $iskelet, gerçek kart farklı',
          );
        }
      },
    );
  });
}
