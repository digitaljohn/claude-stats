import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/theme/claude_theme.dart';
import 'package:claude_stats/ui/widgets/app_card.dart';
import 'package:claude_stats/ui/widgets/chart_columns.dart';
import 'package:claude_stats/ui/widgets/grid_background.dart';
import 'package:claude_stats/ui/widgets/heat_bar.dart';
import 'package:claude_stats/ui/widgets/usage_ring.dart';

import '../../helpers/test_harness.dart';

void main() {
  setUp(installPluginFakes);

  group('AppCard / SectionLabel', () {
    testWidgets('render with default and custom padding', (tester) async {
      await tester.pumpWidget(wrap(const Column(children: [
        AppCard(child: Text('a')),
        AppCard(padding: EdgeInsets.all(4), child: Text('b')),
        SectionLabel('hello'),
        SectionLabel('coloured', color: AppColors.warn),
      ])));
      expect(find.byType(AppCard), findsNWidgets(2));
      // SectionLabel upper-cases its text.
      expect(find.text('HELLO'), findsOneWidget);
    });
  });

  group('GridBackground', () {
    testWidgets('paints and repaints on a cell change', (tester) async {
      await tester.pumpWidget(wrap(const GridBackground()));
      expect(find.byType(GridBackground), findsOneWidget);
      await tester.pumpWidget(wrap(const GridBackground(cell: 20)));
      await tester.pump();
    });
  });

  group('UsageRing', () {
    testWidgets('renders with a centre child and repaints on value change',
        (tester) async {
      await tester.pumpWidget(wrap(
        const UsageRing(value: 0.3, color: AppColors.good, center: Text('30%')),
        size: const Size(200, 200),
      ));
      expect(find.text('30%'), findsOneWidget);
      // New value -> shouldRepaint true.
      await tester.pumpWidget(wrap(
        const UsageRing(value: 0.95, color: AppColors.danger, center: Text('95%')),
        size: const Size(200, 200),
      ));
      await tester.pump();
      expect(find.text('95%'), findsOneWidget);
    });

    testWidgets('renders without a centre child and clamps out-of-range values',
        (tester) async {
      await tester.pumpWidget(wrap(
        const UsageRing(value: 1.5, color: AppColors.good),
        size: const Size(120, 120),
      ));
      expect(find.byType(UsageRing), findsOneWidget);
    });
  });

  group('HeatBar', () {
    testWidgets('renders with and without threshold ticks', (tester) async {
      await tester.pumpWidget(wrap(const Column(children: [
        HeatBar(value: 0.4, color: AppColors.good),
        HeatBar(value: 1.2, color: AppColors.danger, showTicks: false, height: 5),
      ])));
      expect(find.byType(HeatBar), findsNWidgets(2));
      await tester.pump(const Duration(milliseconds: 600)); // settle animation
    });
  });

  group('ChartColumns painter', () {
    Widget chart(List<double> values, {double w = 358, double h = 150}) => wrap(
          ChartColumns(values: values, warnAt: 0.75, dangerAt: 0.90),
          size: Size(w, h),
        );

    testWidgets('empty series draws only the baseline + guides', (tester) async {
      await tester.pumpWidget(chart(const []));
      expect(find.byType(ChartColumns), findsOneWidget);
    });

    testWidgets('few samples pass through with breaches in every colour band',
        (tester) async {
      await tester.pumpWidget(chart(const [0.0, 0.5, 0.8, 0.95, double.nan, -0.2, 1.4]));
      await tester.pump();
    });

    testWidgets('many samples are downsampled (bucketing peak)', (tester) async {
      final many = [for (var i = 0; i < 400; i++) (i % 100) / 100.0];
      await tester.pumpWidget(chart(many));
      // Repaint with a longer list -> shouldRepaint true (length differs).
      await tester.pumpWidget(chart([...many, 0.9]));
      await tester.pump();
    });

    testWidgets('narrow width forces the minimum bar width path', (tester) async {
      final many = [for (var i = 0; i < 200; i++) 0.5];
      await tester.pumpWidget(chart(many, w: 150));
      await tester.pump();
    });

    testWidgets('repaint with the identical list + thresholds is a no-op',
        (tester) async {
      final values = [0.1, 0.5, 0.9];
      // Two builds share the same list instance and thresholds, so
      // shouldRepaint walks every clause (including the length check) to false.
      await tester.pumpWidget(chart(values));
      await tester.pumpWidget(chart(values));
      await tester.pump();
    });
  });
}
