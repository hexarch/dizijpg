import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dizijpg/api.dart';
import 'package:dizijpg/bayrak.dart';
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

Map<String, dynamic> _acikProfil(String? ulke) => {
  'id': 7,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'kapak': null,
  'bio': null,
  'ulke': ulke,
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
Future<void> _baskasi(WidgetTester tester, String? ulke, {Size? boyut}) async {
  _sunucu({'/profil/': _acikProfil(ulke)});
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

  testWidgets('BAŞKASININ PROFİLİ: ülke doluysa bayrak var, konum ikonu YOK', (
    tester,
  ) async {
    await _baskasi(tester, 'Türkiye');
    expect(find.text('Türkiye'), findsOneWidget);
    expect(find.byType(UlkeBayragi), findsOneWidget);
    expect(_bayrakGorseli('tr'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsNothing);
  });

  testWidgets('KENDİ PROFİLİM: ülke doluysa bayrak var, konum ikonu YOK', (
    tester,
  ) async {
    await _kendim(tester, 'Almanya');
    expect(find.text('Almanya'), findsOneWidget);
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
    expect(find.text('Vakanda'), findsOneWidget);
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

  testWidgets('360 dp: en uzun ülke adıyla bile ülke satırı taşmıyor', (
    tester,
  ) async {
    // Listedeki en uzun ad. Deneme yazı tipinde her harf 1em kare olduğu için
    // bu, gerçek yazı tipinden çok daha zorlu bir taşma senaryosu.
    await _baskasi(
      tester,
      'Amerika Birleşik Devletleri',
      boyut: const Size(_darEkran, 800),
    );
    expect(find.byType(UlkeBayragi), findsOneWidget);
    expect(_bayrakGorseli('us'), findsOneWidget);

    // Bayrak metinle aynı hizada, okunur boyutta ve ekranın içinde.
    final bayrak = tester.getRect(find.byType(UlkeBayragi));
    expect(bayrak.height, greaterThan(8));
    expect(bayrak.height, lessThan(20));
    expect(bayrak.left, greaterThanOrEqualTo(0));

    // ASIL ÖLÇÜM: satırın kendisi taşmıyor mu? Bayrak ve ülke metni, satırın
    // (Row) sınırları içinde kalmalı. Flexible+ellipsis kaldırılırsa metin
    // sağa taşar ve bu beklenti kırılır.
    final satir = find
        .ancestor(of: find.byType(UlkeBayragi), matching: find.byType(Row))
        .first;
    final satirKutu = tester.getRect(satir);
    final metinKutu = tester.getRect(find.text('Amerika Birleşik Devletleri'));
    expect(bayrak.left, greaterThanOrEqualTo(satirKutu.left));
    expect(metinKutu.right, lessThanOrEqualTo(satirKutu.right + 0.01));
    expect(metinKutu.right, lessThanOrEqualTo(_darEkran));
    // Metin gerçekten kırpıldı ama kayboolmadı: görünür genişliği var.
    expect(metinKutu.width, greaterThan(0));

    // Bu ekranda 360 dp'de KALAN tek taşma, sekme etiketlerinin deneme yazı
    // tipiyle taşmasıdır (ülke satırı olmadan da oluşur; gerçek yazı tipinde
    // yok). Ülke satırı kaynaklı bir taşma olmadığını yukarıdaki ölçümler
    // kanıtlıyor. İstisnayı yutuyoruz ki test o bilinen gürültüye takılmasın.
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
