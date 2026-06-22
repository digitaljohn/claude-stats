import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Vercel-style design tokens: true black, high-contrast monochrome surfaces,
/// hairline borders, white-on-black typography. Colour is reserved almost
/// entirely for state — usage runs white → amber → red, so a coloured ring
/// always means "pay attention".
class AppColors {
  AppColors._();

  // Monochrome surfaces (black → raised).
  static const Color ink = Color(0xFF000000); // window base
  static const Color surface = Color(0xFF0A0A0A); // cards
  static const Color surfaceRaised = Color(0xFF141414); // inputs / raised
  static const Color hover = Color(0xFF1F1F1F);

  // Hairlines.
  static const Color border = Color(0x1AFFFFFF); // white @ 10%
  static const Color borderStrong = Color(0x29FFFFFF); // white @ 16%

  // Text.
  static const Color textPrimary = Color(0xFFEDEDED);
  static const Color textSecondary = Color(0xFF8F8F8F);
  static const Color textFaint = Color(0xFF565656);

  // Interactive accent = white (Vercel primary buttons / focus).
  static const Color accent = Color(0xFFFAFAFA);

  // Usage state ramp: neutral white → amber → red.
  static const Color good = Color(0xFFEDEDED);
  static const Color warn = Color(0xFFF5A623); // amber
  static const Color danger = Color(0xFFFF4D4D); // red

  // Foreground on the white accent (button labels, etc).
  static const Color onAccent = Color(0xFF000000);

  /// State colour for a 0..1 utilisation given warn/danger thresholds (0..1).
  static Color heat(double t, {double warnAt = 0.75, double dangerAt = 0.90}) {
    if (t >= dangerAt) return danger;
    if (t >= warnAt) return warn;
    return good;
  }
}

/// Spacing / radius / motion tokens. Vercel geometry is restrained — tighter
/// radii than a typical Material card.
class AppDims {
  AppDims._();
  static const double gap = 12;
  static const double pad = 18;
  static const double radius = 12;
  static const double radiusSm = 8;
  static const double radiusXs = 6;
  static const double titleBarHeight = 44; // room for macOS traffic lights
}

/// Typography. Inter for UI (Vercel's long-time UI face), JetBrains Mono for
/// technical readouts (countdowns, ids, raw percentages).
class AppText {
  AppText._();

  static TextStyle wordmark(Color color) => GoogleFonts.inter(
        fontSize: 15,
        height: 1.0,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.3,
      );

  static TextStyle display(Color color) => GoogleFonts.inter(
        fontSize: 44,
        height: 1.0,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -2.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle stat(Color color) => GoogleFonts.inter(
        fontSize: 30,
        height: 1.0,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -1.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle title(Color color) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.3,
      );

  static TextStyle body(Color color) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.45,
        letterSpacing: -0.1,
      );

  static TextStyle label(Color color) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0,
      );

  /// All-caps technical micro-label.
  static TextStyle mono(Color color, {double size = 11}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

ThemeData buildClaudeTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.ink,
    canvasColor: AppColors.ink,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      secondary: AppColors.accent,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
      fontFamily: GoogleFonts.inter().fontFamily,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppDims.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      textStyle: AppText.label(AppColors.textPrimary),
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
