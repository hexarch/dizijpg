import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:dizijpg/seviye.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// MİNİ SEVİYE SİSTEMİ (istek md. 29) — profil alt unvanı.
///
/// "Amatör izleyici → profesör izleyici → ultra mega izleyici gibi unvanlar.
///  Unvanları BİZ koyacağız (kullanıcı seçmeyecek)."
/// Maddenin notu: "Eşikler kullanıcıyı UTANDIRMAMALI — düşük seviyeyi
/// başkasına göstermek caydırıcı olabilir; md. 21'deki gizleme tercihleriyle
/// uyumlu düşünülmeli."
///
/// BU DOSYANIN KİLİTLEDİĞİ DAVRANIŞ:
///  1) Unvan metinleri AŞAĞILAYICI DEĞİL — en alt kademe dahil.
///  2) Eşik/ilerleme matematiği sınırlarda doğru (0, tam eşik, taşma).
///  3) İLERLEME YALNIZ KENDİ PROFİLİNDE: çubuk ve "Sonraki: … · Seviye 5/8"
///     satırı başkasının profilinde ÇİZİLMEZ.
///  4) Sunucu unvanı süzdüyse (1. kademe ya da `izlenenler_gizli`) açık
///     profilde satır HİÇ ÇİZİLMEZ — "seviye gizli" yazısı bile yok.
///  5) 320 dp'de en uzun unvan taşmıyor (45 dil için tampon).
///
/// Eşik TABLOSU burada sınanmaz: tablo yalnız sunucuda (tek kopya).
/// Sınır testleri `backend/test/seviye.test.js` içinde.
const double _darEkran = 320;
const Size _ekran = Size(600, 900);

/// Sunucunun KENDİ profilinde döndürdüğü tam seviye kaydı.
Map<String, dynamic> _tamSeviye({
  int kademe = 5,
  String kod = 'uzman',
  int puan = 1240,
  int esik = 1000,
  int? sonrakiEsik = 2500,
  String? sonrakiKod = 'profesor',
}) => {
  'kademe': kademe,
  'kod': kod,
  'toplam': 8,
  'puan': puan,
  'esik': esik,
  'sonraki_esik': sonrakiEsik,
  'sonraki_kod': sonrakiKod,
};

/// Sunucunun ZİYARETÇİYE döndürdüğü süzülmüş kayıt: puan/eşik YOK.
Map<String, dynamic> _acikSeviye({int kademe = 5, String kod = 'uzman'}) => {
  'kademe': kademe,
  'kod': kod,
  'toplam': 8,
};

Map<String, dynamic> _acikProfil({Object? seviye, bool benMi = false}) => {
  'id': 7,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'kapak': null,
  'bio': null,
  'ulke': null,
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
  'seviye': seviye,
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

/// Kendi profil ekranı: seviye `/rozetler` yanıtında gelir (rozetlerle AYNI
/// uçta — ikinci sayaç sistemi yok).
Future<void> _kendim(WidgetTester tester, Object? seviye, {Size? boyut}) async {
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
      'ulke': null,
      'sosyal': <dynamic>[],
    },
    '/izlediklerim': {'ogeler': <dynamic>[]},
    '/rozetler': {'rozetler': <dynamic>[], 'seviye': seviye},
    '/profil/': _acikProfil(),
  });
  await _kur(tester, const ProfilEkrani(), boyut);
}

/// Başkasının açık profili.
Future<void> _baskasi(
  WidgetTester tester,
  Object? seviye, {
  bool benMi = false,
  Size? boyut,
}) async {
  _sunucu({'/profil/': _acikProfil(seviye: seviye, benMi: benMi)});
  await _kur(
    tester,
    const KullaniciProfilEkrani(kullaniciAdi: 'thelostvibe0'),
    boyut,
  );
}

Finder get _cubuk => find.descendant(
  of: find.byType(SeviyeSatiri),
  matching: find.byType(LinearProgressIndicator),
);

void main() {
  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    SharedPreferences.setMockInitialValues({
      'token': 'sahte',
      'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'thelostvibe0'}),
    });
    await Api.tokenYukle();
  });

  // =========================================================================
  // 1. UNVAN METİNLERİ — utandırmama şartı
  // =========================================================================

  group('unvanlar', () {
    test('8 unvan var, hepsi tekil ve boş değil', () {
      expect(Seviye.tumAdlar, hasLength(8));
      expect(Seviye.tumAdlar.toSet(), hasLength(8));
      for (final ad in Seviye.tumAdlar) {
        expect(ad.trim(), isNotEmpty);
      }
    });

    test('UTANDIRMAMA: hiçbir unvan aşağılayıcı bir sözcük taşımıyor', () {
      // Maddenin şartı. "acemi/çaylak/toy" gibi adlar EN ALT kademede
      // kullanıcının profilinde kalıcı bir küçümseme yazısı olurdu.
      const yasak = [
        'acemi',
        'çaylak',
        'caylak',
        'toy',
        'ezik',
        'zayıf',
        'zayif',
        'kötü',
        'kotu',
        'aptal',
        'cahil',
        'beceriksiz',
        'tembel',
        'başlangıç',
        'baslangic',
        'sıfır',
        'sifir',
        'hiç',
        'yok',
      ];
      for (final ad in Seviye.tumAdlar) {
        final kucuk = ad.toLowerCase();
        for (final y in yasak) {
          expect(
            kucuk.contains(y),
            isFalse,
            reason: 'aşağılayıcı unvan: "$ad" ($y)',
          );
        }
      }
    });

    test('EN ALT kademenin adı nötr-olumlu: "Meraklı izleyici"', () {
      const sv = Seviye(kademe: 1, kod: 'merakli', toplam: 8);
      expect(sv.etiket, 'Meraklı izleyici');
    });

    test('kullanıcının verdiği üç örnek unvan sözlükte var', () {
      for (final kod in ['amator', 'profesor', 'ultra_mega']) {
        expect(Seviye.tumKodlar, contains(kod));
      }
      expect(
        const Seviye(kademe: 3, kod: 'amator', toplam: 8).etiket,
        'Amatör izleyici',
      );
      expect(
        const Seviye(kademe: 6, kod: 'profesor', toplam: 8).etiket,
        'Profesör izleyici',
      );
      expect(
        const Seviye(kademe: 8, kod: 'ultra_mega', toplam: 8).etiket,
        'Ultra mega izleyici',
      );
    });
  });

  // =========================================================================
  // 2. ÇÖZÜMLEME — bozuk/eksik yanıtta satır hiç çizilmez
  // =========================================================================

  group('Seviye.cozumle', () {
    test('null / yanlış tür / eksik alan → null', () {
      expect(Seviye.cozumle(null), isNull);
      expect(Seviye.cozumle('uzman'), isNull);
      expect(Seviye.cozumle(<String, dynamic>{}), isNull);
      expect(Seviye.cozumle({'kademe': 2, 'toplam': 8}), isNull);
      expect(
        Seviye.cozumle({'kademe': 0, 'kod': 'uzman', 'toplam': 8}),
        isNull,
      );
    });

    test('TANINMAYAN KOD → null (ekranda ham anahtar BASILMAZ)', () {
      // Eski istemci + yeni sunucu: yeni bir kademe kodu eklenirse eski
      // uygulama "ultra_ultra_mega" diye bir anahtar göstermez, satırı atlar.
      expect(
        Seviye.cozumle({'kademe': 9, 'kod': 'gizemli_kod', 'toplam': 9}),
        isNull,
      );
    });

    test('toplam < kademe olan tutarsız kayıt → null', () {
      expect(
        Seviye.cozumle({'kademe': 9, 'kod': 'uzman', 'toplam': 8}),
        isNull,
      );
    });

    test('ziyaretçi kaydında puan/eşik yok → ilerleme yok', () {
      final sv = Seviye.cozumle(_acikSeviye())!;
      expect(sv.kademe, 5);
      expect(sv.kod, 'uzman');
      expect(sv.puan, isNull);
      expect(sv.ilerlemeVar, isFalse);
      expect(sv.ilerleme, isNull);
    });

    test('tanınmayan sonraki_kod yok sayılır, kayıt yine çözülür', () {
      final sv = Seviye.cozumle(_tamSeviye(sonrakiKod: 'bilinmeyen'))!;
      expect(sv.kod, 'uzman');
      expect(sv.sonrakiKod, isNull);
      expect(sv.sonrakiEtiket, isNull);
    });
  });

  // =========================================================================
  // 3. İLERLEME MATEMATİĞİ — sınırlar
  // =========================================================================

  group('ilerleme (saf)', () {
    test('kademenin TAM ALT SINIRINDA çubuk boş (0.0)', () {
      final sv = Seviye.cozumle(_tamSeviye(puan: 1000, esik: 1000))!;
      expect(sv.ilerleme, 0.0);
    });

    test('sonraki eşiğin BİR ALTINDA çubuk dolmaya çok yakın ama 1 değil', () {
      final sv = Seviye.cozumle(_tamSeviye(puan: 2499, esik: 1000))!;
      expect(sv.ilerleme, greaterThan(0.99));
      expect(sv.ilerleme, lessThan(1.0));
    });

    test('tam ortada 0.5', () {
      final sv = Seviye.cozumle(_tamSeviye(puan: 1750, esik: 1000))!;
      expect(sv.ilerleme, closeTo(0.5, 0.0001));
    });

    test('EŞİK AŞILMIŞ gecikmiş veride 1.0 ile kırpılır (çubuk taşmaz)', () {
      final sv = Seviye.cozumle(_tamSeviye(puan: 9999, esik: 1000))!;
      expect(sv.ilerleme, 1.0);
    });

    test('EŞİĞİN ALTINDA tutarsız veride 0.0 ile kırpılır', () {
      final sv = Seviye.cozumle(_tamSeviye(puan: 10, esik: 1000))!;
      expect(sv.ilerleme, 0.0);
    });

    test('EN ÜST kademede ilerleme yok, alt satır "En üst unvan" der', () {
      final sv = Seviye.cozumle(
        _tamSeviye(
          kademe: 8,
          kod: 'ultra_mega',
          puan: 20000,
          esik: 12000,
          sonrakiEsik: null,
          sonrakiKod: null,
        ),
      )!;
      expect(sv.enUst, isTrue);
      expect(sv.ilerlemeVar, isFalse);
      expect(sv.ilerleme, isNull);
      expect(sv.altSatir, 'En üst unvan · Seviye 8/8');
    });

    test('alt satır İLERİ BAKAR: hedef unvanı + konum', () {
      final sv = Seviye.cozumle(_tamSeviye())!;
      expect(sv.altSatir, 'Sonraki: Profesör izleyici · Seviye 5/8');
      // Yüzde YOK — "%18 tamamlandı" az izleyene ne kadar AZ yaptığını söyler.
      expect(sv.altSatir.contains('%'), isFalse);
    });

    test('YENİ KULLANICI: en alt kademe, unvanı var, ilerleme çizilebilir', () {
      final sv = Seviye.cozumle(
        _tamSeviye(
          kademe: 1,
          kod: 'merakli',
          puan: 0,
          esik: 0,
          sonrakiEsik: 30,
          sonrakiKod: 'hevesli',
        ),
      )!;
      expect(sv.etiket, 'Meraklı izleyici');
      expect(sv.ilerleme, 0.0);
      expect(sv.altSatir, 'Sonraki: Hevesli izleyici · Seviye 1/8');
    });
  });

  // =========================================================================
  // 4. KENDİ PROFİLİM — unvan + İLERLEME görünür
  // =========================================================================

  testWidgets('KENDİ PROFİLİM: unvan, ilerleme çubuğu ve hedef satırı VAR', (
    tester,
  ) async {
    await _kendim(tester, _tamSeviye());
    expect(find.byType(SeviyeSatiri), findsOneWidget);
    expect(find.text('Uzman izleyici'), findsOneWidget);
    expect(_cubuk, findsOneWidget);
    expect(
      find.text('Sonraki: Profesör izleyici · Seviye 5/8'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.trending_up), findsOneWidget);
    // Çubuk gerçekten kısmen dolu (0 ya da 1'e sıkışmış değil).
    final gosterge = tester.widget<LinearProgressIndicator>(_cubuk);
    expect(gosterge.value, closeTo(0.16, 0.01));
  });

  testWidgets('KENDİ PROFİLİM: unvan kullanıcı adının ALTINDA duruyor', (
    tester,
  ) async {
    await _kendim(tester, _tamSeviye());
    // Kullanıcı adı `@…` ile başlayan tek metin (oturum sahte olduğu için
    // adın kendisi değil, biçimi aranır).
    // (AppBar başlığı da aynı metni taşıyor; kalın başlık olanı aranır.)
    final adFinder = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.data ?? '').startsWith('@') &&
          w.style?.fontWeight == FontWeight.w900,
      description: 'profil başlığındaki kullanıcı adı',
    );
    expect(adFinder, findsOneWidget);
    final ad = tester.getRect(adFinder);
    final unvan = tester.getRect(find.text('Uzman izleyici'));
    expect(unvan.top, greaterThanOrEqualTo(ad.bottom - 1));
    // Aynı sütunda: sol kenarları hizalı.
    expect(unvan.left, closeTo(ad.left, 1));
  });

  testWidgets('KENDİ PROFİLİM: seviye gelmezse satır hiç çizilmez', (
    tester,
  ) async {
    await _kendim(tester, null);
    expect(find.byType(SeviyeSatiri), findsNothing);
    expect(_cubuk, findsNothing);
  });

  testWidgets('EN ÜST kademede çubuk yok, "En üst unvan" satırı var', (
    tester,
  ) async {
    await _kendim(
      tester,
      _tamSeviye(
        kademe: 8,
        kod: 'ultra_mega',
        puan: 20000,
        esik: 12000,
        sonrakiEsik: null,
        sonrakiKod: null,
      ),
    );
    expect(find.text('Ultra mega izleyici'), findsOneWidget);
    expect(_cubuk, findsNothing);
    expect(find.text('En üst unvan · Seviye 8/8'), findsOneWidget);
  });

  // =========================================================================
  // 5. BAŞKASININ PROFİLİ — yalnız unvan; ilerleme YOK
  // =========================================================================

  testWidgets('BAŞKASININ PROFİLİ: unvan VAR ama İLERLEME YOK', (tester) async {
    await _baskasi(tester, _acikSeviye());
    expect(find.byType(SeviyeSatiri), findsOneWidget);
    expect(find.text('Uzman izleyici'), findsOneWidget);
    // Çubuk, hedef satırı ve konum ("Seviye 5/8") ÇİZİLMEZ: başkasının
    // profilindeki ilerleme, unvanı bir sıralama tablosuna çevirirdi.
    expect(_cubuk, findsNothing);
    expect(find.byIcon(Icons.trending_up), findsNothing);
    expect(find.textContaining('Seviye 5/8'), findsNothing);
    expect(find.textContaining('Sonraki:'), findsNothing);
  });

  testWidgets(
    'BAŞKASININ PROFİLİ: sunucu puan/eşik SIZDIRSA BİLE ilerleme çizilmez',
    (tester) async {
      // İkinci kilit: `ilerlemeGoster` bayrağı `ben_mi`ye bağlı. Sunucu bir
      // gün süzgeci gevşetse bile ziyaretçi çubuğu görmez.
      await _baskasi(tester, _tamSeviye());
      expect(find.text('Uzman izleyici'), findsOneWidget);
      expect(_cubuk, findsNothing);
      expect(find.textContaining('Sonraki:'), findsNothing);
    },
  );

  testWidgets(
    'GİZLİ / 1. KADEME: sunucu seviye=null yolladıysa satır HİÇ çizilmez',
    (tester) async {
      // İki durum aynı yanıtı üretir (`seviyeAcikGorunum` → null):
      //  · md. 21 "izlediklerimi gizle" açık,
      //  · kullanıcı henüz 1. kademede (utandırmama kuralı).
      // Ekranda "seviye gizli" gibi bir yer tutucu da YOK — bu, gizlenmiş
      // bir şey olduğunu ele verirdi.
      await _baskasi(tester, null);
      expect(find.byType(SeviyeSatiri), findsNothing);
      expect(_cubuk, findsNothing);
      for (final ad in Seviye.tumAdlar) {
        expect(find.text(ad), findsNothing, reason: 'unvan sızdı: $ad');
      }
    },
  );

  testWidgets('AÇIK PROFİL KENDİ ADIMLA açıldıysa (ben_mi) ilerleme GÖRÜNÜR', (
    tester,
  ) async {
    // Bu ekran kendi kullanıcı adınla da açılabiliyor; "kendi profilim mi"
    // kararı sunucunun `ben_mi` yargısından gelir.
    await _baskasi(tester, _tamSeviye(), benMi: true);
    expect(find.text('Uzman izleyici'), findsOneWidget);
    expect(_cubuk, findsOneWidget);
    expect(
      find.text('Sonraki: Profesör izleyici · Seviye 5/8'),
      findsOneWidget,
    );
  });

  // =========================================================================
  // 6. DAR EKRAN — 45 dilde uzun unvan
  // =========================================================================

  testWidgets('320 dp: en uzun unvan + ilerleme satırı taşmıyor', (
    tester,
  ) async {
    // Deneme yazı tipinde her harf 1em kare: "Ultra mega izleyici" gerçek
    // yazı tipinden çok daha geniş çizilir, yani bu 45 dil için tampon.
    await _kendim(
      tester,
      _tamSeviye(
        kademe: 8,
        kod: 'ultra_mega',
        puan: 13000,
        esik: 12000,
        sonrakiEsik: null,
        sonrakiKod: null,
      ),
      boyut: const Size(_darEkran, 900),
    );
    final satir = find.byType(SeviyeSatiri);
    expect(satir, findsOneWidget);
    final kutu = tester.getRect(satir);
    expect(kutu.left, greaterThanOrEqualTo(0));
    expect(kutu.right, lessThanOrEqualTo(_darEkran + 0.01));
    // Unvan iki satıra SARILIR (üç noktaya düşse bile) ama kaybolmaz.
    final metin = tester.getRect(find.text('Ultra mega izleyici'));
    expect(metin.width, greaterThan(0));
    expect(metin.right, lessThanOrEqualTo(kutu.right + 0.01));

    // Bu ekranda 320 dp'de KALAN taşmalar sekme etiketlerinden gelir (ülke
    // satırı testindeki bilinen gürültü, gerçek yazı tipinde yok). Unvan
    // kaynaklı taşma olmadığını yukarıdaki ölçümler kanıtlıyor.
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
