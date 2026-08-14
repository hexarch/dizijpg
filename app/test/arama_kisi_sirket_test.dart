import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/arama.dart';
import 'package:dizijpg/ekranlar/arama_cubugu.dart';
import 'package:dizijpg/ekranlar/kisi.dart';
import 'package:dizijpg/ekranlar/sirket.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Arama: şirket satırı `/sirket/:id`, kişi satırı meslek alt yazısı + `/kisi/:id`.
/// Dizi/film ve kullanıcı araması gerilemesin.

const Size _mobil = Size(600, 1400);
const Size _masa = Size(1440, 900);

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _sirket({int id = 7899, String ad = 'Cartoon Network'}) =>
    {
      'id': id,
      'media_type': 'company',
      'name': ad,
      'logo_path': null,
      'origin_country': 'US',
    };

Map<String, dynamic> _kisi({
  int id = 66633,
  String ad = 'Vince Gilligan',
  String bolum = 'Directing',
}) => {
  'id': id,
  'media_type': 'person',
  'name': ad,
  'profile_path': '/vince.jpg',
  'known_for_department': bolum,
  'known_for': [
    {'name': 'Breaking Bad', 'media_type': 'tv'},
  ],
};

Map<String, dynamic> _dizi() => {
  'id': 1396,
  'media_type': 'tv',
  'name': 'Breaking Bad',
  'poster_path': '/bb.jpg',
  'first_air_date': '2008-01-20',
};

void _sunucu({
  List<Map<String, dynamic>> ara = const [],
  List<Map<String, dynamic>> kullanicilar = const [],
}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (yol.startsWith('/ara')) {
      return _json({'results': ara});
    }
    if (yol.startsWith('/kullanici-ara')) {
      return _json({'kullanicilar': kullanicilar});
    }
    if (yol.startsWith('/tmdb/company/')) {
      return _json({
        'id': 7899,
        'name': 'Cartoon Network',
        'logo_path': null,
        'origin_country': 'US',
        'headquarters': '',
      });
    }
    if (yol.startsWith('/tmdb/discover/')) {
      return _json({'results': <dynamic>[]});
    }
    if (yol.startsWith('/tmdb/person/') || yol.startsWith('/kisi-ozet/')) {
      return _json({
        'id': 66633,
        'name': 'Vince Gilligan',
        'biography': '',
        'profile_path': null,
        'combined_credits': {'cast': <dynamic>[], 'crew': <dynamic>[]},
      });
    }
    if (yol.startsWith('/tmdb/')) {
      return _json(_dizi());
    }
    if (yol == '/bildirimler' || yol == '/sohbetler') {
      return _json({'okunmamis': 0, 'bildirimler': <dynamic>[]});
    }
    if (yol.startsWith('/profil/')) {
      return _json({
        'kullanici_adi': yol.split('/').last,
        'avatar': null,
        'kapak': null,
        'ben_mi': false,
        'takip_ediyorum': false,
        'istatistik': {'takipci': 0, 'takip': 0, 'yorum': 0},
        'yorumlar': <dynamic>[],
        'listeler': <dynamic>[],
        'izlenenler': <dynamic>[],
      });
    }
    return _json(<String, dynamic>{});
  });
}

Future<GoRouter> _uygulama(WidgetTester tester, String bas) async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
  Oturum.karsilamaGerekli = false;
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = yonlendiriciOlustur(oturum);
  addTearDown(yonlendirici.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: yonlendirici,
        theme: diziTema(acik: false),
      ),
    ),
  );
  await tester.pump();
  yonlendirici.go(bas);
  await _bekle(tester);
  return yonlendirici;
}

Future<void> _bekle(WidgetTester tester, [int kare = 14]) async {
  for (var i = 0; i < kare; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void _ekran(WidgetTester tester, Size boyut) {
  tester.view.physicalSize = boyut;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String _konum(GoRouter y) =>
    y.routerDelegate.currentConfiguration.matches.last.matchedLocation;

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  test('kisiAramaAltYazi: Directing→Yönetmen, Writing→Senarist', () {
    expect(kisiAramaAltYazi(_kisi()), 'Yönetmen · Breaking Bad');
    expect(
      kisiAramaAltYazi(_kisi(bolum: 'Writing')),
      'Senarist · Breaking Bad',
    );
    expect(
      kisiAramaAltYazi(_kisi(bolum: 'Acting', ad: 'Bryan Cranston')),
      'Oyuncular · Breaking Bad',
    );
  });

  test(
    'aramaSirketListesi company alır, poster süzgeci kişiyi/şirketi ayırır',
    () {
      final ham = <dynamic>[_sirket(), _kisi(), _dizi()];
      expect(aramaSirketListesi(ham).single['name'], 'Cartoon Network');
      expect(aramaKisiListesi(ham).single['name'], 'Vince Gilligan');
      expect(aramaIcerikListesi(ham).single['name'], 'Breaking Bad');
      // Eski istemci kalıbı: company poster_path yok → dizi/film listesinde değil.
      expect(
        aramaIcerikListesi(ham).where((r) => r['media_type'] == 'company'),
        isEmpty,
      );
    },
  );

  testWidgets('cartoon network: şirket satırı çizilir, dokununca /sirket/:id', (
    tester,
  ) async {
    _ekran(tester, _mobil);
    _sunucu(
      ara: [_sirket(), _dizi()],
      kullanicilar: [
        {'kullanici_adi': 'alcelik', 'avatar': null, 'bio': 'merhaba'},
      ],
    );
    final y = await _uygulama(tester, '/kesfet');
    await tester.tap(find.byKey(const Key('arama-ac')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cartoon network');
    await tester.pump(const Duration(milliseconds: 500));
    await _bekle(tester);

    expect(find.text('Şirketler'), findsOneWidget);
    expect(find.text('Cartoon Network'), findsWidgets);
    expect(find.text('Dizi ve Filmler'), findsOneWidget);
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('@alcelik'), findsOneWidget);

    final sirketSatiri = tester.getRect(
      find.byKey(const Key('arama-sirket-7899')),
    );
    expect(sirketSatiri.height, greaterThanOrEqualTo(44));

    await tester.tap(find.byKey(const Key('arama-sirket-7899')));
    await _bekle(tester, 20);
    expect(_konum(y), '/sirket/7899');
    expect(find.byType(SirketEkrani), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vince gilligan: Yönetmen alt yazısı, dokununca /kisi/:id', (
    tester,
  ) async {
    _ekran(tester, _mobil);
    _sunucu(ara: [_kisi(), _dizi()]);
    final y = await _uygulama(tester, '/kesfet');
    await tester.tap(find.byKey(const Key('arama-ac')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'vince gilligan');
    await tester.pump(const Duration(milliseconds: 500));
    await _bekle(tester);

    expect(find.text('Kişiler'), findsOneWidget);
    expect(find.text('Vince Gilligan'), findsOneWidget);
    expect(find.text('Yönetmen · Breaking Bad'), findsOneWidget);
    expect(find.text('Breaking Bad'), findsWidgets);

    await tester.tap(find.byKey(const Key('arama-kisi-66633')));
    await _bekle(tester, 20);
    expect(_konum(y), '/kisi/66633');
    expect(find.byType(KisiEkrani), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('masaüstü satır-içi aramada da şirket açılır', (tester) async {
    _ekran(tester, _masa);
    _sunucu(ara: [_sirket()]);
    final y = await _uygulama(tester, '/kesfet');
    await tester.enterText(find.byType(TextField).first, 'cartoon network');
    await tester.pump(const Duration(milliseconds: 500));
    await _bekle(tester);
    expect(find.text('Cartoon Network'), findsWidgets);
    await tester.tap(find.byKey(const Key('arama-sirket-7899')));
    await _bekle(tester, 20);
    expect(_konum(y), '/sirket/7899');
    expect(find.byType(SirketEkrani), findsOneWidget);
  });

  testWidgets('AramaEkrani: şirket kutusu çizilir (aynı sözleşme)', (
    tester,
  ) async {
    _ekran(tester, _mobil);
    _sunucu(ara: [_sirket(), _dizi()]);
    SharedPreferences.setMockInitialValues({
      'token': 'sahte',
      'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
    });
    await Api.tokenYukle();
    await tester.pumpWidget(
      MaterialApp(theme: diziTema(acik: false), home: const AramaEkrani()),
    );
    await tester.enterText(find.byType(TextField), 'cartoon network');
    await tester.pump(const Duration(milliseconds: 500));
    await _bekle(tester);
    expect(find.text('Şirketler'), findsOneWidget);
    expect(find.text('Cartoon Network'), findsWidgets);
    expect(find.text('Breaking Bad'), findsOneWidget);
    final hedef = find.byKey(const Key('arama-sirket-7899'));
    expect(hedef, findsOneWidget);
    expect(hedef.hitTestable(), findsOneWidget);
    expect(tester.getSize(hedef).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(hedef).height, greaterThanOrEqualTo(44));
  });
}
