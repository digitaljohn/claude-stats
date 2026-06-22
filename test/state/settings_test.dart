import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/state/settings.dart';

void main() {
  test('defaults are sensible', () {
    const s = Settings();
    expect(s.warnThreshold, 0.75);
    expect(s.dangerThreshold, 0.90);
    expect(s.use24h, false);
    expect(s.compactMode, false);
    expect(s.refreshSeconds, 300);
    expect(s.alwaysOnTop, false);
    expect(s.showResetDate, false);
    expect(s.notificationsEnabled, true);
    expect(s.mini, false);
  });

  test('copyWith overrides every field', () {
    const s = Settings();
    final n = s.copyWith(
      warnThreshold: 0.6,
      dangerThreshold: 0.8,
      use24h: true,
      compactMode: true,
      refreshSeconds: 60,
      alwaysOnTop: true,
      showResetDate: true,
      notificationsEnabled: false,
      mini: true,
    );
    expect(n.warnThreshold, 0.6);
    expect(n.dangerThreshold, 0.8);
    expect(n.use24h, true);
    expect(n.compactMode, true);
    expect(n.refreshSeconds, 60);
    expect(n.alwaysOnTop, true);
    expect(n.showResetDate, true);
    expect(n.notificationsEnabled, false);
    expect(n.mini, true);
  });

  test('copyWith with no args preserves all fields', () {
    const s = Settings(
      warnThreshold: 0.7,
      dangerThreshold: 0.95,
      use24h: true,
      compactMode: true,
      refreshSeconds: 900,
      alwaysOnTop: true,
      showResetDate: true,
      notificationsEnabled: false,
      mini: true,
    );
    final n = s.copyWith();
    expect(n.encode(), s.encode());
  });

  test('round-trips through JSON', () {
    const s = Settings(
      warnThreshold: 0.7,
      dangerThreshold: 0.95,
      use24h: true,
      compactMode: true,
      refreshSeconds: 900,
      alwaysOnTop: true,
      showResetDate: true,
      notificationsEnabled: false,
      mini: true,
    );
    final decoded = Settings.decode(s.encode());
    expect(decoded.warnThreshold, 0.7);
    expect(decoded.dangerThreshold, 0.95);
    expect(decoded.use24h, true);
    expect(decoded.compactMode, true);
    expect(decoded.refreshSeconds, 900);
    expect(decoded.alwaysOnTop, true);
    expect(decoded.showResetDate, true);
    expect(decoded.notificationsEnabled, false);
    expect(decoded.mini, true);
  });

  test('fromJson falls back to defaults for missing keys', () {
    final s = Settings.fromJson(const {});
    expect(s.warnThreshold, 0.75);
    expect(s.dangerThreshold, 0.90);
    expect(s.use24h, false);
    expect(s.compactMode, false);
    expect(s.refreshSeconds, 300);
    expect(s.alwaysOnTop, false);
    expect(s.showResetDate, false);
    expect(s.notificationsEnabled, true);
    expect(s.mini, false);
  });

  test('decode returns defaults for null, empty, and malformed input', () {
    expect(Settings.decode(null).refreshSeconds, 300);
    expect(Settings.decode('').refreshSeconds, 300);
    expect(Settings.decode('{not json').refreshSeconds, 300);
  });
}
