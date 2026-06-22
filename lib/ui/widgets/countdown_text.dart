import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/claude_theme.dart';

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

  String _remaining(DateTime target) {
    final d = target.difference(DateTime.now());
    if (d.isNegative) return 'now';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    final secs = d.inSeconds % 60;
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? AppText.mono(AppColors.textSecondary, size: 11);
    final target = widget.resetsAt;
    if (target == null) {
      return Text('RESETS IN —', style: style);
    }
    final buf = StringBuffer('RESETS IN ${_remaining(target)}');
    if (widget.showDate) {
      final fmt = widget.use24h ? DateFormat('d MMM HH:mm') : DateFormat('d MMM h:mma');
      buf.write('  ·  ${fmt.format(target).toUpperCase()}');
    }
    return Text(buf.toString(), style: style);
  }
}
