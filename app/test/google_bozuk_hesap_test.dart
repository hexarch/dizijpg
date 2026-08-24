import 'package:dizijpg/google_kapisi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// GOOGLE GİRİŞİ "BAŞARISIZ (5)" — KOPAR VE BİR KEZ DAHA DENE (24 Ağu 2026).
///
/// BELİRTİ (kullanıcı, Play'den inen 1.93): "google ile girişte hata var
/// başarısız (5) diyor". ApiException 5 (INVALID_ACCOUNT) sunucuya hiç
/// ulaşmadan Play Services içinde patlar; kök neden cihazdaki hesabın
/// önbelleklenmiş oturum bağının bozulması. Çare: `disconnect()` ile bağı
/// koparıp girişi BİR KEZ daha denemek. 16 (reauth failed) aynı ailedir.
///
/// Bu testler üç şeyi kilitler:
///  1. 5/16'da sıra: çıkış → giriş(patlar) → KOPAR → giriş (tek tekrar).
///  2. Diğer kodlar (ör. 12501 iptal) AYNEN fırlar, koparma denenmez.
///  3. `disconnect()` kendisi patlasa bile ikinci giriş yine denenir.
///
/// `GoogleSignInAccount` test VM'inde kurulamaz (özel yapıcı); ikinci giriş
/// null döner — dokun() bunu "kullanıcı vazgeçti" sayar, null döndürür.
/// Burada önemli olan istisnanın YUTULMUŞ ve ikinci denemenin YAPILMIŞ olması.
class _PatlayanGoogle extends GoogleSignIn {
  _PatlayanGoogle({required this.ilkGirisKodu, this.koparPatlar = false})
    : super(scopes: const ['email']);

  /// İlk `signIn()` bu ApiException koduyla patlar; sonrakiler null döner.
  final int ilkGirisKodu;

  /// `disconnect()` da patlarsa akış yine ikinci girişe ilerlemeli.
  final bool koparPatlar;

  final izler = <String>[];

  @override
  Future<GoogleSignInAccount?> signOut() async {
    izler.add('cikis');
    return null;
  }

  @override
  Future<GoogleSignInAccount?> signIn() async {
    izler.add('giris');
    if (izler.where((i) => i == 'giris').length == 1) {
      throw PlatformException(
        code: 'sign_in_failed',
        message:
            'com.google.android.gms.common.api.ApiException: '
            '$ilkGirisKodu: ',
      );
    }
    return null; // hesap nesnesi test VM'inde kurulamaz
  }

  @override
  Future<GoogleSignInAccount?> disconnect() async {
    izler.add('kopar');
    if (koparPatlar) throw StateError('Play Services yok');
    return null;
  }
}

void main() {
  test('ApiException 5: kopar ve girişi bir kez daha dene', () async {
    final sahte = _PatlayanGoogle(ilkGirisKodu: 5);
    final kapi = GoogleKapisiMobil(google: sahte);
    final sonuc = await kapi.dokun();
    expect(sonuc, isNull);
    expect(sahte.izler, ['cikis', 'giris', 'kopar', 'giris']);
  });

  test('ApiException 16 da aynı onarımdan geçer', () async {
    final sahte = _PatlayanGoogle(ilkGirisKodu: 16);
    final kapi = GoogleKapisiMobil(google: sahte);
    await kapi.dokun();
    expect(sahte.izler, ['cikis', 'giris', 'kopar', 'giris']);
  });

  test('12501 (iptal) aynen fırlar, koparma denenmez', () async {
    final sahte = _PatlayanGoogle(ilkGirisKodu: 12501);
    final kapi = GoogleKapisiMobil(google: sahte);
    await expectLater(kapi.dokun(), throwsA(isA<PlatformException>()));
    expect(sahte.izler, ['cikis', 'giris']);
  });

  test('disconnect patlasa bile ikinci giriş denenir', () async {
    final sahte = _PatlayanGoogle(ilkGirisKodu: 5, koparPatlar: true);
    final kapi = GoogleKapisiMobil(google: sahte);
    final sonuc = await kapi.dokun();
    expect(sonuc, isNull);
    expect(sahte.izler, ['cikis', 'giris', 'kopar', 'giris']);
  });
}
