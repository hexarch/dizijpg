import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema tercihi: sistem / koyu / acik. Ayarlar'dan seçilir, prefs'te saklanır.
class TemaAyar {
  static const varsayilan = 'sistem';
  static final ValueNotifier<String> mod = ValueNotifier(varsayilan);

  static Future<void> yukle() async {
    final p = await SharedPreferences.getInstance();
    final k = p.getString('tema');
    if (k == 'koyu' || k == 'acik' || k == 'sistem') mod.value = k!;
  }

  static Future<void> sec(String k) async {
    mod.value = k;
    final p = await SharedPreferences.getInstance();
    await p.setString('tema', k);
  }
}

/// dizi.jpg tasarım dili. Renkler tema moduna göre dinamiktir:
/// [acik] bayrağını main.dart, MaterialApp kurulmadan hemen önce günceller.
/// Sarı vurgu her iki temada aynıdır; sarı üstüne DAİMA siyah yazılır.
class DiziRenkler {
  /// Açık tema aktif mi? (main.dart yönetir — ekranlar okumakla yetinir)
  static bool acik = false;

  /// Marka sarısı (her iki temada aynı) — DOLGU/zemin ve daima-koyu (Reels,
  /// poster rozeti, siyah bindirme) yüzeylerde kullanılır.
  static const sari = Color(0xFFF5C518);
  static const acikSari = Color(0xFFFFD75E);

  /// Sarı METİN/ikon için tema-duyarlı ton: koyu temada parlak marka sarısı,
  /// AÇIK temada koyulaştırılmış hardal (beyaz/açık kart üstünde okunur ~4.5:1).
  /// Kart/scaffold zemininde sarı yazı/ikon için `sari` yerine BUNU kullan.
  /// (Daima-siyah zeminlerde — Reels, poster rozeti — yine `sari` kalır.)
  static Color get sariMetin => acik ? const Color(0xFF8A6D00) : sari;

  // --- Zeminler ---
  /// Ana zemin (koyu: gerçek siyah, açık: kırık beyaz)
  static Color get siyah =>
      acik ? const Color(0xFFF6F6F8) : const Color(0xFF0B0B0D);

  /// İkincil zemin (sheet/nav)
  static Color get koyuGri =>
      acik ? const Color(0xFFECECEF) : const Color(0xFF17171A);

  /// Kart zemini
  static Color get kart => acik ? Colors.white : const Color(0xFF1F1F23);
  static Color get acikGri =>
      acik ? const Color(0xFF6E6E76) : const Color(0xFF9E9EA3);

  // --- Metin/ikon tonları (Colors.whiteXX yerine BUNLAR kullanılır) ---
  static Color get metin => acik ? const Color(0xFF17171A) : Colors.white;
  static Color get metin70 => acik ? Colors.black54 : Colors.white70;
  static Color get metin54 => acik ? Colors.black45 : Colors.white54;
  static Color get metin38 => acik ? Colors.black38 : Colors.white38;
  static Color get metin24 => acik ? Colors.black26 : Colors.white24;
  static Color get metin12 => acik ? Colors.black12 : Colors.white12;
}

ThemeData diziTema({required bool acik}) {
  const sari = DiziRenkler.sari;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: sari,
        brightness: acik ? Brightness.light : Brightness.dark,
      ).copyWith(
        primary: sari,
        onPrimary: Colors.black,
        secondary: sari,
        surface: acik ? const Color(0xFFF6F6F8) : const Color(0xFF0B0B0D),
        surfaceContainerLowest: acik
            ? const Color(0xFFF6F6F8)
            : const Color(0xFF0B0B0D),
        surfaceContainerLow: acik ? Colors.white : const Color(0xFF1F1F23),
        surfaceContainer: acik
            ? const Color(0xFFECECEF)
            : const Color(0xFF17171A),
        surfaceContainerHighest: acik
            ? const Color(0xFFE2E2E6)
            : const Color(0xFF2A2A2F),
        onSurface: acik ? const Color(0xFF17171A) : Colors.white,
        onSurfaceVariant: acik
            ? const Color(0xFF54545C)
            : const Color(0xFFB9B9BF),
        outline: acik ? const Color(0xFFC9C9CF) : const Color(0xFF3A3A40),
      );

  // Marka fontu Poppins; Latin-dışı diller (Arapça/Çince/…) sistem fontuna düşer.
  final taban = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Poppins',
  );
  final zemin = acik ? const Color(0xFFF6F6F8) : const Color(0xFF0B0B0D);
  final kart = acik ? Colors.white : const Color(0xFF1F1F23);
  final ikincil = acik ? const Color(0xFFECECEF) : const Color(0xFF17171A);
  final metin = acik ? const Color(0xFF17171A) : Colors.white;
  final metin70 = acik ? Colors.black54 : Colors.white70;

  return taban.copyWith(
    scaffoldBackgroundColor: zemin,
    appBarTheme: AppBarTheme(
      backgroundColor: zemin,
      foregroundColor: metin,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: metin,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: acik ? 1 : 0,
      shadowColor: acik ? Colors.black12 : null,
      color: kart,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ikincil,
      indicatorColor: sari,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Colors.black : metin70,
        ),
      ),
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: metin70,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: sari,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: kart,
      selectedColor: sari,
      // Seçili çip sarı zeminli: yazı siyah; değilse tema metni
      labelStyle: WidgetStateTextStyle.resolveWith(
        (s) => TextStyle(
          fontFamily: 'Poppins',
          color: s.contains(WidgetState.selected) ? Colors.black : metin,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kart,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: acik
            ? const BorderSide(color: Color(0xFFDADAE0))
            : BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: acik
            ? const BorderSide(color: Color(0xFFDADAE0))
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: sari, width: 2),
      ),
      hintStyle: TextStyle(color: acik ? Colors.black38 : Colors.white38),
    ),
    dividerTheme: DividerThemeData(
      color: acik ? const Color(0xFFE2E2E6) : const Color(0xFF2A2A2F),
    ),
  );
}
