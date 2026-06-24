import 'dart:io' show Platform;

/// The desktop hosts claude·stats targets.
enum HostOs { macos, windows, linux }

/// Single place that answers "what can this OS do?" so the rest of the app
/// never branches on `Platform.isX` inline. Centralising it keeps the
/// cross-platform behaviour explicit and — crucially — overridable in tests:
/// like [AppColors.current], the live instance is a mutable static, so a test
/// can pump any host's behaviour by assigning [current].
class PlatformSupport {
  const PlatformSupport(this.os);

  final HostOs os;

  /// The active platform. Defaults to the real host; tests (and, in principle,
  /// a future `--dart-define` override) can reassign it. Reset between tests.
  static PlatformSupport current = PlatformSupport(hostOs());

  bool get isMacOS => os == HostOs.macos;
  bool get isWindows => os == HostOs.windows;
  bool get isLinux => os == HostOs.linux;

  /// Whether an embedded claude.ai login webview is available. `flutter_inappwebview`
  /// ships a real WebView on macOS (WKWebView) and Windows (WebView2) but **not**
  /// Linux — so Linux falls back to the open-in-browser + paste-the-key flow.
  bool get hasEmbeddedWebview => os == HostOs.macos || os == HostOs.windows;

  /// Whether the tray can render text next to its icon. Only macOS' NSStatusItem
  /// shows a title (our live session %); Windows and Linux trays expose just an
  /// icon + tooltip, so there we fold the percentage into the tooltip instead.
  bool get trayShowsTitle => os == HostOs.macos;

  /// Whether the tray icon should be treated as a monochrome template image —
  /// a macOS concept (auto-tinted for light/dark menu bars). Windows and Linux
  /// render the icon as-is.
  bool get trayIconIsTemplate => os == HostOs.macos;

  /// Whether the window uses macOS' floating traffic-light buttons over a hidden
  /// title bar. When false (Windows/Linux) we keep the native title bar and drop
  /// the traffic-light clearance from our in-content title row.
  bool get usesTrafficLights => os == HostOs.macos;
}

/// Resolves the real host OS from `dart:io`. Isolated and coverage-excluded
/// because the non-macOS branches can't execute on the macOS CI test runner;
/// the capability getters above are pure functions of [HostOs] and are fully
/// exercised by constructing a [PlatformSupport] per host.
// coverage:ignore-start
HostOs hostOs() {
  if (Platform.isWindows) return HostOs.windows;
  if (Platform.isLinux) return HostOs.linux;
  return HostOs.macos;
}
// coverage:ignore-end
