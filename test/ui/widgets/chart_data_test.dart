import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/models/usage.dart';
import 'package:claude_stats/ui/widgets/chart_data.dart';

void main() {
  // Fixed clock so binning is deterministic. With days:1, binsPerDay:4 the
  // window is the 24h ending at `now`, split into four 6-hour bins:
  //   bin0 [6/21 12:00–18:00)  bin1 [18:00–6/22 00:00)
  //   bin2 [6/22 00:00–06:00)  bin3 [06:00–12:00]
  final now = DateTime(2026, 6, 22, 12);
  HistoryPoint hp(DateTime t, {double s = 0.0, double w = 0.0}) =>
      HistoryPoint(t: t, session: s, weekly: w);

  test('empty history → all-null bins of the expected length', () {
    final bins =
        binnedSeries(const [], ChartSeries.session, now: now, days: 1, binsPerDay: 4);
    expect(bins.length, 4);
    expect(bins.every((b) => b == null), isTrue);
  });

  test('places samples in the right time bin, leaving empty bins null', () {
    final bins = binnedSeries([
      hp(DateTime(2026, 6, 21, 13), s: 0.2), // bin0
      hp(DateTime(2026, 6, 22, 9), s: 0.5), // bin3
    ], ChartSeries.session, now: now, days: 1, binsPerDay: 4);
    expect(bins, [0.2, null, null, 0.5]);
  });

  test('keeps the PEAK in a bin (a lower later sample never lowers it)', () {
    final bins = binnedSeries([
      hp(DateTime(2026, 6, 22, 9), s: 0.5),
      hp(DateTime(2026, 6, 22, 10), s: 0.8), // higher → wins
      hp(DateTime(2026, 6, 22, 11), s: 0.3), // lower → ignored
    ], ChartSeries.session, now: now, days: 1, binsPerDay: 4);
    expect(bins[3], 0.8);
  });

  test('reads the weekly series when asked', () {
    final bins = binnedSeries([
      hp(DateTime(2026, 6, 22, 9), s: 0.1, w: 0.7),
    ], ChartSeries.weekly, now: now, days: 1, binsPerDay: 4);
    expect(bins[3], 0.7);
  });

  test('excludes samples before the window and after now', () {
    final bins = binnedSeries([
      hp(DateTime(2026, 6, 20, 12), s: 0.9), // a day before the 1-day window
      hp(DateTime(2026, 6, 22, 13), s: 0.9), // in the future
    ], ChartSeries.session, now: now, days: 1, binsPerDay: 4);
    expect(bins.every((b) => b == null), isTrue);
  });

  test('a sample exactly at now lands in the last bin (top clamp)', () {
    final bins = binnedSeries([
      hp(now, s: 0.6),
    ], ChartSeries.session, now: now, days: 1, binsPerDay: 4);
    expect(bins.last, 0.6);
  });

  test('clamps NaN / negative / >1 into 0..1', () {
    final bins = binnedSeries([
      hp(DateTime(2026, 6, 21, 13), s: double.nan), // bin0 → 0
      hp(DateTime(2026, 6, 21, 19), s: -0.5), // bin1 → 0
      hp(DateTime(2026, 6, 22, 1), s: 1.4), // bin2 → 1
    ], ChartSeries.session, now: now, days: 1, binsPerDay: 4);
    expect(bins[0], 0.0);
    expect(bins[1], 0.0);
    expect(bins[2], 1.0);
  });

  test('default 7-day / 6-hourly window yields 28 bins', () {
    expect(
      binnedSeries(const [], ChartSeries.session, now: now).length,
      28,
    );
  });
}
