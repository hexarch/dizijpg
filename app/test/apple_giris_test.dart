import 'dart:async';
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/apple_kapisi.dart';
import 'package:dizijpg/ekranlar/giris.dart';
import 'package:dizijpg/google_kapisi.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// APPLE İLE GİRİŞ (10 Eyl 2026, App Store Guideline 4.8 reddi).
///
/// Apple: "Google varken eşdeğer bir giriş (Sign in with Apple) şart."
/// Bu testlerin kilitlediği şeyler:
///  1. Düğme YALNIZ iOS'ta çizilir (Android/web'de yok — orada Apple'ın web
///     akışı kurulmadı, ekranda ölü düğme durmamalı).
///  2. Dokununca kapıdan gelen kimlik `/auth/apple`e `kimlik`+`nonce` (+kod,
///     e-posta, ad) ile gider ve oturum açılır.
///  3. Kullanıcı Apple sayfasını kapatırsa (null) SESSİZ kalınır; sunucu ya da
///     Apple hatası ise kullanıcı MESAJ görür.
///  4. Nonce yardımcıları: ham nonce rastgele ve boş değil, özet 64 hex.

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _SahteGoogle implements GoogleKapisi {
  @override
  Widget? dugme(BuildContext context) => null;
  @override
  Stream<GoogleKimligi> get akis => const Stream.empty();
  @override
  Future<GoogleKimligi?> dokun() async => null;
  @override
  void birak() {}
}

class _SahteApple implements AppleKapisi {
  _SahteApple({this.kimlik, this.hata});
  final AppleKimligi? kimlik;
  final Object? hata;
  int dokunma = 0;

  @override
  Future<AppleKimligi?> dokun() async {
    dokunma++;
    if (hata != null) throw hata!;
    return kimlik;
  }
}

Future<void> _ekranCiz(
  WidgetTester tester, {
  required bool apple,
  AppleKapisi? kapi,
  List<Map<String, dynamic>>? gonderilen,
  int sunucuKodu = 200,
}) async {
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.endsWith('/auth/apple')) {
      gonderilen?.add(jsonDecode(istek.body) as Map<String, dynamic>);
      if (sunucuKodu != 200) {
        return _json({'hata': 'Apple doğrulaması başarısız'}, sunucuKodu);
      }
      return _json({
        'token': 'jwt-test',
        'kullanici': {
          'id': 7,
          'kullanici_adi': 'testkullanici',
          'email': 'test@dizijpg.com',
          'avatar': null,
          'misafir': false,
        },
        'yeni': false,
      });
    }
    return _json(const {});
  });
  addTearDown(() => Api.istemci = http.Client());
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => Oturum(),
      child: MaterialApp(
        home: GirisEkrani(
          web: false,
          googleKapisi: _SahteGoogle(),
          apple: apple,
          appleKapisi: kapi ?? _SahteApple(),
        ),
      ),
    ),
  );
  await tester.pump();
}

final _dugme = find.byKey(const Key('apple-dugmesi'));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Api.istemci = MockClient((_) async => _json(const {}));
  });
  tearDown(() => Api.istemci = http.Client());

  group('görünürlük', () {
    testWidgets('iOS: Apple düğmesi Google ile misafir arasında', (
      tester,
    ) async {
      await _ekranCiz(tester, apple: true);
      expect(_dugme, findsOneWidget);
      expect(find.text('Apple ile devam et'), findsOneWidget);
      expect(find.text('Google ile devam et'), findsOneWidget);
      expect(find.text('Misafir olarak devam et'), findsOneWidget);
      // Sıra: Google → Apple → Misafir (dikey konum artar).
      final g = tester.getTopLeft(find.text('Google ile devam et')).dy;
      final a = tester.getTopLeft(_dugme).dy;
      final m = tester.getTopLeft(find.text('Misafir olarak devam et')).dy;
      expect(g < a && a < m, isTrue);
    });

    testWidgets('Android/web: düğme YOK', (tester) async {
      await _ekranCiz(tester, apple: false);
      expect(_dugme, findsNothing);
      expect(find.text('Apple ile devam et'), findsNothing);
    });

    test('platform kararı: web → hayır', () {
      expect(appleGirisiUygun(web: true), isFalse);
    });

    testWidgets('platform kararı: iOS → evet, Android → hayır', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(appleGirisiUygun(web: false), isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(appleGirisiUygun(web: false), isFalse);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('akış', () {
    testWidgets('kimlik sunucuya kimlik+nonce+kod+email+ad ile gider', (
      tester,
    ) async {
      final gonderilen = <Map<String, dynamic>>[];
      final kapi = _SahteApple(
        kimlik: const AppleKimligi(
          identityToken: 'jwt-apple',
          nonce: 'ham-nonce',
          yetkiKodu: 'kod-1',
          email: 'gizli@privaterelay.appleid.com',
          ad: 'Ali Veli',
        ),
      );
      await _ekranCiz(tester, apple: true, kapi: kapi, gonderilen: gonderilen);

      await tester.tap(_dugme);
      await tester.pumpAndSettle();

      expect(kapi.dokunma, 1);
      expect(gonderilen, hasLength(1));
      final g = gonderilen.single;
      expect(g['kimlik'], 'jwt-apple');
      expect(g['nonce'], 'ham-nonce');
      expect(g['kod'], 'kod-1');
      expect(g['email'], 'gizli@privaterelay.appleid.com');
      expect(g['ad'], 'Ali Veli');
    });

    testWidgets('ikinci girişte email/ad yoksa anahtarlar GÖNDERİLMEZ', (
      tester,
    ) async {
      final gonderilen = <Map<String, dynamic>>[];
      final kapi = _SahteApple(
        kimlik: const AppleKimligi(identityToken: 'jwt', nonce: 'n'),
      );
      await _ekranCiz(tester, apple: true, kapi: kapi, gonderilen: gonderilen);
      await tester.tap(_dugme);
      await tester.pumpAndSettle();
      final g = gonderilen.single;
      expect(g.containsKey('email'), isFalse);
      expect(g.containsKey('ad'), isFalse);
      expect(g.containsKey('kod'), isFalse);
    });

    testWidgets('kullanıcı vazgeçerse (null) sessiz: istek yok, mesaj yok', (
      tester,
    ) async {
      final gonderilen = <Map<String, dynamic>>[];
      await _ekranCiz(
        tester,
        apple: true,
        kapi: _SahteApple(),
        gonderilen: gonderilen,
      );
      await tester.tap(_dugme);
      await tester.pumpAndSettle();
      expect(gonderilen, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('sunucu reddederse kullanıcı sunucu MESAJINI görür', (
      tester,
    ) async {
      final kapi = _SahteApple(
        kimlik: const AppleKimligi(identityToken: 'jwt', nonce: 'n'),
      );
      await _ekranCiz(tester, apple: true, kapi: kapi, sunucuKodu: 401);
      await tester.tap(_dugme);
      await tester.pumpAndSettle();
      expect(find.text('Apple doğrulaması başarısız'), findsOneWidget);
    });

    testWidgets('Apple tarafı hata verirse genel mesaj', (tester) async {
      await _ekranCiz(
        tester,
        apple: true,
        kapi: _SahteApple(hata: StateError('yetkilendirme patladı')),
      );
      await tester.tap(_dugme);
      await tester.pumpAndSettle();
      expect(find.text('Apple girişi başarısız'), findsOneWidget);
    });
  });

  group('nonce', () {
    test('ham nonce rastgele, özet 64 hex', () {
      final a = appleNonceUret();
      final b = appleNonceUret();
      expect(a, isNotEmpty);
      expect(a, isNot(b));
      expect(appleNonceOzeti(a), matches(RegExp(r'^[0-9a-f]{64}$')));
      // Sabit girdi → sabit özet (sunucu aynı hesabı yapacak).
      expect(
        appleNonceOzeti('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });
  });
}
