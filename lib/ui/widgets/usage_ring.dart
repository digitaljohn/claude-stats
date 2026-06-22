import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/claude_theme.dart';

/// Circular usage gauge: faint full track, a heat-coloured progress arc with a
/// soft glow, and small notches marking the warn/danger thresholds.
class UsageRing extends StatelessWidget {
  const UsageRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 120,
    this.stroke = 9,
    this.warnAt = 0.75,
    this.dangerAt = 0.90,
    this.center,
  });

  final double value; // 0..1
  final Color color;
  final double size;
  final double stroke;
  final double warnAt;
  final double dangerAt;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          color: color,
          stroke: stroke,
          warnAt: warnAt,
          dangerAt: dangerAt,
        ),
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.stroke,
    required this.warnAt,
    required this.dangerAt,
  });

  final double value;
  final Color color;
  final double stroke;
  final double warnAt;
  final double dangerAt;

  static const _start = -math.pi / 2; // 12 o'clock
  static const _full = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track.
    canvas.drawArc(
      rect,
      0,
      _full,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.borderStrong,
    );

    // Progress arc (crisp, no glow).
    final sweep = _full * value;
    canvas.drawArc(
      rect,
      _start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    // Threshold notches.
    for (final th in [warnAt, dangerAt]) {
      final a = _start + _full * th;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * (radius - stroke / 2);
      final p2 = center + Offset(math.cos(a), math.sin(a)) * (radius + stroke / 2);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = AppColors.ink
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.stroke != stroke;
}
