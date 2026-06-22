import 'package:flutter/material.dart';

import '../../models/usage.dart';
import '../../theme/claude_theme.dart';
import 'app_card.dart';
import 'chart_columns.dart';
import 'chart_data.dart';

/// The usage-history card: a [series] toggle (session / weekly), a [zoom] toggle
/// (1W / 1D / 6H), the current value read-out, the time-binned [ChartColumns]
/// chart, and a zoom-aware bottom axis (weekday names at the week zoom, relative
/// endpoints below it).
///
/// Fully controlled — it owns no state; the parent supplies [series] / [zoom]
/// and is notified via [onSeries] / [onZoom].
class HistoryChartCard extends StatelessWidget {
  const HistoryChartCard({
    super.key,
    required this.history,
    required this.series,
    required this.zoom,
    required this.currentUtil,
    required this.percent,
    required this.warnAt,
    required this.dangerAt,
    required this.now,
    required this.onSeries,
    required this.onZoom,
  });

  final List<HistoryPoint> history;
  final ChartSeries series;
  final ChartZoom zoom;
  final double currentUtil; // 0..1, drives the read-out colour
  final int percent; // current value, big read-out
  final double warnAt;
  final double dangerAt;
  final DateTime now;
  final ValueChanged<ChartSeries> onSeries;
  final ValueChanged<ChartZoom> onZoom;

  @override
  Widget build(BuildContext context) {
    final spec = zoomSpecs[zoom]!;
    final bins = binnedSeries(history, series,
        now: now, window: spec.window, bins: spec.bins);
    final color =
        AppColors.heat(currentUtil, warnAt: warnAt, dangerAt: dangerAt);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SegToggle<ChartSeries>(
                value: series,
                options: const {
                  'SESSION': ChartSeries.session,
                  'WEEKLY': ChartSeries.weekly,
                },
                onChanged: onSeries,
              ),
              const Spacer(),
              _SegToggle<ChartZoom>(
                value: zoom,
                options: {
                  for (final z in ChartZoom.values) zoomSpecs[z]!.label: z,
                },
                onChanged: onZoom,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDims.radiusSm),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 150,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ChartColumns(
                      bins: bins,
                      gridEvery: spec.gridEvery,
                      warnAt: warnAt,
                      dangerAt: dangerAt,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$percent%', style: AppText.stat(color)),
                        Text('NOW',
                            style: AppText.mono(AppColors.textFaint, size: 9)),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 8,
                    child: _AxisLabels(zoom: zoom, now: now),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom axis. Week zoom: a weekday centred under each day section. Shorter
/// zooms: the two honest endpoints (e.g. "−24H" … "NOW").
class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.zoom, required this.now});
  final ChartZoom zoom;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final labels = axisLabels(zoom, now);
    final style = AppText.mono(AppColors.textFaint, size: 9);
    if (zoom == ChartZoom.week) {
      return Row(
        children: [
          for (final l in labels)
            Expanded(
              child: Text(l,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: style),
            ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [for (final l in labels) Text(l, style: style)],
    );
  }
}

/// A compact segmented control matching the app's pill style.
class _SegToggle<T> extends StatelessWidget {
  const _SegToggle({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<String, T> options; // label → value, in display order
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in options.entries) _seg(e.key, e.value),
        ],
      ),
    );
  }

  Widget _seg(String label, T v) {
    final active = value == v;
    return GestureDetector(
      onTap: () => onChanged(v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: active
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : Colors.transparent),
        ),
        child: Text(label,
            style: AppText.mono(
                active ? AppColors.accent : AppColors.textFaint,
                size: 10)),
      ),
    );
  }
}
