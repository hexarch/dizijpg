import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/yorumlar.dart' show BolumRozeti;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// AKIŞ KARTI BAŞLIĞINDAKİ DİKEY BOŞLUK (kullanıcı isteği, 3 Ağu 2026):
/// "akıştaki dizi isimleri ve kullanıcı isminin arasında boşluk çok fazla,
/// %50 azaltır mısın".
///
///   [avatar] @kullaniciadi  [Takip Et]        [···] [kapak]
///            Dizi Adı  S4B6
///
/// ÖLÇÜLEN: `@kullaniciadi` metninin ALT kenarı ile `Dizi Adı` metninin ÜST
/// kenarı arasındaki GERÇEK mesafe (getRect; göz kararı yok).
///
/// ÖNCE / SONRA (deneme yazı tipi, 400 dp genişlik):
///   • takip düğmesi YOKken (akışta takip ettiklerin, profil ekranları,
///     /gonderi/:id): 16,50 dp → 8,25 dp  (tam %50)
///   • "Takip Et" düğmesi VARken (düğmenin 48 dp'lik dokunma kutusu satırı
///     şişirir): 26,00 dp → 13,50 dp  (%48,1 — düğmenin 48 dp'si 44 dp
///     kuralının ÜSTÜNDE olduğu için kalan 13,5 dp'nin altına inmek dokunma
///     hedeflerini kırardı; erişilebilirlik feda edilmedi)
///
/// Boşluk artık YAZI TİPİNDEN ve takip düğmesinden bağımsız tek bir yerden
/// (`_adDolgusu`) geliyor; içerik adının dokunma kutusu 44 dp KALDI.
const double _oncekiDugmesiz = 16.5;
const double _yeniDugmesiz = _oncekiDugmesiz / 2; // 8.25
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

/// İki satır arasındaki GERÇEK dikey mesafe.
double _bosluk(WidgetTester tester, [String ad = 'Test Dizi']) =>
    tester.getRect(_icerikAdi(ad)).top - tester.getRect(_kullaniciAdi()).bottom;

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _sunucu();
  });

  group('Kullanıcı adı ile içerik adı arasındaki boşluk YARIYA indi', () {
    testWidgets('takip düğmesiz kart: $_oncekiDugmesiz → $_yeniDugmesiz dp', (
      tester,
    ) async {
      await _kur(tester, _gonderi(takipEdiyorum: true));
      expect(_bosluk(tester), _yeniDugmesiz);
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

    testWidgets('bölüm gönderisinde (S4B6 rozetli) de aynı', (tester) async {
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

    testWidgets('içerik adı ile S4B6 rozeti AYNI HİZADA', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final ad = tester.getRect(_icerikAdi());
      final rozet = tester.getRect(find.text('S4B6'));
      // Rozetin yazısı içerik adıyla aynı satırda (alt kenarlar eşit)
      expect(rozet.bottom, ad.bottom);
      expect((ad.center.dy - rozet.center.dy).abs(), lessThan(2.0));
    });

    testWidgets('kart UZAMADI (düğmeli kart kısaldı bile)', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: false));
      expect(tester.getSize(find.byType(Card)).height, lessThan(180.0));
    });
  });

  group('Dokunma hedefleri 44 dp KALDI', () {
    testWidgets('içerik adının dokunma kutusu en az 44 dp', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final kutu = tester.getSize(
        find
            .ancestor(of: _icerikAdi(), matching: find.byType(ConstrainedBox))
            .first,
      );
      expect(kutu.height, greaterThanOrEqualTo(44));
    });

    testWidgets('S4B6 rozetinin dokunma kutusu en az 44x44 dp', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      final kutu = tester.getSize(find.byType(BolumRozeti));
      expect(kutu.height, greaterThanOrEqualTo(44));
      expect(kutu.width, greaterThanOrEqualTo(44));
    });

    testWidgets('kullanıcı adının dokunma alanı KÜÇÜLMEDİ (büyüdü)', (
      tester,
    ) async {
      await _kur(tester, _gonderi());
      final kutu = tester.getSize(
        find
            .ancestor(of: _kullaniciAdi(), matching: find.byType(Padding))
            .first,
      );
      // Eskiden 4 dp dolguyla 29 dp idi; boşluk oraya taşındığı için arttı.
      expect(kutu.height, greaterThan(29.0));
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

    testWidgets('kullanıcı adı → profil (daralan boşluk dokunuşu yutmadı)', (
      tester,
    ) async {
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
  });

  testWidgets('360 dp genişlikte taşma yok', (tester) async {
    final y = _gonderi(sezon: 12, bolum: 24, tmdbId: 900, takipEdiyorum: false)
      ..['kullanici_adi'] = 'cokuzunbirkullaniciadi';
    await _kur(tester, y, ekran: const Size(360, 780));
    expect(tester.takeException(), isNull);
    expect(find.text('S12B24'), findsOneWidget);
    expect(find.text('Posterli Dizi'), findsOneWidget);
    expect(find.text('Takip Et'), findsOneWidget);
  });
}
