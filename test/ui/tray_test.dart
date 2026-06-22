import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/ui/tray.dart';

void main() {
  group('trayTitle', () {
    test('renders an em dash while usage is still loading', () {
      expect(trayTitle(null), '—');
    });

    test('formats the session percentage like a battery readout', () {
      expect(trayTitle(0), '0%');
      expect(trayTitle(64), '64%');
      expect(trayTitle(100), '100%');
    });
  });
}
