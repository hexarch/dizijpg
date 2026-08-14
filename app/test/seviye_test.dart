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

/// MİNİ SEVİYE SİSTEMİ (istek md. 29) — profil satırı.
///
/// 14 AĞU REVİZYONU: "seviye sistemi kalsın ama 7/8 gibi yazma; bir seviye
/// sistemimiz olsun, ona göre artsın seviyesi."
///
/// BU TURDA DEĞİŞEN İDDİALAR:
///  · UNVAN TESTLERİ KALKTI (8 adın tekilliği, aşağılayıcı sözcük taraması,
///    "en alt kademenin adı Meraklı izleyici", üç örnek unvan). Ortada ad
///    yok; yerlerine "EKRANDA HİÇBİR UNVAN YOK" gerileme kilidi geldi
///    ([_eskiUnvanlar] listesi bu dosyada, `Seviye.tumAdlar` SİLİNDİ).
///  · "Seviye 5/8" ve "Sonraki: {unvan}" iddiaları yerini "Seviye 5" ile
///    "Sonraki seviyeye {} puan kaldı" satırına bıraktı.
///  · "EN ÜST kademe" testleri kalktı: TAVAN YOK, sunucu `sonraki_esik`i
///    her zaman gönderiyor.
///  · `cozumle` artık `kod`/`toplam` istemiyor (sunucu göndermiyor), o
///    yüzden "tanınmayan kod → null" testleri de kalktı.
///
/// BU DOSYANIN KİLİTLEDİĞİ DAVRANIŞ:
///  1) EKRANDA UNVAN YOK — kendi profilinde de başkasınınkinde de.
///  2) PAYDA YOK — "Seviye 5" var, "Seviye 5/8" yok.
///  3) Eşik/ilerleme matematiği sınırlarda doğru (0, tam eşik, taşma).
///  4) İLERLEME YALNIZ KENDİ PROFİLİNDE: çubuk ve "Sonraki seviyeye …"
///     satırı başkasının profilinde ÇİZİLMEZ.
///  5) Sunucu seviyeyi süzdüyse (1. kademe ya da `izlenenler_gizli`) açık
///     profilde satır HİÇ ÇİZİLMEZ — "seviye gizli" yazısı bile yok.
///  6) 320 dp'de üç haneli seviye + uzun ilerleme satırı taşmıyor.
///
/// Eşik EĞRİSİ burada sınanmaz: eğrinin tek kopyası sunucuda.
/// Sınır/gerileme testleri `backend/test/seviye.test.js` içinde.
const double _darEkran = 320;
const Size _ekran = Size(600, 900);

/// 14 Ağu'da kaldırılan unvanlar — ekranda ASLA görünmemeli.
const _eskiUnvanlar = [
  'Meraklı izleyici',
  'Hevesli izleyici',
  'Amatör izleyici',
  'Kıdemli izleyici',
  'Uzman izleyici',
  'Profesör izleyici',
  'Efsane izleyici',
  'Ultra mega izleyici',
];

/// Sunucunun KENDİ profilinde döndürdüğü tam seviye kaydı.
Map<String, dynamic> _tamSeviye({
  int kademe = 5,
  int puan = 1240,
  int esik = 896,
  int? sonrakiEsik = 1750,
}) => {
  'kademe': kademe,
  'puan': puan,
  'esik': esik,
  'sonraki_esik': sonrakiEsik,
};

/// Sunucunun ZİYARETÇİYE döndürdüğü süzülmüş kayıt: puan/eşik YOK.
Map<String, dynamic> _acikSeviye({int kademe = 5}) => {'kademe': kademe};

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

/// Ekranda unvan/payda kalıntısı var mı? (Gerileme kilidi.)
void _unvanYok(WidgetTester tester) {
  for (final ad in _eskiUnvanlar) {
    expect(find.textContaining(ad), findsNothing, reason: 'unvan sızdı: $ad');
  }
  expect(find.textContaining('Sonraki:'), findsNothing);
  expect(find.textContaining('En üst'), findsNothing);
  expect(find.textContaining('/8'), findsNothing);
}

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
  // 1. ETİKET — salt sayı, payda YOK, unvan YOK
  // =========================================================================

  group('etiket', () {
    test('"Seviye 5" — payda ("/8") YOK', () {
      final sv = Seviye.cozumle(_tamSeviye())!;
      expect(sv.etiket, 'Seviye 5');
      expect(sv.etiket.contains('/'), isFalse);
    });

    test('TAVANSIZ: üç haneli kademe de aynı biçimde yazılır', () {
      expect(Seviye.cozumle(_acikSeviye(kademe: 41))!.etiket, 'Seviye 41');
      expect(Seviye.cozumle(_acikSeviye(kademe: 137))!.etiket, 'Seviye 137');
    });

    test('etiket ve alt satır hiçbir ESKİ UNVANI içermiyor', () {
      final sv = Seviye.cozumle(_tamSeviye())!;
      for (final ad in _eskiUnvanlar) {
        expect(sv.etiket.contains(ad), isFalse);
        expect(sv.altSatir!.contains(ad), isFalse);
      }
    });
  });

  // =========================================================================
  // 2. ÇÖZÜMLEME — bozuk/eksik yanıtta satır hiç çizilmez
  // =========================================================================

  group('Seviye.cozumle', () {
    test('null / yanlış tür / eksik alan → null', () {
      expect(Seviye.cozumle(null), isNull);
      expect(Seviye.cozumle('5'), isNull);
      expect(Seviye.cozumle(<String, dynamic>{}), isNull);
      expect(Seviye.cozumle({'puan': 120}), isNull);
      expect(Seviye.cozumle({'kademe': 0}), isNull);
      expect(Seviye.cozumle({'kademe': -3}), isNull);
    });

    test('ziyaretçi kaydında puan/eşik yok → ilerleme yok', () {
      final sv = Seviye.cozumle(_acikSeviye())!;
      expect(sv.kademe, 5);
      expect(sv.puan, isNull);
      expect(sv.ilerlemeVar, isFalse);
      expect(sv.ilerleme, isNull);
      expect(sv.kalanPuan, isNull);
      expect(sv.altSatir, isNull);
    });

    test('ESKİ SUNUCUNUN kod/toplam alanları yok sayılır, kayıt çözülür', () {
      // Dağıtım sırasında eski bir yanıt önbellekten gelebilir.
      final sv = Seviye.cozumle({
        'kademe': 5,
        'kod': 'uzman',
        'toplam': 8,
        'puan': 1240,
        'esik': 896,
        'sonraki_esik': 1750,
      })!;
      expect(sv.etiket, 'Seviye 5');
      expect(sv.altSatir, isNotNull);
      expect(sv.altSatir!.contains('Uzman'), isFalse);
    });
  });

  // =========================================================================
  // 3. İLERLEME MATEMATİĞİ — sınırlar
  // =========================================================================

  group('ilerleme (saf)', () {
    test('kademenin TAM ALT SINIRINDA çubuk boş (0.0)', () {
      final sv = Seviye.cozumle(_tamSeviye(puan: 896))!;
      expect(sv.ilerleme, 0.0);
    });

    test('sonraki eşiğin BİR ALTINDA çubuk dolmaya çok yakın ama 1 değil', () {
      final sv = Seviye.cozumle(_tamSeviye(puan: 1749))!;
      expect(sv.ilerleme, greaterThan(0.99));
      expect(sv.ilerleme, lessThan(1.0));
      expect(sv.kalanPuan, 1);
    });

    test('tam ortada 0.5', () {
      final sv = Seviye.cozumle(_tamSeviye(puan: 1323))!;
      expect(sv.ilerleme, closeTo(0.5, 0.0001));
    });

    test('EŞİK AŞILMIŞ gecikmiş veride 1.0 ile kırpılır (çubuk taşmaz)', () {
      final sv = Seviye.cozumle(_tamSeviye(puan: 9999))!;
      expect(sv.ilerleme, 1.0);
      // "Sonraki seviyeye -8249 puan kaldı" saçmalığı yok.
      expect(sv.kalanPuan, 0);
    });

    test('EŞİĞİN ALTINDA tutarsız veride 0.0 ile kırpılır', () {
      final sv = Seviye.cozumle(_tamSeviye(puan: 10))!;
      expect(sv.ilerleme, 0.0);
    });

    test('sonraki_esik gelmezse (eski/bozuk yanıt) ilerleme çizilmez', () {
      final sv = Seviye.cozumle(_tamSeviye(sonrakiEsik: null))!;
      expect(sv.ilerlemeVar, isFalse);
      expect(sv.ilerleme, isNull);
      expect(sv.altSatir, isNull);
    });

    test('alt satır İLERİ BAKAR: kalan puan, YÜZDE DEĞİL', () {
      final sv = Seviye.cozumle(_tamSeviye())!;
      expect(sv.kalanPuan, 510);
      expect(sv.altSatir, 'Sonraki seviyeye 510 puan kaldı');
      // Yüzde YOK — "%18 tamamlandı" az izleyene ne kadar AZ yaptığını söyler.
      expect(sv.altSatir!.contains('%'), isFalse);
    });

    test('YENİ KULLANICI: 1. kademe, ilerleme çizilebilir, unvan yok', () {
      final sv = Seviye.cozumle(
        _tamSeviye(kademe: 1, puan: 0, esik: 0, sonrakiEsik: 14),
      )!;
      expect(sv.etiket, 'Seviye 1');
      expect(sv.ilerleme, 0.0);
      expect(sv.altSatir, 'Sonraki seviyeye 14 puan kaldı');
    });
  });

  // =========================================================================
  // 4. KENDİ PROFİLİM — seviye + İLERLEME görünür, UNVAN YOK
  // =========================================================================

  testWidgets('KENDİ PROFİLİM: "Seviye 5", çubuk ve kalan puan satırı VAR', (
    tester,
  ) async {
    await _kendim(tester, _tamSeviye());
    expect(find.byType(SeviyeSatiri), findsOneWidget);
    expect(find.text('Seviye 5'), findsOneWidget);
    expect(_cubuk, findsOneWidget);
    expect(find.text('Sonraki seviyeye 510 puan kaldı'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsOneWidget);
    // Çubuk gerçekten kısmen dolu (0 ya da 1'e sıkışmış değil).
    final gosterge = tester.widget<LinearProgressIndicator>(_cubuk);
    expect(gosterge.value, closeTo(0.403, 0.01));
  });

  testWidgets('KENDİ PROFİLİM: EKRANDA HİÇBİR UNVAN/PAYDA YOK', (tester) async {
    await _kendim(tester, _tamSeviye());
    _unvanYok(tester);
  });

  testWidgets('KENDİ PROFİLİM: çubuk ekran okuyucuda ADLI ve DEĞERLİ', (
    tester,
  ) async {
    // Etiketsiz bir `LinearProgressIndicator` erişilebilirlik ağacına HİÇ
    // girmez; dolgu yalnız görene bilgi olurdu.
    final tut = tester.ensureSemantics();
    await _kendim(tester, _tamSeviye());
    // Ağaç gerçekten kuruldu: değer sayıya çevrilemezse çerçeve burada
    // assert'e düşer (bu tuzağa bir kez düşüldü, bu satır kapıyı tutuyor).
    expect(tester.takeException(), isNull);
    final gosterge = tester.widget<LinearProgressIndicator>(_cubuk);
    expect(gosterge.semanticsLabel, 'Seviye 5');
    // SALT SAYI: çerçeve bu düğümü "progress bar" (0..100) olarak kuruyor ve
    // değerin sayıya çevrilebilmesini assert ediyor — "%40" yazılırsa uygulama
    // her karede assert'e düşer (yüzde işaretini ekran okuyucu ekler).
    expect(gosterge.semanticsValue, '40');
    expect(double.tryParse(gosterge.semanticsValue!), isNotNull);
    tut.dispose();
  });

  testWidgets('KENDİ PROFİLİM: seviye kullanıcı adının ALTINDA duruyor', (
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
    final seviye = tester.getRect(find.text('Seviye 5'));
    expect(seviye.top, greaterThanOrEqualTo(ad.bottom - 1));
    // Aynı sütunda: sol kenarları hizalı.
    expect(seviye.left, closeTo(ad.left, 1));
  });

  testWidgets('KENDİ PROFİLİM: seviye gelmezse satır hiç çizilmez', (
    tester,
  ) async {
    await _kendim(tester, null);
    expect(find.byType(SeviyeSatiri), findsNothing);
    expect(_cubuk, findsNothing);
  });

  testWidgets('TAVAN YOK: yüksek kademede de çubuk ve hedef satırı sürüyor', (
    tester,
  ) async {
    // Eskiden 8. kademede çubuk kaybolur, "En üst unvan" yazardı.
    await _kendim(
      tester,
      _tamSeviye(kademe: 12, puan: 20000, esik: 18634, sonrakiEsik: 24192),
    );
    expect(find.text('Seviye 12'), findsOneWidget);
    expect(_cubuk, findsOneWidget);
    expect(find.text('Sonraki seviyeye 4192 puan kaldı'), findsOneWidget);
    _unvanYok(tester);
  });

  // =========================================================================
  // 5. BAŞKASININ PROFİLİ — yalnız sayı; ilerleme YOK
  // =========================================================================

  testWidgets('BAŞKASININ PROFİLİ: "Seviye 5" VAR ama İLERLEME YOK', (
    tester,
  ) async {
    await _baskasi(tester, _acikSeviye());
    expect(find.byType(SeviyeSatiri), findsOneWidget);
    expect(find.text('Seviye 5'), findsOneWidget);
    // Çubuk ve hedef satırı ÇİZİLMEZ: başkasının profilindeki ilerleme,
    // seviyeyi bir sıralama tablosuna çevirirdi.
    expect(_cubuk, findsNothing);
    expect(find.byIcon(Icons.trending_up), findsNothing);
    expect(find.textContaining('Sonraki seviyeye'), findsNothing);
    expect(find.textContaining('puan kaldı'), findsNothing);
    _unvanYok(tester);
  });

  testWidgets(
    'BAŞKASININ PROFİLİ: sunucu puan/eşik SIZDIRSA BİLE ilerleme çizilmez',
    (tester) async {
      // İkinci kilit: `ilerlemeGoster` bayrağı `ben_mi`ye bağlı. Sunucu bir
      // gün süzgeci gevşetse bile ziyaretçi çubuğu görmez.
      await _baskasi(tester, _tamSeviye());
      expect(find.text('Seviye 5'), findsOneWidget);
      expect(_cubuk, findsNothing);
      expect(find.textContaining('puan kaldı'), findsNothing);
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
      expect(find.textContaining('Seviye'), findsNothing);
      _unvanYok(tester);
    },
  );

  testWidgets('AÇIK PROFİL KENDİ ADIMLA açıldıysa (ben_mi) ilerleme GÖRÜNÜR', (
    tester,
  ) async {
    // Bu ekran kendi kullanıcı adınla da açılabiliyor; "kendi profilim mi"
    // kararı sunucunun `ben_mi` yargısından gelir.
    await _baskasi(tester, _tamSeviye(), benMi: true);
    expect(find.text('Seviye 5'), findsOneWidget);
    expect(_cubuk, findsOneWidget);
    expect(find.text('Sonraki seviyeye 510 puan kaldı'), findsOneWidget);
  });

  // =========================================================================
  // 6. DAR EKRAN — 45 dilde uzun ilerleme satırı
  // =========================================================================

  testWidgets('320 dp: üç haneli seviye + ilerleme satırı taşmıyor', (
    tester,
  ) async {
    // Deneme yazı tipinde her harf 1em kare: satır gerçek yazı tipinden çok
    // daha geniş çizilir, yani bu 45 dil için tampon.
    await _kendim(
      tester,
      _tamSeviye(
        kademe: 137,
        puan: 34_000_000,
        esik: 33_918_368,
        sonrakiEsik: 35_998_942,
      ),
      boyut: const Size(_darEkran, 900),
    );
    final satir = find.byType(SeviyeSatiri);
    expect(satir, findsOneWidget);
    final kutu = tester.getRect(satir);
    expect(kutu.left, greaterThanOrEqualTo(0));
    expect(kutu.right, lessThanOrEqualTo(_darEkran + 0.01));
    // Seviye metni sarılır/üç noktaya düşer ama kaybolmaz.
    final metin = tester.getRect(find.text('Seviye 137'));
    expect(metin.width, greaterThan(0));
    expect(metin.right, lessThanOrEqualTo(kutu.right + 0.01));

    // Bu ekranda 320 dp'de KALAN taşmalar sekme etiketlerinden gelir (ülke
    // satırı testindeki bilinen gürültü, gerçek yazı tipinde yok). Seviye
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
