import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/claude_theme.dart';

/// Adaptive remaining-time string that shows the two most-significant units,
/// dropping down a tier as the deadline nears: `2d 3h` → `3h 20m` → `20m 5s` →
/// `45s`. Returns `now` once the target has passed. [from] defaults to the
/// current time; it is injectable so the tiering is deterministically testable.
String formatRemaining(DateTime target, {DateTime? from}) {
  final d = target.difference(from ?? DateTime.now());
  if (d.isNegative) return 'now';
  final days = d.inDays;
  final hours = d.inHours % 24;
  final mins = d.inMinutes % 60;
  final secs = d.inSeconds % 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${mins}m';
  if (mins > 0) return '${mins}m ${secs}s';
  return '${secs}s';
}

/// Fraction (0..1) of the adaptive countdown ring to fill for [secondsLeft]
/// seconds remaining. The ring's full sweep is the next round unit up, so it
/// stays legible at every scale: a 1-minute circle when only seconds remain, a
/// 1-hour circle when minutes remain, and a 12-hour face when hours remain.
/// Crossing a tier snaps the ring back to (nearly) full — the "unit switch".
double countdownFraction(int secondsLeft) {
  if (secondsLeft <= 0) return 0.0;
  if (secondsLeft < 60) return secondsLeft / 60.0; // → 1-minute circle
  if (secondsLeft < 3600) return secondsLeft / 3600.0; // → 1-hour circle
  final f = secondsLeft / 43200.0; // → 12-hour face
  return f > 1.0 ? 1.0 : f;
}

/// Short "updated N ago" relative string. [now] is injectable for tests.
String formatAgo(DateTime? updated, {DateTime? now}) {
  if (updated == null) return '—';
  final d = (now ?? DateTime.now()).difference(updated);
  final s = d.inSeconds;
  if (s < 5) return 'just now';
  if (s < 60) return '${s}s ago';
  final m = d.inMinutes;
  if (m < 60) return '${m}m ago';
  final h = d.inHours;
  if (h < 24) return '${h}h ago';
  return '${d.inDays}d ago';
}

/// Live "resets in …" countdown that ticks every second, optionally followed
/// by the absolute reset time/date.
class CountdownText extends StatefulWidget {
  const CountdownText({
    super.key,
    required this.resetsAt,
    required this.use24h,
    this.showDate = false,
    this.style,
  });

  final DateTime? resetsAt;
  final bool use24h;
  final bool showDate;
  final TextStyle? style;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? AppText.mono(AppColors.textSecondary, size: 11);
    final target = widget.resetsAt;
    if (target == null) {
      return Text('RESETS IN —', style: style);
    }
    final buf = StringBuffer('RESETS IN ${formatRemaining(target)}');
    if (widget.showDate) {
      final fmt = widget.use24h ? DateFormat('d MMM HH:mm') : DateFormat('d MMM h:mma');
      buf.write('  ·  ${fmt.format(target).toUpperCase()}');
    }
    return Text(buf.toString(), style: style);
  }
}

/// A self-refreshing "UPDATED … AGO" label that recomputes the relative time on
/// a 1-second timer, so it never freezes at the value captured when the parent
/// last rebuilt (which made it permanently read "UPDATED 0S AGO").
class UpdatedAgo extends StatefulWidget {
  const UpdatedAgo({super.key, required this.updated, this.style});

  final DateTime? updated;
  final TextStyle? style;

  @override
  State<UpdatedAgo> createState() => _UpdatedAgoState();
}

class _UpdatedAgoState extends State<UpdatedAgo> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? AppText.mono(AppColors.textFaint, size: 9);
    return Text('UPDATED ${formatAgo(widget.updated)}'.toUpperCase(),
        style: style);
  }
}

/// Live, unit-adaptive countdown *ring* shown once a window is maxed out: the
/// static "100 %" gives way to a heat-coloured arc that empties as the reset
/// approaches, with the remaining time ("2h 14m" → "45m 12s" → "30s") fitted in
/// the centre. The arc's full sweep adapts to the magnitude of the time left —
/// 12-hour face → 1-hour circle → 1-minute circle (see [countdownFraction]).
/// Auto-shrinks the centre label to fit whatever ring [size] it is given.
class RingCountdown extends StatefulWidget {
  const RingCountdown({
    super.key,
    required this.resetsAt,
    required this.color,
    required this.size,
    this.stroke = 9,
  });

  final DateTime? resetsAt;
  final Color color;
  final double size;
  final double stroke;

  @override
  State<RingCountdown> createState() => _RingCountdownState();
}

class _RingCountdownState extends State<RingCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.resetsAt;
    final now = DateTime.now();
    final secondsLeft = target == null ? 0 : target.difference(now).inSeconds;
    final fraction = countdownFraction(secondsLeft);
    final label = target == null ? '—' : formatRemaining(target, from: now);
    // Inner clear diameter, minus a little breathing room from the stroke.
    final budget = widget.size - widget.stroke * 2 - widget.size * 0.1;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _CountdownRingPainter(
          fraction: fraction,
          color: widget.color,
          stroke: widget.stroke,
        ),
        child: Center(
          child: SizedBox(
            width: budget,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: AppText.stat(widget.color).copyWith(
                  fontSize: widget.size * 0.22,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Faint full track + an emptying remaining-time arc for [RingCountdown].
class _CountdownRingPainter extends CustomPainter {
  _CountdownRingPainter({
    required this.fraction,
    required this.color,
    required this.stroke,
  });

  final double fraction; // 0..1 of a full sweep
  final Color color;
  final double stroke;

  static const _start = -math.pi / 2; // 12 o'clock
  static const _full = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Faint full track.
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

    // Remaining-time arc.
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        _start,
        _full * fraction,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) =>
      old.fraction != fraction || old.color != color || old.stroke != stroke;
}
