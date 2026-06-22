import '../../models/usage.dart';

/// Which history series the chart shows.
enum ChartSeries { session, weekly }

/// Maps the persisted history to a chronological 0..1 value list for the
/// selected series. [ChartColumns] downsamples this internally.
List<double> seriesValues(List<HistoryPoint> pts, ChartSeries series) => [
      for (final p in pts)
        series == ChartSeries.session ? p.session : p.weekly,
    ];
