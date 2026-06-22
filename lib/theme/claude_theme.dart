import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Claude-brand design tokens: warm dark charcoal surfaces (not true black),
/// cream off-white typography, and Claude's clay-orange used sparingly for
/// brand + interaction. State still runs cream → amber → red, so a hot ring
/// always reads as "pay attention" against the neutral palette.
class AppColors {
  AppColors._(); // coverage:ignore-line

  // Warm charcoal surfaces (Claude dark mode: darkest → raised).
  static const Color ink = Color(0xFF1F1E1D); // window base
  static const Color surface = Color(0xFF262624); // cards
  static const Color surfaceRaised = Color(0xFF30302E); // inputs / pills
  static const Color hover = Color(0xFF3A3A37);

  // Hairlines — warm white at low alpha.
  static const Color border = Color(0x14FAF9F5); // cream @ ~8%
  static const Color borderStrong = Color(0x24FAF9F5); // cream @ ~14%

  // Text — Claude's warm cream ramp.
  static const Color textPrimary = Color(0xFFF5F4EE);
  static const Color textSecondary = Color(0xFFA6A399);
  static const Color textFaint = Color(0xFF6E6C64);

  // Brand / interactive accent = Claude clay orange.
  static const Color accent = Color(0xFFD97757);
  static const Color accentHover = Color(0xFFE08C70);

  // Usage state ramp: neutral cream → warm amber → warm red.
  static const Color good = Color(0xFFF5F4EE);
  static const Color warn = Color(0xFFE8A13C); // amber
  static const Color danger = Color(0xFFE5564B); // red

  // Foreground on the clay accent (button labels, etc).
  static const Color onAccent = Color(0xFF1F1410);

  /// State colour for a 0..1 utilisation given warn/danger thresholds (0..1).
  static Color heat(double t, {double warnAt = 0.75, double dangerAt = 0.90}) {
    if (t >= dangerAt) return danger;
    if (t >= warnAt) return warn;
    return good;
  }
}

/// Spacing / radius / motion tokens. Restrained geometry — tighter radii than
/// a typical Material card.
class AppDims {
  AppDims._(); // coverage:ignore-line
  static const double gap = 12;
  static const double pad = 18;
  static const double radius = 12;
  static const double radiusSm = 8;
  static const double radiusXs = 6;
  static const double titleBarHeight = 44; // room for macOS traffic lights
}

/// Typography. Hanken Grotesk is the closest freely-available stand-in for
/// Claude's "Styrene B" UI face (clean geometric grotesque); JetBrains Mono
/// for technical readouts (countdowns, ids, raw percentages).
class AppText {
  AppText._(); // coverage:ignore-line

  static TextStyle wordmark(Color color) => GoogleFonts.hankenGrotesk(
        fontSize: 15,
        height: 1.0,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.2,
      );

  static TextStyle display(Color color) => GoogleFonts.hankenGrotesk(
        fontSize: 44,
        height: 1.0,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -1.6,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle stat(Color color) => GoogleFonts.hankenGrotesk(
        fontSize: 30,
        height: 1.0,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -1.1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle title(Color color) => GoogleFonts.hankenGrotesk(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.2,
      );

  static TextStyle body(Color color) => GoogleFonts.hankenGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.45,
        letterSpacing: 0,
      );

  static TextStyle label(Color color) => GoogleFonts.hankenGrotesk(
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
      fontFamily: GoogleFonts.hankenGrotesk().fontFamily,
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
