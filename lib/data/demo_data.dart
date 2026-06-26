import 'dart:math' as math;

import '../models/account.dart';
import '../models/usage.dart';

/// Synthesises a believable account so the full UI — rings, countdowns,
/// per-model breakdown, extra usage and the shader history chart — is
/// viewable without a real session key.
class DemoData {
  static final _now = DateTime.now();

  /// A personal + a team org, so demo mode shows off the account switcher.
  static List<Account> accounts() => const [
        Account(id: 'demo-personal', name: 'Personal', type: null),
        Account(id: 'demo-team', name: 'Acme Corp', type: 'team'),
      ];

  static UsageSnapshot snapshot() {
    return UsageSnapshot(
      fetchedAt: _now,
      session: UsageWindow(
        key: 'five_hour',
        label: 'Session',
        utilization: 0.64,
        resetsAt: _now.add(const Duration(hours: 2, minutes: 14)),
      ),
      weekly: UsageWindow(
        key: 'seven_day',
        label: 'Weekly',
        utilization: 0.81,
        resetsAt: _now.add(const Duration(days: 2, hours: 9)),
      ),
      models: [
        UsageWindow(
            key: 'seven_day_opus',
            label: 'Opus',
            utilization: 0.88,
            resetsAt: _now.add(const Duration(days: 2, hours: 9))),
        UsageWindow(
            key: 'seven_day_sonnet',
            label: 'Sonnet',
            utilization: 0.42,
            resetsAt: _now.add(const Duration(days: 2, hours: 9))),
        UsageWindow(
            key: 'seven_day_cowork',
            label: 'Cowork',
            utilization: 0.21,
            resetsAt: _now.add(const Duration(days: 2, hours: 9))),
      ],
      extra: const ExtraUsage(
        isEnabled: true,
        currency: 'USD',
        usedCents: 1840,
        limitCents: 5000,
        balanceCents: 3160,
      ),
    );
  }

  /// 7 days of history at 30-minute resolution: a slow weekly climb that
  /// resets, with bursty session activity layered on top.
  static List<HistoryPoint> history() {
    final pts = <HistoryPoint>[];
    const steps = 7 * 48; // 336 samples
    final start = _now.subtract(const Duration(days: 7));
    final rnd = math.Random(42);
    var weeklyBase = 0.05;
    for (var i = 0; i < steps; i++) {
      final t = start.add(Duration(minutes: 30 * i));
      final dayPhase = (i % 48) / 48.0; // time-of-day 0..1
      // Session: active during "working hours", bursty.
      final active = math.sin(dayPhase * math.pi); // peak midday
      final burst = math.pow(rnd.nextDouble(), 2).toDouble();
      final session = (active * (0.35 + 0.6 * burst)).clamp(0.0, 1.0);
      // Weekly: accumulates, with a reset partway through.
      weeklyBase += session * 0.012;
      if (i == steps ~/ 2) weeklyBase = 0.08; // a reset event
      final weekly = weeklyBase.clamp(0.0, 1.0);
      pts.add(HistoryPoint(t: t, session: session.toDouble(), weekly: weekly));
    }
    return pts;
  }
}
