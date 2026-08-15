// "YAKINDA GELECEK" MODU — sunucu bayrağı kapalıyken düğmeler DURUR.
//
// Kullanıcı kararı (13 Ağu 2026, aynen): "sesli ve görüntülü aramayı şu an
// herkeste devre dışı bırakalım, üstüne tıkladıklarında 'yakında gelecek'
// yazsın."
//
// Sunucu tarafı: `/opt/dizijpg/.env` → `ARAMA_KAPALI=kapali` +
// `ARAMA_GORUNTULU=kapali`, yani `GET /arama/buz-sunuculari` artık
// `arama_acik:false` döndürüyor.
//
// ÖNCESİNDE bayrak kapalıyken düğmeler HİÇ ÇİZİLMİYORDU
// (`AramaServisi.kullanilabilir == false`). Şimdi çiziliyor ama:
//   * PASİF görünüyor (md. 38'deki kalıbın aynısı — soluk ikon),
//   * dokununca "Yakında gelecek" SnackBar'ı çıkıyor,
//   * *** HİÇBİR AĞ İSTEĞİ ATILMIYOR ***: ne arama başlatma, ne karşılıklı
//     takip sorgusu, ne de 4 sn'lik gelen arama yoklaması. Gelmesi imkânsız
//     bir arama için tur harcamak, bu turun asıl tuzağıydı.
//
// `kullanilabilir` SEMANTİĞİ KORUNDU: o hâlâ "gerçekten arayabilir miyim"in
// cevabı ve yoklamayı da o tetikliyor. Yeni durum ayrı bir alan:
// `AramaServisi.yakindaModu`.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/gorusme/arama_dugmeleri.dart';
import 'package:dizijpg/gorusme/arama_servisi.dart';
import 'package:dizijpg/gorusme/gorusme_api.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// SAHTE İSTEMCİ: her isteği sayar. "Hiçbir istek atılmadı" iddiası ancak
/// böyle KANITLANIR — gözle koda bakmak bu turda yasak (CLAUDE.md md. 7).
int _istekSayisi = 0;
final List<String> _yollar = [];

void _sunucu() {
  _istekSayisi = 0;
  _yollar.clear();
  Api.istemci = MockClient((istek) async {
    _istekSayisi++;
    _yollar.add(istek.url.path);
    final yol = istek.url.path;
    if (yol.contains('/profil/')) {
      return _json({
        'kullanici_adi': 'alcelik',
        'ben_mi': false,
        'engelledim': false,
        'takip_ediyorum': true,
        'misafir': false,
      });
    }
    if (yol.contains('/takipedilenler/')) {
      return _json({
        'kullanicilar': [
          {'kullanici_adi': 'ben'},
        ],
      });
    }
    return _json(<String, dynamic>{});
  });
}

BuzAyari _buz({
  bool aramaAcik = true,
  bool goruntuluAcik = true,
  bool misafir = false,
}) => BuzAyari(
  sunucular: const [],
  gecerlilikSn: 43200,
  aramaAcik: aramaAcik,
  goruntuluAcik: goruntuluAcik,
  // Kendi tercihlerim AÇIK: ölçtüğümüz şey SUNUCU bayrağı, md. 38 değil.
  kendiSesliAcik: true,
  kendiGoruntuluAcik: true,
  misafir: misafir,
  calmaSaniye: 45,
  alindi: DateTime.now(),
);

/// Canlıdaki bayrak durumu: `ARAMA_KAPALI=kapali` + `ARAMA_GORUNTULU=kapali`.
BuzAyari _kapali() => _buz(aramaAcik: false, goruntuluAcik: false);

Color _ikonRengi(WidgetTester t, String anahtar) => t
    .widget<Icon>(
      find.descendant(
        of: find.byKey(Key(anahtar)),
        matching: find.byType(Icon),
      ),
    )
    .color!;

/// Gerçek `GoRouter`lı sarmalayıcı: arama düğmesi `/gorusme/:ad`e ITER, yani
/// "arama başladı mı" sorusu ancak yönlendiriciyle ölçülebilir.
String? sonYol;

Widget _sar(Widget cocuk) {
  sonYol = null;
  final oturum = Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'};
  final yonlendirici = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(appBar: AppBar(actions: [cocuk])),
      ),
      GoRoute(
        path: '/gorusme/:ad',
        builder: (_, d) {
          sonYol = d.uri.toString();
          return const Scaffold(body: Text('gorusme'));
        },
      ),
      GoRoute(
        path: '/ayarlar',
        builder: (_, _) {
          sonYol = '/ayarlar';
          return const Scaffold(body: Text('ayarlar'));
        },
      ),
    ],
  );
  return ChangeNotifierProvider<Oturum>.value(
    value: oturum,
    child: MaterialApp.router(
      theme: diziTema(acik: false),
      routerConfig: yonlendirici,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'token': 't'});
    await Api.tokenYukle();
    AramaServisi.karsilikliOnbellegiTemizle();
    AramaServisi.webMi = false;
    _sunucu();
  });

  tearDown(() {
    AramaServisi.gelenYoklamaDur();
    AramaServisi.aktifAramaId = null;
    AramaServisi.webMi = false;
    AramaServisi.ayariKur(null);
  });

  // -------------------------------------------------------------------------
  group('1. yakindaModu koşulu', () {
    test('SUNUCU BAYRAĞI KAPALI + mobil + kayıtlı hesap -> AÇIK', () {
      AramaServisi.ayariKur(_kapali());
      expect(AramaServisi.yakindaModu, isTrue);
      // `kullanilabilir` SEMANTİĞİ BOZULMADI: hâlâ "gerçekten arayabilir
      // miyim" demek ve hâlâ false.
      expect(AramaServisi.kullanilabilir, isFalse);
      expect(AramaServisi.goruntuluAcik, isFalse);
    });

    test('BAYRAK AÇIKKEN yakindaModu KAPALI (iki mod aynı anda olmaz)', () {
      AramaServisi.ayariKur(_buz());
      expect(AramaServisi.yakindaModu, isFalse);
      expect(AramaServisi.kullanilabilir, isTrue);
    });

    test('WEB: bayrak kapalı olsa da yakindaModu KAPALI', () {
      // Web'de özellik "yakında" değil, HİÇ gelmeyecek (arama_servisi.dart
      // başlığındaki web kararı). Tutulamayacak söz verilmez.
      AramaServisi.webMi = true;
      AramaServisi.ayariKur(_kapali());
      expect(AramaServisi.yakindaModu, isFalse);
    });

    test('MİSAFİR: bayrak kapalı olsa da yakindaModu KAPALI', () {
      AramaServisi.ayariKur(_buz(aramaAcik: false, misafir: true));
      expect(AramaServisi.yakindaModu, isFalse);
    });

    test('BAYRAK HİÇ ALINMAMIŞ (ağ yok): yakindaModu KAPALI', () {
      // `_buz == null` iken kapalı olduğunu BİLMİYORUZ. Bilmediğimiz bir şeyi
      // duyurmak yanlış olur.
      AramaServisi.ayariKur(null);
      expect(AramaServisi.yakindaModu, isFalse);
      expect(AramaServisi.kullanilabilir, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('2. düğmeler ÇİZİLİYOR ve PASİF', () {
    testWidgets('(a) bayrak kapalıyken İKİ DÜĞME DE görünür', (t) async {
      AramaServisi.ayariKur(_kapali());
      await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
      await t.pumpAndSettle();

      expect(
        find.byKey(const Key('sohbet-sesli-ara')),
        findsOneWidget,
        reason: 'bayrak kapalıyken düğme gizleniyordu — istek tam tersi',
      );
      expect(find.byKey(const Key('sohbet-goruntulu-ara')), findsOneWidget);
    });

    testWidgets('düğmeler PASİF görünür (aktif hâlden farklı renk)', (t) async {
      AramaServisi.ayariKur(_kapali());
      await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
      await t.pumpAndSettle();
      final pasif = _ikonRengi(t, 'sohbet-sesli-ara');
      expect(pasif, DiziRenkler.metin);
      expect(pasif, isNot(DiziRenkler.sariMetin));
    });

    testWidgets('pasif düğme DOKUNUŞU ALIR ve hedefi >= 44 dp', (t) async {
      // `IconButton(onPressed: null)` dokunuşu hiç almaz; o zaman "Yakında
      // gelecek" hiç gösterilemezdi.
      AramaServisi.ayariKur(_kapali());
      await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
      await t.pumpAndSettle();

      for (final anahtar in ['sohbet-sesli-ara', 'sohbet-goruntulu-ara']) {
        final f = find.byKey(Key(anahtar));
        expect(t.widget<IconButton>(f).onPressed, isNotNull, reason: anahtar);
        final boyut = t.getSize(f);
        expect(boyut.width, greaterThanOrEqualTo(44), reason: anahtar);
        expect(boyut.height, greaterThanOrEqualTo(44), reason: anahtar);
      }
    });

    testWidgets('tooltip SEBEBİ söyler (ekran okuyucuya tek ipucu)', (t) async {
      AramaServisi.ayariKur(_kapali());
      await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
      await t.pumpAndSettle();

      for (final anahtar in ['sohbet-sesli-ara', 'sohbet-goruntulu-ara']) {
        final dugme = t.widget<IconButton>(find.byKey(Key(anahtar)));
        expect(dugme.tooltip, 'Yakında gelecek', reason: anahtar);
      }
    });
  });

  // -------------------------------------------------------------------------
  group('3. dokunuş: "Yakında gelecek" + SIFIR istek', () {
    testWidgets('(b) SESLİ düğmesi: SnackBar çıkar, ARAMA BAŞLAMAZ', (t) async {
      AramaServisi.ayariKur(_kapali());
      await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('sohbet-sesli-ara')));
      await t.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Yakında gelecek'), findsOneWidget);
      // Eski (md. 38) metni SIZMAMALI: burada açılacak bir anahtar yok.
      expect(find.textContaining('Ayarlar > Gizlilik'), findsNothing);
      expect(find.byType(SnackBarAction), findsNothing);
      // *** ARAMA EKRANI AÇILMADI ***
      expect(sonYol, isNull, reason: 'pasif düğme arama ekranına gitti');
    });

    testWidgets('(b) GÖRÜNTÜLÜ düğmesi de aynı metni verir', (t) async {
      AramaServisi.ayariKur(_kapali());
      await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('sohbet-goruntulu-ara')));
      await t.pump();

      expect(find.text('Yakında gelecek'), findsOneWidget);
      expect(find.textContaining('Görüntülü arama kapalı'), findsNothing);
      expect(sonYol, isNull);
    });

    testWidgets('(b) *** HİÇBİR AĞ İSTEĞİ ATILMIYOR ***', (t) async {
      AramaServisi.ayariKur(_kapali());
      await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
      await t.pumpAndSettle();

      // Sohbet açılışında karşılıklı takip sorgusu bile atılmamalı: özellik
      // kimsede açık değil, cevabı düğmenin davranışını değiştirmiyor.
      expect(
        _istekSayisi,
        0,
        reason: 'çizim için boşuna istek atıldı: $_yollar',
      );

      await t.tap(find.byKey(const Key('sohbet-sesli-ara')));
      await t.pump();
      await t.tap(find.byKey(const Key('sohbet-goruntulu-ara')));
      await t.pump();

      expect(
        _istekSayisi,
        0,
        reason: 'dokunuş ağa çıktı (arama denendi): $_yollar',
      );
    });

    testWidgets('gelen arama YOKLAMASI bu modda tur HARCAMAZ', (t) async {
      AramaServisi.ayariKur(_kapali());
      AramaServisi.gelenAramaGeldi = (_) {};
      AramaServisi.gelenYoklamaBaslat();
      // Sahte zaman ekseninde 3 tur ilerlet.
      await t.pump(AramaServisi.gelenYoklamaAraligi * 3);
      AramaServisi.gelenYoklamaDur();

      expect(
        _istekSayisi,
        0,
        reason: 'gelmesi imkânsız arama için yoklama turu harcandı: $_yollar',
      );
    });
  });

  // -------------------------------------------------------------------------
  group('4. GERİLEME — bayrak AÇIKKEN eski davranış aynen', () {
    testWidgets('(c) karşılıklı takipte düğmeler AKTİF ve ARAMA BAŞLIYOR', (
      t,
    ) async {
      AramaServisi.ayariKur(_buz());
      await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('sohbet-sesli-ara')), findsOneWidget);
      expect(_ikonRengi(t, 'sohbet-sesli-ara'), DiziRenkler.sariMetin);
      // Karşılıklı takip sorgusu eskisi gibi ATILIYOR.
      expect(_istekSayisi, greaterThanOrEqualTo(1));

      await t.tap(find.byKey(const Key('sohbet-sesli-ara')));
      await t.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(sonYol, '/gorusme/alcelik?tur=ses');
    });

    testWidgets('(c) GÖRÜNTÜLÜ de eskisi gibi arama ekranına götürür', (
      t,
    ) async {
      AramaServisi.ayariKur(_buz());
      await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('sohbet-goruntulu-ara')));
      await t.pumpAndSettle();
      expect(sonYol, '/gorusme/alcelik?tur=goruntu');
    });

    testWidgets('(c) bayrak açık + KARŞILIKLI TAKİP YOK: düğme yine YOK', (
      t,
    ) async {
      AramaServisi.ayariKur(_buz());
      Api.istemci = MockClient((istek) async {
        _istekSayisi++;
        return _json({
          'kullanici_adi': 'alcelik',
          'ben_mi': false,
          'engelledim': false,
          'takip_ediyorum': false,
        });
      });
      await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('sohbet-sesli-ara')), findsNothing);
    });

    testWidgets('(c) yalnız GÖRÜNTÜLÜ bayrağı kapalıyken davranış değişmedi', (
      t,
    ) async {
      // Sesli açık + görüntülü kapalı = yakindaModu DEĞİL: sesli düğmesi
      // aktif, görüntülü düğmesi hiç çizilmez (eski kural).
      AramaServisi.ayariKur(_buz(goruntuluAcik: false));
      await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('sohbet-sesli-ara')), findsOneWidget);
      expect(find.byKey(const Key('sohbet-goruntulu-ara')), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  group('5. (d) web ve misafir kararları DEĞİŞMEDİ', () {
    testWidgets('WEB: bayrak kapalıyken de düğme YOK', (t) async {
      AramaServisi.webMi = true;
      AramaServisi.ayariKur(_kapali());
      await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('sohbet-sesli-ara')), findsNothing);
      expect(find.byKey(const Key('sohbet-goruntulu-ara')), findsNothing);
      expect(_istekSayisi, 0);
    });

    testWidgets('MİSAFİR: bayrak kapalıyken de düğme YOK', (t) async {
      AramaServisi.ayariKur(_buz(aramaAcik: false, misafir: true));
      await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('sohbet-sesli-ara')), findsNothing);
      expect(find.byKey(const Key('sohbet-goruntulu-ara')), findsNothing);
      expect(_istekSayisi, 0);
    });

    testWidgets('WEB + bayrak AÇIK: eski web kararı yerinde', (t) async {
      AramaServisi.webMi = true;
      AramaServisi.ayariKur(_buz());
      await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('sohbet-sesli-ara')), findsNothing);
    });
  });
}
