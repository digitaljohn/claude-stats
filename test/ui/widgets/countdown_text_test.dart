import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/ui/widgets/countdown_text.dart';

void main() {
  group('formatRemaining', () {
    final now = DateTime(2026, 6, 22, 12);
    String at(Duration d) => formatRemaining(now.add(d), from: now);

    test('days + hours when more than a day out', () {
      expect(at(const Duration(days: 2, hours: 9)), '2d 9h');
    });

    test('hours + minutes when more than an hour out', () {
      expect(at(const Duration(hours: 1, minutes: 23)), '1h 23m');
    });

    test('minutes + seconds when under an hour', () {
      expect(at(const Duration(minutes: 45, seconds: 12)), '45m 12s');
    });

    test('seconds only when under a minute', () {
      expect(at(const Duration(seconds: 30)), '30s');
    });

    test('drops the minutes tier entirely once under a minute', () {
      // Not "0m 30s" — the seconds tier stands alone.
      expect(at(const Duration(seconds: 9)), '9s');
    });

    test('reads as "now" once elapsed', () {
      expect(formatRemaining(now.subtract(const Duration(seconds: 1)), from: now), 'now');
    });
  });

  group('countdownFraction', () {
    test('zero or past is empty', () {
      expect(countdownFraction(0), 0.0);
      expect(countdownFraction(-5), 0.0);
    });

    test('seconds tier fills out of one minute', () {
      expect(countdownFraction(30), closeTo(0.5, 1e-9));
      expect(countdownFraction(59), closeTo(59 / 60, 1e-9));
    });

    test('minutes tier fills out of one hour', () {
      expect(countdownFraction(60), closeTo(60 / 3600, 1e-9));
      expect(countdownFraction(2700), closeTo(0.75, 1e-9)); // 45 min
    });

    test('hours tier fills out of a 12-hour face and clamps', () {
      expect(countdownFraction(3600), closeTo(3600 / 43200, 1e-9)); // 1h
      expect(countdownFraction(6 * 3600), closeTo(0.5, 1e-9)); // 6h
      expect(countdownFraction(48 * 3600), 1.0); // clamps past 12h
    });
  });

  group('formatAgo', () {
    final now = DateTime(2026, 6, 22, 12);
    String at(Duration d) => formatAgo(now.subtract(d), now: now);

    test('null is an em dash', () => expect(formatAgo(null, now: now), '—'));
    test('under 5s reads "just now"',
        () => expect(at(const Duration(seconds: 2)), 'just now'));
    test('seconds', () => expect(at(const Duration(seconds: 42)), '42s ago'));
    test('minutes', () => expect(at(const Duration(minutes: 9)), '9m ago'));
    test('hours', () => expect(at(const Duration(hours: 3)), '3h ago'));
    test('days', () => expect(at(const Duration(days: 2)), '2d ago'));
  });
}
