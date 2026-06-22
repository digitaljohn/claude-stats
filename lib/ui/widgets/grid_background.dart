import 'package:flutter/material.dart';

import '../../theme/claude_theme.dart';

/// Minimal Vercel-style backdrop: true black with a faint hairline grid and a
/// soft top glow to lift overlaid content. Static — no motion, no glitch.
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
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.ink);

    final line = Paint()
      ..color = const Color(0x09FFFFFF) // white @ ~3.5%
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
          colors: const [Color(0x14FFFFFF), Color(0x00000000)],
        ).createShader(glowRect),
    );

    // Bottom vignette.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.center,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x66000000)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.cell != cell;
}
