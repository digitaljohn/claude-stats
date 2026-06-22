import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

import '../data/claude_api.dart';
import '../data/demo_data.dart';
import '../data/session_store.dart';
import '../models/usage.dart';
import 'settings.dart';

enum AppMode { loading, signedOut, demo, live }

/// Single source of truth for auth, usage data, settings, the auto-refresh
/// loop, history accumulation and threshold notifications.
class AppController extends ChangeNotifier {
  AppController({SessionStore? store, ClaudeApiClient? api})
      : _store = store ?? SessionStore(),
        _api = api ?? ClaudeApiClient();

  final SessionStore _store;
  final ClaudeApiClient _api;

  AppMode mode = AppMode.loading;
  Settings settings = const Settings();
  UsageSnapshot? usage;
  List<HistoryPoint> history = [];
  bool refreshing = false;
  bool signingIn = false;
  String? error; // live-fetch error
  String? signInError; // sign-in attempt error
  DateTime? lastUpdated;

  String? _sessionKey;
  String? _orgId;
  Timer? _timer;
  final Set<String> _dangerNotified = {};

  bool get isDemo => mode == AppMode.demo;

  // ── lifecycle ──────────────────────────────────────────────────────────

  Future<void> bootstrap() async {
    settings = await _store.readSettings();
    history = await _store.readHistory();
    if (const bool.fromEnvironment('mini')) {
      settings = settings.copyWith(mini: true);
    }
    await _applyAlwaysOnTop();
    await _applyWindowMode();
    // `--dart-define=demo=true` forces demo data (screenshots / previews),
    // overriding any stored session.
    if (const bool.fromEnvironment('demo')) {
      await enterDemo();
      return;
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
    notifyListeners();
    await _store.writeSettings(next);
    if (onTopChanged) await _applyAlwaysOnTop();
    if (intervalChanged && mode == AppMode.live) _startTimer();
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

  @override
  void dispose() {
    _timer?.cancel();
    _api.dispose();
    super.dispose();
  }
}
