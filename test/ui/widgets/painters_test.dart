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
      await tester.pumpWidget(wrap(Column(children: [
        const AppCard(child: Text('a')),
        const AppCard(padding: EdgeInsets.all(4), child: Text('b')),
        const SectionLabel('hello'),
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
        UsageRing(value: 0.3, color: AppColors.good, center: const Text('30%')),
        size: const Size(200, 200),
      ));
      expect(find.text('30%'), findsOneWidget);
      // New value -> shouldRepaint true.
      await tester.pumpWidget(wrap(
        UsageRing(
            value: 0.95, color: AppColors.danger, center: const Text('95%')),
        size: const Size(200, 200),
      ));
      await tester.pump();
      expect(find.text('95%'), findsOneWidget);
    });

    testWidgets('renders without a centre child and clamps out-of-range values',
        (tester) async {
      await tester.pumpWidget(wrap(
        UsageRing(value: 1.5, color: AppColors.good),
        size: const Size(120, 120),
      ));
      expect(find.byType(UsageRing), findsOneWidget);
    });
  });

  group('HeatBar', () {
    testWidgets('renders with and without threshold ticks', (tester) async {
      await tester.pumpWidget(wrap(Column(children: [
        HeatBar(value: 0.4, color: AppColors.good),
        HeatBar(value: 1.2, color: AppColors.danger, showTicks: false, height: 5),
      ])));
      expect(find.byType(HeatBar), findsNWidgets(2));
      await tester.pump(const Duration(milliseconds: 600)); // settle animation
    });
  });

  group('ChartColumns painter', () {
    Widget chart(List<double?> bins,
            {int gridEvery = 4, double w = 358, double h = 150}) =>
        wrap(
          ChartColumns(
              bins: bins, gridEvery: gridEvery, warnAt: 0.75, dangerAt: 0.90),
          size: Size(w, h),
        );

    testWidgets('empty bins draw only the baseline + guides', (tester) async {
      await tester.pumpWidget(chart(const []));
      expect(find.byType(ChartColumns), findsOneWidget);
    });

    testWidgets('all-null bins render as gaps over the day gridlines',
        (tester) async {
      await tester.pumpWidget(
          chart(const [null, null, null, null, null, null, null, null]));
      await tester.pump();
    });

    testWidgets('values render in every colour band; nulls are skipped',
        (tester) async {
      // 28 six-hourly bins (days > 1 → day gridlines drawn).
      final bins = <double?>[
        for (var i = 0; i < 28; i++) i % 4 == 0 ? null : i / 28.0,
      ];
      bins[5] = 0.0; // recorded-but-zero slice → minVisible stub
      bins[26] = 0.82; // warn band
      bins[27] = 0.97; // danger band
      await tester.pumpWidget(chart(bins));
      await tester.pump();
    });

    testWidgets('a single-day window draws no day separators', (tester) async {
      // gridEvery == length → days == 1 → the gridline branch is skipped.
      await tester.pumpWidget(chart(const [0.1, 0.5, 0.9, 0.4], gridEvery: 4));
      await tester.pump();
    });

    testWidgets('narrow width forces the min bar width + edge clamps',
        (tester) async {
      final many = <double?>[for (var i = 0; i < 200; i++) 0.5];
      await tester.pumpWidget(chart(many, w: 150));
      await tester.pump();
    });

    testWidgets('repaint: identical bins is a no-op; any change repaints',
        (tester) async {
      final bins = <double?>[0.1, null, 0.9, 0.5];
      await tester.pumpWidget(chart(bins));
      await tester.pumpWidget(chart(bins)); // same instance → no repaint
      await tester.pumpWidget(chart(<double?>[0.1, null, 0.9, 0.6])); // changed
      await tester.pump();
    });
  });
}
