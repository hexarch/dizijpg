import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Web dalı YALNIZ web derlemesinde bağlanır: `google_sign_in_web` paketi
// `dart:js_interop` kullanır, Android/iOS derlemesine giremez.
import 'google_kapisi_yok.dart'
    if (dart.library.js_interop) 'google_kapisi_web.dart';

/// Google OAuth WEB istemcisi (dizi-jpg-7b723). Android'de `serverClientId`,
/// web'de `clientId` olarak kullanılır; gizli değildir (sunucu da aynısını
/// `GOOGLE_ISTEMCI` olarak doğrular — backend/server.js).
const googleIstemcisi =
    '1026295944597-alc4fpkc2gvtn1qmq92hols5oba98h55.apps.googleusercontent.com';

/// Google düğmesine ayrılan yükseklik.
///
/// Google'ın "large" düğmesi ~40 px; 44 px hem dokunma hedefi alt sınırını
/// karşılar hem de düğme ölçülene kadar YER TUTAR — yer tutulmazsa
/// `FlexHtmlElementView` 1×1 ile başlar ve form zıplar. Aynı yükseklik
/// yükleme/hata halindeki kilitli eşdeğer düğmede de kullanılır.
const double googleDugmeYuksekligi = 44;

/// Google/Play Services hatasının TEŞHİS EDİLEBİLİR kuyruğu: `' (10)'` gibi.
///
/// Hata mesajının tamamı gösterilmez (kullanıcıya `PlatformException(...)`
/// yığını okutmanın anlamı yok), ama kod olmadan da teşhis edilemiyor:
/// **10** = DEVELOPER_ERROR (paket adı/SHA-1 eşleşmiyor), **16** = hesabın
/// yeniden doğrulanması gerekiyor (cihaz tarafı), **7** = ağ, **12501** =
/// kullanıcı iptal etti. Kod bulunamazsa BOŞ dönülür — çeviri metni tek
/// başına kalır, arayüzde parantez artığı görünmez.
String googleHataKodu(Object? e) {
  if (e == null) return '';
  final m = RegExp(
    r'ApiException:\s*(\d+)|sign_in_failed[^0-9]*(\d+)',
  ).firstMatch(e.toString());
  final kod = m?.group(1) ?? m?.group(2);
  return kod == null ? '' : ' ($kod)';
}

/// Google'dan dönen kimlik kanıtı.
///
/// Sunucu `POST /auth/google` İKİ yolu da kabul eder: `kimlik` (id_token) ya
/// da `erisim` (access_token). Android id_token verir; web'de GIS düğmesi de
/// id_token (JWT credential) verir — eski `signIn()` yolu ise yalnız erişim
/// token'ı verebiliyordu.
class GoogleKimligi {
  const GoogleKimligi({this.idToken, this.erisimToken});

  final String? idToken;
  final String? erisimToken;

  /// Sunucuya götürecek hiçbir kanıt yoksa true (giriş denemesi boşa gitti).
  bool get bos => idToken == null && erisimToken == null;
}

/// Google girişinin PLATFORMA GÖRE DEĞİŞEN yüzü.
///
/// NEDEN AYRI SINIF: web'de Google artık uygulamanın kendi düğmesinden giriş
/// başlatmasına izin vermiyor (GIS SDK'sında "kendi düğmeni çiz" API'si yok).
/// `GoogleSignIn.signIn()` webde açılır pencereyi açıp SONSUZA KADAR bekliyor
/// (bkz. giris.dart'taki not) — desteklenen tek yol Google'ın kendi düğmesini
/// çizdirmek. Mobilde ise eski yol AYNEN korunur (serverClientId + id_token).
abstract class GoogleKapisi {
  /// Web'de Google'ın KENDİ düğmesi; mobilde `null` → uygulama kendi
  /// düğmesini çizer.
  Widget? dugme(BuildContext context);

  /// Web'de kullanıcı Google'ın düğmesiyle giriş yapınca akar.
  Stream<GoogleKimligi> get akis;

  /// Mobilde hesap seçiciyi açar; kullanıcı vazgeçerse `null`.
  Future<GoogleKimligi?> dokun();

  void birak();
}

/// Android/iOS dalı — 6 Ağu 2026 öncesindeki davranışın BİREBİR aynısı.
class GoogleKapisiMobil implements GoogleKapisi {
  GoogleKapisiMobil({GoogleSignIn? google})
    : google =
          google ??
          GoogleSignIn(
            // Web'de `clientId`, mobilde `serverClientId` verilir. Mobilde
            // clientId VERİLMEZ: Android istemci kimliği ayrıdır ve id_token'ın
            // `aud` alanı serverClientId'den gelir — sunucu bunu doğruluyor.
            serverClientId: googleIstemcisi,
            scopes: const ['email'],
          );

  /// Testin yapılandırmayı doğrulayabilmesi için açık bırakıldı.
  final GoogleSignIn google;

  @override
  Widget? dugme(BuildContext context) => null;

  @override
  Stream<GoogleKimligi> get akis => const Stream<GoogleKimligi>.empty();

  @override
  Future<GoogleKimligi?> dokun() async {
    final hesap = await google.signIn();
    if (hesap == null) return null; // kullanıcı seçiciyi kapattı
    final yetki = await hesap.authentication;
    return GoogleKimligi(
      idToken: yetki.idToken,
      erisimToken: yetki.accessToken,
    );
  }

  @override
  void birak() {}
}

/// Platforma uygun kapıyı kurar.
///
/// [web] PARAMETRE OLARAK alınır, içeride `kIsWeb` OKUNMAZ: `flutter test`
/// daima `kIsWeb == false` ile koşar ve gömülü bayrak web dalını testlerden
/// tamamen gizlerdi (bu projede GIF animasyonu hatası tam böyle canlıya çıktı).
GoogleKapisi googleKapisiOlustur({required bool web}) =>
    web ? googleWebKapisi() : GoogleKapisiMobil();
