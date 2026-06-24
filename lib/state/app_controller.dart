import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../data/claude_api.dart';
import '../data/demo_data.dart';
import '../data/session_store.dart';
import '../data/update_checker.dart';
import '../models/usage.dart';
import '../theme/claude_theme.dart';
import 'settings.dart';

enum AppMode { loading, signedOut, demo, live }

/// Single source of truth for auth, usage data, settings, the auto-refresh
/// loop, history accumulation and threshold notifications.
class AppController extends ChangeNotifier {
  AppController({
    SessionStore? store,
    ClaudeApiClient? api,
    UpdateChecker? updateChecker,
    Future<bool> Function(Uri)? urlLauncher,
  })  : _store = store ?? SessionStore(),
        _api = api ?? ClaudeApiClient(),
        _updateChecker = updateChecker ?? UpdateChecker(),
        _launchUrl = urlLauncher ?? _defaultLaunch;

  final SessionStore _store;
  final ClaudeApiClient _api;
  final UpdateChecker _updateChecker;
  final Future<bool> Function(Uri) _launchUrl;

  // coverage:ignore-start
  static Future<bool> _defaultLaunch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
  // coverage:ignore-end

  AppMode mode = AppMode.loading;
  Settings settings = const Settings();
  UsageSnapshot? usage;
  List<HistoryPoint> history = [];
  bool refreshing = false;
  bool signingIn = false;
  String? error; // live-fetch error
  String? signInError; // sign-in attempt error
  DateTime? lastUpdated;
  UpdateInfo? availableUpdate; // newer GitHub release, if any

  String? _sessionKey;
  String? _orgId;
  Timer? _timer;
  final Set<String> _dangerNotified = {};

  bool get isDemo => mode == AppMode.demo;

  // ── lifecycle ──────────────────────────────────────────────────────────

  Future<void> bootstrap() async {
    settings = await _store.readSettings();
    _applyTheme();
    history = await _store.readHistory();
    if (const bool.fromEnvironment('mini')) {
      settings = settings.copyWith(mini: true); // coverage:ignore-line
    }
    await _applyAlwaysOnTop();
    await _applyWindowMode();
    // `--dart-define=demo=true` forces demo data (screenshots / previews),
    // overriding any stored session.
    if (const bool.fromEnvironment('demo')) {
      // coverage:ignore-start
      await enterDemo();
      return;
      // coverage:ignore-end
    }
    final key = await _store.readSessionKey();
    if (key == null || key.isEmpty) {
      mode = AppMode.signedOut;
      notifyListeners();
      return;
    }
    _sessionKey = key;
    _orgId = await _store.readOrgId();
    mode = AppMode.live;
    notifyListeners();
    await refresh();
    _startTimer();
  }

  Future<void> enterDemo() async {
    mode = AppMode.demo;
    usage = DemoData.snapshot();
    history = DemoData.history();
    lastUpdated = DateTime.now();
    notifyListeners();
  }

  Future<bool> signIn(String rawKey) async {
    final key = rawKey.trim();
    if (key.isEmpty) {
      signInError = 'Paste your sessionKey first.';
      notifyListeners();
      return false;
    }
    signingIn = true;
    signInError = null;
    notifyListeners();
    try {
      final org = await _api.resolveOrgId(key);
      _sessionKey = key;
      _orgId = org;
      await _store.writeSessionKey(key);
      await _store.writeOrgId(org);
      mode = AppMode.live;
      signingIn = false;
      notifyListeners();
      await refresh();
      _startTimer();
      return true;
    } on ClaudeApiException catch (e) {
      signInError = e.message;
    } catch (e) {
      signInError = 'Could not verify session: $e';
    }
    signingIn = false;
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    _timer?.cancel();
    _sessionKey = null;
    _orgId = null;
    usage = null;
    error = null;
    signInError = null;
    _dangerNotified.clear();
    await _store.clearCredentials();
    mode = AppMode.signedOut;
    notifyListeners();
  }

  // ── refresh ────────────────────────────────────────────────────────────

  Future<void> refresh() async {
    if (mode == AppMode.demo) {
      refreshing = true;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 650));
      usage = DemoData.snapshot();
      lastUpdated = DateTime.now();
      refreshing = false;
      notifyListeners();
      return;
    }
    if (mode != AppMode.live || _sessionKey == null) return;
    refreshing = true;
    notifyListeners();
    try {
      _orgId ??= await _api.resolveOrgId(_sessionKey!);
      final snap =
          await _api.fetchUsage(sessionKey: _sessionKey!, orgId: _orgId!);
      usage = snap;
      error = null;
      lastUpdated = snap.fetchedAt;
      await _recordHistory(snap);
      _maybeNotify(snap);
    } on ClaudeApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = '$e';
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: settings.refreshSeconds.clamp(30, 3600)),
      (_) => refresh(),
    );
  }

  // ── settings ───────────────────────────────────────────────────────────

  Future<void> updateSettings(Settings next) async {
    final intervalChanged = next.refreshSeconds != settings.refreshSeconds;
    final onTopChanged = next.alwaysOnTop != settings.alwaysOnTop;
    settings = next;
    _applyTheme();
    notifyListeners();
    await _store.writeSettings(next);
    if (onTopChanged) await _applyAlwaysOnTop();
    if (intervalChanged && mode == AppMode.live) _startTimer();
  }

  /// Publishes the active palette so static [AppColors] tokens (incl. painters)
  /// resolve against the user's chosen theme. The [MaterialApp] reads the same
  /// [Settings.themeMode] to pick its [ThemeData].
  void _applyTheme() {
    AppColors.current = AppPalette.of(settings.themeMode);
  }

  Future<void> _applyAlwaysOnTop() async {
    try {
      await windowManager.setAlwaysOnTop(settings.alwaysOnTop);
    } catch (_) {/* non-desktop / not ready */}
  }

  static const Size fullWindow = Size(420, 800);
  static const Size miniWindow = Size(380, 204);

  Future<void> _applyWindowMode() async {
    try {
      if (settings.mini) {
        await windowManager.setMaximumSize(const Size(640, 360));
        await windowManager.setMinimumSize(const Size(320, 150));
        await windowManager.setSize(miniWindow);
      } else {
        await windowManager.setMaximumSize(const Size(640, 1400));
        await windowManager.setMinimumSize(const Size(380, 560));
        await windowManager.setSize(fullWindow);
      }
    } catch (_) {/* non-desktop / not ready */}
  }

  /// Switches between the full dashboard and the compact floating widget,
  /// resizing the window to match.
  Future<void> setMini(bool value) async {
    if (settings.mini == value) return;
    settings = settings.copyWith(mini: value);
    notifyListeners();
    await _store.writeSettings(settings);
    await _applyWindowMode();
  }

  // ── history + notifications ──────────────────────────────────────────────

  Future<void> _recordHistory(UsageSnapshot snap) async {
    final last = history.isNotEmpty ? history.last : null;
    // De-dupe rapid refreshes; one sample at most every 2 minutes.
    if (last != null && snap.fetchedAt.difference(last.t).inMinutes < 2) return;
    history = [
      ...history,
      HistoryPoint(
        t: snap.fetchedAt,
        session: snap.session.utilization,
        weekly: snap.weekly.utilization,
      ),
    ];
    final cutoff = DateTime.now().subtract(const Duration(days: 8));
    history = history.where((p) => p.t.isAfter(cutoff)).toList();
    if (history.length > 4000) {
      history = history.sublist(history.length - 4000);
    }
    await _store.writeHistory(history);
  }

  void _maybeNotify(UsageSnapshot snap) {
    if (!settings.notificationsEnabled) return;
    for (final w in [snap.session, snap.weekly]) {
      final armed = !_dangerNotified.contains(w.key);
      if (w.utilization >= settings.dangerThreshold && armed) {
        _dangerNotified.add(w.key);
        _notify('${w.label} limit almost reached',
            '${w.percent}% used — requests may start failing soon.');
      } else if (w.utilization < settings.warnThreshold) {
        _dangerNotified.remove(w.key); // re-arm once it cools off
      }
    }
  }

  void _notify(String title, String body) {
    try {
      LocalNotification(title: title, body: body).show();
    } catch (_) {/* notifications are best-effort */}
  }

  // ── update check ───────────────────────────────────────────────────────

  /// Best-effort check against GitHub's latest release; surfaces
  /// [availableUpdate] (and a dashboard banner) when a newer version exists.
  Future<void> checkForUpdates() async {
    availableUpdate = await _updateChecker.latestNewerThan(kAppVersion);
    notifyListeners();
  }

  /// Opens an arbitrary external URL in the default browser.
  Future<void> openUrl(String url) => _launchUrl(Uri.parse(url));

  /// Opens the available release's page in the default browser. No-op if there
  /// is no pending update.
  Future<void> openDownloadUrl() async {
    final info = availableUpdate;
    if (info == null) return;
    await openUrl(info.url);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _api.dispose();
    _updateChecker.dispose();
    super.dispose();
  }
}
