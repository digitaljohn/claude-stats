import 'package:flutter/material.dart';

import '../models/usage.dart';
import '../state/app_controller.dart';
import '../theme/claude_theme.dart';
import 'settings_panel.dart';
import 'widgets/app_card.dart';
import 'widgets/countdown_text.dart';
import 'widgets/heat_bar.dart';
import 'widgets/chart_columns.dart';
import 'widgets/chart_data.dart';
import 'widgets/usage_ring.dart';
import 'widgets/window_scaffold.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ChartSeries _series = ChartSeries.session;
  bool _showSettings = const bool.fromEnvironment('settings');

  AppController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final usage = c.usage;
    final s = c.settings;
    return WindowScaffold(
      titleBarColor: AppColors.ink,
      actions: [
        TitleBarButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          spin: c.refreshing,
          onTap: c.refresh,
        ),
        TitleBarButton(
          icon: Icons.close_fullscreen,
          tooltip: 'Mini mode',
          onTap: () => c.setMini(true),
        ),
        TitleBarButton(
          icon: Icons.tune,
          tooltip: 'Settings',
          active: _showSettings,
          onTap: () => setState(() => _showSettings = !_showSettings),
        ),
      ],
      child: Stack(
        children: [
          if (usage == null)
            const _LoadingState()
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                if (c.isDemo) const _Banner.demo(),
                if (c.error != null) _Banner.error(c.error!),
                if (c.isDemo || c.error != null) const SizedBox(height: 12),
                if (s.compactMode)
                  _compact(usage, s)
                else
                  _full(usage, s),
              ],
            ),
          if (_showSettings)
            Positioned.fill(
              child: SettingsPanel(
                controller: c,
                onClose: () => setState(() => _showSettings = false),
              ),
            ),
        ],
      ),
    );
  }

  // ── full layout ──────────────────────────────────────────────────────────

  Widget _full(UsageSnapshot u, settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _windowCard(u.session, settings),
        const SizedBox(height: 12),
        _windowCard(u.weekly, settings),
        const SizedBox(height: 12),
        _chartCard(settings),
        if (u.models.isNotEmpty) ...[
          const SizedBox(height: 12),
          _modelsCard(u.models, settings),
        ],
        if (u.extra != null && u.extra!.isEnabled) ...[
          const SizedBox(height: 12),
          _extraCard(u.extra!),
        ],
        const SizedBox(height: 14),
        _footer(u),
      ],
    );
  }

  Widget _compact(UsageSnapshot u, settings) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _ringTile(u.session, settings)),
            const SizedBox(width: 12),
            Expanded(child: _ringTile(u.weekly, settings)),
          ],
        ),
        const SizedBox(height: 12),
        _footer(u),
      ],
    );
  }

  Widget _ringTile(UsageWindow w, settings) {
    final color =
        AppColors.heat(w.utilization, warnAt: settings.warnThreshold, dangerAt: settings.dangerThreshold);
    return AppCard(
      child: Column(
        children: [
          SectionLabel(w.label),
          const SizedBox(height: 12),
          UsageRing(
            value: w.utilization,
            color: color,
            size: 96,
            warnAt: settings.warnThreshold,
            dangerAt: settings.dangerThreshold,
            center: Text('${w.percent}%', style: AppText.stat(color).copyWith(fontSize: 22)),
          ),
          const SizedBox(height: 10),
          CountdownText(resetsAt: w.resetsAt, use24h: settings.use24h),
        ],
      ),
    );
  }

  // ── primary window card (ring + stats) ─────────────────────────────────────

  Widget _windowCard(UsageWindow w, settings) {
    final color = AppColors.heat(w.utilization,
        warnAt: settings.warnThreshold, dangerAt: settings.dangerThreshold);
    final windowLabel = w.key == 'five_hour' ? '5-hour window' : '7-day window';
    return AppCard(
      child: Row(
        children: [
          UsageRing(
            value: w.utilization,
            color: color,
            size: 96,
            stroke: 8,
            warnAt: settings.warnThreshold,
            dangerAt: settings.dangerThreshold,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${w.percent}',
                    style: AppText.stat(color).copyWith(fontSize: 26)),
                Text('%', style: AppText.mono(color.withValues(alpha: 0.8), size: 10)),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.label, style: AppText.title(AppColors.textPrimary)),
                const SizedBox(height: 2),
                SectionLabel(windowLabel),
                const SizedBox(height: 12),
                HeatBar(
                  value: w.utilization,
                  color: color,
                  warnAt: settings.warnThreshold,
                  dangerAt: settings.dangerThreshold,
                ),
                const SizedBox(height: 10),
                CountdownText(
                  resetsAt: w.resetsAt,
                  use24h: settings.use24h,
                  showDate: settings.showResetDate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── shader history chart card ──────────────────────────────────────────────

  Widget _chartCard(settings) {
    final u = c.usage!;
    final current = _series == ChartSeries.session ? u.session : u.weekly;
    final color = AppColors.heat(current.utilization,
        warnAt: settings.warnThreshold, dangerAt: settings.dangerThreshold);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionLabel('7-day history'),
              const Spacer(),
              _seriesToggle(),
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
                      values: seriesValues(c.history, _series),
                      warnAt: settings.warnThreshold,
                      dangerAt: settings.dangerThreshold,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${current.percent}%',
                            style: AppText.stat(color)),
                        Text('NOW', style: AppText.mono(AppColors.textFaint, size: 9)),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('−7D', style: AppText.mono(AppColors.textFaint, size: 9)),
                        Text('NOW', style: AppText.mono(AppColors.textFaint, size: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seriesToggle() {
    Widget seg(String label, ChartSeries v) {
      final active = _series == v;
      return GestureDetector(
        onTap: () => setState(() => _series = v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? AppColors.accent.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: active ? AppColors.accent.withValues(alpha: 0.5) : Colors.transparent),
          ),
          child: Text(label,
              style: AppText.mono(
                  active ? AppColors.accent : AppColors.textFaint,
                  size: 10)),
        ),
      );
    }

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
          seg('SESSION', ChartSeries.session),
          seg('WEEKLY', ChartSeries.weekly),
        ],
      ),
    );
  }

  // ── per-model breakdown ────────────────────────────────────────────────────

  Widget _modelsCard(List<UsageWindow> models, settings) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Per-model · weekly'),
          const SizedBox(height: 14),
          for (var i = 0; i < models.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _modelRow(models[i], settings),
          ],
        ],
      ),
    );
  }

  Widget _modelRow(UsageWindow w, settings) {
    final color = AppColors.heat(w.utilization,
        warnAt: settings.warnThreshold, dangerAt: settings.dangerThreshold);
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(w.label, style: AppText.body(AppColors.textPrimary)),
        ),
        Expanded(
          child: HeatBar(
            value: w.utilization,
            color: color,
            height: 5,
            showTicks: false,
            warnAt: settings.warnThreshold,
            dangerAt: settings.dangerThreshold,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 38,
          child: Text('${w.percent}%',
              textAlign: TextAlign.right,
              style: AppText.mono(color, size: 12)),
        ),
      ],
    );
  }

  // ── extra usage ─────────────────────────────────────────────────────────────

  Widget _extraCard(ExtraUsage e) {
    final color = AppColors.heat(e.utilization);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionLabel('Extra usage'),
              const Spacer(),
              Text('${e.fmt(e.usedCents)} / ${e.fmt(e.limitCents)}',
                  style: AppText.mono(AppColors.textPrimary, size: 12)),
            ],
          ),
          const SizedBox(height: 12),
          HeatBar(value: e.utilization, color: color, showTicks: false),
          const SizedBox(height: 8),
          Text('Balance ${e.fmt(e.balanceCents)}',
              style: AppText.label(AppColors.textFaint)),
        ],
      ),
    );
  }

  // ── footer ───────────────────────────────────────────────────────────────

  Widget _footer(UsageSnapshot u) {
    final updated = c.lastUpdated;
    final ago = updated == null
        ? '—'
        : '${DateTime.now().difference(updated).inSeconds}s ago';
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: c.error != null ? AppColors.danger : AppColors.good,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(c.isDemo ? 'DEMO DATA' : 'LIVE',
            style: AppText.mono(AppColors.textFaint, size: 9)),
        const Spacer(),
        Text('UPDATED $ago'.toUpperCase(),
            style: AppText.mono(AppColors.textFaint, size: 9)),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner.demo()
      : message = 'Demo data — connect a sessionKey for live usage.',
        isError = false;
  const _Banner.error(this.message) : isError = true;

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDims.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.warning_amber_rounded : Icons.science_outlined,
              size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppText.label(AppColors.textPrimary).copyWith(height: 1.3)),
          ),
        ],
      ),
    );
  }
}
