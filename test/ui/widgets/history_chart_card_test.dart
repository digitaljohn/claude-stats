import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/models/usage.dart';
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
    void Function(ChartSeries)? onSeries,
    void Function(ChartZoom)? onZoom,
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
}
