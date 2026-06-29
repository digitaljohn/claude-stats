import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../data/claude_api.dart';
import '../data/demo_data.dart';
import '../data/keyboard/side_lights.dart';
import '../data/session_store.dart';
import '../data/update_checker.dart';
import '../models/account.dart';
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
    SideLightDriver? sideLights,
  })  : _store = store ?? SessionStore(),
        _api = api ?? ClaudeApiClient(),
        _updateChecker = updateChecker ?? UpdateChecker(),
        _launchUrl = urlLauncher ?? _defaultLaunch,
        _sideLights = sideLights ?? MethodChannelSideLightDriver();

  final SessionStore _store;
  final ClaudeApiClient _api;
  final UpdateChecker _updateChecker;
  final Future<bool> Function(Uri) _launchUrl;
  final SideLightDriver _sideLights;

  // coverage:ignore-start
  static Future<bool> _defaultLaunch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
  // coverage:ignore-end

  AppMode mode = AppMode.loading;
  Settings settings = const Settings();
  UsageSnapshot? usage;
  List<HistoryPoint> history = [];
  List<Account> accounts = []; // every org the session can reach
  bool refreshing = false;
  bool signingIn = false;
  String? error; // live-fetch error
  String? signInError; // sign-in attempt error
  DateTime? lastUpdated;
  UpdateInfo? availableUpdate; // newer GitHub release, if any
  bool keyboardDetected = false; // a NuPhy side-light keyboard is reachable

  String? _sessionKey;
  String? _orgId;
  Timer? _timer;
  final Set<String> _dangerNotified = {};

  bool get isDemo => mode == AppMode.demo;

  /// The org currently being watched (whose usage is on screen).
  String? get activeAccountId => _orgId;

  /// The [Account] for [activeAccountId], if it's in the known list.
  Account? get activeAccount {
    for (final a in accounts) {
      if (a.id == _orgId) return a;
    }
    return null;
  }

  /// Whether to offer the switcher — only worth it once a second org appears.
  bool get hasMultipleAccounts => accounts.length > 1;

  // ── lifecycle ──────────────────────────────────────────────────────────

  Future<void> bootstrap() async {
    settings = await _store.readSettings();
    _applyTheme();
    keyboardDetected = await _sideLights.detect();
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
    accounts = await _store.readAccounts(); // cached list → instant switcher
    history = await _loadHistory(_orgId);
    mode = AppMode.live;
    notifyListeners();
    // Refresh the org list from the network (best-effort — keep the cached one
    // if offline). If the active org disappeared, the default is re-picked, so
    // reload its history before fetching usage.
    final before = _orgId;
    try {
      await _resolveAccounts();
    } catch (_) {/* keep cached accounts / org */}
    if (_orgId != before) history = await _loadHistory(_orgId);
    await refresh();
    _startTimer();
  }

  /// Fetches the org list, persists it, and ensures [_orgId] points at a real
  /// org (picking the default when the stored one is unknown/missing). Throws on
  /// API errors so sign-in can surface them.
  Future<void> _resolveAccounts() async {
    final list = await _api.fetchAccounts(_sessionKey!);
    accounts = list;
    await _store.writeAccounts(list);
    if (_orgId == null || !list.any((a) => a.id == _orgId)) {
      _orgId = list.first.id;
      await _store.writeOrgId(_orgId!);
    }
  }

  /// Loads the per-org chart history, migrating a pre-multi-account global
  /// history file onto the active org the first time we see one.
  Future<List<HistoryPoint>> _loadHistory(String? orgId) async {
    if (orgId == null) return [];
    var h = await _store.readHistoryFor(orgId);
    if (h.isEmpty) {
      final legacy = await _store.readHistory();
      if (legacy.isNotEmpty) {
        h = legacy;
        await _store.writeHistoryFor(orgId, h);
        await _store.clearLegacyHistory();
      }
    }
    return h;
  }

  Future<void> enterDemo() async {
    mode = AppMode.demo;
    usage = DemoData.snapshot();
    history = DemoData.history();
    accounts = DemoData.accounts(); // showcases the switcher in demo mode
    _orgId = accounts.first.id;
    lastUpdated = DateTime.now();
    notifyListeners();
    await _pushSideLights();
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
      _sessionKey = key;
      _orgId = null; // fresh sign-in → pick the default org
      await _resolveAccounts(); // validates the session + lists orgs (throws if bad)
      await _store.writeSessionKey(key); // only persist a key that worked
      history = await _loadHistory(_orgId);
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
    _sessionKey = null;
    signingIn = false;
    notifyListeners();
    return false;
  }

  /// Switches which org the app is watching. Resets the live view (usage,
  /// error, notification arming) and loads that org's own history, then
  /// refreshes. A no-op for the current/unknown org.
  Future<void> switchAccount(String orgId) async {
    if (orgId == _orgId || !accounts.any((a) => a.id == orgId)) return;
    _orgId = orgId;
    if (mode == AppMode.demo) {
      notifyListeners(); // demo data is synthetic — just re-highlight
      return;
    }
    usage = null;
    error = null;
    _dangerNotified.clear();
    await _store.writeOrgId(orgId);
    history = await _loadHistory(orgId);
    notifyListeners();
    await refresh();
  }

  Future<void> signOut() async {
    _timer?.cancel();
    _sessionKey = null;
    _orgId = null;
    usage = null;
    error = null;
    signInError = null;
    accounts = [];
    _dangerNotified.clear();
    await _store.clearCredentials();
    await _sideLights.release(); // hand the side LEDs back to the keyboard
    mode = AppMode.signedOut;
    notifyListeners();
  }

  // ── keyboard side lights ─────────────────────────────────────────────────

  /// Turns the NuPhy side-light mirroring on/off, persisting the choice and
  /// either pushing the current gauge or releasing the LEDs.
  Future<void> setKeyboardLights(bool on) async {
    if (settings.keyboardLightsEnabled == on) return;
    settings = settings.copyWith(keyboardLightsEnabled: on);
    notifyListeners();
    await _store.writeSettings(settings);
    if (on) {
      await _pushSideLights();
    } else {
      await _sideLights.release();
    }
  }

  /// Pushes the current session/weekly usage to the keyboard's side strips
  /// (left = session, right = weekly), coloured by the warn/danger zones.
  /// No-op unless the feature is on, a keyboard is present, and usage is loaded.
  Future<void> _pushSideLights() async {
    if (!settings.keyboardLightsEnabled || !keyboardDetected) return;
    final u = usage;
    if (u == null) return;
    await _sideLights.setGauge(SideGauge(
      leftPct: sidePercent(u.session.utilization),
      left: sideZoneColor(u.session.utilization,
          warnAt: settings.warnThreshold, dangerAt: settings.dangerThreshold),
      rightPct: sidePercent(u.weekly.utilization),
      right: sideZoneColor(u.weekly.utilization,
          warnAt: settings.warnThreshold, dangerAt: settings.dangerThreshold),
    ));
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
      await _pushSideLights();
      return;
    }
    if (mode != AppMode.live || _sessionKey == null || _orgId == null) return;
    refreshing = true;
    notifyListeners();
    try {
      final snap =
          await _api.fetchUsage(sessionKey: _sessionKey!, orgId: _orgId!);
      usage = snap;
      error = null;
      lastUpdated = snap.fetchedAt;
      await _recordHistory(snap);
      _maybeNotify(snap);
      await _pushSideLights();
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

  static const Size fullWindow = Size(420, 760);
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
    // Keep ~a month so the chart can be panned back that far; the 2-minute
    // de-dupe caps a full month at ~22k points, so 24k is a safe backstop.
    final cutoff = DateTime.now().subtract(const Duration(days: 31));
    history = history.where((p) => p.t.isAfter(cutoff)).toList();
    if (history.length > 24000) {
      history = history.sublist(history.length - 24000);
    }
    if (_orgId != null) await _store.writeHistoryFor(_orgId!, history);
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
    _sideLights.release(); // best-effort: don't leave the LEDs frozen
    _api.dispose();
    _updateChecker.dispose();
    super.dispose();
  }
}
