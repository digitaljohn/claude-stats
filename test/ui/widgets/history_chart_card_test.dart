import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/models/usage.dart';
import 'package:claude_stats/ui/widgets/chart_columns.dart';
import 'package:claude_stats/ui/widgets/chart_data.dart';
import 'package:claude_stats/ui/widgets/history_chart_card.dart';

import '../../helpers/test_harness.dart';

void main() {
  setUp(() async {
    installPluginFakes();
    await loadTestFonts();
  });

  final now = DateTime(2026, 6, 22, 12);
  List<HistoryPoint> hist() => [
        for (var i = 0; i < 20; i++)
          HistoryPoint(
              t: now.subtract(Duration(hours: i * 3)),
              session: (i % 5) / 5,
              weekly: 0.4),
      ];

  Future<void> pump(
    WidgetTester tester, {
    required ChartSeries series,
    required ChartZoom zoom,
    DateTime? end,
    void Function(ChartSeries)? onSeries,
    void Function(ChartZoom)? onZoom,
    void Function(Duration)? onPan,
    void Function()? onJumpToNow,
  }) async {
    await tester.pumpWidget(wrap(HistoryChartCard(
      history: hist(),
      series: series,
      zoom: zoom,
      currentUtil: 0.64,
      percent: 64,
      warnAt: 0.75,
      dangerAt: 0.90,
      now: now,
      end: end,
      onPan: onPan,
      onJumpToNow: onJumpToNow,
      onSeries: onSeries ?? (_) {},
      onZoom: onZoom ?? (_) {},
    )));
  }

  testWidgets('week zoom: weekday axis, % read-out, toggles fire',
      (tester) async {
    ChartSeries? gotSeries;
    ChartZoom? gotZoom;
    await pump(tester,
        series: ChartSeries.session,
        zoom: ChartZoom.week,
        onSeries: (v) => gotSeries = v,
        onZoom: (v) => gotZoom = v);

    expect(find.text('64%'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget); // weekday axis, week zoom

    await tester.tap(find.text('WEEKLY'));
    await tester.pump();
    expect(gotSeries, ChartSeries.weekly);

    await tester.tap(find.text('1D'));
    await tester.pump();
    expect(gotZoom, ChartZoom.day);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('day zoom: relative endpoints on the axis', (tester) async {
    await pump(tester, series: ChartSeries.weekly, zoom: ChartZoom.day);
    expect(find.text('−24H'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('six-hour zoom: relative endpoints on the axis', (tester) async {
    await pump(tester, series: ChartSeries.session, zoom: ChartZoom.sixHours);
    expect(find.text('−6H'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('horizontal drag pans into the past (onPan, back > 0)',
      (tester) async {
    var total = Duration.zero;
    await pump(tester,
        series: ChartSeries.session,
        zoom: ChartZoom.sixHours,
        onPan: (d) => total += d);
    await tester.drag(find.byType(ChartColumns), const Offset(120, 0)); // right
    expect(total, greaterThan(Duration.zero)); // dragging right = pan back
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('panned: axis shows the window edges + tappable jump-to-now',
      (tester) async {
    var jumped = false;
    await pump(tester,
        series: ChartSeries.session,
        zoom: ChartZoom.sixHours,
        end: now.subtract(const Duration(hours: 12)),
        onJumpToNow: () => jumped = true);

    expect(find.text('−12H'), findsOneWidget); // right edge, not "NOW"
    expect(find.text('−18H'), findsOneWidget); // left edge
    expect(find.byIcon(Icons.fast_forward_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fast_forward_rounded));
    await tester.pump();
    expect(jumped, isTrue);

    await tester.pumpWidget(const SizedBox());
  });
}
