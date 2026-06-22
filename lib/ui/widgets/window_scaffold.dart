import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../theme/claude_theme.dart';

/// App shell with the integrated macOS title bar: a hidden native title bar
/// (configured in main.dart) leaves the traffic-light buttons floating at the
/// top-left, and this bar reserves space for them, hosts the wordmark + action
/// buttons, and is itself a drag-to-move region.
class WindowScaffold extends StatelessWidget {
  const WindowScaffold({
    super.key,
    required this.child,
    this.background,
    this.actions = const [],
    this.titleBarColor,
    this.showBorder = true,
    this.titleWidget,
  });

  final Widget child;

  /// Title-bar lockup; defaults to the [Wordmark]. Pass a minimal widget in
  /// mini mode.
  final Widget? titleWidget;

  /// Optional full-bleed background painted behind everything (e.g. the
  /// [GridBackground]). The title bar floats transparently over it.
  final Widget? background;

  final List<Widget> actions;
  final Color? titleBarColor;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink,
      child: Stack(
        children: [
          if (background != null) Positioned.fill(child: background!),
          Column(
            children: [
              _TitleBar(
                actions: actions,
                color: titleBarColor,
                showBorder: showBorder,
                title: titleWidget ?? const Wordmark(),
              ),
              Expanded(child: child),
            ],
          ),
        ],
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.actions,
    required this.title,
    this.color,
    this.showBorder = true,
  });

  final List<Widget> actions;
  final Widget title;
  final Color? color;
  final bool showBorder;

  /// Vertical band the title content is centred in, so it lines up with the
  /// native macOS traffic-light buttons. Content centre = [_trafficLightBand] /
  /// 2. Measured (via a native probe of `standardWindowButton(.closeButton)`):
  /// macOS centres the lights **16 px from the window top** in a 32 px title
  /// bar — so a 32 px band centres our content exactly on them. Re-measure if a
  /// macOS version relocates the lights.
  static const double _trafficLightBand = 32;

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: Container(
        height: AppDims.titleBarHeight,
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          border: showBorder
              ? const Border(bottom: BorderSide(color: AppColors.border))
              : null,
        ),
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: _trafficLightBand,
          child: Row(
            children: [
              // Clearance for the native traffic-light cluster (~70px wide).
              const SizedBox(width: 80),
              title,
              const Spacer(),
              // Space the action buttons apart so their hover fills read as
              // distinct pills. Nudge the cluster down ~2px: the icon glyphs are
              // taller than the wordmark's cap height, so box-centring leaves
              // their tops poking above it — this lines the cluster up with the
              // wordmark + traffic lights to the eye.
              Transform.translate(
                offset: const Offset(0, 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      actions[i],
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// "claude / stats" lockup — a slash-separated wordmark.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('claude', style: AppText.wordmark(AppColors.textPrimary)),
        const SizedBox(width: 6),
        Text('/', style: AppText.wordmark(AppColors.textFaint)),
        const SizedBox(width: 6),
        Text('stats', style: AppText.wordmark(AppColors.textSecondary)),
      ],
    );
  }
}

/// A square ghost icon button used in the title bar (refresh, settings…).
class TitleBarButton extends StatefulWidget {
  const TitleBarButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
    this.spin = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;
  final bool spin;

  @override
  State<TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<TitleBarButton>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    // Created eagerly (not lazily) so dispose() never has to construct a
    // ticker mid-teardown — an inherited-widget lookup that is illegal once the
    // element is being unmounted.
    _spin = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    if (widget.spin) _spin.repeat();
  }

  @override
  void didUpdateWidget(TitleBarButton old) {
    super.didUpdateWidget(old);
    if (widget.spin && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.spin && _spin.isAnimating) {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active || _hover
        ? AppColors.accent
        : AppColors.textSecondary;
    Widget icon = Icon(widget.icon, size: 16, color: color);
    if (widget.spin) {
      icon = RotationTransition(turns: _spin, child: icon);
    }
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hover ? AppColors.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(child: icon),
        ),
      ),
    );
    return widget.tooltip == null
        ? button
        : Tooltip(message: widget.tooltip!, child: button);
  }
}
