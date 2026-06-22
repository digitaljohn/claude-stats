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
}
