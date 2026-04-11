import 'package:flutter/material.dart';

/// POSTING — Modern Minimal Dark Theme
/// Palette: Deep navy bg · Pure white text · Vivid violet accent · Soft teal secondary
/// Style: Elevated cards with subtle depth, generous radius, refined typography
class AppTheme {
  // ── Core Palette ──────────────────────────────────────────────────
  static const Color bg          = Color(0xFF0D0F14); // near-black navy
  static const Color bgCard      = Color(0xFF161A24); // card surface
  static const Color bgElevated  = Color(0xFF1E2333); // raised surface
  static const Color bgMuted     = Color(0xFF252B3B); // muted surface

  static const Color white       = Color(0xFFFFFFFF);
  static const Color text        = Color(0xFFF1F3F9); // primary text
  static const Color textMuted   = Color(0xFF8891AA); // secondary text
  static const Color textFaint   = Color(0xFF4A5270); // disabled/faint

  static const Color accent      = Color(0xFF7C6FFF); // vivid violet
  static const Color accentLight = Color(0xFFB3ADFF); // soft violet
  static const Color accentGlow  = Color(0x337C6FFF); // glow layer

  static const Color teal        = Color(0xFF2DD4BF); // teal secondary
  static const Color tealLight   = Color(0xFF99F6E4); // soft teal
  static const Color tealGlow    = Color(0x222DD4BF);

  static const Color rose        = Color(0xFFF43F5E); // error / reject
  static const Color roseLight   = Color(0xFFFFE4E8);
  static const Color amber       = Color(0xFFFBBF24); // warning / pending
  static const Color amberLight  = Color(0xFFFEF3C7);
  static const Color green       = Color(0xFF10B981); // success / hired
  static const Color greenLight  = Color(0xFFD1FAE5);
  static const Color blue        = Color(0xFF3B82F6); // info
  static const Color blueLight   = Color(0xFFDBEAFE);

  // ── Semantic ───────────────────────────────────────────────────────
  static const Color primary      = accent;
  static const Color primaryLight = accentLight;
  static const Color primaryDark  = Color(0xFF5B4EE0);
  static const Color background   = bg;
  static const Color surface      = bgCard;
  static const Color error        = rose;
  static const Color success      = green;
  static const Color warning      = amber;
  static const Color black        = Color(0xFF0D0F14);
  static const Color offWhite     = bgMuted;

  // ── Gradients ──────────────────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C6FFF), Color(0xFF5B4EE0)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C6FFF), Color(0xFF2DD4BF)],
  );

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D0F14), Color(0xFF111420)],
  );

  static const RadialGradient glowGradient = RadialGradient(
    colors: [Color(0x557C6FFF), Color(0x007C6FFF)],
    radius: 0.8,
  );

  // ── Shadows ────────────────────────────────────────────────────────
  static List<BoxShadow> cardShadow() => [
    BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
    BoxShadow(color: accent.withOpacity(0.06), blurRadius: 40, offset: const Offset(0, 0)),
  ];

  static List<BoxShadow> accentShadow({double? opacity}) => [
    BoxShadow(color: accent.withOpacity(0.35), blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> glowShadow({Color? color, double radius = 24}) => [
    BoxShadow(color: (color ?? accent).withOpacity(0.3), blurRadius: radius, spreadRadius: -2),
  ];

  // ── Legacy aliases (kept for compile compat) ───────────────────────
  static BoxShadow get brutalistShadow => BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6));
  static BoxShadow get brutalistShadowSmall => BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3));
  static BoxShadow get brutalistShadowLarge => BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 32, offset: const Offset(0, 12));

  static const Border brutalistBorder = Border.fromBorderSide(BorderSide(color: Color(0xFF252B3B), width: 1));
  static const Border brutalistBorderThick = Border.fromBorderSide(BorderSide(color: Color(0xFF252B3B), width: 1.5));

  // ── Card decoration ────────────────────────────────────────────────
  static BoxDecoration cardDecoration({Color? color, double radius = 20}) => BoxDecoration(
    color: color ?? bgCard,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: bgElevated, width: 1),
    boxShadow: cardShadow(),
  );

  // ── ThemeData ──────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      surface: bgCard,
      primary: accent,
      onPrimary: white,
      secondary: teal,
      onSecondary: white,
      tertiary: amber,
      error: rose,
      onSurface: text,
    ),
    scaffoldBackgroundColor: bg,
    fontFamily: 'SpaceGrotesk',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'SpaceGrotesk',
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: text,
        letterSpacing: -0.5,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontWeight: FontWeight.w700, fontSize: 48, letterSpacing: -2,   color: text),
      displayMedium: TextStyle(fontWeight: FontWeight.w700, fontSize: 36, letterSpacing: -1.5, color: text),
      headlineLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 28, letterSpacing: -1,   color: text),
      headlineMedium:TextStyle(fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.5, color: text),
      titleLarge:    TextStyle(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.3, color: text),
      titleMedium:   TextStyle(fontWeight: FontWeight.w500, fontSize: 16,                      color: text),
      bodyLarge:     TextStyle(fontWeight: FontWeight.w400, fontSize: 16, height: 1.6,         color: textMuted),
      bodyMedium:    TextStyle(fontWeight: FontWeight.w400, fontSize: 14, height: 1.5,         color: textMuted),
      labelLarge:    TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5,  color: text),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgElevated,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: bgMuted, width: 1)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: bgMuted, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: accent, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: rose, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w500, color: textMuted),
      hintStyle: const TextStyle(fontFamily: 'SpaceGrotesk', color: textFaint),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: bgCard,
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: bgElevated,
      labelStyle: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, color: text, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      side: const BorderSide(color: bgMuted, width: 1),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: accent,
      unselectedItemColor: textFaint,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 10),
      unselectedLabelStyle: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w500, fontSize: 10),
    ),
    dividerTheme: const DividerThemeData(color: bgMuted, thickness: 1),
    tabBarTheme: const TabBarThemeData(
      labelColor: accent,
      unselectedLabelColor: textFaint,
      indicatorColor: accent,
      labelStyle: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5),
      unselectedLabelStyle: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w500, fontSize: 12),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: bgMuted,
      thumbColor: accent,
      overlayColor: accentGlow,
    ),
  );
}
