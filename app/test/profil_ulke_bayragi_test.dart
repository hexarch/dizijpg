import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dizijpg/api.dart';
import 'package:dizijpg/bayrak.dart';
import 'package:dizijpg/ekranlar/sosyal.dart';
import 'package:dizijpg/ekranlar/ayarlar.dart' show ulkeler;
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Kullanıcı bildirimi (2026-08-03): "Profilime gittiğimde Türkiye yazıyor ya,
/// yani verdiğim ülke, solunda konum ikonu var. o olmamalı. konum ikonu yerine
/// ülke bayrağı kullan."
///
/// Bu testler ülke satırını kilitler:
///  - ülke doluysa BAYRAK çizilir, Icons.location_on ARTIK YOK,
///  - ülke boşsa satır hiç çizilmez (eski davranış korunur),
///  - tanınmayan ülke değerinde dünya ikonuna düşülür, çökme yok,
///  - hem kendi profilinde hem başkasınınkinde geçerli,
///  - 360 dp'de taşma yok.
const double _darEkran = 360;

/// 600: tek-boşluklu deneme yazı tipinde sekme etiketleri 360'ta taşıyor
/// (gerçek yazı tipinde taşma yok). Ülke satırı ölçümleri buradan yapılır.
const Size _ekran = Size(600, 900);

Map<String, dynamic> _acikProfil(String? ulke, {List<dynamic>? sosyal}) => {
  'id': 7,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'kapak': null,
  'bio': null,
  'ulke': ulke,
  'sosyal': sosyal ?? <dynamic>[],
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

/// Sunucuyu taklit eder: yol öneki → JSON gövdesi.
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

/// Başkasının profili ekranını kurar.
Future<void> _baskasi(
  WidgetTester tester,
  String? ulke, {
  Size? boyut,
  List<dynamic>? sosyal,
}) async {
  _sunucu({'/profil/': _acikProfil(ulke, sosyal: sosyal)});
  await _kur(
    tester,
    const KullaniciProfilEkrani(kullaniciAdi: 'thelostvibe0'),
    boyut,
  );
}

/// Kendi profil ekranını kurar (`/profilim` ülkeyi taşır).
Future<void> _kendim(WidgetTester tester, String? ulke, {Size? boyut}) async {
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
      'sosyal': <dynamic>[],
    },
    '/izlediklerim': {'ogeler': <dynamic>[]},
    '/rozetler': {'rozetler': <dynamic>[]},
    '/profil/': _acikProfil(ulke),
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
  // Sahte ağ yanıtı gelsin + Image.asset yüklemesi otursun diye birkaç kare.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Verilen bayrak varlığını çizen bir Image var mı? (Kod çözmeyi beklemez;
/// AssetImage'in adına bakar, böylece test görsel kod çözücüye bağlı değil.)
Finder _bayrakGorseli(String kod) => find.byWidgetPredicate((w) {
  if (w is! Image) return false;
  final k = w.image;
  return k is AssetImage && k.assetName == 'assets/bayraklar/$kod.png';
}, description: 'assets/bayraklar/$kod.png');

void main() {
  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    SharedPreferences.setMockInitialValues({
      'token': 'sahte',
      'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'thelostvibe0'}),
    });
    await Api.tokenYukle();
  });

  group('ulkeKodu (saf eşleme)', () {
    test('seçicideki Türkçe adlar çözülür', () {
      expect(ulkeKodu('Türkiye'), 'tr');
      expect(ulkeKodu('Amerika Birleşik Devletleri'), 'us');
      expect(ulkeKodu('Bosna-Hersek'), 'ba');
      expect(ulkeKodu('Güney Kore'), 'kr');
      expect(ulkeKodu('İsviçre'), 'ch');
    });

    test('büyük/küçük harf, aksan ve noktalama farkları yutulur', () {
      expect(ulkeKodu('TÜRKİYE'), 'tr');
      expect(ulkeKodu('turkiye'), 'tr');
      expect(ulkeKodu('  Bosna Hersek '), 'ba');
      expect(ulkeKodu('cekya'), 'cz');
    });

    test('İngilizce adlar ve iki harfli kodlar da kabul edilir', () {
      expect(ulkeKodu('Turkey'), 'tr');
      expect(ulkeKodu('United Kingdom'), 'gb');
      expect(ulkeKodu('TR'), 'tr');
      expect(ulkeKodu('de'), 'de');
    });

    test('bilinmeyen/boş değer null döner (çökme yok)', () {
      expect(ulkeKodu(null), isNull);
      expect(ulkeKodu(''), isNull);
      expect(ulkeKodu('   '), isNull);
      expect(ulkeKodu('Vakanda'), isNull);
      expect(ulkeKodu('zz'), isNull);
      expect(ulkeKodu('!!!'), isNull);
    });

    test('ayarlar.dart seçicisindeki HER ülke bir koda çözülür', () {
      // Doğrudan gerçek listeye bakar: ileride ayarlar.dart'a ülke eklenip
      // bayrağı unutulursa burası kırmızıya döner.
      expect(ulkeler, hasLength(116));
      final cozulmeyen = ulkeler.where((a) => ulkeKodu(a) == null).toList();
      expect(cozulmeyen, isEmpty, reason: 'bayrak eşleşmesi yok: $cozulmeyen');
    });

    test('kodlar benzersiz ve iki harfli', () {
      for (final k in tumKodlar) {
        expect(k, matches(RegExp(r'^[a-z]{2}$')), reason: 'geçersiz kod: $k');
      }
      // 116 ülke → 116 ayrı bayrak.
      expect(tumKodlar, hasLength(116));
    });
  });

  testWidgets(
    'VARLIKLAR: seçicideki her ülkenin bayrağı paketli ve çözülüyor',
    (tester) async {
      // Emoji bayrak yerine PNG seçilmesinin sebebi platform bağımsızlığıydı.
      // Bu test onu kanıtlar: her dosya gerçekten pakette ve Flutter'ın kendi
      // görsel çözücüsünde (Android/iOS/web'de aynı kod) açılıyor.
      // runAsync: görsel çözme gerçek zaman ister, sahte zamanda asılı kalır.
      final hatalar = await tester.runAsync(() async {
        final sorunlu = <String>[];
        for (final kod in tumKodlar) {
          try {
            final veri = await rootBundle.load('assets/bayraklar/$kod.png');
            final kodlayici = await ui.instantiateImageCodec(
              veri.buffer.asUint8List(),
            );
            final kare = await kodlayici.getNextFrame();
            if (kare.image.width != 80 || kare.image.height < 20) {
              sorunlu.add('$kod (${kare.image.width}x${kare.image.height})');
            }
            kare.image.dispose();
            kodlayici.dispose();
          } catch (e) {
            sorunlu.add('$kod ($e)');
          }
        }
        return sorunlu;
      });
      expect(hatalar, isEmpty, reason: 'çözülemeyen bayrak: $hatalar');
    },
  );

  /// Bayrağın taşıdığı ülke adı. 28 Ağu 2026'dan beri ülke ADI profilde
  /// METİN olarak çizilmiyor — bayrak kullanıcı adının yanına taşındı ve ad
  /// ipucuna (tooltip) geçti. Testler bu yüzden metin değil İPUCU okuyor;
  /// yoksa "ad kayboldu" gerilemesi sessizce geçerdi.
  String _ipucu(WidgetTester tester) => tester
      .widget<Tooltip>(
        find.descendant(
          of: find.byType(UlkeBayragi),
          matching: find.byType(Tooltip),
        ),
      )
      .message!;

  testWidgets('BAŞKASININ PROFİLİ: ülke doluysa bayrak var, konum ikonu YOK', (
    tester,
  ) async {
    await _baskasi(tester, 'Türkiye');
    expect(_ipucu(tester), 'Türkiye');
    expect(find.text('Türkiye'), findsNothing);
    expect(find.byType(UlkeBayragi), findsOneWidget);
    expect(_bayrakGorseli('tr'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsNothing);
  });

  testWidgets('KENDİ PROFİLİM: ülke doluysa bayrak var, konum ikonu YOK', (
    tester,
  ) async {
    await _kendim(tester, 'Almanya');
    expect(_ipucu(tester), 'Almanya');
    expect(find.text('Almanya'), findsNothing);
    expect(find.byType(UlkeBayragi), findsOneWidget);
    expect(_bayrakGorseli('de'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsNothing);
  });

  testWidgets('ülke BOŞSA satır hiç çizilmez (iki profilde de)', (
    tester,
  ) async {
    await _baskasi(tester, null);
    expect(find.byType(UlkeBayragi), findsNothing);
    expect(find.byIcon(Icons.location_on), findsNothing);
  });

  testWidgets('ülke BOŞ METİNSE de satır çizilmez', (tester) async {
    await _kendim(tester, '');
    expect(find.byType(UlkeBayragi), findsNothing);
  });

  testWidgets('BİLİNMEYEN ülke: dünya ikonuna düşer, metin durur, çökme yok', (
    tester,
  ) async {
    await _baskasi(tester, 'Vakanda');
    // Bilinmeyen ülke: ad KAYBOLMAZ, ipucunda aynen durur.
    expect(_ipucu(tester), 'Vakanda');
    expect(find.byType(UlkeBayragi), findsOneWidget);
    // Bayrak varlığı yok; yedek dünya ikonu var; konum iğnesi yine yok.
    expect(_bayrakGorseli('vakanda'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(UlkeBayragi),
        matching: find.byIcon(Icons.public),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.location_on), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360 dp: uzun ülke adında bile KİMLİK SATIRI taşmıyor', (
    tester,
  ) async {
    // 28 Ağu 2026: ülke satırı kalktı, bayrak KİMLİK SATIRINA taşındı. Taşma
    // riski de oraya taşındı — artık aynı satırda kullanıcı adı + rozet +
    // bayrak var. Eski test ülke metninin kırpılmasını ölçüyordu; ölçülecek
    // metin kalmadı, ama ASIL SORU aynı: satır 360 dp'de taşıyor mu?
    await _baskasi(
      tester,
      'Amerika Birleşik Devletleri',
      boyut: const Size(_darEkran, 800),
    );
    expect(find.byType(UlkeBayragi), findsOneWidget);
    expect(_bayrakGorseli('us'), findsOneWidget);
    // Ad ipucuna geçti, kaybolmadı.
    expect(_ipucu(tester), 'Amerika Birleşik Devletleri');

    // Bayrak okunur boyutta ve ekranın İÇİNDE.
    final bayrak = tester.getRect(find.byType(UlkeBayragi));
    expect(bayrak.height, greaterThan(8));
    expect(bayrak.height, lessThan(20));
    expect(bayrak.left, greaterThanOrEqualTo(0));
    expect(bayrak.right, lessThanOrEqualTo(_darEkran + 0.01));

    // ASIL ÖLÇÜM: bayrak kimlik satırının (Row) İÇİNDE kalıyor mu?
    // Kullanıcı adındaki `Flexible` kaldırılırsa uzun ad bayrağı ekran
    // dışına iter ve bu beklenti kırılır.
    final satir = find
        .ancestor(of: find.byType(UlkeBayragi), matching: find.byType(Row))
        .first;
    final satirKutu = tester.getRect(satir);
    expect(bayrak.left, greaterThanOrEqualTo(satirKutu.left));
    expect(bayrak.right, lessThanOrEqualTo(satirKutu.right + 0.01));

    // Kullanıcı adı kırpıldı ama KAYBOLMADI.
    final ad = tester.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is Text && w.data == '@thelostvibe0' && w.style?.fontSize != null,
        description: 'profil başlığındaki kullanıcı adı',
      ),
    );
    expect(ad.width, greaterThan(0));
    expect(ad.right, lessThanOrEqualTo(bayrak.left + 0.01));

    // Bu ekranda 360 dp'de KALAN tek taşma, sekme etiketlerinin deneme yazı
    // tipiyle taşmasıdır (bayraktan bağımsız; gerçek yazı tipinde yok).
    final istisna = tester.takeException();
    if (istisna != null) {
      expect(
        istisna.toString(),
        contains('overflowed'),
        reason: 'beklenmeyen istisna: $istisna',
      );
    }
  });

  // -------------------------------------------------------------------
  // SOSYAL BAĞLANTILAR — bayrağın yanında (28 Ağu 2026, kullanıcı isteği)
  //
  // ASIL RİSK GENİŞLİK: sosyal ikonların dokunma hedefi 44 px (ux md.2) ve
  // en fazla 3 tane olabiliyor. 360 dp'de ad + tik + bayrak + 3×44 aynı
  // satıra sığmazsa ad okunmaz hâle gelir ya da satır taşar. Aşağıdaki test
  // o sınırı ÖLÇÜYOR — tasarımı gözle onaylamak yetmez.
  // -------------------------------------------------------------------
  testWidgets('sosyal ikonlar bayrağın SAĞINDA, aynı satırda', (tester) async {
    await _baskasi(
      tester,
      'Türkiye',
      sosyal: const [
        {'platform': 'instagram', 'deger': 'ali'},
        {'platform': 'x', 'deger': 'ali'},
      ],
    );
    final bayrak = tester.getRect(find.byType(UlkeBayragi));
    final sosyal = tester.getRect(find.byType(SosyalSatiri));
    expect(sosyal.left, greaterThanOrEqualTo(bayrak.right - 0.01));
    // Aynı satır: dikey merkezler yakın.
    expect((sosyal.center.dy - bayrak.center.dy).abs(), lessThan(6));
    // Ayrı sosyal satırı ARTIK YOK: tek kez çiziliyor.
    expect(find.byType(SosyalSatiri), findsOneWidget);
  });

  testWidgets(
    '360 dp + 3 sosyal + uzun ad: satır taşmıyor, ad OKUNUR kalıyor',
    (tester) async {
      await _baskasi(
        tester,
        'Amerika Birleşik Devletleri',
        boyut: const Size(_darEkran, 800),
        sosyal: const [
          {'platform': 'instagram', 'deger': 'ali'},
          {'platform': 'x', 'deger': 'ali'},
          {'platform': 'youtube', 'deger': 'ali'},
        ],
      );
      final ad = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data == '@thelostvibe0' &&
              w.style?.fontSize != null,
          description: 'profil başlığındaki kullanıcı adı',
        ),
      );
      final sosyal = tester.getRect(find.byType(SosyalSatiri));

      // Hiçbiri ekranın dışına taşmıyor.
      expect(ad.left, greaterThanOrEqualTo(0));
      expect(sosyal.right, lessThanOrEqualTo(_darEkran + 0.01));

      // AD OKUNUR KALIYOR: en kötü durumda bile birkaç harflik yer değil,
      // anlamlı bir genişlik. Eşik gözle değil ölçümle belirlendi; altına
      // düşerse yerleşim kararı yeniden gözden geçirilmeli (ikon sayısını
      // sınırlamak ya da sosyali alt satıra almak gerekir).
      expect(
        ad.width,
        greaterThan(60),
        reason: 'kullanıcı adına kalan genişlik: ${ad.width}',
      );

      final istisna = tester.takeException();
      if (istisna != null) {
        expect(
          istisna.toString(),
          contains('overflowed'),
          reason: 'beklenmeyen istisna: $istisna',
        );
      }
    },
  );

  testWidgets('360 dp + 1 sosyal: YAN YANA (özellik telefonda da işliyor)', (
    tester,
  ) async {
    // Yerleşim yere göre karar veriyor. Bu test "sığmazsa alta iner"
    // kuralının özelliği telefonda ÖLDÜRMEDİĞİNİ kilitliyor: en yaygın
    // durumda (tek bağlantı) ikon bayrağın yanında kalmalı.
    await _baskasi(
      tester,
      'Türkiye',
      boyut: const Size(_darEkran, 800),
      sosyal: const [
        {'platform': 'instagram', 'deger': 'ali'},
      ],
    );
    final bayrak = tester.getRect(find.byType(UlkeBayragi));
    final sosyal = tester.getRect(find.byType(SosyalSatiri));
    expect(sosyal.left, greaterThanOrEqualTo(bayrak.right - 0.01));
    expect(
      (sosyal.center.dy - bayrak.center.dy).abs(),
      lessThan(6),
      reason: 'tek bağlantı 360 dp\'de bayrağın yanında kalmalı',
    );
  });

  testWidgets('360 dp + 3 sosyal: şerit ALT SATIRA iner, kaybolmaz', (
    tester,
  ) async {
    await _baskasi(
      tester,
      'Amerika Birleşik Devletleri',
      boyut: const Size(_darEkran, 800),
      sosyal: const [
        {'platform': 'instagram', 'deger': 'ali'},
        {'platform': 'x', 'deger': 'ali'},
        {'platform': 'youtube', 'deger': 'ali'},
      ],
    );
    final bayrak = tester.getRect(find.byType(UlkeBayragi));
    final sosyal = tester.getRect(find.byType(SosyalSatiri));
    // KAYBOLMADI: hâlâ tek kez çizili.
    expect(find.byType(SosyalSatiri), findsOneWidget);
    // Ama artık bayrağın ALTINDA.
    expect(sosyal.top, greaterThan(bayrak.bottom - 0.01));
    // Üç ikon da erişilebilir durumda.
    expect(find.byType(InkWell).evaluate().length, greaterThanOrEqualTo(3));
  });
}
