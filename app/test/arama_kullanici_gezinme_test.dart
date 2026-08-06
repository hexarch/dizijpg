import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/arama_cubugu.dart';
import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
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

/// KULLANICI BİLDİRİMİ (6 Ağu 2026, birebir):
///   "uygulamada arama kısmına alcelik yazıyorum, gelen kullanıcıya
///    tıklıyorum, alcelik profili açılmıyor, simsiyah ekran açılıyor"
///
/// KÖK NEDEN: mobilde arama TAM EKRAN ve KÖK rotadır ([tamAramaYolu]);
/// `/kullanici/:ad` ise kabuğun (StatefulShellRoute) İÇİNDE yaşar.
/// [kullaniciyaGit]'in "kabuk dışındayım" listesinde `/tam-arama` YOKTU, bu
/// yüzden oradan `push` ediliyordu: kabuk İKİNCİ kez kuruluyor, dal
/// GlobalKey'leri çakışıyor ve Flutter hata widget'ı (siyah ekran) basıyor.
///
/// Test hem istisnayı hem de profilin GÖRÜNÜR olduğunu kilitler.

/// 600 dp: hâlâ MOBİL düzen ([masaustuEsigi] 900), ama profil sekme
/// başlıkları test yazı tipiyle (kare glifler) taşmıyor — ölçtüğümüz şey
/// gezinme, düzen değil.
const double _darG = 600, _darY = 1400;

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.startsWith('/api/kullanici-ara')) {
      return _json({
        'kullanicilar': [
          {
            'id': 3,
            'kullanici_adi': 'alcelik',
            'avatar': null,
            'bio': 'merhaba',
          },
        ],
      });
    }
    if (yol.startsWith('/api/profil/')) {
      return _json({
        'kullanici_adi': yol.split('/').last,
        'avatar': null,
        'kapak': null,
        'ben_mi': false,
        'takip_ediyorum': false,
        'istatistik': {'takipci': 1, 'takip': 2, 'yorum': 0},
        'yorumlar': <dynamic>[],
        'listeler': <dynamic>[],
        'izlenenler': <dynamic>[],
      });
    }
    if (yol.startsWith('/api/ara')) {
      return _json({'results': <dynamic>[]});
    }
    if (yol == '/api/bildirimler' || yol == '/api/sohbetler') {
      return _json({'okunmamis': 0, 'bildirimler': <dynamic>[]});
    }
    return _json(const <String, dynamic>{});
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

/// Kullanıcının yaptığı akış: arama kutusunu aç, "alcelik" yaz, sonucu bekle.
Future<void> _aramadaAra(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('arama-ac')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('tam-ekran-arama')), findsOneWidget);

  await tester.enterText(find.byType(TextField), 'alcelik');
  await tester.pump(const Duration(milliseconds: 500)); // gecikme dolsun
  await _bekle(tester);
  expect(find.text('@alcelik'), findsOneWidget, reason: 'sonuç listelenmeli');
}

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _sunucu();
  });

  void ekran(WidgetTester tester, [double g = _darG, double y = _darY]) {
    tester.view.physicalSize = Size(g, y);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('tam ekran aramadan kullanıcıya dokununca PROFİL açılır', (
    tester,
  ) async {
    ekran(tester);
    final yonlendirici = await _uygulama(tester, '/kesfet');
    await _aramadaAra(tester);

    await tester.tap(find.text('@alcelik'));
    await _bekle(tester, 20);

    expect(
      tester.takeException(),
      isNull,
      reason: 'kabuk ikinci kez kurulursa GlobalKey çakışır → siyah ekran',
    );
    expect(find.byType(KullaniciProfilEkrani), findsOneWidget);
    expect(
      find.byType(KullaniciProfilEkrani).hitTestable(),
      findsOneWidget,
      reason: 'profil GÖRÜNÜR olmalı',
    );
    // Arama kapanmalı, kabuk (alt gezinme) geri gelmeli.
    expect(find.byKey(const Key('tam-ekran-arama')), findsNothing);
    expect(find.byType(KabukEkrani), findsOneWidget);
    // Kabuk TEK kez kurulmuş olmalı (ikincisi = anahtar çakışması = siyah ekran)
    expect(
      yonlendirici.routerDelegate.currentConfiguration.matches
          .whereType<ShellRouteMatch>()
          .length,
      1,
    );
  });

  testWidgets('profilden geri dönünce arama DEĞİL, kabuk kalır', (
    tester,
  ) async {
    ekran(tester);
    await _uygulama(tester, '/kesfet');
    await _aramadaAra(tester);
    await tester.tap(find.text('@alcelik'));
    await _bekle(tester, 20);
    expect(find.byType(KullaniciProfilEkrani), findsOneWidget);

    // Android sistem geri tuşu / tarayıcı geri oku.
    await tester.binding.handlePopRoute();
    await _bekle(tester, 20);

    expect(tester.takeException(), isNull);
    expect(find.byType(KullaniciProfilEkrani), findsNothing);
    expect(
      find.byKey(const Key('tam-ekran-arama')),
      findsNothing,
      reason: 'kapanmış arama dirilmemeli',
    );
    expect(find.byType(KabukEkrani), findsOneWidget);
  });

  testWidgets('masaüstü satır-içi aramadan da profil açılır (regresyon)', (
    tester,
  ) async {
    ekran(tester, 1440, 900);
    await _uygulama(tester, '/kesfet');

    await tester.enterText(find.byType(TextField).first, 'alcelik');
    await tester.pump(const Duration(milliseconds: 500));
    await _bekle(tester);
    expect(find.text('@alcelik'), findsOneWidget);

    await tester.tap(find.text('@alcelik'));
    await _bekle(tester, 20);

    expect(tester.takeException(), isNull);
    expect(find.byType(KullaniciProfilEkrani), findsOneWidget);
    expect(find.byType(KullaniciProfilEkrani).hitTestable(), findsOneWidget);
  });
}
