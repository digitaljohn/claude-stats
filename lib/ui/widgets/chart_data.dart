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

/// A relative-to-now label for a duration: "NOW", "−6H", or "−3D".
String relLabel(Duration d) {
  final h = d.inHours;
  if (h <= 0) return 'NOW';
  if (h < 48) return '−${h}H';
  return '−${d.inDays}D';
}

String _weekdayLabel(DateTime end, int i, DateTime now) {
  final day = end.subtract(Duration(days: 6 - i));
  final isToday =
      day.year == now.year && day.month == now.month && day.day == now.day;
  return isToday ? 'Today' : _weekdays[day.weekday - 1];
}

/// Bottom-axis labels for the window ending at [end] (≤ [now]), left →
/// right-is-newest.
///
/// Live (end == now): week view shows a weekday per day ending in "Today";
/// shorter zooms show "−24H" … "NOW". Panned into the past, the labels track the
/// window's real edges (e.g. "−18H" … "−12H", weekday names anchored at [end]).
List<String> axisLabels(ChartZoom zoom, DateTime end, DateTime now) {
  switch (zoom) {
    case ChartZoom.week:
      return [for (var i = 0; i < 7; i++) _weekdayLabel(end, i, now)];
    case ChartZoom.day:
    case ChartZoom.sixHours:
      final window = zoomSpecs[zoom]!.window;
      return [
        relLabel(now.difference(end.subtract(window))),
        relLabel(now.difference(end)),
      ];
  }
}

/// The window's right-edge anchor after panning [back] from [current]
/// (null = live/now). Returns null to snap back to live when: the pan reaches or
/// passes [now], there's no history ([earliest] null), or the history is shorter
/// than the [window]. Otherwise it pans into the past, clamped so the oldest
/// sample stays in view.
DateTime? pannedAnchor({
  required DateTime? current,
  required Duration back,
  required DateTime now,
  required Duration window,
  required DateTime? earliest,
}) {
  var end = (current ?? now).subtract(back);
  if (!end.isBefore(now)) return null; // at / past the present → live
  if (earliest == null) return null; // nothing recorded yet
  final minEnd = earliest.add(window);
  if (!minEnd.isBefore(now)) return null; // less than one window of history
  if (end.isBefore(minEnd)) end = minEnd; // don't scroll past the oldest data
  return end;
}
