import 'package:flutter/material.dart';

import '../../theme/claude_theme.dart';

/// Thin rounded progress bar with the warm heat colour and faint threshold
/// ticks. Animates to new values.
class HeatBar extends StatelessWidget {
  const HeatBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 6,
    this.warnAt = 0.75,
    this.dangerAt = 0.90,
    this.showTicks = true,
  });

  final double value; // 0..1
  final Color color;
  final double height;
  final double warnAt;
  final double dangerAt;
  final bool showTicks;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                width: w * v,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              if (showTicks)
                for (final th in [warnAt, dangerAt])
                  Positioned(
                    left: w * th - 0.5,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 1, color: AppColors.ink),
                  ),
            ],
          ),
        );
      },
    );
  }
}
