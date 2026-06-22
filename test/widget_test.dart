import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/models/usage.dart';
import 'package:claude_stats/state/settings.dart';

void main() {
  group('UsageWindow.fromJson', () {
    test('normalises a 0–100 percentage to a 0..1 fraction', () {
      final w = UsageWindow.fromJson('five_hour', 'Session', {
        'utilization': 64,
        'resets_at': '2026-06-22T12:00:00Z',
      });
      expect(w.utilization, closeTo(0.64, 1e-9));
      expect(w.percent, 64);
      expect(w.resetsAt, isNotNull);
    });

    test('treats a <=1 value as already-fractional', () {
      final w = UsageWindow.fromJson('seven_day', 'Weekly', {'utilization': 0.8});
      expect(w.utilization, closeTo(0.8, 1e-9));
      expect(w.resetsAt, isNull);
    });

    test('clamps out-of-range values', () {
      final w = UsageWindow.fromJson('x', 'X', {'utilization': 150});
      expect(w.utilization, 1.0);
    });
  });

  test('Settings round-trips through JSON', () {
    const s = Settings(
      warnThreshold: 0.7,
      dangerThreshold: 0.95,
      use24h: true,
      refreshSeconds: 900,
      alwaysOnTop: true,
      showResetDate: true,
      notificationsEnabled: false,
    );
    final decoded = Settings.decode(s.encode());
    expect(decoded.warnThreshold, 0.7);
    expect(decoded.dangerThreshold, 0.95);
    expect(decoded.use24h, true);
    expect(decoded.refreshSeconds, 900);
    expect(decoded.alwaysOnTop, true);
    expect(decoded.showResetDate, true);
    expect(decoded.notificationsEnabled, false);
  });

  test('HistoryPoint list round-trips through JSON', () {
    final pts = [
      HistoryPoint(t: DateTime(2026, 6, 22, 10), session: 0.4, weekly: 0.6),
      HistoryPoint(t: DateTime(2026, 6, 22, 11), session: 0.5, weekly: 0.62),
    ];
    final decoded = HistoryPoint.decode(HistoryPoint.encode(pts));
    expect(decoded.length, 2);
    expect(decoded.first.session, 0.4);
    expect(decoded.last.weekly, 0.62);
  });
}
