// GÖRÜNEN AD ("ad") PROFİL BAŞLIĞINDA (21 Ağu 2026)
//
// SORUN: `kullanicilar.ad` sütunu, ayarlardaki giriş alanı ve iki uç
// (`GET /profilim`, `GET /profil/:kullaniciAdi`) aynı gün eklendi — ama
// HİÇBİR EKRAN ÇİZMİYORDU. Kullanıcı adını kaydedip "neden görünmüyor?" dedi.
// Ayarlardaki alanın kendi açıklaması şunu vaat ediyor:
//   "Profilinde kullanıcı adının ÜSTÜNDE görünür. Boş bırakabilirsin."
//
// Bu dosya o vaadi kilitler:
//
//  1. AD DOLUYKEN kullanıcı adının ÜSTÜNDE, doğru metinle görünür.
//  2. AD BOŞKEN bugünkü görünüm BİREBİR korunur — boş satır yok, kayma yok.
//     (Ölçüm eski düzeni birebir yeniden kuran bir REFERANS widget'la
//     karşılaştırılıyor; "gözle aynı görünüyor" yetmez.)
//  3. `ad` null / boş / yalnız boşluk / BOZUK TİP gelirse çökmez.
//  4. İKİ EKRAN DA AYNI BİLEŞENİ ÇİZER — kopya yok. Görünen ad ekranda
//     yalnız [ProfilKimlikBasligi] içinde geçer ve iki ekranın ürettiği yazı
//     biçemi (punto/kalınlık/renk) BİREBİR aynıdır.
//  5. 40 KARAKTERLİK ad 320 dp'de taşmaz (sunucu sınırı `AD_AZAMI = 40`).
//  6. ROZET (AileRozeti) BİRİNCİL SATIRDA kalır: ad varsa adın yanında.
import 'dart:convert';

import 'package:dizijpg/aile_rozeti.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _kendiIstatistik = {
  'takipci_sayisi': 11,
  'takip_sayisi': 22,
  'toplam_begeni': 33,
  'toplam_goruntulenme': 44,
  'izlenen_bolum': 55,
  'izlenen_film': 66,
  'takip_edilen_dizi': 77,
  'yorum_sayisi': 88,
  'tahmini_dakika': 90,
};

const _acikIstatistik = {
  'takipci': 11,
  'takip_edilen': 22,
  'toplam_begeni': 33,
  'toplam_goruntulenme': 44,
  'bolum': 55,
  'film': 66,
  'dizi': 77,
  'yorum': 88,
  'tahmini_dakika': 90,
};

/// `GET /profilim` gövdesi. [ad] YOKSA anahtar HİÇ konmaz — bayat önbellekten
/// gelen eski gövde tam olarak böyle görünür.
Map<String, dynamic> _profilimGovde({Object? ad, bool adAnahtariVar = true}) =>
    {
      'id': 7,
      'kullanici_adi': 'testkullanici',
      'avatar': null,
      'kapak': null,
      'bio': null,
      'ulke': null,
      'sosyal': <dynamic>[],
      'testci': false,
      if (adAnahtariVar) 'ad': ad,
    };

void _kendiSunucu({Object? ad, bool adAnahtariVar = true}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (yol.startsWith('/istatistiklerim')) return _json(_kendiIstatistik);
    if (yol.startsWith('/kitapligim')) return _json({'durumlar': <dynamic>[]});
    if (yol.startsWith('/listelerim')) return _json({'listeler': <dynamic>[]});
    if (yol.startsWith('/izlediklerim')) return _json({'ogeler': <dynamic>[]});
    if (yol.startsWith('/rozetler')) return _json({'rozetler': <dynamic>[]});
    if (yol.startsWith('/profilim')) {
      return _json(_profilimGovde(ad: ad, adAnahtariVar: adAnahtariVar));
    }
    if (yol.startsWith('/profil/')) {
      return _json({'yorumlar': <dynamic>[], 'icerikler': <String, dynamic>{}});
    }
    return _json(const <String, dynamic>{});
  });
}

Map<String, dynamic> _acikProfilGovde({
  Object? ad,
  bool adAnahtariVar = true,
  bool testci = false,
}) => {
  'id': 42,
  'kullanici_adi': 'baskasi',
  'avatar': null,
  'kapak': null,
  'bio': null,
  'ulke': null,
  'sosyal': <dynamic>[],
  'olusturma': '2026-01-01T00:00:00Z',
  'ben_mi': false,
  'takip_ediyorum': false,
  'testci': testci,
  'misafir': false,
  'izlenenler_gizli': false,
  'yorumlar_gizli': false,
  'yanitlar_gizli': false,
  'takipciler_gizli': false,
  'takip_edilenler_gizli': false,
  'uyum': null,
  'istatistik': _acikIstatistik,
  'rozetler': <dynamic>[],
  'listeler': <dynamic>[],
  'incelemeler': <dynamic>[],
  'yorumlar': <dynamic>[],
  'icerikler': <String, dynamic>{},
  'izlenenler': <dynamic>[],
  if (adAnahtariVar) 'ad': ad,
};

void _acikSunucu(Map<String, dynamic> profil) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (yol.startsWith('/profil/')) return _json(profil);
    return _json(const <String, dynamic>{});
  });
}

Future<void> _oturum() async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'testkullanici'}),
  });
  await Api.tokenYukle();
}

Future<void> _kur(
  WidgetTester tester,
  Widget ekran, {
  Size boyut = const Size(420, 900),
}) async {
  tester.view.physicalSize = boyut;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum()..kullanici = {'id': 7, 'kullanici_adi': 'testkullanici'},
      child: MaterialApp(theme: diziTema(acik: false), home: ekran),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Bileşeni TEK BAŞINA, bilinen genişlikte çizer (yerleşim ölçümleri için).
Future<void> _tekBasina(
  WidgetTester tester,
  Widget cocuk, {
  double genislik = 320,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: diziTema(acik: false),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: genislik,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [cocuk],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 21 Ağu 2026 ÖNCESİNİN kimlik satırı — birebir. "Ad boşken hiçbir şey
/// değişmedi" iddiasının ÖLÇÜLEBİLİR referansı budur.
class _EskiKimlikSatiri extends StatelessWidget {
  final String kullaniciAdi;
  final bool testci;
  final bool genis;
  const _EskiKimlikSatiri({
    required this.kullaniciAdi,
    this.testci = false,
    this.genis = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(
        child: Text(
          '@$kullaniciAdi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: genis ? 21 : 17,
            fontWeight: FontWeight.w900,
            color: DiziRenkler.metin,
          ),
        ),
      ),
      if (testci) AileRozeti(benMi: true, olcu: genis ? 22 : 19),
    ],
  );
}

TextStyle _stil(WidgetTester tester, String metin) =>
    tester.renderObject<RenderParagraph>(find.text(metin)).text.style!;

/// Kimlik bloğunun İÇİNDEKİ metnin biçemi.
///
/// TUZAK: `@kullaniciAdi` iki profil ekranında da AppBar başlığında DA yazıyor
/// (profil.dart, kullanici_profil.dart). Kapsamsız `find.text` iki eleman bulur
/// ve `renderObject` "Too many elements" ile düşer.
TextStyle _kimlikStil(WidgetTester tester, String metin) => tester
    .renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(ProfilKimlikBasligi),
        matching: find.text(metin),
      ),
    )
    .text
    .style!;

void main() {
  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    DiziRenkler.acik = false;
    await _oturum();
  });

  // =========================================================================
  // 1. AYIKLAYICI — tek yer, bütün bozuk gövdeler
  // =========================================================================
  group('ProfilKimlikBasligi.temiz', () {
    test('null / boş / yalnız boşluk → null (ad yok)', () {
      expect(ProfilKimlikBasligi.temiz(null), isNull);
      expect(ProfilKimlikBasligi.temiz(''), isNull);
      expect(ProfilKimlikBasligi.temiz('   '), isNull);
      expect(ProfilKimlikBasligi.temiz('\t \n'), isNull);
    });

    test('BOZUK TİP çökmez, null döner', () {
      expect(ProfilKimlikBasligi.temiz(42), isNull);
      expect(ProfilKimlikBasligi.temiz(const <String>[]), isNull);
      expect(ProfilKimlikBasligi.temiz(true), isNull);
    });

    test('gerçek ad baş/son boşluğundan arındırılır', () {
      expect(ProfilKimlikBasligi.temiz('  Ali Çelik  '), 'Ali Çelik');
      expect(ProfilKimlikBasligi.temiz('A'), 'A');
    });
  });

  // =========================================================================
  // 2. AD DOLUYKEN: ad ÜSTTE, kullanıcı adı ALTTA
  // =========================================================================
  group('ad doluyken', () {
    testWidgets('ad kullanıcı adının ÜSTÜNDE çizilir', (tester) async {
      await _tekBasina(
        tester,
        const ProfilKimlikBasligi(ad: 'Ali Çelik', kullaniciAdi: 'alcelik'),
      );
      expect(find.text('Ali Çelik'), findsOneWidget);
      expect(find.text('@alcelik'), findsOneWidget);
      expect(
        tester.getRect(find.text('Ali Çelik')).top,
        lessThan(tester.getRect(find.text('@alcelik')).top),
        reason: 'ayarlardaki alan "kullanıcı adının ÜSTÜNDE" diyor',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('hiyerarşi PUNTO/KALINLIKLA kurulur, GRİYLE değil', (
      tester,
    ) async {
      await _tekBasina(
        tester,
        const ProfilKimlikBasligi(ad: 'Ali Çelik', kullaniciAdi: 'alcelik'),
      );
      final adStil = _stil(tester, 'Ali Çelik');
      final kadiStil = _stil(tester, '@alcelik');
      expect(adStil.fontSize, greaterThan(kadiStil.fontSize!));
      expect(adStil.fontWeight!.value, greaterThan(kadiStil.fontWeight!.value));
      // KULLANICI İSTEĞİ (16 Ağu 2026): gri yazı yalnız PASİF öğede.
      expect(adStil.color, DiziRenkler.metin);
      expect(
        kadiStil.color,
        DiziRenkler.metin,
        reason: 'kullanıcı adı pasif değil — gri (metin38) OLAMAZ',
      );
      expect(kadiStil.color, isNot(DiziRenkler.metin38));
    });

    testWidgets('yalnız boşluktan ibaret ad = ad yok', (tester) async {
      await _tekBasina(
        tester,
        const ProfilKimlikBasligi(ad: '   ', kullaniciAdi: 'alcelik'),
      );
      expect(find.byType(Text), findsOneWidget);
      expect(find.text('@alcelik'), findsOneWidget);
    });
  });

  // =========================================================================
  // 3. AD BOŞKEN: BUGÜNKÜ GÖRÜNÜM BİREBİR
  // =========================================================================
  group('ad boşken', () {
    for (final (etiket, ad, anahtarVar) in <(String, Object?, bool)>[
      ('null', null, true),
      ('boş dize', '', true),
      ('yalnız boşluk', '  ', true),
      ('anahtar HİÇ YOK', null, false),
      ('bozuk tip (sayı)', 42, true),
    ]) {
      testWidgets('$etiket → tek satır, eski düzenle BİREBİR aynı', (
        tester,
      ) async {
        // Yeni bileşen
        await _tekBasina(
          tester,
          ProfilKimlikBasligi(
            ad: anahtarVar ? ad : null,
            kullaniciAdi: 'alcelik',
            testci: true,
          ),
        );
        expect(
          find.byType(Text),
          findsOneWidget,
          reason: 'boş satır/ikinci Text çizilmemeli',
        );
        final yeniKutu = tester.getRect(find.byType(ProfilKimlikBasligi));
        final yeniYazi = tester.getRect(find.text('@alcelik'));
        final yeniRozet = tester.getRect(find.byType(AileRozeti));
        final yeniStil = _stil(tester, '@alcelik');

        // 21 Ağu ÖNCESİNİN kodu, birebir
        await _tekBasina(
          tester,
          const _EskiKimlikSatiri(kullaniciAdi: 'alcelik', testci: true),
        );
        final eskiKutu = tester.getRect(find.byType(_EskiKimlikSatiri));
        final eskiYazi = tester.getRect(find.text('@alcelik'));
        final eskiRozet = tester.getRect(find.byType(AileRozeti));
        final eskiStil = _stil(tester, '@alcelik');

        expect(
          yeniKutu.size,
          eskiKutu.size,
          reason: 'kimlik bloğunun ölçüsü değişirse ALTINDAKİ HER ŞEY kayar',
        );
        expect(yeniYazi, eskiYazi, reason: 'kullanıcı adı aynı yerde durmalı');
        expect(yeniRozet, eskiRozet, reason: 'onay tiki aynı yerde durmalı');
        expect(yeniStil.fontSize, eskiStil.fontSize);
        expect(yeniStil.fontWeight, eskiStil.fontWeight);
        expect(yeniStil.color, eskiStil.color);
      });
    }

    testWidgets('MASAÜSTÜ ölçüsünde de birebir', (tester) async {
      await _tekBasina(
        tester,
        const ProfilKimlikBasligi(
          ad: null,
          kullaniciAdi: 'alcelik',
          testci: true,
          genis: true,
        ),
        genislik: 520,
      );
      final yeni = tester.getRect(find.byType(ProfilKimlikBasligi)).size;
      final yeniPunto = _stil(tester, '@alcelik').fontSize;

      await _tekBasina(
        tester,
        const _EskiKimlikSatiri(
          kullaniciAdi: 'alcelik',
          testci: true,
          genis: true,
        ),
        genislik: 520,
      );
      expect(yeni, tester.getRect(find.byType(_EskiKimlikSatiri)).size);
      expect(yeniPunto, _stil(tester, '@alcelik').fontSize);
      expect(yeniPunto, 21);
    });
  });

  // =========================================================================
  // 4. UZUN AD — 40 karakter (sunucu sınırı) 320 dp'de taşmaz
  // =========================================================================
  group('uzun ad', () {
    // `AD_AZAMI = 40` (server.js). Sunucu KIRPMIYOR, REDDEDİYOR — yani 40
    // karakterlik ad gerçekten kaydedilebilir ve ekrana gelir.
    final kirkKarakter = 'Ağça' * 10; // 40 kod noktası
    setUp(() => expect(kirkKarakter.runes.length, 40));

    testWidgets('320 dp: taşma YOK, tek satır, üç nokta', (tester) async {
      await _tekBasina(
        tester,
        ProfilKimlikBasligi(ad: kirkKarakter, kullaniciAdi: 'alcelik'),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'RenderFlex overflow = taşma',
      );
      final kutu = tester.getRect(find.byType(ProfilKimlikBasligi));
      expect(kutu.width, lessThanOrEqualTo(320));
      final yazi = tester.widget<Text>(find.text(kirkKarakter));
      expect(yazi.maxLines, 1);
      expect(yazi.overflow, TextOverflow.ellipsis);
      expect(
        tester.getRect(find.text(kirkKarakter)).width,
        lessThanOrEqualTo(320),
      );
    });

    testWidgets('320 dp + onay tiki: tik ekran DIŞINA itilmez', (tester) async {
      await _tekBasina(
        tester,
        ProfilKimlikBasligi(
          ad: kirkKarakter,
          kullaniciAdi: 'cok-uzun-bir-kullanici-adi',
          testci: true,
        ),
      );
      expect(tester.takeException(), isNull);
      final tik = tester.getRect(find.byType(AileRozeti));
      expect(tik.right, lessThanOrEqualTo(320));
      expect(tik.left, greaterThanOrEqualTo(0));
    });
  });

  // =========================================================================
  // 5. ROZET KARARI — tik BİRİNCİL satırda (ad varsa ADIN yanında)
  // =========================================================================
  group('onay tiki (AileRozeti)', () {
    testWidgets('ad VARKEN tik ADIN yanında, kullanıcı adının DEĞİL', (
      tester,
    ) async {
      await _tekBasina(
        tester,
        const ProfilKimlikBasligi(
          ad: 'Ali Çelik',
          kullaniciAdi: 'alcelik',
          testci: true,
        ),
      );
      final tik = tester.getRect(find.byType(AileRozeti));
      final adK = tester.getRect(find.text('Ali Çelik'));
      final kadiK = tester.getRect(find.text('@alcelik'));
      expect(
        tik.left,
        greaterThanOrEqualTo(adK.right - 1),
        reason: 'tik adın SAĞINDA',
      );
      expect(
        (tik.center.dy - adK.center.dy).abs(),
        lessThan((tik.center.dy - kadiK.center.dy).abs()),
        reason: 'tik ADIN satırında hizalı olmalı',
      );
    });

    testWidgets('testci DEĞİLSE tik hiç çizilmez', (tester) async {
      await _tekBasina(
        tester,
        const ProfilKimlikBasligi(ad: 'Ali Çelik', kullaniciAdi: 'alcelik'),
      );
      expect(find.byType(AileRozeti), findsNothing);
    });
  });

  // =========================================================================
  // 6. KENDİ PROFİLİM (profil.dart) — uçtan uca
  // =========================================================================
  group('kendi profilim', () {
    testWidgets('/profilim `ad` dönerse başlıkta GÖRÜNÜR', (tester) async {
      _kendiSunucu(ad: 'Ali Çelik');
      await _kur(tester, const ProfilEkrani());
      expect(find.byType(ProfilKimlikBasligi), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProfilKimlikBasligi),
          matching: find.text('Ali Çelik'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ProfilKimlikBasligi),
          matching: find.text('@testkullanici'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.text('Ali Çelik')).top,
        lessThan(
          tester
              .getRect(
                find.descendant(
                  of: find.byType(ProfilKimlikBasligi),
                  matching: find.text('@testkullanici'),
                ),
              )
              .top,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ad YOKKEN ekran eskisi gibi, çökme yok', (tester) async {
      _kendiSunucu(adAnahtariVar: false);
      await _kur(tester, const ProfilEkrani());
      expect(find.byType(ProfilKimlikBasligi), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProfilKimlikBasligi),
          matching: find.byType(Text),
        ),
        findsOneWidget,
        reason: 'ad yoksa kimlik bloğunda TEK satır olmalı',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ad `null` gelirse çökmez', (tester) async {
      _kendiSunucu(ad: null);
      await _kur(tester, const ProfilEkrani());
      expect(find.byType(ProfilKimlikBasligi), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BOZUK gövde (ad sayı) çökmez', (tester) async {
      _kendiSunucu(ad: 42);
      await _kur(tester, const ProfilEkrani());
      expect(find.byType(ProfilKimlikBasligi), findsOneWidget);
      expect(find.text('42'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // 21 AĞU GERİLEMESİ (kullanıcı bildirdi): dokunma hedefi için `Container`a
    // `alignment` verilince kutu genişledi ve sayaçlar ALT ALTA dizildi.
    // Buradaki soru "kaç satıra sığıyorlar" DEĞİL (Wrap dar ekranda satır
    // atlayabilir ve bu DOĞRU davranış) — soru şu: AD EKLENMESİ sarmayı
    // DEĞİŞTİRİYOR MU? Ad, sayaçlarla AYNI sütunun üstünde duruyor; başlık
    // yanlış kurulursa (ör. sabit yükseklik/genişlik) sarma bozulurdu.
    testWidgets('ad EKLENİNCE sayaçların sarması DEĞİŞMEZ', (tester) async {
      List<double> ustler() => tester
          .widgetList<TakipSayac>(find.byType(TakipSayac))
          .where((w) => w.etiket != 'görüntülenme')
          .map((w) => tester.getRect(find.byWidget(w)).top)
          .toList();

      _kendiSunucu(adAnahtariVar: false);
      await _kur(tester, const ProfilEkrani());
      final adsizSatirSayisi = ustler().toSet().length;
      final adsizGenislikler = tester
          .widgetList<TakipSayac>(find.byType(TakipSayac))
          .map((w) => tester.getRect(find.byWidget(w)).width)
          .toList();

      _kendiSunucu(ad: 'Ali Çelik');
      await _kur(tester, const ProfilEkrani());
      expect(
        ustler().toSet().length,
        adsizSatirSayisi,
        reason: 'ad eklenince sayaçlar farklı sayıda satıra dağıldı',
      );
      expect(
        tester
            .widgetList<TakipSayac>(find.byType(TakipSayac))
            .map((w) => tester.getRect(find.byWidget(w)).width)
            .toList(),
        adsizGenislikler,
        reason: 'sayaç kutuları genişledi — alignment gerilemesinin imzası',
      );
      // Ve hiçbiri satırın tamamını kaplamıyor (asıl gerileme buydu).
      for (final w in tester.widgetList<TakipSayac>(find.byType(TakipSayac))) {
        expect(
          tester.getRect(find.byWidget(w)).width,
          lessThan(420 * 0.5),
          reason: 'bir sayaç ekranın yarısından geniş — Container genişlemiş',
        );
      }
    });

    testWidgets('ad EKLENİNCE avatar hâlâ kimlik satırıyla HİZALI', (
      tester,
    ) async {
      // KULLANICI İSTEĞİ (21 Ağu): profil resmi kullanıcı adıyla aynı hizada,
      // görüntülenme sayacı resmin ALTINDA. Ad satırı eklenince avatarın
      // ortalanıp aşağı kaymadığını burada kilitliyoruz.
      _kendiSunucu(ad: 'Ali Çelik');
      await _kur(tester, const ProfilEkrani());
      final kimlik = tester.getRect(find.byType(ProfilKimlikBasligi));
      final avatar = tester
          .getRect(find.byType(GestureDetector).first)
          .translate(0, 0);
      expect(
        (avatar.top - kimlik.top).abs(),
        lessThan(8),
        reason: 'avatarın ÜST kenarı kimlik bloğuyla aynı çizgide kalmalı',
      );
      // 26 Ağu 2026: "avatarın altında" kuralı KALKTI — görüntülenme artık
      // takip satırının İLK öğesi (ikonlu biçim; kullanıcı isteği). Burada
      // kalan kilit: satırda takipçinin SOLUNDA ve onunla AYNI HİZADA durur.
      final goruntulenme = tester
          .widgetList<TakipSayac>(find.byType(TakipSayac))
          .firstWhere((w) => w.etiket == 'görüntülenme');
      final takipci = tester
          .widgetList<TakipSayac>(find.byType(TakipSayac))
          .firstWhere((w) => w.etiket == 'takipçi');
      final gRect = tester.getRect(find.byWidget(goruntulenme));
      final tRect = tester.getRect(find.byWidget(takipci));
      expect(
        gRect.left,
        lessThan(tRect.left),
        reason: 'görüntülenme takipçinin SOLUNDA olmalı',
      );
      expect(
        (gRect.top - tRect.top).abs(),
        lessThan(1),
        reason: 'görüntülenme ile takipçi AYNI satırda olmalı',
      );
    });
  });

  // =========================================================================
  // 7. BAŞKASININ PROFİLİ (kullanici_profil.dart) — uçtan uca
  // =========================================================================
  group('başkasının profili', () {
    testWidgets('/profil/:ad `ad` dönerse başlıkta GÖRÜNÜR', (tester) async {
      _acikSunucu(_acikProfilGovde(ad: 'Veli Yılmaz'));
      await _kur(tester, const KullaniciProfilEkrani(kullaniciAdi: 'baskasi'));
      expect(find.byType(ProfilKimlikBasligi), findsOneWidget);
      expect(find.text('Veli Yılmaz'), findsOneWidget);
      expect(
        tester.getRect(find.text('Veli Yılmaz')).top,
        lessThan(
          tester
              .getRect(
                find.descendant(
                  of: find.byType(ProfilKimlikBasligi),
                  matching: find.text('@baskasi'),
                ),
              )
              .top,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ad YOKKEN kimlik bloğu TEK satır', (tester) async {
      _acikSunucu(_acikProfilGovde(adAnahtariVar: false));
      await _kur(tester, const KullaniciProfilEkrani(kullaniciAdi: 'baskasi'));
      expect(
        find.descendant(
          of: find.byType(ProfilKimlikBasligi),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ad `null` gelirse çökmez', (tester) async {
      _acikSunucu(_acikProfilGovde(ad: null));
      await _kur(tester, const KullaniciProfilEkrani(kullaniciAdi: 'baskasi'));
      expect(find.byType(ProfilKimlikBasligi), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // 8. KOPYA YOK — İKİ EKRAN, TEK BİLEŞEN
  //
  // Bu iki ekran BUGÜN bir kez kopyalama yüzünden ayrıştı (15 Ağu'da kendi
  // profilde yapılan değişiklik açık profile hiç gitmedi) ve birleştirmek ayrı
  // bir iş oldu. Testin sorduğu şey "aynı görünüyor mu" DEĞİL, "AYNI KODU MU
  // ÇİZİYORLAR": görünen ad ekranda yalnız [ProfilKimlikBasligi] içinde geçer
  // ve iki ekranın ürettiği yazı biçemi birebir aynıdır.
  // =========================================================================
  group('kopya yok', () {
    testWidgets('görünen ad SADECE ortak bileşenin içinde geçer', (
      tester,
    ) async {
      _kendiSunucu(ad: 'Ali Çelik');
      await _kur(tester, const ProfilEkrani());
      expect(
        find.text('Ali Çelik'),
        findsOneWidget,
        reason: 'ikinci bir kopya = ayrışmanın başlangıcı',
      );
      expect(
        find.descendant(
          of: find.byType(ProfilKimlikBasligi),
          matching: find.text('Ali Çelik'),
        ),
        findsOneWidget,
      );

      _acikSunucu(_acikProfilGovde(ad: 'Ali Çelik'));
      await _kur(tester, const KullaniciProfilEkrani(kullaniciAdi: 'baskasi'));
      expect(find.text('Ali Çelik'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProfilKimlikBasligi),
          matching: find.text('Ali Çelik'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('iki ekran AYNI biçemi çizer (punto/kalınlık/renk)', (
      tester,
    ) async {
      _kendiSunucu(ad: 'Ortak Ad');
      await _kur(tester, const ProfilEkrani());
      final kendiAd = _kimlikStil(tester, 'Ortak Ad');
      final kendiKadi = _kimlikStil(tester, '@testkullanici');

      _acikSunucu(_acikProfilGovde(ad: 'Ortak Ad'));
      await _kur(tester, const KullaniciProfilEkrani(kullaniciAdi: 'baskasi'));
      final acikAd = _kimlikStil(tester, 'Ortak Ad');
      final acikKadi = _kimlikStil(tester, '@baskasi');

      for (final (etiket, a, b) in [
        ('ad punto', kendiAd.fontSize, acikAd.fontSize),
        ('ad kalınlık', kendiAd.fontWeight, acikAd.fontWeight),
        ('ad renk', kendiAd.color, acikAd.color),
        ('kadi punto', kendiKadi.fontSize, acikKadi.fontSize),
        ('kadi kalınlık', kendiKadi.fontWeight, acikKadi.fontWeight),
        ('kadi renk', kendiKadi.color, acikKadi.color),
      ]) {
        expect(a, b, reason: '$etiket iki ekranda AYNI olmalı');
      }
    });
  });
}
