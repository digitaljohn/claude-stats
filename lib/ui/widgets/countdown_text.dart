import 'dart:async';

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

/// Compact live countdown shown *inside* the usage ring once a window is maxed
/// out — the static "100%" gives way to a ticking "resets in" figure that
/// scales its precision (hours → minutes → seconds) as the reset approaches.
/// Auto-shrinks to fit whatever ring [size] it is dropped into.
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
    final label = target == null ? '—' : formatRemaining(target);
    // Inner clear diameter, minus a little breathing room from the stroke.
    final budget = widget.size - widget.stroke * 2 - widget.size * 0.1;
    return SizedBox(
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
    );
  }
}
