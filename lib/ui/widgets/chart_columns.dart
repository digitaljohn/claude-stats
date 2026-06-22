import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Time-binned column chart, Claude-styled.
///
/// [bins] is a fixed-length, time-accurate series (see `binnedSeries`): one
/// uniform time slice per entry, oldest first, where `null` means "no data in
/// that slice" (an honest gap) and a value is that slice's peak utilisation
/// (0..1). A faint vertical gridline is drawn every [gridEvery] slices, marking
/// the section boundaries (days at the week zoom, hours at shorter zooms).
///
/// Bars are cream by default and only adopt amber/red where their value breaches
/// [warnAt] / [dangerAt]. A no-data slice draws nothing (bare baseline), which
/// reads differently from a recorded-but-tiny slice (a 1px cream tick). Faint
/// baseline and dashed warn/danger guide lines complete the frame.
class ChartColumns extends StatelessWidget {
  const ChartColumns({
    super.key,
    required this.bins,
    required this.gridEvery,
    required this.warnAt,
    required this.dangerAt,
  });

  /// Fixed time slices, oldest → newest; `null` = no data recorded in the slice.
  final List<double?> bins;

  /// A faint vertical gridline is drawn every [gridEvery] slices.
  final int gridEvery;

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
            bins: bins,
            gridEvery: gridEvery,
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
    required this.bins,
    required this.gridEvery,
    required this.warnAt,
    required this.dangerAt,
  });

  final List<double?> bins;
  final int gridEvery;
  final double warnAt;
  final double dangerAt;

  // Palette — Claude state ramp (cream → amber → red).
  static const Color _normal = Color(0xFFF5F4EE);
  static const Color _warn = Color(0xFFE8A13C);
  static const Color _danger = Color(0xFFE5564B);
  static const Color _grid = Color(0x12FAF9F5); // warm hairline grid
  static const Color _day = Color(0x0AFAF9F5); // even fainter day separators
  // Faint dashed threshold guides (amber/red at ~28% alpha, pre-baked).
  static const Color _warnGuide = Color(0x47E8A13C);
  static const Color _dangerGuide = Color(0x47E5564B);

  double _clamp01(double v) {
    if (v.isNaN) return 0.0;
    if (v < 0.0) return 0.0;
    if (v > 1.0) return 1.0;
    return v;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Inset so rounded tops aren't clipped (top) and the bottom axis labels
    // drawn over the chart have a clear band beneath the bars (bottom).
    const padTop = 10.0;
    const padBottom = 22.0;
    const padSide = 1.0;
    final plotTop = padTop;
    final plotBottom = (h - padBottom).clamp(padTop + 1.0, h);
    final plotLeft = padSide;
    final plotRight = (w - padSide).clamp(padSide + 1.0, w);
    final plotW = plotRight - plotLeft;
    final plotH = plotBottom - plotTop;
    if (plotW <= 0 || plotH <= 0) return;

    final baseY = plotBottom;

    // Faint vertical section separators (every [gridEvery] slices).
    final total = bins.length;
    final sections = (gridEvery > 0) ? (total / gridEvery) : 0.0;
    if (sections > 1) {
      final sectionPaint = Paint()
        ..isAntiAlias = false
        ..color = _day
        ..strokeWidth = 1.0;
      final sectionW = plotW / sections;
      for (var d = 1; d < sections; d++) {
        final x = (plotLeft + d * sectionW).roundToDouble() + 0.5;
        canvas.drawLine(Offset(x, plotTop), Offset(x, baseY), sectionPaint);
      }
    }

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
    _drawDashedGuide(canvas, plotLeft, plotRight, _yFor(cw, plotH, baseY), _warnGuide);
    _drawDashedGuide(canvas, plotLeft, plotRight, _yFor(cd, plotH, baseY), _dangerGuide);

    if (total == 0) return;

    // Geometry: distribute one slot per bin evenly (slots ARE uniform time
    // slices, so x is real time), with a gap between bars.
    final slot = plotW / total;
    const gap = 2.0;
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

    // A 1px stub so a recorded-but-tiny slice still registers as a tick — and
    // stays visually distinct from a no-data slice, which draws nothing.
    const minVisible = 1.0;

    for (var i = 0; i < total; i++) {
      final raw = bins[i];
      if (raw == null) continue; // no data in this slice → bare baseline
      final v = _clamp01(raw);
      final cx = plotLeft + slot * i + slot / 2.0;
      var left = cx - barW / 2.0;
      var right = cx + barW / 2.0;
      if (left < plotLeft) left = plotLeft;
      if (right > plotRight) right = plotRight;

      var barH = v * plotH;
      if (barH < minVisible) barH = minVisible;
      final top = baseY - barH;

      // Colour means breach only: danger above dangerAt, amber above warnAt,
      // cream otherwise.
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

  double _yFor(double v, double plotH, double baseY) => baseY - v * plotH;

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
        old.gridEvery != gridEvery ||
        !listEquals(old.bins, bins);
  }
}
