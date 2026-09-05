// SOHBETTE GERİ TUŞU + EMOJİ PANELİ (5 Eyl 2026, Galaxy S24'te görüldü:
// panel açıkken geri tuşu uygulamayı kapattı).
//
// Sohbet KABUĞUN İÇİNDEKİ (StatefulShellRoute) dalda `push` ile açılır; yani
// PopScope iç içe bir Navigator'da durur. Sistem geri tuşu Flutter'a
// `handlePopRoute` ile gelir → GoRouter `popRoute` → iç navigator
// `maybePop`. Kilitlenen sıra:
//   1. panel açık + geri → panel kapanır, sohbet KALIR
//   2. panel kapalı + geri → sohbet kapanır, liste görünür (uygulama değil)
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/emoji_paneli.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (yol.startsWith('/mesajlar/')) {
      return _json({
        'mesajlar': [
          {
            'id': 1,
            'metin': 'selam',
            'tarih': '2026-08-05T10:00:00Z',
            'gonderen_id': 2,
            'tepkiler': const [],
          },
        ],
        'icerikler': const <String, dynamic>{},
        'gonderiler': const <String, dynamic>{},
        'partner': const {'son_gorulme': null, 'avatar': null},
        'yaziyor': false,
      });
    }
    return _json(const {});
  });
}

void main() {
  testWidgets('kabuk içinde: geri önce paneli kapatır, sonra sohbeti', (
    tester,
  ) async {
    _sunucu();
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final oturum = Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'};
    final yonlendirici = GoRouter(
      initialLocation: '/sohbetler',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, kabuk) => Scaffold(body: kabuk),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/sohbetler',
                  builder: (_, _) => const Text('LİSTE'),
                ),
                GoRoute(
                  path: '/sohbet/:ad',
                  builder: (_, s) =>
                      SohbetEkrani(kullaniciAdi: s.pathParameters['ad']!),
                ),
              ],
            ),
          ],
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
    yonlendirici.push('/sohbet/ayse');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SohbetEkrani), findsOneWidget);

    await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(EmojiPaneli), findsOneWidget);

    // 1) Sistem geri tuşu: panel kapanır, sohbet kalır.
    final ilk = await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      ilk,
      isTrue,
      reason: 'geri Flutter içinde işlenmeli (uygulama kapanmaz)',
    );
    expect(find.byType(EmojiPaneli), findsNothing);
    expect(find.byType(SohbetEkrani), findsOneWidget);

    // 2) İkinci geri: sohbet kapanır, liste görünür.
    final ikinci = await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(ikinci, isTrue);
    expect(find.byType(SohbetEkrani), findsNothing);
    expect(find.text('LİSTE'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
