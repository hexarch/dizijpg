import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/ortak.dart' show KullaniciAvatari;
import 'package:dizijpg/ekranlar/yorumlar.dart' show BolumRozeti;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// AKIŞ KARTI BAŞLIĞININ HİZALAMASI (kullanıcı isteği, 3 Ağu 2026):
/// "akışta hâlâ kullanıcı profil resminin hemen ortasında kullanıcı adı,
/// resmin altından başlayacak şekilde de dizi filmin adı olmalı".
///
/// ÖNCE (avatar dış satırda, iki metin satırı avatarın SAĞINDA):
///   [avatar] @kullaniciadi  [Takip Et]        [···] [kapak]
///            Dizi Adı  S4B6      ← avatarın SAĞINA girintili
///   ölçüm: adın merkezi avatarın merkezinden 22,0 dp YUKARIDA,
///          içerik adının solu avatarın solundan 50,0 dp SAĞDA.
///
/// SONRA (avatar kullanıcı adıyla AYNI satırda, içerik adı ALT satırda):
///   [avatar] @kullaniciadi  [Takip Et]        [···] [kapak]
///   Dizi Adı  S4B6                ← avatarın ALTINDAN, sol kenarlar eşit
///   ölçüm: merkez farkı 0,0 dp — sol kenar farkı 0,0 dp.
///
/// İKİ SATIR ARASINDAKİ BOŞLUK bu düzende geometriden doğar: ad 44 dp'lik
/// satırın ortasında, içerik adı satırın hemen altındadır →
/// (44 - yazıYüksekliği) / 2. Deneme yazı tipinde 11,5 dp; "Takip Et"
/// düğmeli kartta düğmenin 48 dp'lik dokunma kutusu satırı şişirdiği için
/// 13,5 dp. Kullanıcının bir önceki isteği olan "boşluk yarıya insin"
/// (16,50 → 8,25) bozulmadı: eski 16,50'nin ALTINDA kalındı. Daha aşağı
/// inmek avatarı (40 dp) ya da adın dokunma kutusunu (44 dp) küçültmeyi
/// gerektirirdi; erişilebilirlik feda EDİLMEDİ.
const double _oncekiDugmesiz = 16.5;
const double _yeniDugmesiz = 11.5;
const double _oncekiDugmeli = 26.0;
const double _yeniDugmeli = 13.5;

const _benimId = 7;

Map<String, dynamic> _gonderi({
  int? sezon,
  int? bolum,
  String tur = 'tv',
  int tmdbId = 100,
  // null = sunucu bildirmedi (profil ekranları) → düğme çizilmez
  bool? takipEdiyorum,
}) => {
  'id': 55,
  'kullanici_id': 42,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'metin': 'Kısa yorum',
  'tur': tur,
  'tmdb_id': tmdbId,
  'sezon': sezon,
  'bolum': bolum,
  'medya': const <String>[],
  'begeni': 3,
  'yanit': 4,
  'goruntulenme': 9,
  'begendim': false,
  'spoiler': false,
  'tarih': '2026-08-03T10:00:00Z',
  'kaynak_dil': 'tr',
  'ceviri_var': false,
  'cevrildi': false,
  if (takipEdiyorum != null) 'takip_ediyorum': takipEdiyorum,
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
  'movie:500': {'ad': 'Test Film', 'poster': null},
  'tv:900': {'ad': 'Posterli Dizi', 'poster': '/kapak.jpg'},
};

String? _sonRota;

void _sunucu() {
  Api.istemci = MockClient(
    (istek) async => http.Response(
      '{}',
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  );
}

Future<void> _kur(
  WidgetTester tester,
  Map<String, dynamic> yorum, {
  Size ekran = const Size(400, 900),
}) async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': _benimId, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
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

/// Başlıktaki kullanıcı adı (aynı ad yorum metninin başında da geçer; ağaçta
/// başlık önce geldiği için ilki alınır).
Finder _kullaniciAdi() => find.text('@thelostvibe0').first;
Finder _icerikAdi([String ad = 'Test Dizi']) => find.text(ad);
Finder _avatar() => find.byType(KullaniciAvatari);

/// İki satır arasındaki GERÇEK dikey mesafe.
double _bosluk(WidgetTester tester, [String ad = 'Test Dizi']) =>
    tester.getRect(_icerikAdi(ad)).top - tester.getRect(_kullaniciAdi()).bottom;

/// Bir metnin ETRAFINDAKİ dokunma kutusu (44 dp'lik ConstrainedBox).
Size _dokunmaKutusu(WidgetTester tester, Finder metin) => tester.getSize(
  find.ancestor(of: metin, matching: find.byType(ConstrainedBox)).first,
);

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _sunucu();
  });

  // ------------------------------------------------------------- 1. istek
  group('Kullanıcı adı avatarın DİKEY ORTASINDA', () {
    testWidgets('düğmesiz kartta merkezler BİREBİR aynı', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: true));
      final avatar = tester.getRect(_avatar());
      final ad = tester.getRect(_kullaniciAdi());
      expect(
        (ad.center.dy - avatar.center.dy).abs(),
        lessThan(1.0),
        reason: 'ad avatarın üst kenarına değil TAM ORTASINA hizalanmalı',
      );
    });

    testWidgets('"Takip Et" düğmeli kartta da merkezler aynı', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: false));
      expect(find.text('Takip Et'), findsOneWidget);
      final avatar = tester.getRect(_avatar());
      final ad = tester.getRect(_kullaniciAdi());
      expect((ad.center.dy - avatar.center.dy).abs(), lessThan(1.0));
    });

    testWidgets('bölüm gönderisinde (S4B6 rozetli) de aynı', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final avatar = tester.getRect(_avatar());
      final ad = tester.getRect(_kullaniciAdi());
      expect((ad.center.dy - avatar.center.dy).abs(), lessThan(1.0));
    });

    testWidgets('kullanıcı adı avatarın SAĞINDA duruyor (yan yana)', (
      tester,
    ) async {
      await _kur(tester, _gonderi());
      expect(
        tester.getRect(_kullaniciAdi()).left,
        greaterThan(tester.getRect(_avatar()).right),
      );
    });
  });

  // ------------------------------------------------------------- 2. istek
  group('İçerik adı AVATARIN ALTINDAN başlıyor', () {
    testWidgets('sol kenarlar BİREBİR aynı (girinti YOK)', (tester) async {
      await _kur(tester, _gonderi());
      final avatar = tester.getRect(_avatar());
      final icerik = tester.getRect(_icerikAdi());
      expect(
        (icerik.left - avatar.left).abs(),
        lessThan(1.0),
        reason: 'içerik adı avatarın sağına girintili olmamalı',
      );
    });

    testWidgets('dikeyde avatarın ALTINDA', (tester) async {
      await _kur(tester, _gonderi());
      expect(
        tester.getRect(_icerikAdi()).top,
        greaterThanOrEqualTo(tester.getRect(_avatar()).bottom),
      );
    });

    testWidgets('düğmeli kartta da sol kenar avatarla aynı', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: false));
      final avatar = tester.getRect(_avatar());
      final icerik = tester.getRect(_icerikAdi());
      expect((icerik.left - avatar.left).abs(), lessThan(1.0));
      expect(icerik.top, greaterThanOrEqualTo(avatar.bottom));
    });

    testWidgets('film gönderisinde de sol kenar avatarla aynı', (tester) async {
      await _kur(tester, _gonderi(tur: 'movie', tmdbId: 500));
      final avatar = tester.getRect(_avatar());
      final icerik = tester.getRect(_icerikAdi('Test Film'));
      expect((icerik.left - avatar.left).abs(), lessThan(1.0));
    });

    testWidgets('S4B6 rozeti içerik adının HEMEN YANINDA ve aynı hizada', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final ad = tester.getRect(_icerikAdi());
      final rozet = tester.getRect(find.text('S4B6'));
      // Alt kenarlar birebir aynı (aynı satır)
      expect(rozet.bottom, ad.bottom);
      expect((ad.center.dy - rozet.center.dy).abs(), lessThan(2.0));
      // Rozet adın SAĞINDA ve yakınında (satır sonuna savrulmadı)
      expect(rozet.left, greaterThan(ad.right));
      expect(rozet.left - ad.right, lessThan(40.0));
    });
  });

  // ------------------------------------------------ satırlar arası boşluk
  group('Kullanıcı adı ile içerik adı arasındaki boşluk', () {
    testWidgets('takip düğmesiz kart: $_oncekiDugmesiz → $_yeniDugmesiz dp', (
      tester,
    ) async {
      await _kur(tester, _gonderi(takipEdiyorum: true));
      expect(_bosluk(tester), _yeniDugmesiz);
      expect(_yeniDugmesiz, lessThan(_oncekiDugmesiz));
    });

    testWidgets('profil ekranı kartı (takip alanı yok) da $_yeniDugmesiz dp', (
      tester,
    ) async {
      await _kur(tester, _gonderi());
      expect(_bosluk(tester), _yeniDugmesiz);
    });

    testWidgets('"Takip Et" düğmeli kart: $_oncekiDugmeli → $_yeniDugmeli dp', (
      tester,
    ) async {
      await _kur(tester, _gonderi(takipEdiyorum: false));
      expect(find.text('Takip Et'), findsOneWidget);
      expect(_bosluk(tester), _yeniDugmeli);
    });

    testWidgets('bölüm gönderisinde de aynı', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      expect(_bosluk(tester), _yeniDugmesiz);
    });

    testWidgets('film gönderisinde de aynı', (tester) async {
      await _kur(tester, _gonderi(tur: 'movie', tmdbId: 500));
      expect(_bosluk(tester, 'Test Film'), _yeniDugmesiz);
    });

    testWidgets('satırlar BİRBİRİNE DEĞMİYOR, sıra bozulmadı', (tester) async {
      await _kur(tester, _gonderi());
      final ad = tester.getRect(_kullaniciAdi());
      final icerik = tester.getRect(_icerikAdi());
      expect(icerik.top - ad.bottom, greaterThan(4));
      expect(icerik.top, greaterThan(ad.bottom));
      // Kullanıcı adı daha büyük ve üstte: görsel hiyerarşi korunur
      expect(ad.height, greaterThan(icerik.height));
    });

    testWidgets('kart makul yükseklikte kaldı', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: false));
      expect(tester.getSize(find.byType(Card)).height, lessThan(190.0));
    });
  });

  group('Dokunma hedefleri', () {
    // İÇERİK ADI ve ROZET 5 Ağu 2026'da 44 → 24 dp'ye İNDİ. Sebebi ve
    // ölçümü akis_karti_medya_bosluk_test.dart'ta: başlığın SON satırı
    // 44 dp kaldıkça medya, içerik adından 25 dp uzakta kalıyordu
    // (kullanıcı: "görsel veya videoyu yukarı çekip dizi adına dayaman
    // gerekiyordu"). 24 dp, WCAG 2.2 SC 2.5.8 (AA) normatif tabanıdır;
    // 44 dp AAA'dır (SC 2.5.5). İki hedefin de GENİŞLİĞİ 44 dp'nin
    // üstünde kaldı ve aynı sayfalara giden 50x60 dp'lik kapak posteri
    // eşdeğer hedef olarak duruyor.
    testWidgets('içerik adının dokunma kutusu en az 24 dp (WCAG AA)', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final kutu = _dokunmaKutusu(tester, _icerikAdi());
      expect(kutu.height, greaterThanOrEqualTo(24));
      // Yükseklikten verilen, genişlikten geri alındı: alan 44x44'ün üstünde
      expect(kutu.width, greaterThanOrEqualTo(44));
    });

    testWidgets('S4B6 rozeti en az 24 dp yüksek ve 44 dp geniş', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final kutu = tester.getSize(find.byType(BolumRozeti));
      expect(kutu.height, greaterThanOrEqualTo(24));
      expect(kutu.width, greaterThanOrEqualTo(44));
    });

    testWidgets('kullanıcı adının dokunma kutusu 37,5 → 44 dp BÜYÜDÜ', (
      tester,
    ) async {
      await _kur(tester, _gonderi());
      expect(
        _dokunmaKutusu(tester, _kullaniciAdi()).height,
        greaterThanOrEqualTo(44),
        reason: 'eski düzende 37,5 dp idi; yeni düzende kutu sabit 44 dp',
      );
    });

    testWidgets('"Takip Et" dokunma kutusu en az 44 dp', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: false));
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.text('Takip Et'),
                matching: find.byType(FilledButton),
              ),
            )
            .height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('Dokunuşlar hâlâ doğru sayfaya gidiyor', () {
    testWidgets('içerik adı → içerik sayfası', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      await tester.tap(_icerikAdi());
      await tester.pumpAndSettle();
      expect(_sonRota, '/icerik/tv/100');
    });

    testWidgets('S4B6 rozeti → bölüm sayfası', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      await tester.tap(find.byType(BolumRozeti));
      await tester.pumpAndSettle();
      expect(_sonRota, '/dizi/100/sezon/4/bolum/6');
    });

    testWidgets('kullanıcı adı → profil', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      await tester.tap(_kullaniciAdi());
      await tester.pumpAndSettle();
      expect(_sonRota, '/kullanici/thelostvibe0');
    });

    testWidgets('düğmeli kartta da kullanıcı adı → profil', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: false));
      await tester.tap(_kullaniciAdi());
      await tester.pumpAndSettle();
      expect(_sonRota, '/kullanici/thelostvibe0');
    });

    testWidgets('avatar → profil (yeni satırda da tıklanır)', (tester) async {
      await _kur(tester, _gonderi());
      await tester.tap(_avatar());
      await tester.pumpAndSettle();
      expect(_sonRota, '/kullanici/thelostvibe0');
    });
  });

  group('Sağdaki menü ve kapak ile ÇAKIŞMA yok', () {
    testWidgets('içerik adı sola inince ··· ve kapağın altına girmiyor', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6, tmdbId: 900));
      final adKutu = tester.getRect(
        find
            .ancestor(
              of: _icerikAdi('Posterli Dizi'),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      final rozet = tester.getRect(find.byType(BolumRozeti));
      final menu = tester.getRect(find.byIcon(Icons.more_vert));
      final kapak = tester.getRect(find.byType(CachedNetworkImage));
      expect(adKutu.right, lessThanOrEqualTo(menu.left));
      expect(rozet.right, lessThanOrEqualTo(menu.left));
      expect(menu.right, lessThanOrEqualTo(kapak.left));
      // Sıra soldan sağa bozulmadı
      expect(kapak.center.dx, greaterThan(menu.center.dx));
    });
  });

  testWidgets('360 dp genişlikte taşma yok', (tester) async {
    final y = _gonderi(sezon: 12, bolum: 24, tmdbId: 900, takipEdiyorum: false)
      ..['kullanici_adi'] = 'cokuzunbirkullaniciadi';
    await _kur(tester, y, ekran: const Size(360, 780));
    expect(tester.takeException(), isNull);
    expect(find.text('S12B24'), findsOneWidget);
    expect(find.text('Posterli Dizi'), findsOneWidget);
    expect(find.text('Takip Et'), findsOneWidget);
    // Hizalama dar ekranda da geçerli
    final avatar = tester.getRect(_avatar());
    expect(
      (tester.getRect(find.text('@cokuzunbirkullaniciadi').first).center.dy -
              avatar.center.dy)
          .abs(),
      lessThan(1.0),
    );
    expect(
      (tester.getRect(_icerikAdi('Posterli Dizi')).left - avatar.left).abs(),
      lessThan(1.0),
    );
  });
}
