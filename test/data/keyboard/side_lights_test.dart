import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/data/keyboard/side_lights.dart';

void main() {
  group('sideZoneColor', () {
    SideColor z(double u) => sideZoneColor(u, warnAt: 0.75, dangerAt: 0.90);

    test('green below warn, amber in the warn band, red above danger', () {
      expect((z(0.50).r, z(0.50).g, z(0.50).b), (0, 255, 60)); // green
      expect((z(0.80).r, z(0.80).g, z(0.80).b), (255, 150, 0)); // amber
      expect((z(0.95).r, z(0.95).g, z(0.95).b), (255, 0, 0)); // red
    });

    test('thresholds are inclusive', () {
      expect((z(0.75).r, z(0.75).g, z(0.75).b), (255, 150, 0)); // == warn → amber
      expect((z(0.90).r, z(0.90).g, z(0.90).b), (255, 0, 0)); // == danger → red
    });
  });

  group('sidePercent', () {
    test('scales, rounds and clamps to 0..100', () {
      expect(sidePercent(0.0), 0);
      expect(sidePercent(0.5), 50);
      expect(sidePercent(0.644), 64);
      expect(sidePercent(1.0), 100);
      expect(sidePercent(1.5), 100); // clamped high
      expect(sidePercent(-0.2), 0); // clamped low
    });
  });
}
