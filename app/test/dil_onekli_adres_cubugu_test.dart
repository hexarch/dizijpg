import 'package:dizijpg/dil_onekli_adres.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// WEB'DE DİL ÖNEKİ ADRES ÇUBUĞUNDA KALIR  (5 Eyl 2026)
///
/// Kullanıcı kararı: `/de` açılınca Almanca Keşfet görünsün ve adres `/de`
/// kalsın; dizi sayfası `/de/icerik/tv/2098` olsun. Bot ile insan aynı
/// adreste aynı sayfayı görsün. Mekanizma `dil_onekli_adres.dart`.
///
/// Rota ağacı BİLEREK küçük ve sahte: ölçüm yalnız ayrıştırıcının iki yönüne
/// bakar (gelen adres → öneksiz rota, giden konum → önekli adres). Gerçek
/// rota ağacının dil önekiyle açılması `yenileme_ayni_sayfa_test.dart`
/// "platform rotasıyken" grubunda kilitli.
GoRouter _sahteRota() => GoRouter(
  initialLocation: '/kesfet',
  routes: [
    GoRoute(path: '/kesfet', builder: (_, _) => const Text('kesfet')),
    GoRoute(path: '/giris', builder: (_, _) => const Text('giris')),
    GoRoute(
      path: '/icerik/:tur/:id',
      builder: (_, s) => Text('icerik ${s.pathParameters['id']}'),
    ),
  ],
);

/// Adres çubuğuna yazılacak konum: Router'ın `restoreRouteInformation` yolu.
String adresCubugu(GoRouter y, DilOnekliRotaAyristirici a) =>
    a
        .restoreRouteInformation(y.routerDelegate.currentConfiguration)
        ?.uri
        .toString() ??
    '';

Future<GoRouter> _kur(
  WidgetTester tester,
  DilOnekliRotaAyristirici Function(GoRouter) sar,
) async {
  final y = _sahteRota();
  final a = sar(y);
  await tester.pumpWidget(
    MaterialApp.router(
      routeInformationProvider: y.routeInformationProvider,
      routeInformationParser: a,
      routerDelegate: y.routerDelegate,
      backButtonDispatcher: y.backButtonDispatcher,
    ),
  );
  await tester.pumpAndSettle();
  return y;
}

void main() {
  group('dilOnekiEkle', () {
    test('kök ve /kesfet kanonik dil ana sayfasına, derin yol öneke gider', () {
      expect(dilOnekiEkle(Uri.parse('/kesfet'), 'de').toString(), '/de');
      expect(dilOnekiEkle(Uri.parse('/'), 'ja').toString(), '/ja');
      expect(
        dilOnekiEkle(Uri.parse('/icerik/tv/2098'), 'de').toString(),
        '/de/icerik/tv/2098',
      );
      expect(
        dilOnekiEkle(Uri.parse('/icerik/tv/1396?tur=tv'), 'es').toString(),
        '/es/icerik/tv/1396?tur=tv',
        reason: 'sorgu korunmalı',
      );
      expect(
        dilOnekiEkle(
          Uri.parse('/giris?donus=%2Ficerik%2Ftv%2F1'),
          'fr',
        ).toString(),
        '/fr/giris?donus=%2Ficerik%2Ftv%2F1',
      );
    });

    test('tr, bilinmeyen kod ve ZATEN önekli adres DOKUNULMAZ', () {
      expect(dilOnekiEkle(Uri.parse('/kesfet'), 'tr'), isNull);
      expect(dilOnekiEkle(Uri.parse('/icerik/tv/1'), 'zz'), isNull);
      expect(dilOnekiEkle(Uri.parse('/de/icerik/tv/1'), 'de'), isNull);
      expect(dilOnekiEkle(Uri.parse('/de'), 'de'), isNull);
    });
  });

  testWidgets('WEB + Almanca: adres çubuğu /de ve /de/icerik/…, rota öneksiz', (
    tester,
  ) async {
    late DilOnekliRotaAyristirici a;
    final y = await _kur(
      tester,
      (y) => a = DilOnekliRotaAyristirici(
        y.routeInformationParser,
        dil: () => 'de',
        web: true,
      ),
    );
    expect(adresCubugu(y, a), '/de', reason: 'Keşfet Almancada /de görünür');
    expect(y.routerDelegate.currentConfiguration.uri.path, '/kesfet');

    y.go('/icerik/tv/2098');
    await tester.pumpAndSettle();
    expect(find.text('icerik 2098'), findsOneWidget);
    expect(adresCubugu(y, a), '/de/icerik/tv/2098');
    expect(
      y.routerDelegate.currentConfiguration.uri.path,
      '/icerik/tv/2098',
      reason:
          'rota ağacı öneksiz kalır; currentConfiguration okuyanlar bozulmaz',
    );
  });

  testWidgets('WEB: gelen önekli adres öneksiz rotaya açılır (çift önek yok)', (
    tester,
  ) async {
    late DilOnekliRotaAyristirici a;
    final y = await _kur(
      tester,
      (y) => a = DilOnekliRotaAyristirici(
        y.routeInformationParser,
        dil: () => 'de',
        web: true,
      ),
    );
    y.go('/de/icerik/tv/7');
    await tester.pumpAndSettle();
    expect(find.text('icerik 7'), findsOneWidget);
    expect(y.routerDelegate.currentConfiguration.uri.path, '/icerik/tv/7');
    expect(adresCubugu(y, a), '/de/icerik/tv/7');

    y.go('/de');
    await tester.pumpAndSettle();
    expect(find.text('kesfet'), findsOneWidget);
    expect(adresCubugu(y, a), '/de');
  });

  testWidgets('Türkçe: önek YOK (kökte yaşar)', (tester) async {
    late DilOnekliRotaAyristirici a;
    final y = await _kur(
      tester,
      (y) => a = DilOnekliRotaAyristirici(
        y.routeInformationParser,
        dil: () => 'tr',
        web: true,
      ),
    );
    y.go('/icerik/tv/2098');
    await tester.pumpAndSettle();
    expect(adresCubugu(y, a), '/icerik/tv/2098');
  });

  testWidgets('MOBİL: giden yön dokunmaz, gelen önek yine düşer', (
    tester,
  ) async {
    late DilOnekliRotaAyristirici a;
    final y = await _kur(
      tester,
      (y) => a = DilOnekliRotaAyristirici(
        y.routeInformationParser,
        dil: () => 'de',
        web: false,
      ),
    );
    y.go('/ja/icerik/tv/3');
    await tester.pumpAndSettle();
    expect(find.text('icerik 3'), findsOneWidget);
    expect(adresCubugu(y, a), '/icerik/tv/3');
  });
}
