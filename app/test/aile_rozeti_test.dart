import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dizijpg/aile_rozeti.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/bayrak.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// KULLANICI İSTEĞİ (5 Ağu 2026): "tester olarak eklediğimiz mail adresinden
/// kayıt olan kullanıcıların profilinde ülke bayrağı yanında dizi.jpg logosu
/// koy ve yanına yaz" — etiket aynı gün "Founding Member" olarak sabitlendi,
/// ardından "rozete dokununca ne olduğunu anlatan modal açılsın" istendi.
///
/// Bu testler rozeti kilitler:
///  - `testci: true` → logo + metin görünür; `false`/eksik → GÖRÜNMEZ,
///  - ÜLKESİ BOŞ testçide de görünür (karar: rozet ülkeye BAĞLI DEĞİL —
///    canlıda 8 testçinin 3'ünün ülkesi boş, bağlansa onlar rozeti hiç
///    göremezdi; ülke varsa istendiği gibi bayrağın yanında durur),
///  - hem kendi profilinde hem başkasınınkinde,
///  - 360 dp'de en uzun ülke adıyla birlikte bile TAŞMA YOK (Wrap alt satıra
///    indirir),
///  - logo varlığının kırpma sabitleri gerçek PNG ile uyuşuyor,
///  - DOKUNMA: hedef ≥44 dp, modal açılıyor, gövde cümlesi `ben_mi`ye göre
///    ikinci tekil şahsa dönüyor, modal kapanıyor.
const String _metin = AileRozeti.etiket;
const double _darEkran = 360;

/// 600: tek-boşluklu deneme yazı tipinde sekme etiketleri 360'ta taşıyor
/// (gerçek yazı tipinde taşma yok). Rozet ölçümleri buradan yapılır.
const Size _ekran = Size(600, 900);

Map<String, dynamic> _acikProfil({
  String? ulke,
  bool? testci,
  bool benMi = false,
}) => {
  'id': 7,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'kapak': null,
  'bio': null,
  'ulke': ulke,
  if (testci != null) 'testci': testci,
  'sosyal': <dynamic>[],
  'ben_mi': benMi,
  'takip_ediyorum': false,
  'yorumlar_gizli': false,
  'istatistik': {
    'takipci': 3,
    'takip_edilen': 2,
    'yorum': 0,
    'film': 0,
    'bolum': 0,
    'dizi': 0,
    'tahmini_dakika': 0,
    'toplam_begeni': 0,
    'toplam_goruntulenme': 0,
  },
  'rozetler': <dynamic>[],
  'izlenenler': <dynamic>[],
  'listeler': <dynamic>[],
  'yorumlar': <dynamic>[],
  'icerikler': <String, dynamic>{},
};

void _sunucu(Map<String, Object> yollar) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    for (final e in yollar.entries) {
      if (yol.startsWith(e.key)) {
        return http.Response(
          jsonEncode(e.value),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
    }
    return http.Response(
      '{}',
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Future<void> _baskasi(
  WidgetTester tester, {
  String? ulke,
  bool? testci,
  Size? boyut,
  bool benMi = false,
}) async {
  _sunucu({'/profil/': _acikProfil(ulke: ulke, testci: testci, benMi: benMi)});
  await _kur(
    tester,
    const KullaniciProfilEkrani(kullaniciAdi: 'thelostvibe0'),
    boyut,
  );
}

/// Kendi profil ekranı başlığını `/profilim` ile çizer — rozet oradan gelir.
Future<void> _kendim(
  WidgetTester tester, {
  String? ulke,
  bool? testci,
  Size? boyut,
}) async {
  _sunucu({
    '/istatistiklerim': {'tahmini_dakika': 0, 'dizi': 0, 'film': 0},
    '/kitapligim': {'durumlar': <dynamic>[]},
    '/listelerim': {'listeler': <dynamic>[]},
    '/profilim': {
      'id': 7,
      'kullanici_adi': 'thelostvibe0',
      'avatar': null,
      'kapak': null,
      'bio': null,
      'ulke': ulke,
      if (testci != null) 'testci': testci,
      'sosyal': <dynamic>[],
    },
    '/izlediklerim': {'ogeler': <dynamic>[]},
    '/rozetler': {'rozetler': <dynamic>[]},
    '/profil/': _acikProfil(ulke: ulke, testci: testci),
  });
  await _kur(tester, const ProfilEkrani(), boyut);
}

Future<void> _kur(WidgetTester tester, Widget ekran, Size? boyut) async {
  await tester.binding.setSurfaceSize(boyut ?? _ekran);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(home: ekran),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Rozet içindeki dizi.jpg logosu (varlık adına bakar, kod çözmeyi beklemez).
final Finder _logoGorseli = find.byWidgetPredicate((w) {
  if (w is! Image) return false;
  final k = w.image;
  return k is AssetImage && k.assetName == 'assets/logo.png';
}, description: 'assets/logo.png');

void main() {
  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    SharedPreferences.setMockInitialValues({
      'token': 'sahte',
      'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'thelostvibe0'}),
    });
    await Api.tokenYukle();
    DiziRenkler.acik = false;
  });

  tearDown(() => DiziRenkler.acik = false);

  // ---------------------------------------------------------------------
  // Varlık: kırpma sabitleri gerçekten logo.png ile uyuşuyor mu?
  // ---------------------------------------------------------------------
  testWidgets('VARLIK: logo.png kırpma sabitleri gerçek mürekkeple uyuşuyor', (
    tester,
  ) async {
    // DiziLogosu, saydam kenar boşluğunu kırpmak için ölçülmüş bir dikdörtgen
    // kullanıyor. Logo yeniden çizilirse (kenar boşluğu değişirse) rozet ya
    // kayar ya kırpılır — burası o anda kırmızıya döner.
    final kutu = await tester.runAsync(() async {
      final veri = await rootBundle.load('assets/logo.png');
      final kodlayici = await ui.instantiateImageCodec(
        veri.buffer.asUint8List(),
      );
      final kare = await kodlayici.getNextFrame();
      final resim = kare.image;
      final bayt = await resim.toByteData(format: ui.ImageByteFormat.rawRgba);
      final p = bayt!.buffer.asUint8List();
      int solx = resim.width, ustx = resim.height, sagx = -1, altx = -1;
      for (var y = 0; y < resim.height; y++) {
        for (var x = 0; x < resim.width; x++) {
          if (p[(y * resim.width + x) * 4 + 3] > 16) {
            if (x < solx) solx = x;
            if (x > sagx) sagx = x;
            if (y < ustx) ustx = y;
            if (y > altx) altx = y;
          }
        }
      }
      final olcu = Size(resim.width.toDouble(), resim.height.toDouble());
      resim.dispose();
      kodlayici.dispose();
      return (
        olcu,
        Rect.fromLTRB(solx.toDouble(), ustx.toDouble(), sagx + 1.0, altx + 1.0),
      );
    });
    expect(kutu!.$1.width, DiziLogosu.tuval);
    expect(kutu.$1.height, DiziLogosu.tuval);
    expect(kutu.$2, DiziLogosu.murekkep);
  });

  // ---------------------------------------------------------------------
  // Görünürlük
  // ---------------------------------------------------------------------
  testWidgets('BAŞKASININ PROFİLİ: testci true → logo + metin görünür', (
    tester,
  ) async {
    await _baskasi(tester, ulke: 'Türkiye', testci: true);
    expect(find.byType(AileRozeti), findsOneWidget);
    expect(find.text(_metin), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AileRozeti), matching: _logoGorseli),
      findsOneWidget,
    );
    // Ülke satırı yerinde duruyor; rozet onun yanında.
    expect(find.byType(UlkeBayragi), findsOneWidget);
    expect(find.text('Türkiye'), findsOneWidget);
  });

  testWidgets('BAŞKASININ PROFİLİ: testci false → rozet YOK', (tester) async {
    await _baskasi(tester, ulke: 'Türkiye', testci: false);
    expect(find.byType(AileRozeti), findsNothing);
    expect(find.text(_metin), findsNothing);
    expect(_logoGorseli, findsNothing);
    // Ülke satırı bozulmadı.
    expect(find.byType(UlkeBayragi), findsOneWidget);
    expect(find.text('Türkiye'), findsOneWidget);
  });

  testWidgets('ESKİ SUNUCU: testci alanı hiç yoksa rozet YOK (çökme de yok)', (
    tester,
  ) async {
    await _baskasi(tester, ulke: 'Almanya');
    expect(find.byType(AileRozeti), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KENDİ PROFİLİM: testci true → logo + metin görünür', (
    tester,
  ) async {
    await _kendim(tester, ulke: 'Almanya', testci: true);
    expect(find.byType(AileRozeti), findsOneWidget);
    expect(find.text(_metin), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AileRozeti), matching: _logoGorseli),
      findsOneWidget,
    );
  });

  testWidgets('KENDİ PROFİLİM: testci false → rozet YOK', (tester) async {
    await _kendim(tester, ulke: 'Almanya', testci: false);
    expect(find.byType(AileRozeti), findsNothing);
    expect(find.text(_metin), findsNothing);
  });

  // ---------------------------------------------------------------------
  // KARAR: rozet ülkeden BAĞIMSIZ görünür
  // ---------------------------------------------------------------------
  testWidgets('ÜLKESİ BOŞ testçi: rozet GÖRÜNÜR, ülke parçası çizilmez', (
    tester,
  ) async {
    // Canlıda işaretlenen 8 hesabın 3'ünün ülkesi boş. Rozet ülke satırına
    // bağlansaydı bu kişiler onu hiç göremezdi — istek "testçilerin
    // profilinde rozet olsun"du, "ülkesi olan testçilerin" değil.
    await _baskasi(tester, ulke: null, testci: true);
    expect(find.byType(AileRozeti), findsOneWidget);
    expect(find.text(_metin), findsOneWidget);
    expect(find.byType(UlkeSatiri), findsNothing);
    expect(find.byType(UlkeBayragi), findsNothing);
  });

  testWidgets(
    'ÜLKESİ BOŞ METİN olan testçi: rozet yine görünür (kendi profil)',
    (tester) async {
      await _kendim(tester, ulke: '', testci: true);
      expect(find.byType(AileRozeti), findsOneWidget);
      expect(find.byType(UlkeSatiri), findsNothing);
    },
  );

  testWidgets('ülkesi boş + testçi DEĞİL: satırın tamamı çizilmez', (
    tester,
  ) async {
    await _baskasi(tester, ulke: null, testci: false);
    expect(find.byType(AileRozeti), findsNothing);
    expect(find.byType(UlkeSatiri), findsNothing);
  });

  // ---------------------------------------------------------------------
  // Ölçü / hizalama
  // ---------------------------------------------------------------------
  testWidgets('logo metinle aynı hizada ve okunur boyutta', (tester) async {
    await _baskasi(tester, ulke: 'Türkiye', testci: true);
    final logo = tester.getRect(find.byType(DiziLogosu));
    final metinKutu = tester.getRect(find.text(_metin));
    // Mürekkep 11 dp + 2 dp dolgu (üst/alt) = 15 dp pul yüksekliği.
    expect(logo.height, greaterThan(10));
    expect(logo.height, lessThan(22));
    // Dikey merkezler birbirine yakın (aynı satırda duruyor).
    expect((logo.center.dy - metinKutu.center.dy).abs(), lessThan(3));
    // Logo metnin SOLUNDA.
    expect(logo.right, lessThanOrEqualTo(metinKutu.left + 0.01));
  });

  testWidgets('AÇIK TEMA: logo daima koyu pulun üstünde çizilir', (
    tester,
  ) async {
    // logo.png koyu zemin için çizilmiş (DİZİ harfleri açık gri + ince siyah
    // kontur). Rozet boyutunda kontur kaybolduğu için açık temanın kırık beyaz
    // zemininde erirdi; bu yüzden altına DAİMA koyu pul konur.
    DiziRenkler.acik = true;
    await _baskasi(tester, ulke: 'Türkiye', testci: true);
    final kutu = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(DiziLogosu),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final sekil = kutu.decoration as BoxDecoration;
    expect(sekil.color, DiziRenkler.markaKoyu);
    // Pul gerçekten koyu: parlaklığı düşük olmalı.
    expect(sekil.color!.computeLuminance(), lessThan(0.05));
    // Açık temada metin de okunur tonda (sarıMetin hardal, marka sarısı değil).
    final metin = tester.widget<Text>(find.text(_metin));
    expect(metin.style!.color, DiziRenkler.sariMetin);
    expect(metin.style!.color, isNot(DiziRenkler.sari));
  });

  testWidgets('KOYU TEMA: metin marka sarısına döner', (tester) async {
    DiziRenkler.acik = false;
    await _baskasi(tester, ulke: 'Türkiye', testci: true);
    final metin = tester.widget<Text>(find.text(_metin));
    expect(metin.style!.color, DiziRenkler.sari);
  });

  // ---------------------------------------------------------------------
  // Dar ekran: taşma yok
  // ---------------------------------------------------------------------
  testWidgets('360 dp: rozet + EN UZUN ülke adı — hiç taşma yok (izole)', (
    tester,
  ) async {
    // Profil ekranının tamamı 360 dp'de deneme yazı tipiyle sekme etiketlerini
    // taşırıyor (gerçek yazı tipinde olmayan, rozetle ilgisiz bir gürültü —
    // profil_ulke_bayragi_test.dart'ta da belgelenmiş). Bu yüzden "hiç taşma
    // yok" iddiası, ekrandaki DÜZENİN AYNISI kurularak burada ölçülür:
    // gerçek UlkeSatiri + gerçek AileRozeti, aynı Wrap parametreleriyle.
    await tester.binding.setSurfaceSize(const Size(_darEkran, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const SizedBox(width: 80 + 16), // avatar + boşluk
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          UlkeSatiri(ulke: 'Amerika Birleşik Devletleri'),
                          AileRozeti(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    // ASIL İDDİA: tek bir taşma bile yok.
    expect(tester.takeException(), isNull);

    // İkisi de ekranda ve ekranın içinde.
    expect(find.byType(UlkeBayragi), findsOneWidget);
    expect(find.byType(AileRozeti), findsOneWidget);
    final rozet = tester.getRect(find.byType(AileRozeti));
    final ulke = tester.getRect(find.byType(UlkeSatiri));
    expect(ulke.left, greaterThanOrEqualTo(0));
    expect(ulke.right, lessThanOrEqualTo(_darEkran + 0.01));
    expect(rozet.right, lessThanOrEqualTo(_darEkran + 0.01));
    expect(rozet.width, greaterThan(0));
    // Yer kalmadığı için rozet ALT SATIRA indi (kırpılmadı, taşmadı).
    expect(rozet.top, greaterThanOrEqualTo(ulke.bottom - 0.01));
    // Rozet metni gerçekten görünür (sıfır genişliğe ezilmedi).
    expect(tester.getRect(find.text(_metin)).width, greaterThan(0));
  });

  testWidgets('360 dp: kısa ülke adında rozet AYNI satırda kalır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(_darEkran, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              UlkeSatiri(ulke: 'Çin'),
              AileRozeti(),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    final rozet = tester.getRect(find.byType(AileRozeti));
    final ulke = tester.getRect(find.byType(UlkeSatiri));
    expect(rozet.left, greaterThan(ulke.right - 0.01));
    expect((rozet.center.dy - ulke.center.dy).abs(), lessThan(3));
  });

  testWidgets('360 dp gerçek ekran: rozet ekranın dışına taşmıyor', (
    tester,
  ) async {
    await _baskasi(
      tester,
      ulke: 'Amerika Birleşik Devletleri',
      testci: true,
      boyut: const Size(_darEkran, 800),
    );
    expect(find.byType(AileRozeti), findsOneWidget);
    final rozet = tester.getRect(find.byType(AileRozeti));
    expect(rozet.left, greaterThanOrEqualTo(0));
    expect(rozet.right, lessThanOrEqualTo(_darEkran + 0.01));
    expect(tester.getRect(find.text(_metin)).width, greaterThan(0));

    // Bu ekranda 360 dp'de KALAN tek taşma sekme etiketlerinden gelir (deneme
    // yazı tipi; ülke/rozet satırı olmasa da oluşur — üstteki izole test o
    // satırda hiç taşma olmadığını kanıtlıyor).
    final istisna = tester.takeException();
    if (istisna != null) {
      expect(
        istisna.toString(),
        contains('overflowed'),
        reason: 'beklenmeyen istisna: $istisna',
      );
    }
  });

  // ---------------------------------------------------------------------
  // DOKUNMA HEDEFİ
  // ---------------------------------------------------------------------
  testWidgets('DOKUNMA HEDEFİ: rozet en az 44x44 dp (yazı büyütülmeden)', (
    tester,
  ) async {
    await _baskasi(tester, ulke: 'Türkiye', testci: true);
    final hedef = tester.getRect(find.byType(AileRozeti));
    expect(
      hedef.height,
      greaterThanOrEqualTo(44),
      reason: 'dokunma hedefi 44 dp altına düştü: ${hedef.height}',
    );
    expect(hedef.width, greaterThanOrEqualTo(44));
    // Hedef DOLGUYLA büyüdü, YAZIYLA değil: etiket hâlâ 12 punto.
    expect(tester.widget<Text>(find.text(_metin)).style!.fontSize, 12);
    // Logo da büyümedi (mürekkep 11 + 2x2 dolgu = 15 dp pul).
    expect(tester.getRect(find.byType(DiziLogosu)).height, lessThan(22));
  });

  // ---------------------------------------------------------------------
  // MODAL: kendi profilim / başkasının profili ayrımı
  // ---------------------------------------------------------------------
  testWidgets('BAŞKASININ PROFİLİ: dokununca ÜÇÜNCÜ ŞAHIS cümlesi açılır', (
    tester,
  ) async {
    await _baskasi(tester, ulke: 'Türkiye', testci: true);
    // Modal daha açılmadı.
    expect(find.text(aileRozetiBaskasi), findsNothing);

    await tester.tap(find.byType(AileRozeti));
    await tester.pumpAndSettle();

    expect(find.text(AileRozeti.etiket), findsWidgets); // rozet + modal başlığı
    expect(find.text(aileRozetiBaskasi), findsOneWidget);
    // KENDİ profil varyantı burada ASLA çıkmaz.
    expect(find.text(aileRozetiBenim), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KENDİ PROFİLİM: dokununca İKİNCİ TEKİL ŞAHIS cümlesi açılır', (
    tester,
  ) async {
    await _kendim(tester, ulke: 'Almanya', testci: true);
    await tester.tap(find.byType(AileRozeti));
    await tester.pumpAndSettle();

    expect(find.text(aileRozetiBenim), findsOneWidget);
    expect(find.text(aileRozetiBaskasi), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'KENDİ KULLANICI ADIMLA açılan kullanıcı profili: ayrım ekranın türünden '
    'değil sunucunun ben_mi yargısından gelir',
    (tester) async {
      // kullanici_profil.dart kendi kullanıcı adınla da açılabiliyor. Ekran
      // türüne bakılsaydı burada yanlışlıkla üçüncü şahıs cümlesi çıkardı.
      await _baskasi(tester, ulke: 'Türkiye', testci: true, benMi: true);
      await tester.tap(find.byType(AileRozeti));
      await tester.pumpAndSettle();

      expect(find.text(aileRozetiBenim), findsOneWidget);
      expect(find.text(aileRozetiBaskasi), findsNothing);
    },
  );

  testWidgets('TESTÇİ DEĞİL: rozet yok, dolayısıyla açılacak modal da yok', (
    tester,
  ) async {
    await _baskasi(tester, ulke: 'Türkiye', testci: false);
    expect(find.byType(AileRozeti), findsNothing);
    // Dokunulacak bir şey yok; iki gövde varyantı da hiçbir yerde çizilmedi.
    expect(find.text(aileRozetiBaskasi), findsNothing);
    expect(find.text(aileRozetiBenim), findsNothing);
  });

  // ---------------------------------------------------------------------
  // MODAL: kalıp / kapanma
  // ---------------------------------------------------------------------
  testWidgets(
    'MODAL: SafeArea var (alt içerik gezinme çubuğu altında kalmaz)',
    (tester) async {
      // Bu hafta üç modalde (ListeSheet, takvim gün detayı, puan verme) alt
      // içerik sistem gezinme çubuğunun altında kalmıştı. Burası o hatayı
      // tekrarlamadığımızı kilitler.
      await _baskasi(tester, ulke: 'Türkiye', testci: true);
      await tester.tap(find.byType(AileRozeti));
      await tester.pumpAndSettle();

      final sheet = find.ancestor(
        of: find.text(aileRozetiBaskasi),
        matching: find.byType(SafeArea),
      );
      expect(sheet, findsWidgets, reason: 'modal SafeArea içinde değil');
      // Alttan açılan sayfa kalıbı: sürükleme tutamağı + BottomSheet.
      expect(find.byType(BottomSheet), findsOneWidget);
    },
  );

  testWidgets('MODAL: "Kapat" ile kapanıyor', (tester) async {
    await _baskasi(tester, ulke: 'Türkiye', testci: true);
    await tester.tap(find.byType(AileRozeti));
    await tester.pumpAndSettle();
    expect(find.text(aileRozetiBaskasi), findsOneWidget);

    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();
    expect(find.text(aileRozetiBaskasi), findsNothing);
    // Rozet yerinde duruyor, tekrar açılabilir.
    expect(find.byType(AileRozeti), findsOneWidget);
  });

  testWidgets('MODAL: dışına dokununca kapanıyor (barrier)', (tester) async {
    await _baskasi(tester, ulke: 'Türkiye', testci: true);
    await tester.tap(find.byType(AileRozeti));
    await tester.pumpAndSettle();
    expect(find.text(aileRozetiBaskasi), findsOneWidget);

    // Sayfanın en üstü: alt sayfanın DIŞI (barrier).
    await tester.tapAt(const Offset(300, 20));
    await tester.pumpAndSettle();
    expect(find.text(aileRozetiBaskasi), findsNothing);
  });

  testWidgets('MODAL: 360 dp genişlikte taşma yok', (tester) async {
    await _baskasi(
      tester,
      ulke: 'Amerika Birleşik Devletleri',
      testci: true,
      boyut: const Size(_darEkran, 800),
    );
    // Ekranın kendi sekme etiketi taşmasını (deneme yazı tipi gürültüsü)
    // modalı açmadan ÖNCE temizle ki kalan taşma yalnız modaldan gelsin.
    tester.takeException();

    await tester.tap(find.byType(AileRozeti));
    await tester.pumpAndSettle();

    expect(find.text(aileRozetiBaskasi), findsOneWidget);
    final govde = tester.getRect(find.text(aileRozetiBaskasi));
    expect(govde.left, greaterThanOrEqualTo(0));
    expect(govde.right, lessThanOrEqualTo(_darEkran + 0.01));
    expect(govde.height, greaterThan(0));
    // ASIL İDDİA: modal 360 dp'de tek bir taşma bile üretmiyor.
    expect(tester.takeException(), isNull);
  });
}
