import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Column / bar telemetry chart, Vercel-styled.
///
/// One thin vertical bar per (downsampled) sample, bottom-aligned with
/// ~1px rounded tops. Bars are white by default and only adopt amber/red
/// where their value breaches [warnAt] / [dangerAt]. Faint baseline and
/// optional faint dashed warn/danger guide lines. No connecting line.
class ChartColumns extends StatelessWidget {
  const ChartColumns({
    super.key,
    required this.values,
    required this.warnAt,
    required this.dangerAt,
  });

  final List<double> values; // 0..1 utilisation, chronological (oldest first)
  final double warnAt; // 0..1
  final double dangerAt; // 0..1

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 358.0,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 150.0,
        );
        return CustomPaint(
          size: size,
          isComplex: false,
          willChange: false,
          painter: _ColumnsPainter(
            values: values,
            warnAt: warnAt,
            dangerAt: dangerAt,
          ),
        );
      },
    );
  }
}

class _ColumnsPainter extends CustomPainter {
  _ColumnsPainter({
    required this.values,
    required this.warnAt,
    required this.dangerAt,
  });

  final List<double> values;
  final double warnAt;
  final double dangerAt;

  // Palette
  static const Color _normal = Color(0xFFEDEDED);
  static const Color _warn = Color(0xFFF5A623);
  static const Color _danger = Color(0xFFFF4D4D);
  static const Color _grid = Color(0x14FFFFFF);
  // Faint dashed threshold guides (amber/red at ~28% alpha, pre-baked).
  static const Color _warnGuide = Color(0x47F5A623);
  static const Color _dangerGuide = Color(0x47FF4D4D);

  double _clamp01(double v) {
    if (v.isNaN) return 0.0;
    if (v < 0.0) return 0.0;
    if (v > 1.0) return 1.0;
    return v;
  }

  /// Downsample (or pass through) the input to at most [maxBars] buckets,
  /// taking the peak of each bucket so breaches are never hidden.
  List<double> _bucket(List<double> src, int maxBars) {
    if (src.isEmpty) return const <double>[];
    if (src.length <= maxBars) {
      return [for (final v in src) _clamp01(v)];
    }
    final out = List<double>.filled(maxBars, 0.0);
    final n = src.length;
    for (var i = 0; i < maxBars; i++) {
      final start = (i * n) ~/ maxBars;
      var end = ((i + 1) * n) ~/ maxBars;
      if (end <= start) end = start + 1;
      var peak = 0.0;
      for (var j = start; j < end && j < n; j++) {
        final v = _clamp01(src[j]);
        if (v > peak) peak = v;
      }
      out[i] = peak;
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Inset so rounded tops and baseline aren't clipped.
    const padTop = 10.0;
    const padBottom = 8.0;
    const padSide = 1.0;
    final plotTop = padTop;
    final plotBottom = (h - padBottom).clamp(padTop + 1.0, h);
    final plotLeft = padSide;
    final plotRight = (w - padSide).clamp(padSide + 1.0, w);
    final plotW = plotRight - plotLeft;
    final plotH = plotBottom - plotTop;
    if (plotW <= 0 || plotH <= 0) return;

    final baseY = plotBottom;

    // Decide bar count from available width: aim ~48-64 bars with a 2px gap.
    const gap = 2.0;
    const targetBar = 4.0; // nominal bar+gap budget
    var maxBars = ((plotW + gap) / (targetBar + gap)).floor();
    maxBars = maxBars.clamp(1, 64);

    final data = _bucket(values, maxBars);

    // Faint baseline (always drawn — gives the empty/zero state structure).
    final basePaint = Paint()
      ..isAntiAlias = true
      ..color = _grid
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    final by = baseY + 0.5; // crisp hairline
    canvas.drawLine(Offset(plotLeft, by), Offset(plotRight, by), basePaint);

    // Faint dashed guide lines for warn / danger thresholds.
    final cw = _clamp01(warnAt);
    final cd = _clamp01(dangerAt);
    _drawDashedGuide(canvas, plotLeft, plotRight, _yFor(cw, plotTop, plotH, baseY), _warnGuide);
    _drawDashedGuide(canvas, plotLeft, plotRight, _yFor(cd, plotTop, plotH, baseY), _dangerGuide);

    if (data.isEmpty) return;

    // Geometry: distribute bars evenly across the plot, gaps between.
    final count = data.length;
    final slot = plotW / count;
    var barW = slot - gap;
    if (barW < 1.0) barW = math.max(1.0, slot * 0.7);
    final radius = math.min(barW / 2.0, 1.5);

    final normalPaint = Paint()
      ..isAntiAlias = true
      ..color = _normal
      ..style = PaintingStyle.fill;
    final warnPaint = Paint()
      ..isAntiAlias = true
      ..color = _warn
      ..style = PaintingStyle.fill;
    final dangerPaint = Paint()
      ..isAntiAlias = true
      ..color = _danger
      ..style = PaintingStyle.fill;

    // A 1px stub so zero/near-zero samples still register as a tick.
    const minVisible = 1.0;

    for (var i = 0; i < count; i++) {
      final v = data[i];
      final cx = plotLeft + slot * i + slot / 2.0;
      var left = cx - barW / 2.0;
      var right = cx + barW / 2.0;
      // Keep within plot.
      if (left < plotLeft) left = plotLeft;
      if (right > plotRight) right = plotRight;

      var barH = v * plotH;
      if (barH < minVisible) barH = minVisible;
      final top = baseY - barH;

      // Colour means breach only: danger above dangerAt, amber above warnAt,
      // white otherwise.
      final Paint p;
      if (v >= cd) {
        p = dangerPaint;
      } else if (v >= cw) {
        p = warnPaint;
      } else {
        p = normalPaint;
      }

      final rect = Rect.fromLTRB(left, top, right, baseY);
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
      );
      canvas.drawRRect(rrect, p);
    }
  }

  double _yFor(double v, double plotTop, double plotH, double baseY) {
    return baseY - v * plotH;
  }

  void _drawDashedGuide(
    Canvas canvas,
    double x0,
    double x1,
    double y,
    Color color,
  ) {
    final paint = Paint()
      ..isAntiAlias = true
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.butt;
    const dash = 3.0;
    const space = 4.0;
    final yy = y.roundToDouble() + 0.5;
    var x = x0;
    while (x < x1) {
      final end = math.min(x + dash, x1);
      canvas.drawLine(Offset(x, yy), Offset(end, yy), paint);
      x += dash + space;
    }
  }

  @override
  bool shouldRepaint(covariant _ColumnsPainter old) {
    return old.warnAt != warnAt ||
        old.dangerAt != dangerAt ||
        !identical(old.values, values) ||
        old.values.length != values.length;
  }
}