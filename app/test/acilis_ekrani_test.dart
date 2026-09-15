import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/acilis.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AÇILIŞ VİTRİNİ (15 Eyl 2026) — oturumsuz kök sayfa.
///
/// Kilitlenen davranış: başlık ve eylemler çizilir; "Ücretsiz başla" ve
/// "Giriş yap" `/giris`e, "Keşfet'e göz at" `/kesfet`e GİDER (go, push
/// değil: vitrin geçmişte kalmasın); afiş duvarı trend uçlarından beslenir
/// ve ağ hatasında sayfa çökmez (iskelet kalır). Dar ve geniş düzen ayrı
/// ölçülür — masaüstünde üst çubukta ikinci bir "başla" düğmesi vardır.

/// Afiş yolları GERÇEK ağa çıkmasın diye görsel yüklenmez; yalnız hücre
/// sayısı ve yol listesi ölçülür (CachedNetworkImage testte ağa çıkardı).
http.Client _sahteIstemci({bool hata = false, List<String>? kayit}) =>
    MockClient((istek) async {
      kayit?.add(istek.url.path);
      if (hata) return http.Response('kapali', 503);
      final tv = istek.url.path.contains('/trending/tv');
      return http.Response(
        jsonEncode({
          'results': [
            for (var i = 0; i < 8; i++)
              {'id': (tv ? 100 : 200) + i, 'poster_path': null},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

Future<GoRouter> _kur(
  WidgetTester tester, {
  Size boyut = const Size(400, 900),
  bool hata = false,
  List<String>? kayit,
}) async {
  tester.view.physicalSize = boyut;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  Api.istemci = _sahteIstemci(hata: hata, kayit: kayit);
  final oturum = Oturum();
  final y = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const AcilisEkrani()),
      GoRoute(path: '/giris', builder: (_, __) => const Text('GIRIS')),
      GoRoute(path: '/kesfet', builder: (_, __) => const Text('KESFET')),
      GoRoute(path: '/gizlilik', builder: (_, __) => const Text('GIZLILIK')),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: oturum,
      child: MaterialApp.router(routerConfig: y, theme: diziTema(acik: false)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return y;
}

Future<void> _dokun(WidgetTester tester, Key anahtar) async {
  await tester.ensureVisible(find.byKey(anahtar));
  await tester.tap(find.byKey(anahtar));
  // Sayfa geçişi bitene kadar bekle: çıkan sayfa animasyon boyunca ağaçta
  // kalır, aynı anahtar iki kez bulunurdu.
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dar ekran: başlık, eylemler ve afiş duvarı çizilir', (
    tester,
  ) async {
    final kayit = <String>[];
    await _kur(tester, kayit: kayit);

    expect(find.text('İzlediğin her şeyi tek yerde takip et'), findsOneWidget);
    expect(find.byKey(const Key('acilis-basla')), findsOneWidget);
    expect(find.byKey(const Key('acilis-kesfet')), findsOneWidget);
    expect(find.byKey(const Key('acilis-giris')), findsOneWidget);
    // Telefonda üst çubukta ikinci "başla" YOK (yer dar, kahramandaki yeter).
    expect(find.byKey(const Key('acilis-basla-ust')), findsNothing);
    expect(find.byKey(const Key('acilis-afis-duvari')), findsOneWidget);
    // İki trend ucu da soruldu.
    expect(kayit.where((y) => y.contains('/trending/')).length, 2);
  });

  testWidgets('geniş ekran: üst çubukta da başla düğmesi var', (tester) async {
    await _kur(tester, boyut: const Size(1300, 900));
    expect(find.byKey(const Key('acilis-basla-ust')), findsOneWidget);
    expect(find.byKey(const Key('acilis-basla')), findsOneWidget);
    // Altı özellik kartı da görünür.
    expect(find.text('Bölüm bölüm takip'), findsOneWidget);
    expect(find.text('Birlikte izle'), findsOneWidget);
  });

  testWidgets('"Ücretsiz başla" ve "Giriş yap" giriş ekranına GİDER', (
    tester,
  ) async {
    final y = await _kur(tester);
    await _dokun(tester, const Key('acilis-basla'));
    expect(y.routerDelegate.currentConfiguration.uri.path, '/giris');
    expect(find.text('GIRIS'), findsOneWidget);

    y.go('/');
    await tester.pumpAndSettle();
    await _dokun(tester, const Key('acilis-giris'));
    expect(y.routerDelegate.currentConfiguration.uri.path, '/giris');
  });

  testWidgets('"Keşfet\'e göz at" keşfete gider, vitrin geçmişte kalmaz', (
    tester,
  ) async {
    final y = await _kur(tester);
    await _dokun(tester, const Key('acilis-kesfet'));
    expect(y.routerDelegate.currentConfiguration.uri.path, '/kesfet');
    expect(find.text('KESFET'), findsOneWidget);
    // `go` kullanıldı: yığında vitrin yok, geri dönülecek sayfa yok.
    expect(y.canPop(), isFalse);
  });

  testWidgets('trend ucu çökerse sayfa yine çizilir (iskelet)', (tester) async {
    await _kur(tester, hata: true);
    expect(tester.takeException(), isNull);
    expect(find.text('İzlediğin her şeyi tek yerde takip et'), findsOneWidget);
    expect(find.byKey(const Key('acilis-afis-duvari')), findsOneWidget);
  });
}
