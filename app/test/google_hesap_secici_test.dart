import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/giris.dart';
import 'package:dizijpg/google_kapisi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GOOGLE HESAP SEÇİCİ BİR DAHA AÇILMIYOR (13 Ağu 2026).
///
/// BELİRTİ (kullanıcı): "google ile girişte 1 kere hesap seçtim mi daha
/// seçemiyorum, çıkış yapsam da eski hesabı seçiyor otomatik olarak, onunla
/// giriş yapıyor."
///
/// KÖK NEDEN: iki ayrı yerde aynı eksik.
///  1. `Oturum.cikis()` YALNIZ kendi JWT'mizi siliyordu; Google tarafındaki
///     oturuma hiç dokunmuyordu.
///  2. `GoogleKapisiMobil.dokun()` doğrudan `signIn()` çağırıyordu —
///     `signIn()` önbellekteki hesabı SESSİZCE geri verir, seçici açılmaz.
///
/// Bu testler ikisini de kilitler. `GoogleSignIn` düz bir sınıf, metotları da
/// sanal: alt sınıf yapıp çağrıları kaydediyoruz. `GoogleSignInAccount`
/// KURULAMAZ (özel yapıcı), bu yüzden `signIn()` daima null döner — yani aynı
/// zamanda "kullanıcı seçiciden vazgeçti" halini geziyoruz.
class _SahteGoogle extends GoogleSignIn {
  _SahteGoogle({this.cikisPatlar = false}) : super(scopes: const ['email']);

  /// Çıkış (önbellek temizliği) hata verirse giriş YİNE denenmeli.
  final bool cikisPatlar;

  /// Çağrı SIRASI da önemli: temizlik seçiciden ÖNCE olmalı.
  final izler = <String>[];

  @override
  Future<GoogleSignInAccount?> signOut() async {
    izler.add('cikis');
    if (cikisPatlar) throw StateError('Play Services yok');
    return null;
  }

  @override
  Future<GoogleSignInAccount?> signIn() async {
    izler.add('giris');
    return null; // hesap nesnesi test VM'inde kurulamaz
  }

  @override
  Future<GoogleSignInAccount?> disconnect() async {
    izler.add('kopar');
    return null;
  }
}

http.Response _bosJson() => http.Response(
  jsonEncode(const <String, dynamic>{}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late _SahteGoogle sahte;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Api.istemci = MockClient((_) async => _bosJson());
    sahte = _SahteGoogle();
    googleIstemcisiUret = () => sahte;
  });

  tearDown(() {
    Api.istemci = http.Client();
    // Kanca GLOBAL: sızarsa diğer test dosyalarını bozar.
    googleIstemcisiUret = googleIstemcisiVarsayilan;
  });

  // ---------------------------------------------------------------------------
  // 1. ÇIKIŞ — Google oturumu DA kapanır
  // ---------------------------------------------------------------------------
  group('Uygulamadan çıkış', () {
    test('Google oturumunu DA kapatır', () async {
      await Oturum().cikis();
      expect(sahte.izler, contains('cikis'));
    });

    test('kendi oturumumuz yine de kapanır (Google patlasa bile)', () async {
      sahte = _SahteGoogle(cikisPatlar: true);
      googleIstemcisiUret = () => sahte;
      await Api.tokenKaydet('jwt-test');
      final oturum = Oturum();
      oturum.kullanici = const {'id': 7};
      expect(Api.girisli, isTrue); // ön koşul

      await oturum.cikis(); // atmamalı: kullanıcı hesabında kilitli kalamaz

      expect(sahte.izler, contains('cikis'));
      expect(oturum.kullanici, isNull);
      expect(Api.girisli, isFalse);
    });

    test('KARAR: signOut kullanılır, disconnect DEĞİL', () async {
      // `disconnect()` OAuth iznini de geri alır → kullanıcı her girişte onay
      // ekranını yeniden görürdü. İstenen hesap DEĞİŞTİREBİLMEK, izni iptal
      // etmek değil. Bu test o kararı kilitler.
      await Oturum().cikis();
      expect(sahte.izler, isNot(contains('kopar')));
    });

    test('WEB dalı mobil istemciyi KURMAZ', () async {
      // Webde `serverClientId` desteklenmez; çıkış GIS'in
      // `disableAutoSelect()`ine iner (google_kapisi_web.dart). VM'de o dal
      // UnsupportedError atar ve YUTULUR — çıkış akışı yine tamamlanır.
      await googleOturumunuKapat(web: true);
      expect(sahte.izler, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. GİRİŞ — seçici açılmadan önce önbellek temizlenir
  // ---------------------------------------------------------------------------
  group('GoogleKapisiMobil.dokun()', () {
    test('signIn ÖNCESİ önbellek temizlenir (seçici açılsın diye)', () async {
      final kapi = GoogleKapisiMobil();
      await kapi.dokun();
      // Sıra şart: önce 'cikis', sonra 'giris'.
      expect(sahte.izler, ['cikis', 'giris']);
    });

    test('temizlik patlarsa giriş YİNE denenir', () async {
      sahte = _SahteGoogle(cikisPatlar: true);
      final kapi = GoogleKapisiMobil(google: sahte);
      await kapi.dokun();
      expect(sahte.izler, ['cikis', 'giris']);
    });

    test('kullanıcı vazgeçerse null döner (hata ATILMAZ)', () async {
      final kapi = GoogleKapisiMobil();
      expect(await kapi.dokun(), isNull);
    });

    test('yapılandırma korunur: serverClientId var, clientId YOK', () {
      googleIstemcisiUret = googleIstemcisiVarsayilan;
      final kapi = GoogleKapisiMobil();
      expect(kapi.google.serverClientId, googleIstemcisi);
      expect(kapi.google.clientId, isNull);
      expect(kapi.google.scopes, const ['email']);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. GİRİŞ EKRANI — vazgeçmek hata DEĞİLDİR
  // ---------------------------------------------------------------------------
  testWidgets('vazgeçen kullanıcıya hata SnackBar\'ı GÖSTERİLMEZ', (
    tester,
  ) async {
    // Sahte kapı değil GERÇEK kapı: `dokun()` içindeki temizlik + seçici yolu
    // ekranla birlikte geziliyor. `signIn()` null → kullanıcı vazgeçti.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => Oturum(),
        child: MaterialApp(
          home: GirisEkrani(
            web: false,
            googleKapisi: GoogleKapisiMobil(google: sahte),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Google ile devam et'));
    await tester.pumpAndSettle();

    expect(sahte.izler, ['cikis', 'giris']);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Google girişi başarısız'), findsNothing);
  });
}
