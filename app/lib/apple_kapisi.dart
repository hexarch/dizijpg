import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Apple ile giriş — App Store Guideline 4.8 (10 Eyl 2026 reddi).
///
/// NEDEN VAR: Apple, üçüncü taraf giriş (Google) sunan her uygulamadan
/// "eşdeğer" bir seçenek istiyor: veri toplama ad+e-posta ile sınırlı,
/// e-posta gizlenebilir, reklam için etkileşim toplanmıyor. E-posta/şifre
/// kaydı bu şartı KARŞILAMIYOR (adres gizlenemez); Apple'ın kendi cümlesi
/// "Sign in with Apple bu şartların hepsini karşılar". Google akışıyla aynı
/// kalıpta kuruldu (bkz. google_kapisi.dart): kapı sınıfı platforma göre
/// değişir, ekran kapıyı test için dışarıdan alır.
///
/// YALNIZ iOS'ta gösterilir: Android/web'de Apple'ın web akışı (Services
/// ID + dönüş adresi) ayrı bir kurulum ister ve 4.8 yalnız App Store'daki
/// uygulamayı bağlar. [appleGirisiUygun] tek karar noktasıdır.

/// Apple'dan dönen kimlik kanıtı.
///
/// [identityToken] Apple'ın imzaladığı JWT — sunucu `POST /auth/apple` ile
/// Apple'ın açık anahtarlarıyla doğrular. [nonce] HAM değerdir: istekte
/// SHA-256'sı gönderildi, jetonun `nonce` alanında o özet durur; sunucu hamı
/// yeniden özetleyip karşılaştırır (yeniden oynatma koruması).
///
/// [email] ve [ad] Apple'dan YALNIZ İLK yetkilendirmede gelir; sonraki
/// girişlerde ikisi de null'dır (e-posta jetonun içinde yine vardır). Sunucu
/// bu yüzden hesabı `sub` ile bulur, e-postayı ikinci sırada kullanır.
class AppleKimligi {
  const AppleKimligi({
    required this.identityToken,
    required this.nonce,
    this.yetkiKodu,
    this.email,
    this.ad,
  });

  final String identityToken;
  final String nonce;

  /// Tek kullanımlık yetki kodu: sunucu bununla Apple'dan yenileme jetonu
  /// alır ve hesap silinince o jetonu İPTAL EDER (Apple 5.1.1(v) şartı).
  final String? yetkiKodu;
  final String? email;
  final String? ad;
}

/// Apple girişinin platform yüzü. Test sahtesini koyabilmek için soyut.
abstract class AppleKapisi {
  /// Apple'ın sistem sayfasını açar; kullanıcı vazgeçerse `null`.
  Future<AppleKimligi?> dokun();
}

/// Apple düğmesi bu platformda ÇİZİLİR Mİ?
///
/// [web] parametre olarak alınır (`kIsWeb` testte hep false); platform
/// `defaultTargetPlatform`dan okunur ki test `debugDefaultTargetPlatformOverride`
/// ile iOS'u taklit edebilsin.
bool appleGirisiUygun({required bool web}) =>
    !web && defaultTargetPlatform == TargetPlatform.iOS;

/// Kriptografik rastgele nonce (32 bayt, base64url).
String appleNonceUret([Random? r]) {
  final rnd = r ?? Random.secure();
  final baytlar = List<int>.generate(32, (_) => rnd.nextInt(256));
  return base64UrlEncode(baytlar).replaceAll('=', '');
}

/// Ham nonce'un SHA-256 özeti (hex) — Apple isteğine BU gider.
String appleNonceOzeti(String ham) =>
    sha256.convert(utf8.encode(ham)).toString();

/// iOS dalı: Apple'ın yerel yetkilendirme sayfası.
class AppleKapisiIos implements AppleKapisi {
  @override
  Future<AppleKimligi?> dokun() async {
    final ham = appleNonceUret();
    final AuthorizationCredentialAppleID c;
    try {
      c = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: appleNonceOzeti(ham),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      // Kullanıcının kendi vazgeçmesi hata DEĞİL: ekran sessiz kalır.
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
    final jeton = c.identityToken;
    if (jeton == null || jeton.isEmpty) {
      throw StateError('Apple kimlik jetonu boş döndü');
    }
    final ad = [
      c.givenName,
      c.familyName,
    ].where((p) => p != null && p.trim().isNotEmpty).join(' ').trim();
    return AppleKimligi(
      identityToken: jeton,
      nonce: ham,
      yetkiKodu: c.authorizationCode,
      email: c.email,
      ad: ad.isEmpty ? null : ad,
    );
  }
}
