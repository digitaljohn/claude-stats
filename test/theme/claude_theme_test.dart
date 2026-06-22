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
    expect(AppDims.titleBarHeight, 44);
  });

  test('buildClaudeTheme produces a dark theme with accent primary', () {
    final theme = buildClaudeTheme();
    expect(theme.scaffoldBackgroundColor, AppColors.ink);
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AppColors.accent);
    expect(theme.splashFactory, NoSplash.splashFactory);
  });
}
