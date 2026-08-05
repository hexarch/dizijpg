import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/etiket.dart' show EtiketliMetin;
import 'package:dizijpg/ekranlar/ortak.dart' show AkisMedya;
import 'package:dizijpg/ekranlar/yorumlar.dart' show BolumRozeti;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// MEDYA DİZİ ADINA DAYANDI — 4 Ağu'daki YANLIŞ ANLAŞILMIŞ düzeltme geri
/// alındı (kullanıcı, 5 Ağu 2026):
///   "sen gidip dizi film kapağını aşağı çekmişsin, tam tersi olmalıydı.
///    görsel veya videoyu yukarı çekip dizi adına dayaman gerekiyordu"
///
/// 4 AĞU'DA NE YAPILMIŞTI: kapak `Stack` + `Positioned(bottom: 0)` ile başlığın
/// ALT kenarına yaslanmış (eskiden Row onu DİKEY ORTALIYORDU), ayırıcı 6 → 4 dp
/// olmuştu. Kapak ile medya arası 22 → 4 dp indi ama İÇERİK ADI ile medya arası
/// 31 → 29 dp'de takıldı: kapak aşağı inmişti, medya yukarı ÇIKMAMIŞTI.
///
/// ŞİMDİ: kapak yine satırın içinde ve DİKEY ORTALI; medyayı yukarı çeken şey
/// başlığın SON satırının kısalmasıdır (içerik adının dokunma kutusu 44 → 24
/// dp, rozet de aynı kutuya indi).
///
/// ÜÇ İSTEK AYNI ANDA SAĞLANAMAZDI — ölçülmüş çakışma:
///   başlık = kullanıcı adı satırı (44/48 dp) + içerik adı satırı.
///   İçerik adının metni 19 dp; kutusu 44 dp ve metin ÜSTE yaslı olduğu için
///   metnin ALTINDA 25 dp dokunulabilir ama BOŞ görünen pay kalıyordu.
///   • Kutuyu 44'te tutup metni kutunun ALTINA yaslamak → kullanıcı adı ile
///     içerik adı arası 11,5 → 36,5 dp olurdu (3 Ağu'da kullanıcı bunu
///     yarıya indirtmişti; bozulurdu).
///   • Kutuyu 44'te tutup medyanın ÜSTÜNE bindirmek → medyanın sol üst
///     şeridindeki dokunuş yutulur, Reels yerine içerik sayfası açılırdı
///     (hit-test tuzağı). "medyanın üst şeridi MEDYANINDIR" testi bunun
///     yapılmadığını kanıtlar.
///   • Kalan tek yol kutuyu kısaltmaktı: 44 (WCAG SC 2.5.5 AAA) yerine
///     24 dp (WCAG 2.2 SC 2.5.8 AA normatif tabanı). Kutu ALÇALDI ama
///     genişliği 44 dp'nin üstünde kaldı ve aynı sayfaya giden 50x60 dp'lik
///     kapak posteri "eşdeğer hedef" olarak duruyor (SC 2.5.8 istisnası).
///     Aşağıdaki "erişilebilirlik bedeli" grubu bunların hepsini ölçer.
///
/// ÖLÇÜM (400 dp ekran, deneme yazı tipi):
///   içerik adı ↔ medya : 29,0 → 9,0 dp   (asıl hedef)
///   kapak ↔ medya      : 4,0 → 10,0 dp   (kapak ortaya döndüğü için ARTTI;
///                                          4 Ağu ÖNCESİ 22,0 dp idi)
///   kullanıcı adı ↔ içerik adı : 13,5 dp — DEĞİŞMEDİ
const double _oncekiAdBosluk = 29.0;
const double _yeniAdBosluk = 9.0;

/// Kapak ↔ medya: kapak dikey ortaya döndüğü için 4 → 10 dp (düğmesiz kartta
/// 8 dp). Yine de 4 Ağu ÖNCESİNDEN (22 / 20 dp) çok daha dar: başlığın son
/// satırı kısaldıkça ortalanan kapak da aşağı iner.
const double _yeniKapakBosluk = 10.0;
const double _yeniKapakBoslukDugmesiz = 8.0;
const double _dortAgustusOncesiKapakBosluk = 22.0;

/// İçerik adının ve bölüm rozetinin dokunma kutusu (bkz. akis.dart
/// `_icerikAdiDokunmaYuksekligi`). WCAG 2.2 SC 2.5.8 (AA) tabanı 24x24.
const double _adKutusu = 24.0;

const _benimId = 7;

Map<String, dynamic> _gonderi({
  String metin = 'Kısa yorum',
  List<String> medya = const ['/medya/a.jpg'],
  int? sezon,
  int? bolum,
  String tur = 'tv',
  int tmdbId = 900,
  bool? takipEdiyorum = false,
  bool spoiler = false,
}) => {
  'id': 55,
  'kullanici_id': 42,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'metin': metin,
  'tur': tur,
  'tmdb_id': tmdbId,
  'sezon': sezon,
  'bolum': bolum,
  'medya': medya,
  'begeni': 3,
  'yanit': 4,
  'goruntulenme': 9,
  'begendim': false,
  'spoiler': spoiler,
  'tarih': '2026-08-03T10:00:00Z',
  'kaynak_dil': 'tr',
  'ceviri_var': false,
  'cevrildi': false,
  if (takipEdiyorum != null) 'takip_ediyorum': takipEdiyorum,
};

const _icerikler = {
  // Kapağı OLMAYAN içerik: kapaksız kartın bozulmadığını ölçmek için
  'tv:100': {'ad': 'Kapaksız Dizi', 'poster': null},
  'movie:500': {'ad': 'Test Film', 'poster': '/kapak.jpg'},
  'tv:900': {'ad': 'Posterli Dizi', 'poster': '/kapak.jpg'},
};

String? _sonRota;

Future<void> _kur(
  WidgetTester tester,
  Map<String, dynamic> yorum, {
  Size ekran = const Size(400, 1400),
}) async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': _benimId, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
  Api.istemci = MockClient(
    (istek) async => http.Response(
      '{}',
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  );
  _sonRota = null;
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = ekran;
  addTearDown(tester.view.reset);
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: SingleChildScrollView(
            child: AkisKarti(yorum: yorum, icerikler: _icerikler),
          ),
        ),
      ),
      for (final yol in [
        '/icerik/:tur/:id',
        '/dizi/:id/sezon/:sezon/bolum/:bolum',
        '/kullanici/:ad',
      ])
        GoRoute(
          path: yol,
          builder: (_, s) {
            _sonRota = s.uri.path;
            return const Scaffold(body: Text('hedef-sayfa'));
          },
        ),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(routerConfig: yonlendirici),
    ),
  );
  await tester.pump();
}

/// Başlıktaki kapak posteri. Ağaçta medyadan ÖNCE geldiği için `.first`;
/// 42x60 kutusu ("kapak 42x60 kaldı" testi) medyanın kendi görsellerinden
/// ayırt edilebildiğini ayrıca kanıtlar.
Finder _kapak() => find
    .descendant(
      of: find.byType(Card),
      matching: find.byType(CachedNetworkImage),
    )
    .first;
Finder _medya() => find.byType(AkisMedya);

/// Kapağın DOKUNMA kutusu: dolgu InkWell'in içinde olduğu için 42 değil 50 dp.
Finder _kapakDokunma() =>
    find.ancestor(of: _kapak(), matching: find.byType(InkWell)).first;

/// İçerik adının dokunma kutusu.
Finder _adKutusuF([String ad = 'Posterli Dizi']) => find
    .ancestor(of: find.text(ad), matching: find.byType(ConstrainedBox))
    .first;

/// (1) ASIL HEDEF: içerik adı METNİNİN alt kenarı ↔ medyanın üst kenarı.
double _adBosluk(WidgetTester tester, [String ad = 'Posterli Dizi']) =>
    tester.getRect(_medya()).top - tester.getRect(find.text(ad)).bottom;

/// (2) Kapağın ALT kenarı ↔ medyanın ÜST kenarı.
double _kapakBosluk(WidgetTester tester) =>
    tester.getRect(_medya()).top - tester.getRect(_kapak()).bottom;

/// (3) Kullanıcı adının altı ↔ içerik adının üstü (3 Ağu'da kilitlenen değer).
double _satirBoslugu(WidgetTester tester, [String ad = 'Posterli Dizi']) =>
    tester.getRect(find.text(ad)).top -
    tester.getRect(find.text('@thelostvibe0').first).bottom;

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('(1) İçerik adı ↔ medya: $_oncekiAdBosluk → $_yeniAdBosluk dp', () {
    testWidgets('bölüm gönderisi (Takip Et düğmeli)', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      expect(_adBosluk(tester), _yeniAdBosluk);
      expect(_yeniAdBosluk, lessThan(_oncekiAdBosluk));
    });

    testWidgets('takip düğmesiz kartta da aynı', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: true));
      expect(find.text('Takip Et'), findsNothing);
      expect(_adBosluk(tester), _yeniAdBosluk);
    });

    testWidgets('profil kartında (takip alanı yok) da aynı', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: null));
      expect(_adBosluk(tester), _yeniAdBosluk);
    });

    testWidgets('film gönderisinde de aynı', (tester) async {
      await _kur(tester, _gonderi(tur: 'movie', tmdbId: 500));
      expect(_adBosluk(tester, 'Test Film'), _yeniAdBosluk);
    });

    testWidgets('NEFES PAYI: sıfır DEĞİL, metin medyaya yapışmıyor', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      expect(
        _adBosluk(tester),
        greaterThan(0),
        reason: 'sıfır olsaydı yazı görselin kenarına yapışık okunurdu',
      );
      expect(
        tester.getRect(_adKutusuF()).bottom,
        lessThanOrEqualTo(tester.getRect(_medya()).top),
        reason: 'adın dokunma kutusu medyanın üstüne BİNMEMELİ',
      );
    });

    testWidgets('boşluğun tamamı görünür boşluk: ölü dokunma payı 5 dp', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final kutu = tester.getRect(_adKutusuF());
      final metin = tester.getRect(find.text('Posterli Dizi'));
      // Eskiden metnin altında 25 dp'lik kutu payı vardı; artık 5 dp.
      expect(kutu.bottom - metin.bottom, 5.0);
      // Medya bu kutunun hemen altından başlar: arada başka boşluk YOK.
      expect(tester.getRect(_medya()).top - kutu.bottom, 4.0);
    });
  });

  group('(2) Kapak DİKEY ORTALI konumuna DÖNDÜ', () {
    testWidgets('kapağın üstündeki ve altındaki pay EŞİT (ortalı)', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final kapak = tester.getRect(_kapak());
      final ad = tester.getRect(find.text('@thelostvibe0').first);
      // Başlık bloğunun sınırları: kartın üst dolgusu 8 dp, altı ad kutusu.
      final baslikUst = tester.getRect(find.byType(Card)).top + 8;
      final baslikAlt = tester.getRect(_adKutusuF()).bottom;
      expect(
        (kapak.top - baslikUst) - (baslikAlt - kapak.bottom),
        closeTo(0, 0.01),
        reason: '4 Ağu\'da alta yaslanmıştı; kullanıcı "tam tersi" dedi',
      );
      // Ortalıysa kapağın üstü kullanıcı adı satırının içindedir.
      expect(kapak.top, lessThan(ad.bottom));
    });

    testWidgets('kapağın altı artık içerik adının ALTINDA DEĞİL', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final kapak = tester.getRect(_kapak());
      final adKutusu = tester.getRect(_adKutusuF());
      // 4 Ağu düzeninde kapak.bottom == adKutusu.bottom idi (alta yaslıydı).
      expect(kapak.bottom, lessThan(adKutusu.bottom));
    });

    testWidgets('kapak ↔ medya: $_yeniKapakBosluk dp (4 Ağu öncesi '
        '$_dortAgustusOncesiKapakBosluk dp)', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      expect(_kapakBosluk(tester), _yeniKapakBosluk);
      expect(_yeniKapakBosluk, lessThan(_dortAgustusOncesiKapakBosluk));
    });

    testWidgets('düğmesiz kartta $_yeniKapakBoslukDugmesiz dp', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: true));
      expect(_kapakBosluk(tester), _yeniKapakBoslukDugmesiz);
    });

    testWidgets('kapak 42x60 kaldı ve hâlâ sağ uçta', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final kapak = tester.getRect(_kapak());
      expect(kapak.size, const Size(42, 60));
      final menu = tester.getRect(find.byIcon(Icons.more_vert));
      final ad = tester.getRect(find.text('Posterli Dizi'));
      // Soldan sağa sıra bozulmadı: içerik adı → ··· → kapak
      expect(menu.center.dx, greaterThan(ad.center.dx));
      expect(kapak.left, greaterThanOrEqualTo(menu.right));
      // Kartın sağ kenarından 12 dp içeride (4 Ağu öncesiyle birebir aynı)
      expect(tester.getRect(find.byType(Card)).right - kapak.right, 12);
    });
  });

  group('(3) Kullanıcı adı ↔ içerik adı boşluğu DEĞİŞMEDİ', () {
    testWidgets('düğmeli kartta 13,5 dp', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      expect(_satirBoslugu(tester), 13.5);
    });

    testWidgets('düğmesiz kartta 11,5 dp', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: true));
      expect(_satirBoslugu(tester), 11.5);
    });

    testWidgets('içerik adı metninin yeri hiç oynamadı', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      // 4 Ağu düzeninde de metin tam buradaydı: kısalan kutunun ALTIDIR,
      // metin AŞAĞI/YUKARI kaymadı — yalnız medya yukarı geldi.
      expect(tester.getRect(find.text('Posterli Dizi')).top, 56.0);
    });
  });

  group('ERİŞİLEBİLİRLİK BEDELİ: 44 → 24 dp ve telafisi', () {
    testWidgets('içerik adının kutusu $_adKutusu dp (WCAG 2.2 AA tabanı)', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final kutu = tester.getSize(_adKutusuF());
      expect(kutu.height, _adKutusu);
      expect(
        kutu.height,
        greaterThanOrEqualTo(24),
        reason: 'WCAG 2.2 SC 2.5.8 (AA) normatif taban 24x24',
      );
    });

    testWidgets('kutu ALÇALDI ama 44x44\'ten GENİŞ: alan küçülmedi', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final kutu = tester.getSize(_adKutusuF());
      expect(kutu.width, greaterThanOrEqualTo(44));
      expect(
        kutu.width * kutu.height,
        greaterThan(44 * 44),
        reason: 'daralan tek boyut yükseklik; hedefin ALANI 44x44\'ün üstünde',
      );
    });

    testWidgets('rozet de aynı kutuya indi ama genişliği 44 dp\'nin üstünde', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final rozet = tester.getSize(find.byType(BolumRozeti));
      expect(rozet.height, _adKutusu);
      expect(rozet.width, greaterThanOrEqualTo(44));
    });

    testWidgets('TELAFİ: kapağın dokunma alanı 50x60 (44 dp kuralına uyar)', (
      tester,
    ) async {
      await _kur(tester, _gonderi());
      final dokunma = tester.getSize(_kapakDokunma());
      expect(dokunma.width, greaterThanOrEqualTo(44));
      expect(dokunma.height, greaterThanOrEqualTo(44));
      expect(dokunma, const Size(50, 60));
    });

    testWidgets('TELAFİ: dizi gönderisinde kapak da İÇERİK SAYFASINA gider '
        '(eşdeğer hedef)', (tester) async {
      await _kur(tester, _gonderi());
      await tester.tap(_kapakDokunma());
      await tester.pumpAndSettle();
      expect(_sonRota, '/icerik/tv/900');
    });

    testWidgets('kullanıcı adının kutusu 44 dp KALDI (dokunulmadı)', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('@thelostvibe0').first,
                    matching: find.byType(ConstrainedBox),
                  )
                  .first,
            )
            .height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('yorum listelerindeki rozet 44x44 KALDI (varsayılan)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(
                  body: BolumRozeti(diziId: 1, sezon: 2, bolum: 3),
                ),
              ),
            ],
          ),
        ),
      );
      final rozet = tester.getSize(find.byType(BolumRozeti));
      expect(
        rozet.height,
        greaterThanOrEqualTo(44),
        reason: 'kısaltma YALNIZ akış kartının başlığına özeldir',
      );
    });
  });

  group('HİT-TEST: kimin pikseli kimin', () {
    testWidgets('metnin ALTINDAKİ 5 dp hâlâ içerik sayfasını açar', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final metin = tester.getRect(find.text('Posterli Dizi'));
      await tester.tapAt(Offset(metin.center.dx, metin.bottom + 2));
      await tester.pumpAndSettle();
      expect(_sonRota, '/icerik/tv/900');
    });

    testWidgets('medyanın ÜST ŞERİDİ MEDYANINDIR (ad kutusu yutmuyor)', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final metin = tester.getRect(find.text('Posterli Dizi'));
      final medya = tester.getRect(_medya());
      // Adın tam altındaki x'te, medyanın en üst pikseline dokun.
      await tester.tapAt(Offset(metin.center.dx, medya.top + 2));
      await tester.pumpAndSettle();
      expect(
        _sonRota,
        isNull,
        reason:
            'ad kutusu medyaya bindirilseydi burada içerik sayfası açılırdı '
            '— medyanın dokunuşu yutulmuş olurdu',
      );
    });

    testWidgets('kapağın EN ALT pikseli de tıklanır', (tester) async {
      await _kur(tester, _gonderi());
      final kapak = tester.getRect(_kapak());
      await tester.tapAt(Offset(kapak.center.dx, kapak.bottom - 1));
      await tester.pumpAndSettle();
      expect(
        _sonRota,
        '/icerik/tv/900',
        reason: 'Stack dışına taşan Positioned görünür ama tıklanamazdı',
      );
    });

    testWidgets('bölüm gönderisinde kapak → bölüm sayfası', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      await tester.tap(_kapakDokunma());
      await tester.pumpAndSettle();
      expect(_sonRota, '/dizi/900/sezon/4/bolum/6');
    });

    testWidgets('rozet dokunuşu bozulmadı', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      await tester.tap(find.byType(BolumRozeti));
      await tester.pumpAndSettle();
      expect(_sonRota, '/dizi/900/sezon/4/bolum/6');
    });

    testWidgets('içerik adının metnine dokunmak da içerik sayfasını açar', (
      tester,
    ) async {
      await _kur(tester, _gonderi(tur: 'movie', tmdbId: 500));
      await tester.tap(find.text('Test Film'));
      await tester.pumpAndSettle();
      expect(_sonRota, '/icerik/movie/500');
    });
  });

  group('MEDYASIZ gönderide düzen bozulmadı', () {
    testWidgets('sıra: başlık → metin → eylem satırı', (tester) async {
      await _kur(tester, _gonderi(medya: const []));
      expect(_medya(), findsNothing);
      final kapak = tester.getRect(_kapak());
      final metin = tester.getRect(find.byType(EtiketliMetin));
      final eylem = tester.getTopLeft(find.byIcon(Icons.favorite_border)).dy;
      expect(metin.top, greaterThanOrEqualTo(kapak.bottom));
      expect(eylem, greaterThanOrEqualTo(metin.bottom));
    });

    testWidgets('kapak metnin üstüne binmiyor, nefes payı korunuyor', (
      tester,
    ) async {
      await _kur(tester, _gonderi(medya: const []));
      final bosluk =
          tester.getRect(find.byType(EtiketliMetin)).top -
          tester.getRect(_kapak()).bottom;
      expect(bosluk, greaterThan(0));
      // Ad kutusunun altı + metin bloğunun kendi 8 dp üst dolgusu
      expect(
        tester.getRect(find.byType(EtiketliMetin)).top -
            tester.getRect(_adKutusuF()).bottom,
        8,
      );
    });

    testWidgets('metinsiz ve medyasız kartta da hata yok', (tester) async {
      await _kur(tester, _gonderi(medya: const [], metin: ''));
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(_kapak(), findsOneWidget);
    });
  });

  group('SPOILER perdesi', () {
    testWidgets('perde kapalıyken medya çizilmez, düzen bozulmaz', (
      tester,
    ) async {
      await _kur(tester, _gonderi(spoiler: true, sezon: 4, bolum: 6));
      expect(_medya(), findsNothing);
      expect(find.byType(EtiketliMetin), findsNothing);
      final perde = tester.getRect(
        find.text('Spoiler olabilir — dokun ve gör'),
      );
      final kapak = tester.getRect(_kapak());
      expect(
        perde.top,
        greaterThan(kapak.bottom),
        reason: 'perde kapağın altında kalmalı',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('perde açılınca medya yine adın $_yeniAdBosluk dp altında', (
      tester,
    ) async {
      await _kur(tester, _gonderi(spoiler: true, sezon: 4, bolum: 6));
      await tester.tap(find.text('Spoiler olabilir — dokun ve gör'));
      await tester.pump();
      expect(_medya(), findsOneWidget);
      expect(_adBosluk(tester), _yeniAdBosluk);
      expect(_kapakBosluk(tester), _yeniKapakBosluk);
    });
  });

  group('KAPAKSIZ içerikte düzen bozulmadı', () {
    testWidgets('kapak yoksa medya yine adın hemen altında', (tester) async {
      await _kur(tester, _gonderi(tmdbId: 100));
      expect(_adBosluk(tester, 'Kapaksız Dizi'), _yeniAdBosluk);
      // Kapak yokken sağda ayrılan 50 dp'lik yer de YOK: menü sağ uca yaklaşır
      final menu = tester.getRect(find.byIcon(Icons.more_vert));
      expect(
        tester.getRect(find.byType(Card)).right - menu.right,
        lessThanOrEqualTo(20),
      );
    });
  });

  group('Kart bütünlüğü', () {
    testWidgets('kart ve medya TAM GENİŞLİK', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final kart = tester.getRect(find.byType(Card));
      expect(kart.left, 0);
      expect(kart.width, 400);
      final medya = tester.getRect(_medya());
      expect(medya.left, 0);
      expect(medya.width, 400);
    });

    testWidgets('360 dp genişlikte taşma yok, mesafeler aynı', (tester) async {
      final y = _gonderi(sezon: 12, bolum: 24)
        ..['kullanici_adi'] = 'cokuzunbirkullaniciadi';
      await _kur(tester, y, ekran: const Size(360, 1200));
      expect(tester.takeException(), isNull);
      expect(find.text('S12B24'), findsOneWidget);
      expect(find.text('Takip Et'), findsOneWidget);
      expect(_adBosluk(tester), _yeniAdBosluk);
      expect(_kapakBosluk(tester), _yeniKapakBosluk);
      final kapak = tester.getRect(_kapak());
      expect(kapak.right, 360 - 12);
      expect(
        kapak.left,
        greaterThanOrEqualTo(
          tester.getRect(find.byIcon(Icons.more_vert)).right,
        ),
      );
    });

    testWidgets('kart 4 Ağu düzeninden de KISALDI', (tester) async {
      await _kur(tester, _gonderi(medya: const []));
      // 4 Ağu düzeninde 190 dp'nin altındaydı; 20 dp'lik ölü pay gidince daha da
      expect(tester.getSize(find.byType(Card)).height, lessThan(170.0));
    });
  });
}
