import 'package:flutter/services.dart';

/// An RGB triple for a side-light strip (0–255 per channel). The keyboard's
/// own driver scales these down internally, so full-bright values are fine.
class SideColor {
  const SideColor(this.r, this.g, this.b);
  final int r;
  final int g;
  final int b;
}

// LED zone colours — hand-tuned on the actual WS2812 side strips to read like
// the app's heat ramp (white → amber → red). These aren't the literal AppColors
// hex: on these LEDs the app's amber (#E8A13C) looks yellow-green and its red
// (#E5564B) looks pink, so warn/danger are pushed toward orange / pure red.
const SideColor _kGood = SideColor(0xF5, 0xF4, 0xEE); // cream / white (= AppColors.good)
const SideColor _kWarn = SideColor(255, 100, 0); // amber
const SideColor _kDanger = SideColor(255, 0, 0); // red

/// The zone colour for a 0..1 utilisation, using the same warn/danger
/// thresholds the on-screen rings use.
SideColor sideZoneColor(double util,
    {required double warnAt, required double dangerAt}) {
  if (util >= dangerAt) return _kDanger;
  if (util >= warnAt) return _kWarn;
  return _kGood;
}

/// A 0..1 utilisation as an integer percent (0..100) for the fill height.
int sidePercent(double util) => (util.clamp(0.0, 1.0) * 100).round();

/// One frame for the two side strips: left = session, right = weekly.
class SideGauge {
  const SideGauge({
    required this.leftPct,
    required this.left,
    required this.rightPct,
    required this.right,
  });

  final int leftPct; // 0..100 — fill height of the left strip
  final SideColor left;
  final int rightPct; // 0..100 — fill height of the right strip
  final SideColor right;
}

/// Talks to the NuPhy Air75 V2's side LEDs. Detection + the actual HID writes
/// live in the native macOS layer; this is the seam tests fake.
abstract class SideLightDriver {
  /// Whether a compatible keyboard is reachable (USB / 2.4 GHz; not Bluetooth).
  Future<bool> detect();

  /// Pushes a gauge frame to the side strips.
  Future<void> setGauge(SideGauge gauge);

  /// Hands the side LEDs back to the keyboard's own animations.
  Future<void> release();
}

/// Real driver: a method channel onto the IOKit HID plugin in the macOS runner.
/// Every call is best-effort — a missing plugin / absent keyboard never throws
/// into the app. Excluded from coverage as untestable platform glue (the seam
/// is the [SideLightDriver] interface, faked in tests).
class MethodChannelSideLightDriver implements SideLightDriver {
  // coverage:ignore-start
  static const MethodChannel _channel = MethodChannel('claude_stats/sidelights');

  @override
  Future<bool> detect() async {
    try {
      return await _channel.invokeMethod<bool>('detect') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setGauge(SideGauge g) async {
    try {
      await _channel.invokeMethod<void>('setGauge', <String, int>{
        'leftPct': g.leftPct,
        'lr': g.left.r,
        'lg': g.left.g,
        'lb': g.left.b,
        'rightPct': g.rightPct,
        'rr': g.right.r,
        'rg': g.right.g,
        'rb': g.right.b,
      });
    } catch (_) {/* keyboard unplugged / firmware not flashed */}
  }

  @override
  Future<void> release() async {
    try {
      await _channel.invokeMethod<void>('release');
    } catch (_) {}
  }
  // coverage:ignore-end
}
