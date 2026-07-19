import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

/// Matching Mode: leitet aus einer beliebigen, vom Nutzer frei gewählten
/// Basisfarbe ein passendes AppAccent-Paar (main/hover) ab -- damit ist der
/// Nutzer nicht auf die 6 festen kAccents-Presets beschränkt.
AppAccent generateMatchingAccent(Color base) {
final hsl = HSLColor.fromColor(base);
final hoverLightness = (hsl.lightness - 0.12).clamp(0.0, 1.0);
final hover = hsl.withLightness(hoverLightness).toColor();
return AppAccent('Matching', base, hover);
}

/// Kuratierte Schriftart-Auswahl (Google Fonts) fürs Font-Customization-
/// Feature. "Comic Neue" ist die offene, frei nutzbare Alternative zu
/// Comic Sans MS (das proprietär ist und hier nicht gebündelt wird).
class AppFontOption {
final String key;
final String label;
final String family;
const AppFontOption(this.key, this.label, this.family);
}

final List<AppFontOption> kFontOptions = [
const AppFontOption('Roboto', 'Roboto', 'Roboto'),
AppFontOption('ComicNeue', 'Comic Neue (Comic-Sans-Alternative)',
GoogleFonts.comicNeue().fontFamily ?? 'Roboto'),
AppFontOption(
'OpenSans', 'Open Sans', GoogleFonts.openSans().fontFamily ?? 'Roboto'),
AppFontOption('Lato', 'Lato', GoogleFonts.lato().fontFamily ?? 'Roboto'),
AppFontOption(
'Poppins', 'Poppins', GoogleFonts.poppins().fontFamily ?? 'Roboto'),
];

String resolveFontFamily(String key) {
return kFontOptions
.firstWhere((f) => f.key == key, orElse: () => kFontOptions[0])
.family;
}

const Color kBgDark = Color(0xFF0F0F14);
const Color kCardDark = Color(0xFF1A1A22);
const Color kCardDark2 = Color(0xFF20202A);
const Color kMuted = Color(0xFF9CA3AF);

ThemeData buildAppTheme(AppAccent accent,
{String fontFamily = 'Roboto', double fontSizeScale = 1.0}) {
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
    fontFamily: fontFamily,
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
    ).apply(fontSizeFactor: fontSizeScale),
  );
}
