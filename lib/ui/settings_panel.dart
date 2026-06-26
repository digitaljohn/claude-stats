import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../state/settings.dart';
import '../theme/claude_theme.dart';
import 'widgets/app_card.dart';

/// Full-body overlay with all preferences + sign-out.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.controller, required this.onClose});

  final AppController controller;
  final VoidCallback onClose;

  Settings get s => controller.settings;
  void _set(Settings next) => controller.updateSettings(next);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.ink,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Row(
            children: [
              const SectionLabel('Settings'),
              const Spacer(),
              _CloseButton(onTap: onClose),
            ],
          ),
          const SizedBox(height: 14),

          // Thresholds
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Alert thresholds'),
                const SizedBox(height: 8),
                _SliderRow(
                  label: 'Warning',
                  color: AppColors.warn,
                  value: s.warnThreshold,
                  min: 0.5,
                  max: 0.95,
                  onChanged: (v) => _set(s.copyWith(
                      warnThreshold: v,
                      dangerThreshold:
                          v >= s.dangerThreshold ? (v + 0.02).clamp(0, 1) : null)),
                ),
                _SliderRow(
                  label: 'Danger',
                  color: AppColors.danger,
                  value: s.dangerThreshold,
                  min: 0.6,
                  max: 1.0,
                  onChanged: (v) => _set(s.copyWith(
                      dangerThreshold: v,
                      warnThreshold:
                          v <= s.warnThreshold ? (v - 0.02).clamp(0, 1) : null)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Refresh interval
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Refresh interval'),
                const SizedBox(height: 12),
                _Segmented<int>(
                  value: s.refreshSeconds,
                  options: const {
                    '1m': 60,
                    '5m': 300,
                    '15m': 900,
                    '30m': 1800,
                  },
                  onChanged: (v) => _set(s.copyWith(refreshSeconds: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Appearance
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Appearance'),
                const SizedBox(height: 12),
                _Segmented<AppThemeMode>(
                  value: s.themeMode,
                  options: const {
                    'Dark': AppThemeMode.dark,
                    'Light': AppThemeMode.light,
                  },
                  onChanged: (v) => _set(s.copyWith(themeMode: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Toggles
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                _ToggleRow(
                  label: '24-hour time',
                  value: s.use24h,
                  onChanged: (v) => _set(s.copyWith(use24h: v)),
                ),
                _ToggleRow(
                  label: 'Show reset date',
                  value: s.showResetDate,
                  onChanged: (v) => _set(s.copyWith(showResetDate: v)),
                ),
                _ToggleRow(
                  label: 'Always on top',
                  value: s.alwaysOnTop,
                  onChanged: (v) => _set(s.copyWith(alwaysOnTop: v)),
                ),
                _ToggleRow(
                  label: 'Threshold notifications',
                  value: s.notificationsEnabled,
                  onChanged: (v) => _set(s.copyWith(notificationsEnabled: v)),
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Keyboard side lights — only when a NuPhy keyboard is detected.
          if (controller.keyboardDetected) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Keyboard'),
                  const SizedBox(height: 6),
                  _ToggleRow(
                    label: 'NuPhy side lights',
                    value: s.keyboardLightsEnabled,
                    onChanged: controller.setKeyboardLights,
                    last: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mirror session (left) + weekly (right) onto the side strips.',
                    style: AppText.label(AppColors.textFaint).copyWith(height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Account
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(controller.isDemo ? 'Demo session' : 'Connected',
                          style: AppText.title(AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        controller.isDemo
                            ? 'Showing synthetic data'
                            : 'session stored privately on this Mac',
                        style: AppText.label(AppColors.textFaint),
                      ),
                    ],
                  ),
                ),
                _DangerButton(
                  label: controller.isDemo ? 'Exit demo' : 'Sign out',
                  onTap: () {
                    onClose();
                    controller.signOut();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('claude·stats  v0.1.0',
                style: AppText.mono(AppColors.textFaint, size: 9)),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(Icons.close, size: 14, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
  });

  final String label;
  final Color color;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label, style: AppText.body(AppColors.textSecondary))),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: color,
              inactiveTrackColor: AppColors.borderStrong,
              thumbColor: color,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text('${(value * 100).round()}%',
              textAlign: TextAlign.right, style: AppText.mono(color, size: 12)),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.body(AppColors.textPrimary))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.onAccent,
            activeTrackColor: AppColors.accent,
            inactiveThumbColor: AppColors.textSecondary,
            inactiveTrackColor: AppColors.surfaceRaised,
            trackOutlineColor:
                WidgetStateProperty.all(AppColors.borderStrong),
          ),
        ],
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<String, T> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: options.entries.map((e) {
          final active = e.value == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  e.key,
                  textAlign: TextAlign.center,
                  style: AppText.mono(
                      active ? AppColors.onAccent : AppColors.textSecondary,
                      size: 11),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DangerButton extends StatefulWidget {
  const _DangerButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_DangerButton> createState() => _DangerButtonState();
}

class _DangerButtonState extends State<_DangerButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _hover
                ? AppColors.danger.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDims.radiusSm),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
          ),
          child: Text(widget.label, style: AppText.label(AppColors.danger)),
        ),
      ),
    );
  }
}
