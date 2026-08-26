// OTURUM DÜŞTÜ — 401 alınca otomatik çıkış (26 Ağu 2026, kullanıcı bildirdi).
//
// İSTEK (birebir): "dün tüm oturumları kapattık ama oturumdan atmak yerine
// bağlantı koptu hatası veriyor, neden oturumdan otomatik çıkış yapmadı,
// webde ve android tarafında da aynı mı acaba"
//
// Aynıydı — `api.dart` iki platformda ORTAK ve 401 hiçbir yerde özel
// işlenmiyordu. Kilitlenen davranışlar:
//   1) Token VARKEN gelen 401 `Api.oturumDustu` bayrağını kaldırır.
//   2) Token YOKKEN gelen 401 bayrağı KALDIRMAZ (giriş ekranındaki
//      ziyaretçiye "oturumun sonlandı" demek yanlış olurdu).
//   3) 401 dışındaki hatalar (403/500) bayrağı kaldırmaz — "bağlantı hatası"
//      ile "oturum öldü" ayrı şeylerdir.
//   4) Katman bayrağı görünce açıklayıcı diyaloğu gösterir ve oturumu kapatır.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/oturum_dustu.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Client _istemci(int kod) => MockClient((istek) async {
  if (istek.url.path.endsWith('/cikis')) {
    return http.Response(
      '{}',
      200,
      headers: {'content-type': 'application/json'},
    );
  }
  return http.Response(
    jsonEncode({
      'hata': kod == 401 ? 'Oturum sonlandı, tekrar giriş yap' : 'olmadı',
    }),
    kod,
    headers: {'content-type': 'application/json'},
  );
});

void main() {
  setUp(() => Api.oturumDustuTemizle());
  tearDown(() => Api.oturumDustuTemizle());

  group('401 → oturum düştü bayrağı', () {
    test('TOKEN VARKEN gelen 401 bayrağı kaldırır', () async {
      SharedPreferences.setMockInitialValues({'token': 'eski-token'});
      await Api.tokenYukle();
      Api.istemci = _istemci(401);

      expect(Api.oturumDustu.value, isFalse);
      await expectLater(Api.get('/benim'), throwsA(isA<ApiHata>()));
      expect(
        Api.oturumDustu.value,
        isTrue,
        reason: 'sunucu token\'ı reddetti; istemci oturumu ölü saymalı',
      );
    });

    test('TOKEN YOKKEN gelen 401 bayrağı KALDIRMAZ', () async {
      SharedPreferences.setMockInitialValues({});
      await Api.tokenYukle();
      Api.istemci = _istemci(401);

      await expectLater(Api.get('/benim'), throwsA(isA<ApiHata>()));
      expect(
        Api.oturumDustu.value,
        isFalse,
        reason: 'ziyaretçiye "oturumun sonlandı" demek anlamsız',
      );
    });

    test('403 ve 500 bayrağı KALDIRMAZ', () async {
      SharedPreferences.setMockInitialValues({'token': 'gecerli'});
      await Api.tokenYukle();

      for (final kod in [403, 500]) {
        Api.oturumDustuTemizle();
        Api.istemci = _istemci(kod);
        await expectLater(Api.get('/benim'), throwsA(isA<ApiHata>()));
        expect(
          Api.oturumDustu.value,
          isFalse,
          reason: '$kod oturumun öldüğü anlamına gelmez',
        );
      }
    });
  });

  testWidgets('katman bayrağı görünce diyaloğu gösterir ve çıkış yapar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'token': 'eski',
      'kullanici': jsonEncode({'id': 1, 'kullanici_adi': 'test'}),
    });
    await Api.tokenYukle();
    Api.istemci = _istemci(401);
    final oturum = Oturum();
    await oturum.yukle();
    expect(oturum.girisli, isTrue);

    final yonlendirici = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const OturumDustuKatmani(child: Scaffold(body: Text('içerik'))),
        ),
        GoRoute(path: '/giris', builder: (_, _) => const Text('giriş ekranı')),
      ],
    );
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
    expect(find.text('içerik'), findsOneWidget);

    // Sunucu token'ı reddetti.
    Api.oturumDustu.value = true;
    await tester.pumpAndSettle();

    // SESSİZ ÇIKIŞ YOK: önce sebebi söyleyen katman.
    expect(find.text('Oturumun sonlandı'), findsOneWidget);
    // Arkadaki ekran dokunulamaz olmalı (her dokunuş yeni 401 üretirdi).
    expect(find.byType(ModalBarrier), findsWidgets);

    await tester.tap(find.text('Giriş Yap'));
    // `pumpAndSettle` KULLANILMAZ: çıkış sürerken butonda sonsuz dönen bir
    // ilerleme göstergesi var, settle asla gerçekleşmez (ilk sürümde tam
    // burada zaman aşımına uğradı).
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Yerel oturum GERÇEKTEN temizlendi ve giriş ekranına gidildi.
    expect(oturum.girisli, isFalse);
    expect(Api.girisli, isFalse);
    expect(find.text('giriş ekranı'), findsOneWidget);
  });
}
