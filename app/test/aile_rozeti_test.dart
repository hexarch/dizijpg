import 'dart:convert';

import 'package:dizijpg/aile_rozeti.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/bayrak.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsFlag;
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
/// KULLANICI İSTEĞİ (7 Ağu 2026): "Profildeki fonding member yazısını ve dizi
/// jpg yazısını kaldır, kullanıcı adının yanına gold renkde onaylı iconu koy
/// (tabi sadece test kullanıcı olarak belirlediğimiz kişilerde bunlar olacak)"
///
/// Rozet METİNSİZ bir onay tikine indi ve ülke satırından çıkıp KULLANICI
/// ADININ yanına taşındı. Bu testler yeni hâli kilitler:
///  - `testci: true` → tik görünür; `false`/eksik → GÖRÜNMEZ,
///  - tik kullanıcı adının YANINDA (ülke satırında DEĞİL) ve ülkeden bağımsız
///    (canlıda 8 testçinin 3'ünün ülkesi boş — ülkeye bağlansa göremezlerdi),
///  - hem kendi profilinde hem başkasınınkinde,
///  - metinli rozet ve dizi.jpg logosu ARTIK ÇİZİLMİYOR (gerileme koruması),
///  - renk her iki temada da `sariMetin` (marka sarısı açık temada 1,51:1 ile
///    grafik nesne eşiğinin altında kalıyordu),
///  - 360 dp'de uzun kullanıcı adıyla bile tik ekran dışına taşmıyor,
///  - DOKUNMA: hedef ≥44 dp, modal açılıyor, gövde cümlesi `ben_mi`ye göre
///    ikinci tekil şahsa dönüyor, modal kapanıyor.
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

/// Eski tasarımın dizi.jpg logosu. ARTIK ÇİZİLMEMELİ — gerileme koruması
/// olarak duruyor: rozet metinsiz tike indi, logo tamamen kalktı.
final Finder _logoGorseli = find.byWidgetPredicate((w) {
  if (w is! Image) return false;
  final k = w.image;
  return k is AssetImage && k.assetName == 'assets/logo.png';
}, description: 'assets/logo.png');

/// Onay tiki (rozetin İÇİNDEKİ ikon).
final Finder _tik = find.descendant(
  of: find.byType(AileRozeti),
  matching: find.byIcon(Icons.verified),
);

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
  // Görünürlük
  // ---------------------------------------------------------------------
  testWidgets('BAŞKASININ PROFİLİ: testci true → onay tiki görünür', (
    tester,
  ) async {
    await _baskasi(tester, ulke: 'Türkiye', testci: true);
    expect(find.byType(AileRozeti), findsOneWidget);
    expect(_tik, findsOneWidget);
    // Ülke satırı yerinde duruyor ama rozet ARTIK ORADA DEĞİL.
    expect(find.byType(UlkeBayragi), findsOneWidget);
    expect(find.text('Türkiye'), findsOneWidget);
  });

  testWidgets('BAŞKASININ PROFİLİ: testci false → rozet YOK', (tester) async {
    await _baskasi(tester, ulke: 'Türkiye', testci: false);
    expect(find.byType(AileRozeti), findsNothing);
    expect(_tik, findsNothing);
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

  testWidgets('KENDİ PROFİLİM: testci true → onay tiki görünür', (
    tester,
  ) async {
    await _kendim(tester, ulke: 'Almanya', testci: true);
    expect(find.byType(AileRozeti), findsOneWidget);
    expect(_tik, findsOneWidget);
  });

  testWidgets('KENDİ PROFİLİM: testci false → rozet YOK', (tester) async {
    await _kendim(tester, ulke: 'Almanya', testci: false);
    expect(find.byType(AileRozeti), findsNothing);
  });

  // ---------------------------------------------------------------------
  // GERİLEME: eski metinli rozet geri gelmesin
  // ---------------------------------------------------------------------
  testWidgets('metinli rozet ve dizi.jpg logosu ARTIK ÇİZİLMİYOR', (
    tester,
  ) async {
    // 7 Ağu'ya kadar rozet "Founding Member" yazısı + dizi.jpg logosuydu.
    // Kullanıcı ikisinin de kaldırılmasını istedi. Etiket sabiti duruyor ama
    // yalnız MODAL BAŞLIĞINDA kullanılıyor; profilde hiçbir yerde yazmıyor.
    await _baskasi(tester, ulke: 'Türkiye', testci: true);
    expect(find.text(AileRozeti.etiket), findsNothing);
    expect(_logoGorseli, findsNothing);
    // Tik ise yerinde.
    expect(_tik, findsOneWidget);
  });

  // ---------------------------------------------------------------------
  // KONUM: tik kullanıcı adının yanında, ülke satırında DEĞİL
  // ---------------------------------------------------------------------
  testWidgets('tik kullanıcı adının SAĞINDA ve onunla aynı hizada', (
    tester,
  ) async {
    await _baskasi(tester, ulke: 'Türkiye', testci: true);
    final tik = tester.getRect(find.byType(AileRozeti));
    // Kullanıcı adı İKİ yerde çiziliyor: profil başlığı (18 punto, w900) ve
    // üst bar. Ölçüm başlıktakinden yapılmalı — tik onun yanında duruyor.
    final ad = tester.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is Text && w.data == '@thelostvibe0' && w.style?.fontSize != null,
        description: 'profil başlığındaki kullanıcı adı',
      ),
    );
    // Adın sağında.
    expect(tik.left, greaterThanOrEqualTo(ad.right - 0.01));
    // Aynı satırda: dikey merkezler yakın.
    expect((tik.center.dy - ad.center.dy).abs(), lessThan(4));
    // Ve ülke satırının ÜSTÜNDE (artık oraya ait değil).
    final ulke = tester.getRect(find.byType(UlkeSatiri));
    expect(tik.center.dy, lessThan(ulke.top));
  });

  testWidgets('ÜLKESİ BOŞ testçi: tik yine görünür, ülke satırı çizilmez', (
    tester,
  ) async {
    // Canlıda işaretlenen 8 hesabın 3'ünün ülkesi boş. Rozet ülke satırına
    // bağlı OLSAYDI bu kişiler onu hiç göremezdi.
    await _baskasi(tester, ulke: null, testci: true);
    expect(_tik, findsOneWidget);
    expect(find.byType(UlkeSatiri), findsNothing);
    expect(find.byType(UlkeBayragi), findsNothing);
  });

  testWidgets('ÜLKESİ BOŞ METİN olan testçi: tik yine görünür (kendi profil)', (
    tester,
  ) async {
    await _kendim(tester, ulke: '', testci: true);
    expect(_tik, findsOneWidget);
    expect(find.byType(UlkeSatiri), findsNothing);
  });

  testWidgets('ülkesi boş + testçi DEĞİL: ne tik ne ülke satırı', (
    tester,
  ) async {
    await _baskasi(tester, ulke: null, testci: false);
    expect(find.byType(AileRozeti), findsNothing);
    expect(find.byType(UlkeSatiri), findsNothing);
  });

  // ---------------------------------------------------------------------
  // Renk: grafik nesne kontrastı (WCAG 1.4.11, eşik 3:1)
  // ---------------------------------------------------------------------
  testWidgets('KOYU TEMA: tik sariMetin ile boyanır', (tester) async {
    DiziRenkler.acik = false;
    await _baskasi(tester, ulke: 'Türkiye', testci: true);
    expect(tester.widget<Icon>(_tik).color, DiziRenkler.sariMetin);
  });

  testWidgets('AÇIK TEMA: tik MARKA SARISI değil, sariMetin', (tester) async {
    // Marka sarısı (#F5C518) açık temanın kırık beyaz zemininde 1,51:1 —
    // grafik nesne eşiği 3:1'in ÇOK altında, tik kaybolur. Tema-duyarlı
    // sariMetin her iki temada da geçiyor.
    DiziRenkler.acik = true;
    await _baskasi(tester, ulke: 'Türkiye', testci: true);
    final renk = tester.widget<Icon>(_tik).color;
    expect(renk, DiziRenkler.sariMetin);
    expect(renk, isNot(DiziRenkler.sari));
  });

  // ---------------------------------------------------------------------
  // Dar ekran: taşma yok
  // ---------------------------------------------------------------------
  testWidgets('360 dp: uzun kullanıcı adında tik ekran dışına taşmıyor', (
    tester,
  ) async {
    await _baskasi(
      tester,
      ulke: 'Amerika Birleşik Devletleri',
      testci: true,
      boyut: const Size(_darEkran, 800),
    );
    expect(find.byType(AileRozeti), findsOneWidget);
    final tik = tester.getRect(find.byType(AileRozeti));
    expect(tik.left, greaterThanOrEqualTo(0));
    expect(tik.right, lessThanOrEqualTo(_darEkran + 0.01));
    // Tik sıfır genişliğe ezilmedi.
    expect(tik.width, greaterThan(0));

    // Bu ekranda 360 dp'de KALAN tek taşma sekme etiketlerinden gelir (deneme
    // yazı tipi gürültüsü; rozetle ilgisi yok, profil_ulke_bayragi_test.dart'ta
    // da belgelenmiş).
    final istisna = tester.takeException();
    if (istisna != null) {
      expect(
        istisna.toString(),
        contains('overflowed'),
        reason: 'beklenmeyen istisna: $istisna',
      );
    }
  });

  testWidgets('360 dp: çok uzun ad tiki EZMEZ (ad kısalır, tik kalır)', (
    tester,
  ) async {
    // İzole düzen: ekranın sekme gürültüsü olmadan yalnız ad+tik satırı.
    // Ad `Expanded`+ellipsis olduğu için tik daima tam boyutunda kalmalı.
    await tester.binding.setSurfaceSize(const Size(_darEkran, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: Text(
                  '@cokcokcokuzunbirkullaniciadibudurgercekten',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AileRozeti(),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    final tik = tester.getRect(find.byType(AileRozeti));
    expect(tik.width, AileRozeti.hedef);
    expect(tik.right, lessThanOrEqualTo(_darEkran + 0.01));
  });

  // ---------------------------------------------------------------------
  // DOKUNMA HEDEFİ
  // ---------------------------------------------------------------------
  testWidgets('DOKUNMA HEDEFİ: tik en az 44x44 dp (mürekkep büyümeden)', (
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
    // Hedef DOLGUYLA büyüdü, ikonla değil: mürekkep 22 dp'nin altında kalır.
    expect(tester.widget<Icon>(_tik).size, lessThan(24));
  });

  testWidgets('ERİŞİLEBİLİRLİK: ikon-only tikin okunacak bir adı var', (
    tester,
  ) async {
    // İkon-only düğme ekran okuyucuda "düğme" diye okunursa kullanıcı ne
    // olduğunu anlamaz.
    await _baskasi(tester, ulke: 'Türkiye', testci: true);
    final anlam = tester.getSemantics(find.byType(AileRozeti));
    expect(anlam.label, isNotEmpty);
    expect(anlam.hasFlag(SemanticsFlag.isButton), isTrue);
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
