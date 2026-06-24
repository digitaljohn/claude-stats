import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/theme/claude_theme.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(() {
    // Configures GoogleFonts for offline use.
    installPluginFakes();
  });

  group('AppColors.heat', () {
    test('returns the danger colour at/above dangerAt', () {
      expect(AppColors.heat(0.95), AppColors.danger);
      expect(AppColors.heat(0.90), AppColors.danger);
    });
    test('returns the warn colour between thresholds', () {
      expect(AppColors.heat(0.80), AppColors.warn);
      expect(AppColors.heat(0.75), AppColors.warn);
    });
    test('returns the good colour below warnAt', () {
      expect(AppColors.heat(0.10), AppColors.good);
    });
    test('honours custom thresholds', () {
      expect(AppColors.heat(0.5, warnAt: 0.4, dangerAt: 0.6), AppColors.warn);
      expect(AppColors.heat(0.7, warnAt: 0.4, dangerAt: 0.6), AppColors.danger);
    });
  });

  test('AppText styles all build a TextStyle with the requested colour', () {
    const c = Color(0xFF123456);
    for (final style in [
      AppText.wordmark(c),
      AppText.display(c),
      AppText.stat(c),
      AppText.title(c),
      AppText.body(c),
      AppText.label(c),
      AppText.mono(c),
      AppText.mono(c, size: 20),
    ]) {
      expect(style.color, c);
    }
  });

  test('AppDims exposes the layout tokens', () {
    expect(AppDims.gap, 12);
    expect(AppDims.pad, 18);
    expect(AppDims.radius, 12);
    expect(AppDims.radiusSm, 8);
    expect(AppDims.radiusXs, 6);
    expect(AppDims.titleBarHeight, 36);
  });

  test('buildClaudeTheme defaults to a dark theme with accent primary', () {
    final theme = buildClaudeTheme();
    expect(theme.scaffoldBackgroundColor, AppPalette.dark.ink);
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AppPalette.dark.accent);
    expect(theme.splashFactory, NoSplash.splashFactory);
  });

  test('buildClaudeTheme builds a light theme from the light palette', () {
    final theme = buildClaudeTheme(AppPalette.light);
    expect(theme.scaffoldBackgroundColor, AppPalette.light.ink);
    expect(theme.canvasColor, AppPalette.light.ink);
    expect(theme.colorScheme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, AppPalette.light.accent);
    expect(theme.colorScheme.surface, AppPalette.light.surface);
    expect(theme.splashFactory, NoSplash.splashFactory);
  });

  group('AppColors.current palette switching', () {
    tearDown(() => AppColors.current = AppPalette.dark);

    test('AppColors tokens follow the active palette', () {
      AppColors.current = AppPalette.dark;
      expect(AppColors.ink, AppPalette.dark.ink);
      expect(AppColors.textPrimary, AppPalette.dark.textPrimary);
      expect(AppColors.accentHover, AppPalette.dark.accentHover);

      AppColors.current = AppPalette.light;
      expect(AppColors.ink, AppPalette.light.ink);
      expect(AppColors.textPrimary, AppPalette.light.textPrimary);
      expect(AppColors.accent, AppPalette.light.accent);
      expect(AppColors.accentHover, AppPalette.light.accentHover);
    });

    test('AppPalette.of maps the theme mode to a palette', () {
      expect(AppPalette.of(AppThemeMode.dark), AppPalette.dark);
      expect(AppPalette.of(AppThemeMode.light), AppPalette.light);
    });

    test('heat still ramps good → warn → danger in the light palette', () {
      AppColors.current = AppPalette.light;
      expect(AppColors.heat(0.1), AppPalette.light.good);
      expect(AppColors.heat(0.8), AppPalette.light.warn);
      expect(AppColors.heat(0.95), AppPalette.light.danger);
    });
  });
}
