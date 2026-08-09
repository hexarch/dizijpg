// SOHBETTEKİ ARAMA DÜĞMELERİ.
//
// Kilitlenen davranışlar:
//   * düğme YALNIZ karşılıklı takipleşmede çizilir (sunucu zaten zorluyor ama
//     tıklanabilir görünüp reddedilen düğme kötü deneyimdir),
//   * ben onu takip etmiyorsam İKİNCİ İSTEK HİÇ ATILMAZ (karşılıklı olamaz),
//   * `goruntulu_acik:false` ise yalnız görüntülü düğmesi gizlenir,
//   * `arama_acik:false` ya da web ise ikisi de gizlenir,
//   * dokunma hedefleri >= 44 dp.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/gorusme/arama_dugmeleri.dart';
import 'package:dizijpg/gorusme/arama_servisi.dart';
import 'package:dizijpg/gorusme/gorusme_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

int _takipEdilenlerCagrisi = 0;

void _sunucu({required bool takipEdiyorum, required bool geriTakip}) {
  _takipEdilenlerCagrisi = 0;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.contains('/profil/')) {
      return _json({
        'kullanici_adi': 'alcelik',
        'ben_mi': false,
        'engelledim': false,
        'takip_ediyorum': takipEdiyorum,
      });
    }
    if (yol.contains('/takipedilenler/')) {
      _takipEdilenlerCagrisi++;
      return _json({
        'kullanicilar': [
          {'kullanici_adi': 'baskasi'},
          if (geriTakip) {'kullanici_adi': 'ben'},
        ],
      });
    }
    return _json({'hata': 'beklenmeyen: $yol'}, 500);
  });
}

BuzAyari _buz({bool aramaAcik = true, bool goruntuluAcik = true}) => BuzAyari(
  sunucular: const [],
  gecerlilikSn: 43200,
  aramaAcik: aramaAcik,
  goruntuluAcik: goruntuluAcik,
  calmaSaniye: 45,
  alindi: DateTime.now(),
);

Widget _sar(Widget cocuk) {
  final oturum = Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'};
  return ChangeNotifierProvider<Oturum>.value(
    value: oturum,
    child: MaterialApp(
      home: Scaffold(appBar: AppBar(actions: [cocuk])),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'token': 't'});
    AramaServisi.karsilikliOnbellegiTemizle();
    AramaServisi.webMi = false;
    AramaServisi.ayariKur(_buz());
  });

  tearDown(() => AramaServisi.ayariKur(null));

  testWidgets('KARŞILIKLI TAKİP: iki düğme de görünür', (t) async {
    _sunucu(takipEdiyorum: true, geriTakip: true);
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sohbet-sesli-ara')), findsOneWidget);
    expect(find.byKey(const Key('sohbet-goruntulu-ara')), findsOneWidget);
  });

  testWidgets('TEK YÖNLÜ TAKİP (o beni takip etmiyor): düğme YOK', (t) async {
    _sunucu(takipEdiyorum: true, geriTakip: false);
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sohbet-sesli-ara')), findsNothing);
    expect(find.byKey(const Key('sohbet-goruntulu-ara')), findsNothing);
  });

  testWidgets('BEN TAKİP ETMİYORSAM ikinci istek HİÇ atılmaz', (t) async {
    _sunucu(takipEdiyorum: false, geriTakip: true);
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sohbet-sesli-ara')), findsNothing);
    expect(
      _takipEdilenlerCagrisi,
      0,
      reason: 'karşılıklı olamayacağı kesinken ikinci tur harcanmamalı',
    );
  });

  testWidgets('GÖRÜNTÜLÜ KILL SWITCH kapalı: yalnız sesli düğmesi', (t) async {
    AramaServisi.ayariKur(_buz(goruntuluAcik: false));
    _sunucu(takipEdiyorum: true, geriTakip: true);
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sohbet-sesli-ara')), findsOneWidget);
    expect(find.byKey(const Key('sohbet-goruntulu-ara')), findsNothing);
  });

  testWidgets('ARAMA KILL SWITCH kapalı: hiçbir düğme yok', (t) async {
    AramaServisi.ayariKur(_buz(aramaAcik: false));
    _sunucu(takipEdiyorum: true, geriTakip: true);
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sohbet-sesli-ara')), findsNothing);
  });

  testWidgets('WEB: arama düğmeleri hiç çizilmez', (t) async {
    // `flutter test` DAİMA VM'de koşar (kIsWeb == false). Web dalı `kIsWeb`
    // ile koda gömülü olsaydı bu test onu HİÇ göremezdi — bu yüzden
    // AramaServisi.webMi ayrı bir alan (bkz. arama_servisi.dart başlığı).
    AramaServisi.webMi = true;
    _sunucu(takipEdiyorum: true, geriTakip: true);
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sohbet-sesli-ara')), findsNothing);
    expect(find.byKey(const Key('sohbet-goruntulu-ara')), findsNothing);
    AramaServisi.webMi = false;
  });

  testWidgets('AĞ HATASINDA düğme gizlenmez (sunucu son sözü söyler)', (
    t,
  ) async {
    Api.istemci = MockClient((_) async => _json({'hata': 'patladı'}, 500));
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sohbet-sesli-ara')), findsOneWidget);
  });

  testWidgets('DOKUNMA HEDEFLERİ >= 44 dp', (t) async {
    _sunucu(takipEdiyorum: true, geriTakip: true);
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    for (final anahtar in ['sohbet-sesli-ara', 'sohbet-goruntulu-ara']) {
      final boyut = t.getSize(find.byKey(Key(anahtar)));
      expect(boyut.width, greaterThanOrEqualTo(44), reason: anahtar);
      expect(boyut.height, greaterThanOrEqualTo(44), reason: anahtar);
    }
  });

  testWidgets('düğmelerin ERİŞİLEBİLİRLİK etiketi var (ikon-tek değil)', (
    t,
  ) async {
    _sunucu(takipEdiyorum: true, geriTakip: true);
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    final sesli = t.widget<IconButton>(
      find.byKey(const Key('sohbet-sesli-ara')),
    );
    expect(sesli.tooltip, isNotNull);
    expect(sesli.tooltip, isNotEmpty);
  });

  test('önbellek: aynı kullanıcı için ikinci sorgu ağa çıkmaz', () async {
    AramaServisi.karsilikliOnbellegiTemizle();
    _sunucu(takipEdiyorum: true, geriTakip: true);
    expect(await AramaServisi.karsilikliTakipMi('alcelik', 'ben'), isTrue);
    final ilk = _takipEdilenlerCagrisi;
    expect(await AramaServisi.karsilikliTakipMi('alcelik', 'ben'), isTrue);
    expect(_takipEdilenlerCagrisi, ilk);
  });

  test('oturum yoksa karşılıklı takip SORULMAZ', () async {
    AramaServisi.karsilikliOnbellegiTemizle();
    _sunucu(takipEdiyorum: true, geriTakip: true);
    expect(await AramaServisi.karsilikliTakipMi('alcelik', null), isFalse);
  });
}
