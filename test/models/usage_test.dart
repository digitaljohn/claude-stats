import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/models/usage.dart';

void main() {
  group('UsageWindow.fromJson / _normalizeUtil', () {
    test('normalises a 0–100 percentage to a 0..1 fraction', () {
      final w = UsageWindow.fromJson('five_hour', 'Session', {
        'utilization': 64,
        'resets_at': '2026-06-22T12:00:00Z',
      });
      expect(w.key, 'five_hour');
      expect(w.label, 'Session');
      expect(w.utilization, closeTo(0.64, 1e-9));
      expect(w.percent, 64);
      expect(w.resetsAt, isNotNull);
    });

    test('reads a small percentage as a fraction (1 → 0.01), no reset', () {
      // The live API sends a percentage, so `1` means 1% — not 100%. Mis-reading
      // it as maxed used to show a 1%-used session as a full / countdown ring.
      final w = UsageWindow.fromJson('five_hour', 'Session', const {'utilization': 1});
      expect(w.utilization, closeTo(0.01, 1e-9));
      expect(w.percent, 1);
      expect(w.resetsAt, isNull);
    });

    test('clamps out-of-range values to 1.0', () {
      final w = UsageWindow.fromJson('x', 'X', {'utilization': 150});
      expect(w.utilization, 1.0);
      expect(w.percent, 100);
    });

    test('parses a numeric-string utilization', () {
      final w = UsageWindow.fromJson('x', 'X', {'utilization': '42'});
      expect(w.utilization, closeTo(0.42, 1e-9));
    });

    test('falls back to 0 for an unparseable / null utilization', () {
      final w = UsageWindow.fromJson('x', 'X', {'utilization': 'nope'});
      expect(w.utilization, 0.0);
      final w2 = UsageWindow.fromJson('x', 'X', const {});
      expect(w2.utilization, 0.0);
    });
  });

  group('_parseTs (via UsageWindow.resetsAt)', () {
    test('ignores an empty timestamp string', () {
      final w = UsageWindow.fromJson('x', 'X', {'utilization': 0.1, 'resets_at': ''});
      expect(w.resetsAt, isNull);
    });

    test('ignores a non-string timestamp', () {
      final w = UsageWindow.fromJson('x', 'X', {'utilization': 0.1, 'resets_at': 12345});
      expect(w.resetsAt, isNull);
    });

    test('ignores an unparseable timestamp string', () {
      final w = UsageWindow.fromJson('x', 'X', {'utilization': 0.1, 'resets_at': 'not-a-date'});
      expect(w.resetsAt, isNull);
    });
  });

  group('ExtraUsage', () {
    test('utilization divides used by limit and clamps', () {
      const e = ExtraUsage(
        isEnabled: true,
        currency: 'USD',
        usedCents: 2500,
        limitCents: 5000,
        balanceCents: 2500,
      );
      expect(e.utilization, closeTo(0.5, 1e-9));
    });

    test('utilization is 0 when there is no limit', () {
      const e = ExtraUsage(
        isEnabled: false,
        currency: 'USD',
        usedCents: 100,
        limitCents: 0,
        balanceCents: 0,
      );
      expect(e.utilization, 0.0);
    });

    test('utilization clamps over-spend to 1.0', () {
      const e = ExtraUsage(
        isEnabled: true,
        currency: 'USD',
        usedCents: 9000,
        limitCents: 5000,
        balanceCents: 0,
      );
      expect(e.utilization, 1.0);
    });

    test('symbol covers each currency branch + default', () {
      ExtraUsage withCurrency(String c) => ExtraUsage(
            isEnabled: true,
            currency: c,
            usedCents: 0,
            limitCents: 1,
            balanceCents: 0,
          );
      expect(withCurrency('eur').symbol, '€');
      expect(withCurrency('GBP').symbol, '£');
      expect(withCurrency('usd').symbol, r'$');
      expect(withCurrency('JPY').symbol, r'$');
    });

    test('fmt renders cents with the currency symbol', () {
      const e = ExtraUsage(
        isEnabled: true,
        currency: 'GBP',
        usedCents: 1840,
        limitCents: 5000,
        balanceCents: 3160,
      );
      expect(e.fmt(1840), '£18.40');
      expect(e.fmt(0), '£0.00');
    });
  });

  test('UsageSnapshot defaults models to empty and extra to null', () {
    final snap = UsageSnapshot(
      fetchedAt: DateTime(2026, 6, 22),
      session: const UsageWindow(key: 'five_hour', label: 'Session', utilization: 0.5),
      weekly: const UsageWindow(key: 'seven_day', label: 'Weekly', utilization: 0.6),
    );
    expect(snap.models, isEmpty);
    expect(snap.extra, isNull);
    expect(snap.session.utilization, 0.5);
    expect(snap.weekly.utilization, 0.6);
  });

  group('HistoryPoint', () {
    test('round-trips through toJson/fromJson preserving local time', () {
      final p = HistoryPoint(t: DateTime(2026, 6, 22, 10), session: 0.4, weekly: 0.6);
      final back = HistoryPoint.fromJson(p.toJson());
      expect(back.t, p.t);
      expect(back.session, 0.4);
      expect(back.weekly, 0.6);
    });

    test('encode/decode round-trips a list', () {
      final pts = [
        HistoryPoint(t: DateTime(2026, 6, 22, 10), session: 0.4, weekly: 0.6),
        HistoryPoint(t: DateTime(2026, 6, 22, 11), session: 0.5, weekly: 0.62),
      ];
      final decoded = HistoryPoint.decode(HistoryPoint.encode(pts));
      expect(decoded.length, 2);
      expect(decoded.first.session, 0.4);
      expect(decoded.last.weekly, 0.62);
    });

    test('decode returns [] for null, empty, and malformed input', () {
      expect(HistoryPoint.decode(null), isEmpty);
      expect(HistoryPoint.decode(''), isEmpty);
      expect(HistoryPoint.decode('{not json'), isEmpty);
      // Valid JSON, wrong shape — also caught.
      expect(HistoryPoint.decode('{"t":1}'), isEmpty);
    });
  });
}
