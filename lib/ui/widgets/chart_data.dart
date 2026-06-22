import '../../models/usage.dart';

/// Which history series the chart shows.
enum ChartSeries { session, weekly }

/// How far back the chart looks (and how finely it bins).
enum ChartZoom { week, day, sixHours }

/// Window length, bin count and gridline spacing for each [ChartZoom].
class ZoomSpec {
  const ZoomSpec({
    required this.window,
    required this.bins,
    required this.gridEvery,
    required this.label,
  });

  /// Trailing time span shown (ending "now").
  final Duration window;

  /// Number of uniform time slices across [window].
  final int bins;

  /// Draw a faint vertical gridline every [gridEvery] bins (a "section").
  final int gridEvery;

  /// Short toggle label.
  final String label;

  /// Sections across the window (= number of gridline groups).
  int get sections => bins ~/ gridEvery;
}

const Map<ChartZoom, ZoomSpec> zoomSpecs = {
  // 7 days in 6-hour slices, a gridline per day (7 day sections).
  ChartZoom.week:
      ZoomSpec(window: Duration(days: 7), bins: 28, gridEvery: 4, label: '1W'),
  // 24 hours in 1-hour slices, a gridline every 6h (4 sections).
  ChartZoom.day:
      ZoomSpec(window: Duration(hours: 24), bins: 24, gridEvery: 6, label: '1D'),
  // 6 hours in 15-minute slices, a gridline per hour (6 sections).
  ChartZoom.sixHours:
      ZoomSpec(window: Duration(hours: 6), bins: 24, gridEvery: 4, label: '6H'),
};

double _value(HistoryPoint p, ChartSeries s) =>
    s == ChartSeries.session ? p.session : p.weekly;

/// Bins [pts] into a fixed, time-accurate series over the trailing [window]
/// ending at [now]: [bins] uniform time slices, each holding the **peak**
/// utilisation (0..1) of the samples that fall inside it, or `null` for a slice
/// with no samples (an honest gap).
///
/// Because the bins are fixed time slices — not one-per-sample — the chart reads
/// identically whether the history holds 8 points or 800, and the x-axis is real
/// time. Peak (not mean) aggregation is deliberate: this is an *alerting* chart,
/// so a breach must never be averaged away.
List<double?> binnedSeries(
  List<HistoryPoint> pts,
  ChartSeries series, {
  required DateTime now,
  required Duration window,
  required int bins,
}) {
  final out = List<double?>.filled(bins, null);
  final start = now.subtract(window);
  final spanMs = window.inMilliseconds;
  for (final p in pts) {
    final t = p.t;
    if (t.isBefore(start) || t.isAfter(now)) continue;
    final offsetMs = t.difference(start).inMilliseconds;
    // offsetMs is always >= 0 here (t >= start); only the upper edge (t == now)
    // can land one past the last bin, so just clamp the top.
    var idx = offsetMs * bins ~/ spanMs;
    if (idx >= bins) idx = bins - 1;
    var v = _value(p, series);
    if (v.isNaN || v < 0.0) v = 0.0;
    if (v > 1.0) v = 1.0;
    final cur = out[idx];
    if (cur == null || v > cur) out[idx] = v;
  }
  return out;
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Bottom-axis labels for the chart, left → newest-on-the-right.
///
/// Week view: one short weekday per day, the rightmost being "Today". Shorter
/// zooms: just the two honest endpoints (e.g. "−24H" … "NOW").
List<String> axisLabels(ChartZoom zoom, DateTime now) {
  switch (zoom) {
    case ChartZoom.week:
      return [
        for (var i = 0; i < 7; i++)
          i == 6
              ? 'Today'
              : _weekdays[now.subtract(Duration(days: 6 - i)).weekday - 1],
      ];
    case ChartZoom.day:
      return const ['−24H', 'NOW'];
    case ChartZoom.sixHours:
      return const ['−6H', 'NOW'];
  }
}
