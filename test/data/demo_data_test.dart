import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/data/demo_data.dart';

void main() {
  // Asserts the snapshot's *shape* rather than the exact demo magnitudes,
  // which are deliberately hand-tuned for screenshots and change often.
  test('snapshot is fully populated and internally consistent', () {
    final snap = DemoData.snapshot();
    expect(snap.session.key, 'five_hour');
    expect(snap.session.label, 'Session');
    expect(snap.session.utilization, inInclusiveRange(0.0, 1.0));
    expect(snap.session.resetsAt, isNotNull);
    expect(snap.weekly.key, 'seven_day');
    expect(snap.weekly.label, 'Weekly');
    expect(snap.weekly.utilization, inInclusiveRange(0.0, 1.0));
    expect(snap.models.map((m) => m.label), ['Opus', 'Sonnet', 'Cowork']);
    for (final m in snap.models) {
      expect(m.utilization, inInclusiveRange(0.0, 1.0));
      expect(m.resetsAt, isNotNull);
    }
    expect(snap.extra, isNotNull);
    expect(snap.extra!.isEnabled, true);
    expect(snap.extra!.usedCents, greaterThanOrEqualTo(0));
  });

  test('history produces a full week of clamped samples with a mid reset', () {
    final pts = DemoData.history();
    expect(pts.length, 7 * 48);
    for (final p in pts) {
      expect(p.session, inInclusiveRange(0.0, 1.0));
      expect(p.weekly, inInclusiveRange(0.0, 1.0));
    }
    // Samples are chronological.
    expect(pts.first.t.isBefore(pts.last.t), isTrue);
    // The reset event drops the weekly value at the midpoint below the
    // sample just before it.
    final mid = (7 * 48) ~/ 2;
    expect(pts[mid].weekly, lessThan(pts[mid - 1].weekly));
  });

  test('accounts seed a personal + team org for the switcher', () {
    final accounts = DemoData.accounts();
    expect(accounts.length, 2);
    expect(accounts.map((a) => a.typeLabel), ['Personal', 'Team']);
    expect(accounts.map((a) => a.id).toSet().length, 2); // distinct ids
  });

  test('history is deterministic (seeded RNG)', () {
    final a = DemoData.history();
    final b = DemoData.history();
    expect(a.map((p) => p.session).toList(),
        b.map((p) => p.session).toList());
  });
}
