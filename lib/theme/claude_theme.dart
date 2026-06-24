import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Which Claude palette is active. Persisted via [Settings].
enum AppThemeMode { dark, light }

/// A full set of Claude-brand colour tokens for one brightness. Two instances
/// exist — [AppPalette.dark] and [AppPalette.light] — and the active one is
/// published through [AppColors.current] so that static call sites (including
/// custom painters that can't reach `Theme.of(context)`) all read the same
/// selected palette at paint time.
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.ink,
    required this.surface,
    required this.surfaceRaised,
    required this.hover,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.accent,
    required this.accentHover,
    required this.good,
    required this.warn,
    required this.danger,
    required this.onAccent,
    required this.gridLine,
    required this.gridSection,
    required this.topGlow,
    required this.bottomVignette,
    required this.cardShadow,
    required this.primaryButtonFill,
    required this.primaryButtonFillHover,
    required this.primaryButtonText,
  });

  final Brightness brightness;

  // Surfaces: window base → raised pills/inputs.
  final Color ink;
  final Color surface;
  final Color surfaceRaised;
  final Color hover;

  // Hairlines.
  final Color border;
  final Color borderStrong;

  // Text ramp.
  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;

  // Brand / interactive accent.
  final Color accent;
  final Color accentHover;

  // Usage state ramp: neutral → amber → red.
  final Color good;
  final Color warn;
  final Color danger;

  // Foreground on the clay accent.
  final Color onAccent;

  // Painter-only tokens (the [GridBackground] backdrop + [ChartColumns] frame).
  final Color gridLine; // faint hairline grid
  final Color gridSection; // even fainter day separators
  final Color topGlow; // radial lift at the top of the backdrop
  final Color bottomVignette; // bottom fade of the backdrop

  // Sign-in card elevation + monochrome CTA.
  final Color cardShadow;
  final Color primaryButtonFill;
  final Color primaryButtonFillHover;
  final Color primaryButtonText;

  /// Claude dark mode: warm charcoal surfaces (not true black), cream off-white
  /// typography, clay-orange brand accent.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    ink: Color(0xFF1F1E1D),
    surface: Color(0xFF262624),
    surfaceRaised: Color(0xFF30302E),
    hover: Color(0xFF3A3A37),
    border: Color(0x14FAF9F5), // cream @ ~8%
    borderStrong: Color(0x24FAF9F5), // cream @ ~14%
    textPrimary: Color(0xFFF5F4EE),
    textSecondary: Color(0xFFA6A399),
    textFaint: Color(0xFF6E6C64),
    accent: Color(0xFFD97757),
    accentHover: Color(0xFFE08C70),
    good: Color(0xFFF5F4EE),
    warn: Color(0xFFE8A13C),
    danger: Color(0xFFE5564B),
    onAccent: Color(0xFF1F1410),
    gridLine: Color(0x12FAF9F5),
    gridSection: Color(0x0AFAF9F5),
    topGlow: Color(0x12FAF9F5),
    bottomVignette: Color(0x66161514),
    cardShadow: Color(0x88000000),
    primaryButtonFill: Color(0xFFF5F4EE), // cream fill
    primaryButtonFillHover: Color(0xFFFFFFFF),
    primaryButtonText: Color(0xFF1F1E1D), // dark ink
  );

  /// Claude light mode: warm ivory/paper base, raised warm surfaces, charcoal
  /// text, the same clay-orange accent and warn/danger semantics.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    ink: Color(0xFFF5F2EC), // warm ivory window base
    surface: Color(0xFFFBF9F4), // raised paper cards
    surfaceRaised: Color(0xFFFFFFFF), // inputs / pills sit brightest
    hover: Color(0xFFEEEAE1),
    border: Color(0x14262420), // warm charcoal @ ~8%
    borderStrong: Color(0x2E262420), // warm charcoal @ ~18%
    textPrimary: Color(0xFF262420), // readable charcoal
    textSecondary: Color(0xFF6B675E),
    textFaint: Color(0xFF99948A),
    accent: Color(0xFFC55F3F), // slightly deeper clay for contrast on paper
    accentHover: Color(0xFFAE4F31),
    good: Color(0xFF4A463E), // dark neutral reads as "fine" on light
    warn: Color(0xFFC9810E), // amber, darkened for contrast
    danger: Color(0xFFC8362B), // red, darkened for contrast
    onAccent: Color(0xFFFBF9F4),
    gridLine: Color(0x0F262420), // faint charcoal hairline
    gridSection: Color(0x08262420),
    topGlow: Color(0x18FFFFFF), // soft white lift
    bottomVignette: Color(0x14262420),
    cardShadow: Color(0x22463E33),
    primaryButtonFill: Color(0xFF2B2925), // dark ink fill
    primaryButtonFillHover: Color(0xFF1F1E1D),
    primaryButtonText: Color(0xFFF5F2EC), // ivory text
  );

  static AppPalette of(AppThemeMode mode) =>
      mode == AppThemeMode.light ? light : dark;
}

/// Claude-brand design tokens. The values delegate to the active [AppPalette]
/// ([AppColors.current]), so the same call sites adapt when the user switches
/// between the dark and light themes — including in custom painters that read
/// these statically at paint time rather than from `Theme.of(context)`.
class AppColors {
  AppColors._(); // coverage:ignore-line

  /// The palette every token below resolves against. Defaults to dark for
  /// backwards compatibility; [AppController] updates it from saved settings.
  static AppPalette current = AppPalette.dark;

  static Color get ink => current.ink;
  static Color get surface => current.surface;
  static Color get surfaceRaised => current.surfaceRaised;
  static Color get hover => current.hover;

  static Color get border => current.border;
  static Color get borderStrong => current.borderStrong;

  static Color get textPrimary => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get textFaint => current.textFaint;

  static Color get accent => current.accent;
  static Color get accentHover => current.accentHover;

  static Color get good => current.good;
  static Color get warn => current.warn;
  static Color get danger => current.danger;

  static Color get onAccent => current.onAccent;

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
  static const double titleBarHeight = 36; // matches the 32px native title bar + a hair
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

  /// Monospace technical readout (countdowns, ids, URLs, micro-labels) with
  /// tabular figures. Capitalisation is decided at the call site.
  static TextStyle mono(Color color, {double size = 11}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// Builds the [ThemeData] for the given [palette]. Used for both the dark and
/// light themes; pass [AppPalette.dark] (the default) or [AppPalette.light].
ThemeData buildClaudeTheme([AppPalette palette = AppPalette.dark]) {
  final base = palette.brightness == Brightness.light
      ? ThemeData.light(useMaterial3: true)
      : ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: palette.ink,
    canvasColor: palette.ink,
    colorScheme: base.colorScheme.copyWith(
      brightness: palette.brightness,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      secondary: palette.accent,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
      fontFamily: GoogleFonts.hankenGrotesk().fontFamily,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        borderRadius: BorderRadius.circular(AppDims.radiusSm),
        border: Border.all(color: palette.border),
      ),
      textStyle: AppText.label(palette.textPrimary),
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
