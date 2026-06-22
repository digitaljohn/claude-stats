import '../../models/usage.dart';

/// Which history series the chart shows.
enum ChartSeries { session, weekly }

double _value(HistoryPoint p, ChartSeries s) =>
    s == ChartSeries.session ? p.session : p.weekly;

/// Bins [pts] into a fixed, time-accurate series over the trailing [days]-day
/// window ending at [now]: `days * binsPerDay` uniform time slices, each holding
/// the **peak** utilisation (0..1) of the samples that fall inside it, or `null`
/// for a slice with no samples (an honest gap).
///
/// Because the bins are fixed time slices — not one-per-sample — the chart reads
/// identically whether the history holds 8 points or 800, and the x-axis is real
/// time (so a "−7D … NOW" axis is actually true). Peak (not mean) aggregation is
/// deliberate: this is an *alerting* chart, so a breach must never be averaged
/// away.
List<double?> binnedSeries(
  List<HistoryPoint> pts,
  ChartSeries series, {
  required DateTime now,
  int days = 7,
  int binsPerDay = 4,
}) {
  final total = days * binsPerDay;
  final out = List<double?>.filled(total, null);
  final start = now.subtract(Duration(days: days));
  final spanMs = days * 24 * 60 * 60 * 1000;
  for (final p in pts) {
    final t = p.t;
    if (t.isBefore(start) || t.isAfter(now)) continue;
    final offsetMs = t.difference(start).inMilliseconds;
    // offsetMs is always >= 0 here (t >= start); only the upper edge (t == now)
    // can land one past the last bin, so just clamp the top.
    var idx = offsetMs * total ~/ spanMs;
    if (idx >= total) idx = total - 1;
    var v = _value(p, series);
    if (v.isNaN || v < 0.0) v = 0.0;
    if (v > 1.0) v = 1.0;
    final cur = out[idx];
    if (cur == null || v > cur) out[idx] = v;
  }
  return out;
}
