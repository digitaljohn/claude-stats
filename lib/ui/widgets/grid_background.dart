import 'package:flutter/material.dart';

import '../../theme/claude_theme.dart';

/// Claude-brand backdrop: warm charcoal ([AppColors.ink]) with a faint
/// warm-cream hairline grid, a soft neutral top glow to lift overlaid content,
/// and a bottom vignette. Static — no motion, no glitch.
class GridBackground extends StatelessWidget {
  const GridBackground({super.key, this.cell = 34});

  final double cell;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GridPainter(cell: cell),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.cell});
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = AppColors.current;
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.ink);

    final line = Paint()
      ..color = palette.gridSection // faint hairline grid
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    // Soft top glow.
    final glowRect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height * 0.16),
      radius: size.width * 0.9,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [palette.topGlow, const Color(0x00000000)], // faint lift
        ).createShader(glowRect),
    );

    // Bottom vignette.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.center,
          end: Alignment.bottomCenter,
          colors: [const Color(0x00000000), palette.bottomVignette],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.cell != cell;
}
