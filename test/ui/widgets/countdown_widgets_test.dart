import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/theme/claude_theme.dart';
import 'package:claude_stats/ui/widgets/countdown_text.dart';

import '../../helpers/test_harness.dart';

void main() {
  setUp(installPluginFakes);

  group('CountdownText widget', () {
    testWidgets('renders an em dash with no reset and ticks each second',
        (tester) async {
      await tester.pumpWidget(wrap(const CountdownText(resetsAt: null, use24h: false)));
      expect(find.text('RESETS IN —'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1)); // periodic rebuild
      await tester.pumpWidget(const SizedBox()); // dispose -> cancel timer
    });

    testWidgets('renders a live countdown with the absolute date appended',
        (tester) async {
      final target = DateTime.now().add(const Duration(hours: 5, minutes: 2));
      await tester.pumpWidget(wrap(CountdownText(
        resetsAt: target,
        use24h: true,
        showDate: true,
        style: AppText.mono(AppColors.textFaint, size: 9),
      )));
      expect(find.textContaining('RESETS IN'), findsOneWidget);
      expect(find.textContaining('·'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('uses a 12-hour absolute format when use24h is false',
        (tester) async {
      final target = DateTime.now().add(const Duration(days: 1, hours: 5));
      await tester.pumpWidget(wrap(CountdownText(
        resetsAt: target, use24h: false, showDate: true)));
      expect(find.textContaining('RESETS IN 1d'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('RingCountdown widget', () {
    testWidgets('renders an em dash when there is no reset time', (tester) async {
      await tester.pumpWidget(wrap(
        RingCountdown(resetsAt: null, color: AppColors.danger, size: 96),
        size: const Size(96, 96),
      ));
      expect(find.text('—'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('renders a fitted countdown and ticks', (tester) async {
      final target = DateTime.now().add(const Duration(minutes: 47, seconds: 20));
      await tester.pumpWidget(wrap(
        RingCountdown(
            resetsAt: target, color: AppColors.danger, size: 96, stroke: 8),
        size: const Size(96, 96),
      ));
      expect(find.byType(FittedBox), findsOneWidget);
      expect(find.textContaining('47m'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('UpdatedAgo widget', () {
    testWidgets('renders an em dash with no timestamp', (tester) async {
      await tester.pumpWidget(wrap(const UpdatedAgo(updated: null)));
      expect(find.text('UPDATED —'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows a relative time and ticks each second', (tester) async {
      final t = DateTime.now().subtract(const Duration(seconds: 8));
      await tester.pumpWidget(wrap(UpdatedAgo(updated: t)));
      expect(find.textContaining('AGO'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1)); // fire the periodic timer
      await tester.pumpWidget(const SizedBox());
    });
  });
}
