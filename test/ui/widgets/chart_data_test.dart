import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/models/usage.dart';
import 'package:claude_stats/ui/widgets/chart_data.dart';

void main() {
  final pts = [
    HistoryPoint(t: DateTime(2026, 6, 22, 10), session: 0.2, weekly: 0.5),
    HistoryPoint(t: DateTime(2026, 6, 22, 11), session: 0.4, weekly: 0.6),
  ];

  test('seriesValues extracts the session series in order', () {
    expect(seriesValues(pts, ChartSeries.session), [0.2, 0.4]);
  });

  test('seriesValues extracts the weekly series in order', () {
    expect(seriesValues(pts, ChartSeries.weekly), [0.5, 0.6]);
  });

  test('seriesValues on empty history is empty', () {
    expect(seriesValues(const [], ChartSeries.session), isEmpty);
  });
}
