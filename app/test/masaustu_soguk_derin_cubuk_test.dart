import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/dil_onekli_adres.dart';
import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SOĞUK AÇILAN DERİN SAYFADAN MASAÜSTÜ ÇUBUĞU  (5 Eyl 2026)
///
/// Kullanıcı: "/de'de takvime tıklayınca takvim açılmıyor." Canlıda ölçüldü:
/// tarayıcıya DOĞRUDAN `/de/icerik/tv/2098` (ve Türkçe `/icerik/tv/2098`)
/// yazılıp açılınca beşli çubuktaki Takvim/Akış/Mesajlar/Ana Sayfa
/// düğmelerinin hiçbiri bir şey yapmıyor. Kabuk sayfasından (`/de`) gelince
/// aynı düğme çalışıyor.
///
/// `masaustu_kalici_cubuk_test.dart`teki "dizi sayfasından takvim sekmesine
/// gidilir" testi bunu YAKALAMIYOR: orada uygulama önce başlangıç rotasında
/// (kabuk) kuruluyor, dizi sayfasına SONRA `go` ile gidiliyor. Bu dosya
/// kabuğun HİÇ kurulmadığı soğuk derin açılışı ölçer — üretimdeki
/// `main.dart` bağlantısıyla (dört parça + `DilOnekliRotaAyristirici`).
const double _genisG = 1440, _genisY = 900;

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.startsWith('/api/tmdb/')) {
      return _json({
        'id': 1396,
        'name': 'Breaking Bad',
        'title': 'Breaking Bad',
        'poster_path': null,
        'overview': '',
      });
    }
    return _json(const <String, dynamic>{});
  });
}

Future<void> _pompala(WidgetTester tester) async {
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  while (tester.takeException() != null) {}
}

/// Tarayıcı [adres]te SOĞUK açıldı: kabuk yok, ilk sayfa derin sayfa.
Future<GoRouterKurulum> _sogukAc(
  WidgetTester tester,
  String adres, {
  required bool sarili,
}) async {
  tester.view.physicalSize = const Size(_genisG, _genisY);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
  Oturum.karsilamaGerekli = false;
  final oturum = Oturum();
  await oturum.yukle();
  final y = yonlendiriciOlustur(
    oturum,
    tarayiciAdresi: Uri.parse('https://dizijpg.com$adres'),
  );
  addTearDown(y.dispose);
  final a = DilOnekliRotaAyristirici(
    y.routeInformationParser,
    dil: () => 'de',
    web: true,
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: sarili
          ? MaterialApp.router(
              routeInformationProvider: y.routeInformationProvider,
              routeInformationParser: a,
              routerDelegate: y.routerDelegate,
              backButtonDispatcher: y.backButtonDispatcher,
              theme: diziTema(acik: false),
            )
          : MaterialApp.router(routerConfig: y, theme: diziTema(acik: false)),
    ),
  );
  await _pompala(tester);
  return GoRouterKurulum(y, a);
}

class GoRouterKurulum {
  final GoRouter y;
  final DilOnekliRotaAyristirici a;
  GoRouterKurulum(this.y, this.a);
  String get konum => y.routerDelegate.currentConfiguration.uri.toString();
}

void main() {
  setUp(_sunucu);

  for (final sarili in [false, true]) {
    final etiket = sarili ? 'sarılı ayrıştırıcı (üretim)' : 'routerConfig';
    testWidgets(
      '$etiket: soğuk /icerik/tv/1396 → Takvim düğmesi takvimi açar',
      (tester) async {
        final k = await _sogukAc(tester, '/icerik/tv/1396', sarili: sarili);
        expect(k.konum, '/icerik/tv/1396');
        expect(
          find.byType(KabukEkrani),
          findsNothing,
          reason: 'soğuk: kabuk yok',
        );

        await tester.tap(find.byIcon(Icons.calendar_month_outlined));
        await _pompala(tester);

        expect(
          k.konum,
          '/takvim',
          reason: 'Takvim düğmesi rotayı değiştirmedi',
        );
        expect(find.byType(KabukEkrani), findsOneWidget);
      },
    );
  }

  testWidgets(
    'sarılı: soğuk /de/icerik/tv/1396 → Takvim → /takvim, adres /de/takvim',
    (tester) async {
      final k = await _sogukAc(tester, '/de/icerik/tv/1396', sarili: true);
      expect(k.konum, '/icerik/tv/1396');
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await _pompala(tester);
      expect(k.konum, '/takvim');
      expect(
        k.a
            .restoreRouteInformation(k.y.routerDelegate.currentConfiguration)
            ?.uri
            .toString(),
        '/de/takvim',
      );
    },
  );
}
