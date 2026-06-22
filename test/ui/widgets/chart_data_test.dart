import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/models/usage.dart';
import 'package:claude_stats/ui/widgets/chart_data.dart';

void main() {
  // Fixed clock so binning is deterministic. With a 24h window / 4 bins, each
  // bin is 6h, starting at now-24h:
  //   bin0 [6/21 12:00–18:00)  bin1 [18:00–6/22 00:00)
  //   bin2 [6/22 00:00–06:00)  bin3 [06:00–12:00]
  final now = DateTime(2026, 6, 22, 12);
  const day = Duration(hours: 24);
  HistoryPoint hp(DateTime t, {double s = 0.0, double w = 0.0}) =>
      HistoryPoint(t: t, session: s, weekly: w);

  group('binnedSeries', () {
    test('empty history → all-null bins of the expected length', () {
      final bins = binnedSeries(const [], ChartSeries.session,
          now: now, window: day, bins: 4);
      expect(bins.length, 4);
      expect(bins.every((b) => b == null), isTrue);
    });

    test('places samples in the right time bin, leaving empty bins null', () {
      final bins = binnedSeries([
        hp(DateTime(2026, 6, 21, 13), s: 0.2), // bin0
        hp(DateTime(2026, 6, 22, 9), s: 0.5), // bin3
      ], ChartSeries.session, now: now, window: day, bins: 4);
      expect(bins, [0.2, null, null, 0.5]);
    });

    test('keeps the PEAK in a bin (a lower later sample never lowers it)', () {
      final bins = binnedSeries([
        hp(DateTime(2026, 6, 22, 9), s: 0.5),
        hp(DateTime(2026, 6, 22, 10), s: 0.8), // higher → wins
        hp(DateTime(2026, 6, 22, 11), s: 0.3), // lower → ignored
      ], ChartSeries.session, now: now, window: day, bins: 4);
      expect(bins[3], 0.8);
    });

    test('reads the weekly series when asked', () {
      final bins = binnedSeries([
        hp(DateTime(2026, 6, 22, 9), s: 0.1, w: 0.7),
      ], ChartSeries.weekly, now: now, window: day, bins: 4);
      expect(bins[3], 0.7);
    });

    test('excludes samples before the window and after now', () {
      final bins = binnedSeries([
        hp(DateTime(2026, 6, 20, 12), s: 0.9), // before the 24h window
        hp(DateTime(2026, 6, 22, 13), s: 0.9), // in the future
      ], ChartSeries.session, now: now, window: day, bins: 4);
      expect(bins.every((b) => b == null), isTrue);
    });

    test('a sample exactly at now lands in the last bin (top clamp)', () {
      final bins = binnedSeries([hp(now, s: 0.6)],
          ChartSeries.session, now: now, window: day, bins: 4);
      expect(bins.last, 0.6);
    });

    test('clamps NaN / negative / >1 into 0..1', () {
      final bins = binnedSeries([
        hp(DateTime(2026, 6, 21, 13), s: double.nan), // bin0 → 0
        hp(DateTime(2026, 6, 21, 19), s: -0.5), // bin1 → 0
        hp(DateTime(2026, 6, 22, 1), s: 1.4), // bin2 → 1
      ], ChartSeries.session, now: now, window: day, bins: 4);
      expect(bins[0], 0.0);
      expect(bins[1], 0.0);
      expect(bins[2], 1.0);
    });
  });

  group('zoomSpecs', () {
    test('week / day / 6h have the expected shape', () {
      expect(zoomSpecs[ChartZoom.week]!.bins, 28);
      expect(zoomSpecs[ChartZoom.week]!.sections, 7); // a day each
      expect(zoomSpecs[ChartZoom.day]!.bins, 24);
      expect(zoomSpecs[ChartZoom.day]!.sections, 4); // 6h each
      expect(zoomSpecs[ChartZoom.sixHours]!.bins, 24);
      expect(zoomSpecs[ChartZoom.sixHours]!.sections, 6); // 1h each
      expect(zoomSpecs[ChartZoom.week]!.label, '1W');
    });
  });

  group('axisLabels', () {
    const weekdays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'};

    test('week → 7 day labels ending in Today', () {
      final labels = axisLabels(ChartZoom.week, now);
      expect(labels.length, 7);
      expect(labels.last, 'Today');
      expect(labels.take(6).every(weekdays.contains), isTrue);
    });

    test('shorter zooms → honest endpoints', () {
      expect(axisLabels(ChartZoom.day, now), ['−24H', 'NOW']);
      expect(axisLabels(ChartZoom.sixHours, now), ['−6H', 'NOW']);
    });
  });
}
