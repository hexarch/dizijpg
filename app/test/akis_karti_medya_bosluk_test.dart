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

/// AKIŞ KARTINDA MEDYA BAŞLIĞA YAKLAŞTI (kullanıcı isteği, 4 Ağu 2026):
/// "akıştaki gönderilerde gönderinin resmini veya videosunu biraz daha yukarı
/// çekip neredeyse dizi filmin kapak fotoğrafına dayayabilir misin".
///
/// BOŞLUĞUN GERÇEK KAYNAĞI TEK BİR SizedBox DEĞİLDİ:
///   • Başlık satırı iki satır yüksekliğindedir (kullanıcı adı 44/48 dp +
///     içerik adı 44 dp = 88/92 dp), kapak ise 60 dp. Row kapağı DİKEY
///     ORTALADIĞI için kapağın ALTINDA 16 dp ölü alan kalıyordu.
///   • Üstüne başlık ile medya arasındaki 6 dp'lik SizedBox biniyordu.
///   → kapak ile medya arası 22 dp.
/// Kapak artık Stack içinde başlığın ALT kenarına yaslı; geriye yalnız 4 dp
/// nefes payı kaldı.
///
/// İÇERİK ADI ile medya arasındaki 29 dp'nin 25 dp'si BOŞLUK DEĞİL, içerik
/// adının 44 dp'lik DOKUNMA KUTUSUDUR (metin 19 dp, kutu 44 dp, metin kutunun
/// üstüne yaslı). Orayı kısaltmak dokunma hedefini 44 dp'nin altına indirirdi;
/// erişilebilirlik feda edilmedi — o alana dokunmak içerik sayfasını açar
/// ("o alana dokunmak İÇERİK SAYFASINI açar" testi bunu kanıtlar).
const double _oncekiKapakBosluk = 22.0;
const double _yeniKapakBosluk = 4.0;
const double _oncekiAdBosluk = 31.0;
const double _yeniAdBosluk = 29.0;

/// Takip düğmesiz kartta (düğmenin 48 dp'lik kutusu satırı şişirmez) önceki
/// değer 20 dp idi; yeni değer düğmeliyle AYNI 4 dp.
const double _oncekiKapakBoslukDugmesiz = 20.0;

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

/// (1) Kapağın ALT kenarı ↔ medyanın ÜST kenarı.
double _kapakBosluk(WidgetTester tester) =>
    tester.getRect(_medya()).top - tester.getRect(_kapak()).bottom;

/// (2) İçerik adı satırının ALT kenarı ↔ medyanın ÜST kenarı.
double _adBosluk(WidgetTester tester, [String ad = 'Posterli Dizi']) =>
    tester.getRect(_medya()).top - tester.getRect(find.text(ad)).bottom;

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('(1) Kapak ↔ medya: $_oncekiKapakBosluk → $_yeniKapakBosluk dp', () {
    testWidgets('bölüm gönderisi (Takip Et düğmeli)', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      expect(_kapakBosluk(tester), _yeniKapakBosluk);
      expect(_yeniKapakBosluk, lessThan(_oncekiKapakBosluk));
    });

    testWidgets(
      'takip düğmesiz kart: $_oncekiKapakBoslukDugmesiz → $_yeniKapakBosluk dp',
      (tester) async {
        await _kur(tester, _gonderi(takipEdiyorum: true));
        expect(find.text('Takip Et'), findsNothing);
        expect(_kapakBosluk(tester), _yeniKapakBosluk);
        expect(_yeniKapakBosluk, lessThan(_oncekiKapakBoslukDugmesiz));
      },
    );

    testWidgets('profil kartında (takip alanı yok) da aynı', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: null));
      expect(_kapakBosluk(tester), _yeniKapakBosluk);
    });

    testWidgets('film gönderisinde de aynı', (tester) async {
      await _kur(tester, _gonderi(tur: 'movie', tmdbId: 500));
      expect(_kapakBosluk(tester), _yeniKapakBosluk);
    });

    testWidgets('NEFES PAYI: sıfır DEĞİL, kapak medyaya değmiyor', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      expect(
        _kapakBosluk(tester),
        greaterThan(0),
        reason: 'sıfır olsaydı kapak ile gönderi görseli tek görsele karışırdı',
      );
      expect(
        tester.getRect(_kapak()).bottom,
        lessThanOrEqualTo(tester.getRect(_medya()).top),
        reason: 'kapak medyanın üstüne binmemeli',
      );
    });

    testWidgets('kapak artık başlığın ALT kenarına yaslı (ortalı değil)', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final kapak = tester.getRect(_kapak());
      final ad = tester.getRect(find.text('Posterli Dizi'));
      // Eskiden kapak dikey ORTALIYDI: alt kenarı içerik adı satırının
      // ortalarında kalıyordu. Artık o satırın da ALTINA iniyor.
      expect(
        kapak.bottom,
        greaterThan(ad.bottom),
        reason: 'kapağın altı içerik adının altından da aşağıda olmalı',
      );
      expect(
        kapak.top,
        greaterThan(tester.getRect(find.byType(Card)).top + 30),
      );
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
      // Kartın sağ kenarından 12 dp içeride (eski konumla birebir aynı)
      expect(tester.getRect(find.byType(Card)).right - kapak.right, 12);
    });
  });

  group('(2) İçerik adı ↔ medya: $_oncekiAdBosluk → $_yeniAdBosluk dp', () {
    testWidgets('bölüm gönderisi (Takip Et düğmeli)', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      expect(_adBosluk(tester), _yeniAdBosluk);
      expect(_yeniAdBosluk, lessThan(_oncekiAdBosluk));
    });

    testWidgets('takip düğmesiz kartta da aynı', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: true));
      expect(_adBosluk(tester), _yeniAdBosluk);
    });

    testWidgets('kalan boşluğun 25 dp\'si içerik adının DOKUNMA KUTUSU', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final kutu = tester.getRect(
        find
            .ancestor(
              of: find.text('Posterli Dizi'),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      final metin = tester.getRect(find.text('Posterli Dizi'));
      expect(kutu.height, greaterThanOrEqualTo(44));
      // Metnin ALTINDAKİ alan dokunulabilir: boş piksel değil.
      expect(kutu.bottom - metin.bottom, greaterThan(20));
      // Medya bu kutunun hemen altından başlar: arada başka boşluk YOK.
      expect(tester.getRect(_medya()).top - kutu.bottom, _yeniKapakBosluk);
    });

    testWidgets('o alana dokunmak İÇERİK SAYFASINI açar (ölü alan değil)', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final metin = tester.getRect(find.text('Posterli Dizi'));
      // Metnin 15 dp ALTINA dokun: kutunun içi
      await tester.tapAt(Offset(metin.center.dx, metin.bottom + 15));
      await tester.pumpAndSettle();
      expect(_sonRota, '/icerik/tv/900');
    });
  });

  group('Kapak Stack\'e taşındı ama HÂLÂ TIKLANIR', () {
    testWidgets('bölüm gönderisinde kapak → bölüm sayfası', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      await tester.tap(_kapak());
      await tester.pumpAndSettle();
      expect(_sonRota, '/dizi/900/sezon/4/bolum/6');
    });

    testWidgets('dizi gönderisinde kapak → içerik sayfası', (tester) async {
      await _kur(tester, _gonderi());
      await tester.tap(_kapak());
      await tester.pumpAndSettle();
      expect(_sonRota, '/icerik/tv/900');
    });

    testWidgets('kapağın EN ALT pikseli de tıklanır (Stack sınırı içinde)', (
      tester,
    ) async {
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

    testWidgets('rozet dokunuşu bozulmadı', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      await tester.tap(find.byType(BolumRozeti));
      await tester.pumpAndSettle();
      expect(_sonRota, '/dizi/900/sezon/4/bolum/6');
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
      expect(bosluk, 8, reason: 'metin bloğunun kendi 8 dp üst dolgusu');
      expect(bosluk, greaterThan(0));
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

    testWidgets(
      'perde açılınca medya yine kapağın $_yeniKapakBosluk dp altında',
      (tester) async {
        await _kur(tester, _gonderi(spoiler: true, sezon: 4, bolum: 6));
        await tester.tap(find.text('Spoiler olabilir — dokun ve gör'));
        await tester.pump();
        expect(_medya(), findsOneWidget);
        expect(_kapakBosluk(tester), _yeniKapakBosluk);
        expect(_adBosluk(tester), _yeniAdBosluk);
      },
    );
  });

  group('KAPAKSIZ içerikte düzen bozulmadı', () {
    testWidgets('kapak yoksa medya başlığın hemen altında', (tester) async {
      await _kur(tester, _gonderi(tmdbId: 100));
      final ad = tester.getRect(find.text('Kapaksız Dizi'));
      final medya = tester.getRect(_medya());
      expect(medya.top - ad.bottom, _yeniAdBosluk);
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

    testWidgets('dokunma hedefleri hâlâ >= 44 dp', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      for (final metin in [
        find.text('Posterli Dizi'),
        find.text('@thelostvibe0').first,
      ]) {
        expect(
          tester
              .getSize(
                find
                    .ancestor(of: metin, matching: find.byType(ConstrainedBox))
                    .first,
              )
              .height,
          greaterThanOrEqualTo(44),
        );
      }
      final rozet = tester.getSize(find.byType(BolumRozeti));
      expect(rozet.height, greaterThanOrEqualTo(44));
      expect(rozet.width, greaterThanOrEqualTo(44));
    });

    testWidgets('360 dp genişlikte taşma yok, mesafe aynı', (tester) async {
      final y = _gonderi(sezon: 12, bolum: 24)
        ..['kullanici_adi'] = 'cokuzunbirkullaniciadi';
      await _kur(tester, y, ekran: const Size(360, 1200));
      expect(tester.takeException(), isNull);
      expect(find.text('S12B24'), findsOneWidget);
      expect(find.text('Takip Et'), findsOneWidget);
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

    testWidgets('kart makul yükseklikte kaldı (kısaldı)', (tester) async {
      await _kur(tester, _gonderi(medya: const []));
      expect(tester.getSize(find.byType(Card)).height, lessThan(190.0));
    });
  });
}
