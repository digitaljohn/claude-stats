import 'package:flutter/material.dart';

import '../models/usage.dart';
import '../state/app_controller.dart';
import '../state/settings.dart';
import '../theme/claude_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/countdown_text.dart';
import 'widgets/usage_ring.dart';
import 'widgets/window_scaffold.dart';

/// Compact floating-widget mode: just the two headline limits as small rings,
/// in a small always-resizable window. Click expand to return to the full
/// dashboard.
class MiniScreen extends StatelessWidget {
  const MiniScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final u = c.usage;
    final s = c.settings;
    return WindowScaffold(
      titleBarColor: AppColors.ink,
      titleWidget: const SizedBox.shrink(),
      actions: [
        TitleBarButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          spin: c.refreshing,
          onTap: c.refresh,
        ),
        TitleBarButton(
          icon: Icons.open_in_full,
          tooltip: 'Expand to full',
          onTap: () => c.setMini(false),
        ),
      ],
      child: u == null
          ? const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
              child: Row(
                children: [
                  Expanded(child: _tile(u.session, s)),
                  const SizedBox(width: 12),
                  Expanded(child: _tile(u.weekly, s)),
                ],
              ),
            ),
    );
  }

  Widget _tile(UsageWindow w, Settings s) {
    final color = AppColors.heat(w.utilization,
        warnAt: s.warnThreshold, dangerAt: s.dangerThreshold);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDims.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionLabel(w.label),
          const SizedBox(height: 7),
          UsageRing(
            value: w.utilization,
            color: color,
            size: 56,
            stroke: 6,
            warnAt: s.warnThreshold,
            dangerAt: s.dangerThreshold,
            center: Text('${w.percent}%',
                style: AppText.stat(color).copyWith(fontSize: 17)),
          ),
          const SizedBox(height: 7),
          CountdownText(
            resetsAt: w.resetsAt,
            use24h: s.use24h,
            style: AppText.mono(AppColors.textFaint, size: 9),
          ),
        ],
      ),
    );
  }
}
