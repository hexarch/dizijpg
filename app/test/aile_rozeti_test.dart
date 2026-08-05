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
/// koy ve yanına 'Dizi jpg aile üyesi' yaz"
///
/// Bu testler rozeti kilitler:
///  - `testci: true` → logo + metin görünür; `false`/eksik → GÖRÜNMEZ,
///  - ÜLKESİ BOŞ testçide de görünür (karar: rozet ülkeye BAĞLI DEĞİL —
///    canlıda 8 testçinin 3'ünün ülkesi boş, bağlansa onlar rozeti hiç
///    göremezdi; ülke varsa istendiği gibi bayrağın yanında durur),
///  - hem kendi profilinde hem başkasınınkinde,
///  - 360 dp'de en uzun ülke adıyla birlikte bile TAŞMA YOK (Wrap alt satıra
///    indirir),
///  - logo varlığının kırpma sabitleri gerçek PNG ile uyuşuyor.
const String _metin = 'Dizi jpg aile üyesi';
const double _darEkran = 360;

/// 600: tek-boşluklu deneme yazı tipinde sekme etiketleri 360'ta taşıyor
/// (gerçek yazı tipinde taşma yok). Rozet ölçümleri buradan yapılır.
const Size _ekran = Size(600, 900);

Map<String, dynamic> _acikProfil({String? ulke, bool? testci}) => {
  'id': 7,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'kapak': null,
  'bio': null,
  'ulke': ulke,
  if (testci != null) 'testci': testci,
  'sosyal': <dynamic>[],
  'ben_mi': false,
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
}) async {
  _sunucu({'/profil/': _acikProfil(ulke: ulke, testci: testci)});
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
}
