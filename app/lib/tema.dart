import 'package:flutter/material.dart';

/// dizi.jpg tasarım dili: siyah zemin, beyaz metin, logo kırmızısı vurgu.
class DiziRenkler {
  /// Logodan örneklenen marka kırmızısı
  static const kirmizi = Color(0xFFA80828);
  static const acikKirmizi = Color(0xFFD32341);
  static const siyah = Color(0xFF0B0B0D);
  static const koyuGri = Color(0xFF17171A);
  static const kart = Color(0xFF1F1F23);
  static const acikGri = Color(0xFF9E9EA3);
}

ThemeData diziTema() {
  const kirmizi = DiziRenkler.kirmizi;
  final scheme = ColorScheme.fromSeed(
    seedColor: kirmizi,
    brightness: Brightness.dark,
  ).copyWith(
    primary: kirmizi,
    onPrimary: Colors.white,
    secondary: kirmizi,
    surface: DiziRenkler.siyah,
    surfaceContainerLowest: DiziRenkler.siyah,
    surfaceContainerLow: DiziRenkler.kart,
    surfaceContainer: DiziRenkler.koyuGri,
    surfaceContainerHighest: const Color(0xFF2A2A2F),
    onSurface: Colors.white,
    onSurfaceVariant: const Color(0xFFB9B9BF),
    outline: const Color(0xFF3A3A40),
  );

  final taban = ThemeData(useMaterial3: true, colorScheme: scheme);
  return taban.copyWith(
    scaffoldBackgroundColor: DiziRenkler.siyah,
    appBarTheme: const AppBarTheme(
      backgroundColor: DiziRenkler.siyah,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: DiziRenkler.kart,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: DiziRenkler.koyuGri,
      indicatorColor: kirmizi,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Colors.white : Colors.white70)),
      labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kirmizi,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    chipTheme: const ChipThemeData(
      shape: StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: DiziRenkler.kart,
      selectedColor: kirmizi,
      labelStyle: TextStyle(color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DiziRenkler.kart,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kirmizi, width: 2),
      ),
      hintStyle: const TextStyle(color: Colors.white38),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF2A2A2F)),
  );
}
