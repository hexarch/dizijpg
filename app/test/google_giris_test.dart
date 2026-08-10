import 'dart:async';
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/giris.dart';
import 'package:dizijpg/google_kapisi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WEBDE GOOGLE İLE GİRİŞ (10 Ağu 2026).
///
/// BELİRTİ: "Google ile devam et"e basılıyor, hiçbir pencere açılmıyor,
/// konsolda hata yok, sunucuya `/auth/google` isteği HİÇ ULAŞMIYOR.
///
/// KÖK NEDEN (tarayıcıda üretildi): `GoogleSignIn.signIn()` webde OAuth
/// "implicit" açılır penceresini açıyor; GIS konsola
/// `[GSI_LOGGER-TOKEN_CLIENT]: Starting popup flow` yazıyor, ardından
/// `Checking popup closed` SONSUZA kadar dönüyor. Future hiç tamamlanmıyor →
/// ekran "yükleniyor"da kilitleniyor, hata da atılmıyor. Paketin kendi kaynağı
/// da uyarıyor: "`signIn` web'de önerilmez, id_token veremez; `renderButton`
/// kullan."
///
/// BU TESTLERİN KİLİTLEDİĞİ ÜÇ ŞEY:
///  1. WEB dalı Google'ın KENDİ düğmesini çizer (bizim düğme çizilmez).
///  2. MOBİL dal ESKİ yolu korur: `serverClientId` + `id_token` (Android'de
///     çalışan giriş bozulmadı).
///  3. Her başarısızlıkta kullanıcı ANLAMLI bir mesaj görür — sessiz
///     başarısızlık bu hatanın ta kendisiydi.
///
/// DİKKAT: `flutter test` DAİMA `kIsWeb == false` ile koşar. Bu yüzden ekran
/// web bayrağını PARAMETRE olarak alır; gömülü olsaydı web dalı testlerden
/// görünmezdi (bu projede GIF animasyonu hatası tam böyle canlıya çıkmıştı).

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Google kapısının test ikizi. Gerçek kapı web'de Google'ın JS SDK'sına,
/// mobilde hesap seçiciye bağlı — ikisi de test VM'inde yok.
class _SahteKapi implements GoogleKapisi {
  _SahteKapi({this.googleninDugmesi = false, this.kimlik, this.hata});

  /// Web dalında Google'ın kendi düğmesi çizilir.
  final bool googleninDugmesi;
  final GoogleKimligi? kimlik;
  final Object? hata;

  int dokunmaSayisi = 0;
  bool birakildi = false;
  final denetci = StreamController<GoogleKimligi>.broadcast();

  @override
  Widget? dugme(BuildContext context) => googleninDugmesi
      ? const SizedBox(key: Key('googlenin-dugmesi'), height: 44)
      : null;

  @override
  Stream<GoogleKimligi> get akis => denetci.stream;

  @override
  Future<GoogleKimligi?> dokun() async {
    dokunmaSayisi++;
    if (hata != null) throw hata!;
    return kimlik;
  }

  @override
  void birak() => birakildi = true;
}

Future<void> _ekranCiz(
  WidgetTester tester, {
  required bool web,
  required GoogleKapisi kapi,
  List<Map<String, dynamic>>? gonderilen,
  int googleKodu = 200,
}) async {
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.endsWith('/auth/google')) {
      gonderilen?.add(jsonDecode(istek.body) as Map<String, dynamic>);
      if (googleKodu != 200) {
        return _json({'hata': 'Google doğrulaması başarısız'}, googleKodu);
      }
      return _json({
        'token': 'jwt-test',
        // `avatar` anahtarı BİLEREK var: yoksa Oturum arka planda /profilim'e
        // gider ve test ağ trafiği üretir.
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
        home: GirisEkrani(web: web, googleKapisi: kapi),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Api.istemci = MockClient((_) async => _json(const {}));
  });
  tearDown(() => Api.istemci = http.Client());

  // -------------------------------------------------------------------------
  // 1. WEB DALI — Google'ın kendi düğmesi
  // -------------------------------------------------------------------------
  group('WEB dalı', () {
    testWidgets('Google KENDİ düğmesini çizer; bizim düğme çizilmez', (
      tester,
    ) async {
      final kapi = _SahteKapi(googleninDugmesi: true);
      await _ekranCiz(tester, web: true, kapi: kapi);

      expect(find.byKey(const Key('googlenin-dugmesi')), findsOneWidget);
      // Kendi "Google ile devam et" düğmemiz webde YOK: Google, uygulamanın
      // kendi düğmesinden giriş başlatmasına izin vermiyor. İki farklı
      // Google düğmesi aynı ekranda görünmemeli.
      expect(find.text('Google ile devam et'), findsNothing);
      // Misafir yolu duruyor.
      expect(find.text('Misafir olarak devam et'), findsOneWidget);
    });

    testWidgets('Google düğmesinden gelen id_token sunucuya `kimlik` gider', (
      tester,
    ) async {
      final gonderilen = <Map<String, dynamic>>[];
      final kapi = _SahteKapi(googleninDugmesi: true);
      await _ekranCiz(tester, web: true, kapi: kapi, gonderilen: gonderilen);

      kapi.denetci.add(const GoogleKimligi(idToken: 'jwt-google'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(gonderilen, hasLength(1));
      expect(gonderilen.single['kimlik'], 'jwt-google');
      // id_token varken erişim token'ı GÖNDERİLMEZ: sunucu `kimlik` yolunda
      // `aud` doğrulaması yapıyor (backend/server.js).
      expect(gonderilen.single.containsKey('erisim'), isFalse);
    });

    testWidgets('id_token yoksa erişim token\'ı ile denenir', (tester) async {
      final gonderilen = <Map<String, dynamic>>[];
      final kapi = _SahteKapi(googleninDugmesi: true);
      await _ekranCiz(tester, web: true, kapi: kapi, gonderilen: gonderilen);

      kapi.denetci.add(const GoogleKimligi(erisimToken: 'erisim-abc'));
      await tester.pumpAndSettle();

      expect(gonderilen.single['erisim'], 'erisim-abc');
      expect(gonderilen.single.containsKey('kimlik'), isFalse);
    });

    testWidgets('sunucu reddederse kullanıcı MESAJ görür (sessiz değil)', (
      tester,
    ) async {
      final kapi = _SahteKapi(googleninDugmesi: true);
      await _ekranCiz(tester, web: true, kapi: kapi, googleKodu: 401);

      kapi.denetci.add(const GoogleKimligi(idToken: 'jwt-google'));
      await tester.pumpAndSettle();

      expect(find.text('Google doğrulaması başarısız'), findsOneWidget);
    });

    testWidgets('Google tarafı hata verirse kullanıcı MESAJ görür', (
      tester,
    ) async {
      final kapi = _SahteKapi(googleninDugmesi: true);
      await _ekranCiz(tester, web: true, kapi: kapi);

      kapi.denetci.addError(StateError('popup kapandı'));
      await tester.pumpAndSettle();

      expect(find.text('Google girişi başarısız'), findsOneWidget);
    });

    testWidgets('boş kimlik gelirse SESSİZCE yutulmaz', (tester) async {
      final gonderilen = <Map<String, dynamic>>[];
      final kapi = _SahteKapi(googleninDugmesi: true);
      await _ekranCiz(tester, web: true, kapi: kapi, gonderilen: gonderilen);

      kapi.denetci.add(const GoogleKimligi());
      await tester.pumpAndSettle();

      expect(gonderilen, isEmpty); // sunucuya boş istek atılmaz
      expect(find.text('Google girişi başarısız'), findsOneWidget);
    });

    testWidgets('ekran kapanınca Google kapısı bırakılır', (tester) async {
      final kapi = _SahteKapi(googleninDugmesi: true);
      await _ekranCiz(tester, web: true, kapi: kapi);
      await tester.pumpWidget(const SizedBox());
      expect(kapi.birakildi, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // 2. MOBİL DAL — Android'de ÇALIŞAN yol korunuyor
  // -------------------------------------------------------------------------
  group('MOBİL dal', () {
    testWidgets('kendi düğmemiz çizilir ve id_token `kimlik` olarak gider', (
      tester,
    ) async {
      final gonderilen = <Map<String, dynamic>>[];
      final kapi = _SahteKapi(kimlik: const GoogleKimligi(idToken: 'jwt-and'));
      await _ekranCiz(tester, web: false, kapi: kapi, gonderilen: gonderilen);

      expect(find.text('Google ile devam et'), findsOneWidget);
      await tester.tap(find.text('Google ile devam et'));
      await tester.pumpAndSettle();

      expect(kapi.dokunmaSayisi, 1);
      expect(gonderilen.single['kimlik'], 'jwt-and');
    });

    testWidgets('kullanıcı seçiciyi kapatırsa sunucuya istek gitmez', (
      tester,
    ) async {
      final gonderilen = <Map<String, dynamic>>[];
      final kapi = _SahteKapi(); // dokun() null döner
      await _ekranCiz(tester, web: false, kapi: kapi, gonderilen: gonderilen);

      await tester.tap(find.text('Google ile devam et'));
      await tester.pumpAndSettle();

      expect(gonderilen, isEmpty);
      // Vazgeçmek hata değildir — kullanıcıya hata basılmaz.
      expect(find.text('Google girişi başarısız'), findsNothing);
    });

    testWidgets('hesap seçici hata verirse kullanıcı MESAJ görür', (
      tester,
    ) async {
      final kapi = _SahteKapi(hata: StateError('sign_in_failed'));
      await _ekranCiz(tester, web: false, kapi: kapi);

      await tester.tap(find.text('Google ile devam et'));
      await tester.pumpAndSettle();

      expect(find.text('Google girişi başarısız'), findsOneWidget);
    });

    test('ANDROID YAPILANDIRMASI: serverClientId var, clientId YOK', () {
      final kapi = GoogleKapisiMobil();
      // Android id_token'ının `aud` alanı serverClientId'den gelir ve sunucu
      // bunu doğrular (backend/server.js `GOOGLE_ISTEMCI`). clientId verilseydi
      // Android istemcisi ile karışırdı.
      expect(kapi.google.serverClientId, googleIstemcisi);
      expect(kapi.google.clientId, isNull);
      expect(kapi.google.scopes, const ['email']);
    });

    test('googleKapisiOlustur: web olmayan derleme mobil kapıyı verir', () {
      expect(googleKapisiOlustur(web: false), isA<GoogleKapisiMobil>());
      // Web dalı `dart:js_interop` gerektirir; VM derlemesinde YOKTUR.
      expect(() => googleKapisiOlustur(web: true), throwsUnsupportedError);
    });
  });
}
