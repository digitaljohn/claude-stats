import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../state/app_controller.dart';

/// The menu-bar title for the given session percentage — shown next to the
/// icon like a battery readout. Null (still loading) renders as an em dash.
String trayTitle(int? sessionPercent) =>
    sessionPercent == null ? '—' : '$sessionPercent%';

// coverage:ignore-start
// Platform glue around tray_manager (the macOS NSStatusItem): it drives the
// native status item, mirrors the session % into its title, and routes OS tray
// events to the window/controller. Not unit-testable (no status bar under the
// test binding); the title text it shows is covered via `trayTitle`.
class TrayController with TrayListener {
  TrayController(this._controller);

  final AppController _controller;

  Future<void> init() async {
    trayManager.addListener(this);
    await trayManager.setIcon('assets/tray/icon.png', isTemplate: true);
    await _syncTitle();
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Show claude·stats'),
      MenuItem(key: 'refresh', label: 'Refresh now'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]));
    _controller.addListener(_syncTitle);
  }

  Future<void> _syncTitle() =>
      trayManager.setTitle(trayTitle(_controller.usage?.session.percent));

  @override
  void onTrayIconMouseDown() {
    // Defer off the native tray-event callback before touching window_manager:
    // calling it re-entrantly from this callback crashes the engine on macOS.
    Future<void>.delayed(Duration.zero, _showWindow);
  }

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
        break;
      case 'refresh':
        _controller.refresh();
        break;
      case 'quit':
        exit(0);
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  void dispose() {
    _controller.removeListener(_syncTitle);
    trayManager.removeListener(this);
  }
}
// coverage:ignore-end
