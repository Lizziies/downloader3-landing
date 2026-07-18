import 'package:flutter/material.dart';

/// 💜 Farben 1:1 aus der Desktop-App übernommen (main.py -> ACCENTS-Dict),
/// damit App und Webseite auf den ersten Blick zusammengehören. "Pink" ist
/// dort wie hier der Standard-Akzent.
class AppAccent {
  final String name;
  final Color main;
  final Color hover;
  const AppAccent(this.name, this.main, this.hover);
}

const List<AppAccent> kAccents = [
  AppAccent('Pink', Color(0xFFEC4899), Color(0xFFB9226E)),
  AppAccent('Violet', Color(0xFF8B5CF6), Color(0xFF7C3AED)),
  AppAccent('Cyan', Color(0xFF06B6D4), Color(0xFF0891B2)),
  AppAccent('Emerald', Color(0xFF10B981), Color(0xFF059669)),
  AppAccent('Rose', Color(0xFFF43F5E), Color(0xFFE11D48)),
  AppAccent('Amber', Color(0xFFF59E0B), Color(0xFFD97706)),
];

const Color kBgDark = Color(0xFF0F0F14);
const Color kCardDark = Color(0xFF1A1A22);
const Color kCardDark2 = Color(0xFF20202A);
const Color kMuted = Color(0xFF9CA3AF);

ThemeData buildAppTheme(AppAccent accent) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBgDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent.main,
      brightness: Brightness.dark,
      primary: accent.main,
      secondary: accent.main,
      surface: kCardDark,
    ),
    cardColor: kCardDark,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: kBgDark,
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent.main,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCardDark2,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent.main, width: 1.4),
      ),
      hintStyle: const TextStyle(color: kMuted),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white),
      bodyLarge: TextStyle(color: Colors.white),
    ),
  );
}
