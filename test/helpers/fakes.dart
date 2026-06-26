import 'package:claude_stats/data/claude_api.dart';
import 'package:claude_stats/data/keyboard/side_lights.dart';
import 'package:claude_stats/data/session_store.dart';
import 'package:claude_stats/data/update_checker.dart';
import 'package:claude_stats/models/account.dart';
import 'package:claude_stats/models/usage.dart';
import 'package:claude_stats/state/app_controller.dart';
import 'package:claude_stats/state/settings.dart';

/// In-memory [SessionStore]: all reads/writes resolve as microtasks (no file
/// IO), which keeps it usable under `fakeAsync`. History is single-org here —
/// [history] backs the active org; [legacyHistory] backs the pre-multi-account
/// global file (so the migration path can be exercised).
class FakeStore extends SessionStore {
  FakeStore({
    this.sessionKey,
    this.orgId,
    Settings? settings,
    List<HistoryPoint>? history,
    List<HistoryPoint>? legacyHistory,
    List<Account>? accounts,
  })  : settings = settings ?? const Settings(),
        history = history ?? [],
        legacyHistory = legacyHistory ?? [],
        accounts = accounts ?? [];

  String? sessionKey;
  String? orgId;
  Settings settings;
  List<HistoryPoint> history;
  List<HistoryPoint> legacyHistory;
  List<Account> accounts;

  int settingsWrites = 0;
  int historyWrites = 0;
  bool legacyCleared = false;

  @override
  Future<String?> readSessionKey() async => sessionKey;
  @override
  Future<void> writeSessionKey(String value) async => sessionKey = value;
  @override
  Future<String?> readOrgId() async => orgId;
  @override
  Future<void> writeOrgId(String value) async => orgId = value;
  @override
  Future<List<Account>> readAccounts() async => accounts;
  @override
  Future<void> writeAccounts(List<Account> a) async => accounts = a;
  @override
  Future<Settings> readSettings() async => settings;
  @override
  Future<void> writeSettings(Settings s) async {
    settings = s;
    settingsWrites++;
  }

  @override
  Future<List<HistoryPoint>> readHistory() async => legacyHistory;
  @override
  Future<void> writeHistory(List<HistoryPoint> pts) async {
    legacyHistory = pts;
    historyWrites++;
  }

  @override
  Future<void> clearLegacyHistory() async {
    legacyHistory = [];
    legacyCleared = true;
  }

  @override
  Future<List<HistoryPoint>> readHistoryFor(String orgId) async => history;
  @override
  Future<void> writeHistoryFor(String orgId, List<HistoryPoint> pts) async {
    history = pts;
    historyWrites++;
  }

  @override
  Future<void> clearCredentials() async {
    sessionKey = null;
    orgId = null;
    accounts = [];
  }
}

/// A fully controllable [ClaudeApiClient] stand-in. Lets a test dictate the
/// org list, the returned snapshot (or its windows), and arbitrary errors —
/// including non-[ClaudeApiException] errors that the real client never throws.
class FakeApi extends ClaudeApiClient {
  FakeApi();

  /// Default single org id, used when [accounts] isn't overridden.
  String orgId = 'org-1';

  /// Explicit org list `fetchAccounts` returns; defaults to one org from [orgId].
  List<Account>? accounts;

  Object? resolveError; // thrown by fetchAccounts
  Object? usageError;

  /// Builds the snapshot each `fetchUsage` returns; defaults to a mid-usage
  /// account. Override to drive notification / history logic.
  UsageSnapshot Function()? snapshotBuilder;

  int fetchAccountsCalls = 0;
  int fetchCalls = 0;
  bool disposed = false;

  static UsageSnapshot snapshotWith({
    double session = 0.5,
    double weekly = 0.5,
    DateTime? fetchedAt,
  }) {
    return UsageSnapshot(
      fetchedAt: fetchedAt ?? DateTime(2026, 6, 22, 12),
      session: UsageWindow(key: 'five_hour', label: 'Session', utilization: session),
      weekly: UsageWindow(key: 'seven_day', label: 'Weekly', utilization: weekly),
    );
  }

  @override
  Future<List<Account>> fetchAccounts(String sessionKey) async {
    fetchAccountsCalls++;
    if (resolveError != null) throw resolveError!;
    return accounts ?? [Account(id: orgId, name: 'Org')];
  }

  @override
  Future<UsageSnapshot> fetchUsage({
    required String sessionKey,
    required String orgId,
  }) async {
    fetchCalls++;
    if (usageError != null) throw usageError!;
    return (snapshotBuilder ?? snapshotWith)();
  }

  @override
  void dispose() => disposed = true;
}

/// A [SideLightDriver] that records what it was asked to do instead of touching
/// any real keyboard.
class FakeSideLightDriver implements SideLightDriver {
  FakeSideLightDriver({this.present = false});

  bool present; // what detect() reports
  int detectCalls = 0;
  final List<SideGauge> gauges = [];
  int releaseCalls = 0;

  @override
  Future<bool> detect() async {
    detectCalls++;
    return present;
  }

  @override
  Future<void> setGauge(SideGauge gauge) async => gauges.add(gauge);

  @override
  Future<void> release() async => releaseCalls++;
}

/// An [UpdateChecker] that returns a fixed [result] without touching the network.
class FakeUpdateChecker extends UpdateChecker {
  FakeUpdateChecker({this.result});

  UpdateInfo? result;

  @override
  Future<UpdateInfo?> latestNewerThan(String currentVersion) async => result;

  @override
  void dispose() {}
}

/// A representative snapshot for screen tests. [session] defaults to a maxed-out
/// window (so the in-ring `RingCountdown` path renders) and [weekly] to a
/// mid-range value (so the percentage-text path renders) — covering both ring
/// centre branches in a single pump. Toggle [models] / [extra] to drive the
/// optional dashboard cards.
UsageSnapshot screenSnapshot({
  double session = 1.0,
  double weekly = 0.5,
  bool models = true,
  List<String> rawKeys = const [],
  ExtraUsage? extra = const ExtraUsage(
    isEnabled: true,
    currency: 'USD',
    usedCents: 1840,
    limitCents: 5000,
    balanceCents: 3160,
  ),
}) {
  final reset = DateTime.now().add(const Duration(hours: 2, minutes: 14));
  return UsageSnapshot(
    fetchedAt: DateTime.now(),
    session: UsageWindow(
        key: 'five_hour', label: 'Session', utilization: session, resetsAt: reset),
    weekly: UsageWindow(
        key: 'seven_day', label: 'Weekly', utilization: weekly, resetsAt: reset),
    models: models
        ? [
            UsageWindow(key: 'seven_day_opus', label: 'Opus', utilization: 0.88, resetsAt: reset),
            UsageWindow(key: 'seven_day_sonnet', label: 'Sonnet', utilization: 0.42, resetsAt: reset),
          ]
        : const [],
    rawKeys: rawKeys,
    extra: extra,
  );
}

/// Builds a controller with its public state pre-set, so screen tests can pump
/// any UI state deterministically without driving async bootstrap.
AppController readyController({
  AppMode mode = AppMode.demo,
  UsageSnapshot? usage,
  Settings settings = const Settings(),
  List<HistoryPoint>? history,
  List<Account>? accounts,
  String? error,
  DateTime? lastUpdated,
  bool refreshing = false,
  bool keyboardDetected = false,
  FakeStore? store,
  FakeApi? api,
  FakeSideLightDriver? sideLights,
  UpdateInfo? availableUpdate,
  Future<bool> Function(Uri)? urlLauncher,
}) {
  final c = AppController(
    store: store ?? FakeStore(),
    api: api ?? FakeApi(),
    sideLights: sideLights ?? FakeSideLightDriver(),
    urlLauncher: urlLauncher,
  );
  c.mode = mode;
  c.usage = usage;
  c.settings = settings;
  c.history = history ?? [];
  c.accounts = accounts ?? [];
  c.error = error;
  c.lastUpdated = lastUpdated;
  c.refreshing = refreshing;
  c.keyboardDetected = keyboardDetected;
  c.availableUpdate = availableUpdate;
  return c;
}

