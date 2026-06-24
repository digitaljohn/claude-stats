import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'state/app_controller.dart';
import 'theme/claude_theme.dart';
import 'ui/dashboard_screen.dart';
import 'ui/mini_screen.dart';
import 'ui/sign_in_screen.dart';
import 'ui/tray.dart';
import 'ui/widgets/window_scaffold.dart';

/// When set via `--dart-define=shotpath=/abs/file.png`, the app captures its
/// content (real GPU shaders included) to that PNG a moment after launch and
/// exits — a self-contained visual-verification harness.
const String _shotPath = String.fromEnvironment('shotpath');

// coverage:ignore-start
// Desktop entrypoint: initialises window_manager / local_notifier and calls
// runApp. Not unit-testable — runApp with the real plugins never settles under
// the test binding (the widget tree itself is covered via ClaudeStatsApp).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  final options = WindowOptions(
    size: const Size(420, 800),
    minimumSize: const Size(380, 560),
    maximumSize: const Size(560, 1200),
    center: true,
    backgroundColor: AppColors.ink, // first-paint flash; dark default is fine
    title: 'claude·stats',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    // Integrated chrome: hide the native title bar but keep the traffic-light
    // buttons floating over a full-size content view.
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: true,
    );
    await windowManager.show();
    await windowManager.focus();
  });

  try {
    await localNotifier.setup(appName: 'claude·stats');
  } catch (_) {/* notifications are best-effort */}

  final controller = AppController();
  runApp(ClaudeStatsApp(controller: controller));
  // Fire-and-forget: surface a banner if a newer GitHub release exists.
  controller.checkForUpdates();
  // Live in the menu bar (NSStatusItem) showing the session %.
  await TrayController(controller).init();
}
// coverage:ignore-end

/// Root widget: wires the [AppController] into the Claude theme and routes the
/// active [AppMode] to its screen (loading / sign-in / dashboard / mini).
class ClaudeStatsApp extends StatefulWidget {
  const ClaudeStatsApp({super.key, required this.controller});
  final AppController controller;

  @override
  State<ClaudeStatsApp> createState() => _ClaudeStatsAppState();
}

class _ClaudeStatsAppState extends State<ClaudeStatsApp> {
  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller.bootstrap();
    // coverage:ignore-start
    // Screenshot harness, only armed by --dart-define=shotpath; _capture ends
    // in exit(0) and so cannot run under the test runner.
    if (_shotPath.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(milliseconds: 2600), _capture);
      });
    }
    // coverage:ignore-end
  }

  // coverage:ignore-start
  Future<void> _capture() async {
    try {
      final boundary =
          _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List();
      // Sandbox blocks arbitrary paths, so always drop a copy in the app's
      // container (the harness copies it out); also try the requested path
      // directly in case the sandbox is off.
      final dir = await getApplicationSupportDirectory();
      File('${dir.path}/__shot.png').writeAsBytesSync(bytes);
      try {
        File(_shotPath).writeAsBytesSync(bytes);
      } catch (_) {}
    } catch (e) {
      stderr.writeln('capture failed: $e');
    }
    exit(0);
  }
  // coverage:ignore-end

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen above MaterialApp so a theme change (which mutates settings +
    // AppColors.current) rebuilds MaterialApp.theme — switching live, no restart.
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'claude·stats',
          debugShowCheckedModeBanner: false,
          theme: buildClaudeTheme(
              AppPalette.of(widget.controller.settings.themeMode)),
          home: RepaintBoundary(
            key: _captureKey,
            child: Builder(
              builder: (context) {
                switch (widget.controller.mode) {
                  case AppMode.loading:
                    return WindowScaffold(
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent),
                        ),
                      ),
                    );
                  case AppMode.signedOut:
                    return SignInScreen(controller: widget.controller);
                  case AppMode.demo:
                  case AppMode.live:
                    return widget.controller.settings.mini
                        ? MiniScreen(controller: widget.controller)
                        : DashboardScreen(controller: widget.controller);
                }
              },
            ),
          ),
        );
      },
    );
  }
}
