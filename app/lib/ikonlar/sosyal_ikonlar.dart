import 'package:flutter/widgets.dart';

/// Sosyal platform marka ikonları — `simple_icons` paketinin SABİT HARİTASINA
/// dokunmadan, aynı fontun yalnızca kullandığımız 18 glifini işaret eden yerel
/// tanımlar.
///
/// NEDEN BÖYLE?
/// `package:simple_icons` ikonları `SimpleIcons` sınıfında 3.442 adet
/// `static const IconData` olarak tutuyor ve dosyanın sonunda hepsini tek tek
/// referans eden `static const Map<String, IconData> values` haritası var
/// (simple_icons-16.23.0/lib/src/icon_data.g.dart:13776). Paketi bir kez import
/// ettiğimizde bu kütüphane bütünüyle derleme birimine (kernel/dill) giriyor;
/// Flutter'ın ikon budayıcısı (`--tree-shake-icons`) kernel içindeki TÜM sabit
/// `IconData` örneklerini "kullanılıyor" saydığı için 1,46 MB'lık
/// `SimpleIcons.ttf`ten yalnızca %6,8 kırpabiliyordu.
///
/// Aşağıdaki tanımlar `SimpleIcons` sınıfını hiç referans etmez; yalnızca
/// fontun kendisini (`fontFamily: 'SimpleIcons'`, `fontPackage:
/// 'simple_icons'`) işaret eder. Böylece budayıcı yalnız bu 18 glifi korur.
///
/// KURAL: Bu dosyadaki her `IconData` **`const`** olmak ZORUNDA. Tek bir
/// `const` olmayan `IconData` bile ikon budamayı komple kapatır (derleme
/// "Font subsetting is disabled" uyarısı verir).
///
/// KURAL: `pubspec.yaml`daki `simple_icons` bağımlılığı KALMALI — fontun
/// varlık olarak derlemeye girmesi o bağımlılığın kendi
/// `flutter: fonts:` bildirimiyle sağlanıyor.
///
/// Kod noktaları `simple_icons-16.23.0/lib/src/icon_data.g.dart` kaynağından
/// birebir alınmıştır; paket yükseltilirse `test/sosyal_ikonlar_test.dart`
/// bunları tekrar doğrular.
class SosyalIkonlar {
  const SosyalIkonlar._();

  /// İkonların geldiği font ailesi (paketin pubspec'inde bildirilen ad).
  static const String fontAilesi = 'SimpleIcons';

  /// Fontu sağlayan paket; varlık yolu bundan türetilir
  /// (`assets/packages/simple_icons/fonts/SimpleIcons.ttf`).
  static const String fontPaketi = 'simple_icons';

  /// Instagram
  static const IconData instagram = IconData(
    0xef98,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// Facebook
  static const IconData facebook = IconData(
    0xeda7,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// X (eski Twitter)
  static const IconData x = IconData(
    0xf71a,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// TikTok
  static const IconData tiktok = IconData(
    0xf5cb,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// Discord
  static const IconData discord = IconData(
    0xed07,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// Steam
  static const IconData steam = IconData(
    0xf51b,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// Epic Games
  static const IconData epicgames = IconData(
    0xed7e,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// IMDb
  static const IconData imdb = IconData(
    0xef78,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// VK (VKontakte)
  static const IconData vk = IconData(
    0xf6a0,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// YouTube
  static const IconData youtube = IconData(
    0xf73d,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// Twitch
  static const IconData twitch = IconData(
    0xf625,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// Spotify
  static const IconData spotify = IconData(
    0xf4f2,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// GitHub
  static const IconData github = IconData(
    0xee5e,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// Reddit
  static const IconData reddit = IconData(
    0xf3ba,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// Telegram
  static const IconData telegram = IconData(
    0xf58e,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// Snapchat
  static const IconData snapchat = IconData(
    0xf4b5,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// Pinterest
  static const IconData pinterest = IconData(
    0xf2d0,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );

  /// Letterboxd
  static const IconData letterboxd = IconData(
    0xf076,
    fontFamily: fontAilesi,
    fontPackage: fontPaketi,
  );
}
