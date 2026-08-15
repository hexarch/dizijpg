// SOHBETTEKİ ARAMA DÜĞMELERİ.
//
// Kilitlenen davranışlar:
//   * düğme YALNIZ karşılıklı takipleşmede çizilir (sunucu zaten zorluyor ama
//     tıklanabilir görünüp reddedilen düğme kötü deneyimdir),
//   * ben onu takip etmiyorsam İKİNCİ İSTEK HİÇ ATILMAZ (karşılıklı olamaz),
//   * `goruntulu_acik:false` ise yalnız görüntülü düğmesi gizlenir,
//   * web ise ikisi de gizlenir,
//   * `arama_acik:false` (kill switch) ise düğmeler ARTIK GİZLENMİYOR: pasif
//     çizilip "Yakında gelecek" diyorlar — kullanıcı kararı 13 Ağu. O modun
//     bütün kilitleri `test/arama_yakinda_test.dart`ta.
//   * dokunma hedefleri >= 44 dp,
//   * md. 38: KENDİ tercihim kapalıysa düğme GİZLENMEZ, PASİF görünür ve
//     tıklanınca nereden açılacağını söyleyen bir açıklama çıkar.
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

// `kendi*` VARSAYILANI true: bu yardımcının çoğu çağrısı md. 38 ÖNCESİNDEN
// kalma testlerde ve orada ölçülen şey düğmenin AKTİF hâli. Gerçek sunucu
// varsayılanı KAPALI'dır ve onu ayrı testler ölçüyor.
BuzAyari _buz({
  bool aramaAcik = true,
  bool goruntuluAcik = true,
  bool kendiSesli = true,
  bool kendiGoruntulu = true,
}) => BuzAyari(
  sunucular: const [],
  gecerlilikSn: 43200,
  aramaAcik: aramaAcik,
  goruntuluAcik: goruntuluAcik,
  kendiSesliAcik: kendiSesli,
  kendiGoruntuluAcik: kendiGoruntulu,
  calmaSaniye: 45,
  alindi: DateTime.now(),
);

/// Düğmenin ikon rengi — pasiflik GÖRSEL olarak buradan ölçülüyor.
Color _ikonRengi(WidgetTester t, String anahtar) => t
    .widget<Icon>(
      find.descendant(
        of: find.byKey(Key(anahtar)),
        matching: find.byType(Icon),
      ),
    )
    .color!;

Widget _sar(Widget cocuk) {
  final oturum = Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'};
  return ChangeNotifierProvider<Oturum>.value(
    value: oturum,
    child: MaterialApp(
      home: Scaffold(appBar: AppBar(actions: [cocuk])),
    ),
  );
}

/// Yönlendiricili sarmalayıcı — pasif düğmenin "Ayarlar" kısayolu GERÇEK bir
/// `GoRouter` ister. Üretimde daima vardır; [_sar] onsuz olduğu için md. 38
/// testleri bunu kullanıyor.
String? sonGidilenYol;

Widget _sarYonlendirmeli(Widget cocuk) {
  sonGidilenYol = null;
  final oturum = Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'};
  final yonlendirici = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(appBar: AppBar(actions: [cocuk])),
      ),
      GoRoute(
        path: '/ayarlar',
        builder: (_, _) {
          sonGidilenYol = '/ayarlar';
          return const Scaffold(body: Text('ayarlar'));
        },
      ),
    ],
  );
  return ChangeNotifierProvider<Oturum>.value(
    value: oturum,
    child: MaterialApp.router(routerConfig: yonlendirici),
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

  testWidgets('ARAMA KILL SWITCH kapalı: düğmeler PASİF (gizli DEĞİL)', (
    t,
  ) async {
    // 13 Ağu'ya kadar burada `findsNothing` yazıyordu. Kullanıcı kararı
    // değişti: bayrak kapalıyken düğmeler görünsün ve dokununca "Yakında
    // gelecek" desin. Arama YİNE BAŞLAMIYOR — `kullanilabilir` hâlâ false.
    AramaServisi.ayariKur(_buz(aramaAcik: false));
    _sunucu(takipEdiyorum: true, geriTakip: true);
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sohbet-sesli-ara')), findsOneWidget);
    expect(AramaServisi.kullanilabilir, isFalse);
    expect(AramaServisi.yakindaModu, isTrue);
    expect(_ikonRengi(t, 'sohbet-sesli-ara'), DiziRenkler.metin);
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

  // ==========================================================================
  // md. 38 — KENDİ TERCİHİM KAPALIYKEN: PASİF, GİZLİ DEĞİL
  // ==========================================================================
  // Kullanıcının kendi cümlesi (10 Ağu): "kullanıcıda sohbet ekranında PASİF
  // gözükmeli bu buttonlar üstüne tıklayınca nereden aktif edeceğini söyle."
  //
  // Gizlemek YANLIŞ olurdu: varsayılan KAPALI olduğu için özelliği kimse
  // görmez ve kimse açmaz. Pasif düğme + açıklaması tanıtımın kendisidir.

  testWidgets('md.38 KENDİ SESLİ KAPALI: düğme DURUYOR ama PASİF', (t) async {
    AramaServisi.ayariKur(_buz(kendiSesli: false));
    _sunucu(takipEdiyorum: true, geriTakip: true);
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    expect(
      find.byKey(const Key('sohbet-sesli-ara')),
      findsOneWidget,
      reason: 'kendi tercihi kapalıyken düğme GİZLENMEMELİ',
    );
    // Pasiflik görsel: kapalı = tema metni, açık = marka sarısı (gri yok).
    final kapali = _ikonRengi(t, 'sohbet-sesli-ara');

    AramaServisi.ayariKur(_buz());
    await t.pumpAndSettle();
    final acik = _ikonRengi(t, 'sohbet-sesli-ara');
    expect(
      kapali,
      isNot(acik),
      reason: 'pasif düğme aktif düğmeyle aynı görünüyor',
    );
  });

  testWidgets('md.38 PASİF DÜĞME TIKLANABİLİR ve NEREDEN AÇILACAĞINI söyler', (
    t,
  ) async {
    AramaServisi.ayariKur(_buz(kendiSesli: false));
    _sunucu(takipEdiyorum: true, geriTakip: true);
    await t.pumpWidget(
      _sarYonlendirmeli(const AramaDugmeleri(kullaniciAdi: 'alcelik')),
    );
    await t.pumpAndSettle();

    // `IconButton(onPressed: null)` DOKUNUŞU HİÇ ALMAZ — o yüzden pasiflik
    // yalnız görseldir. Bu satır o tuzağı kilitliyor.
    final dugme = t.widget<IconButton>(
      find.byKey(const Key('sohbet-sesli-ara')),
    );
    expect(dugme.onPressed, isNotNull, reason: 'pasif düğme dokunuşu almıyor');

    await t.tap(find.byKey(const Key('sohbet-sesli-ara')));
    await t.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.textContaining('Ayarlar'),
      findsWidgets,
      reason: 'açıklama nereden açılacağını söylemeli',
    );
    // Kurtarma yolu: doğrudan ayarlara GÖTÜREN bir eylem olmalı — etiketi
    // olup bir yere gitmeyen düğme, hata mesajından daha kötüdür.
    expect(find.byType(SnackBarAction), findsOneWidget);
    // SnackBar aşağıdan kayarak giriyor; giriş animasyonu bitmeden eylem
    // düğmesi ekranın DIŞINDA kalır ve dokunuş ıskalanır.
    await t.pump(const Duration(milliseconds: 750));
    await t.tap(find.byType(SnackBarAction));
    await t.pumpAndSettle();
    expect(sonGidilenYol, '/ayarlar');
  });

  testWidgets('md.38 TÜR BAZLI: sesli açık + görüntülü kapalı', (t) async {
    AramaServisi.ayariKur(_buz(kendiGoruntulu: false));
    _sunucu(takipEdiyorum: true, geriTakip: true);
    await t.pumpWidget(
      _sarYonlendirmeli(const AramaDugmeleri(kullaniciAdi: 'alcelik')),
    );
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sohbet-goruntulu-ara')), findsOneWidget);
    expect(
      _ikonRengi(t, 'sohbet-sesli-ara'),
      isNot(_ikonRengi(t, 'sohbet-goruntulu-ara')),
      reason: 'biri açık biri kapalıyken ikisi aynı görünüyor',
    );

    // Görüntülü düğmesine dokununca GÖRÜNTÜLÜ metni çıkmalı, sesli değil.
    await t.tap(find.byKey(const Key('sohbet-goruntulu-ara')));
    await t.pump();
    expect(find.textContaining('Görüntülü arama kapalı'), findsOneWidget);
    expect(find.textContaining('Sesli arama kapalı'), findsNothing);
  });

  testWidgets('md.38 PASİF düğmenin dokunma hedefi de >= 44 dp', (t) async {
    // Küçültülseydi açıklamayı okumak isteyen kullanıcı düğmeyi ıskalardı.
    AramaServisi.ayariKur(_buz(kendiSesli: false, kendiGoruntulu: false));
    _sunucu(takipEdiyorum: true, geriTakip: true);
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    for (final anahtar in ['sohbet-sesli-ara', 'sohbet-goruntulu-ara']) {
      final boyut = t.getSize(find.byKey(Key(anahtar)));
      expect(boyut.width, greaterThanOrEqualTo(44), reason: anahtar);
      expect(boyut.height, greaterThanOrEqualTo(44), reason: anahtar);
    }
  });

  testWidgets('md.38 PASİF düğmenin tooltip-i SEBEBİ söyler (ekran okuyucu)', (
    t,
  ) async {
    // Renk farkı sesli okunmaz. "Sesli ara" deseydik kullanıcı basar ve neden
    // çalışmadığını anlamazdı.
    AramaServisi.ayariKur(_buz(kendiSesli: false));
    _sunucu(takipEdiyorum: true, geriTakip: true);
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    final dugme = t.widget<IconButton>(
      find.byKey(const Key('sohbet-sesli-ara')),
    );
    expect(dugme.tooltip, contains('kapalı'));
  });

  testWidgets('md.38 SUNUCU BAYRAĞI ile KENDİ TERCİHİ farklı davranır', (
    t,
  ) async {
    // Sunucu bayrağı kapalı = özellik YOK -> düğme HİÇ çizilmez.
    // Kendi tercihim kapalı = özellik VAR, ben kapatmışım -> pasif çizilir.
    AramaServisi.ayariKur(_buz(goruntuluAcik: false));
    _sunucu(takipEdiyorum: true, geriTakip: true);
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('sohbet-goruntulu-ara')), findsNothing);

    AramaServisi.ayariKur(_buz(kendiGoruntulu: false));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('sohbet-goruntulu-ara')), findsOneWidget);
  });

  test('md.38 kendiTercihiKur bellekteki kopyayı günceller ve haber verir', () {
    AramaServisi.ayariKur(_buz(kendiSesli: false, kendiGoruntulu: false));
    final oncekiSurum = AramaServisi.surum.value;
    expect(AramaServisi.kendiSesliAcik, isFalse);

    AramaServisi.kendiTercihiKur(sesli: true);
    expect(AramaServisi.kendiSesliAcik, isTrue);
    expect(
      AramaServisi.kendiGoruntuluAcik,
      isFalse,
      reason: 'tek anahtar çevrilince öteki de değişmemeli',
    );
    expect(
      AramaServisi.surum.value,
      greaterThan(oncekiSurum),
      reason: 'düğmeler yeniden çizilmezse anahtar ölü görünür',
    );
  });

  test('md.38 kendiTercihiKur TURN kimliğini ve tazelik saatini KORUR', () {
    // Her anahtar dokunuşu `alindi`yi bugüne çekseydi bayat kimlikle arama
    // başlatma riski geri gelirdi (sözleşme §3.3).
    final eski = DateTime.now().subtract(
      const Duration(hours: 11, minutes: 30),
    );
    AramaServisi.ayariKur(
      BuzAyari(
        sunucular: const [
          {'urls': 'stun:turn.dizijpg.com:3478'},
        ],
        gecerlilikSn: 43200,
        aramaAcik: true,
        goruntuluAcik: true,
        calmaSaniye: 45,
        alindi: eski,
      ),
    );
    AramaServisi.kendiTercihiKur(sesli: true);
    expect(AramaServisi.kendiSesliAcik, isTrue);
    // Hâlâ tazelenmesi gerekiyor olmalı — `alindi` sıfırlanmadı.
    expect(AramaServisi.calmaSaniye, 45);
  });

  test('md.38 BuzAyari.json: alan yoksa KAPALI kabul edilir', () {
    // Eski bir sunucudan yanıt gelirse düğmeler pasif görünür (kullanıcı
    // sebebini okur); tersi olsaydı aktif görünüp 403 yerdi.
    final b = BuzAyari.json(const {
      'buz_sunuculari': [],
      'gecerlilik_sn': 43200,
      'arama_acik': true,
      'goruntulu_acik': true,
      'calma_saniye': 45,
    });
    expect(b.kendiSesliAcik, isFalse);
    expect(b.kendiGoruntuluAcik, isFalse);

    final c = BuzAyari.json(const {
      'buz_sunuculari': [],
      'gecerlilik_sn': 43200,
      'arama_acik': true,
      'goruntulu_acik': true,
      'kendi_sesli_acik': true,
      'kendi_goruntulu_acik': true,
      'calma_saniye': 45,
    });
    expect(c.kendiSesliAcik, isTrue);
    expect(c.kendiGoruntuluAcik, isTrue);
  });
}
