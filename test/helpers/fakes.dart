import 'package:claude_stats/data/claude_api.dart';
import 'package:claude_stats/data/session_store.dart';
import 'package:claude_stats/models/usage.dart';
import 'package:claude_stats/state/app_controller.dart';
import 'package:claude_stats/state/settings.dart';

/// In-memory [SessionStore]: all reads/writes resolve as microtasks (no file
/// IO), which keeps it usable under `fakeAsync`.
class FakeStore extends SessionStore {
  FakeStore({
    this.sessionKey,
    this.orgId,
    Settings? settings,
    List<HistoryPoint>? history,
  })  : settings = settings ?? const Settings(),
        history = history ?? [];

  String? sessionKey;
  String? orgId;
  Settings settings;
  List<HistoryPoint> history;

  int settingsWrites = 0;
  int historyWrites = 0;

  @override
  Future<String?> readSessionKey() async => sessionKey;
  @override
  Future<void> writeSessionKey(String value) async => sessionKey = value;
  @override
  Future<String?> readOrgId() async => orgId;
  @override
  Future<void> writeOrgId(String value) async => orgId = value;
  @override
  Future<Settings> readSettings() async => settings;
  @override
  Future<void> writeSettings(Settings s) async {
    settings = s;
    settingsWrites++;
  }

  @override
  Future<List<HistoryPoint>> readHistory() async => history;
  @override
  Future<void> writeHistory(List<HistoryPoint> pts) async {
    history = pts;
    historyWrites++;
  }

  @override
  Future<void> clearCredentials() async {
    sessionKey = null;
    orgId = null;
  }
}

/// A fully controllable [ClaudeApiClient] stand-in. Lets a test dictate the
/// resolved org, the returned snapshot (or its windows), and arbitrary errors —
/// including non-[ClaudeApiException] errors that the real client never throws.
class FakeApi extends ClaudeApiClient {
  FakeApi();

  String orgId = 'org-1';
  Object? resolveError;
  Object? usageError;

  /// Builds the snapshot each `fetchUsage` returns; defaults to a mid-usage
  /// account. Override to drive notification / history logic.
  UsageSnapshot Function()? snapshotBuilder;

  int resolveCalls = 0;
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
  Future<String> resolveOrgId(String sessionKey) async {
    resolveCalls++;
    if (resolveError != null) throw resolveError!;
    return orgId;
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

/// A representative snapshot for screen tests. [session] defaults to a maxed-out
/// window (so the in-ring `RingCountdown` path renders) and [weekly] to a
/// mid-range value (so the percentage-text path renders) — covering both ring
/// centre branches in a single pump. Toggle [models] / [extra] to drive the
/// optional dashboard cards.
UsageSnapshot screenSnapshot({
  double session = 1.0,
  double weekly = 0.5,
  bool models = true,
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
  String? error,
  DateTime? lastUpdated,
  bool refreshing = false,
  FakeStore? store,
  FakeApi? api,
}) {
  final c = AppController(store: store ?? FakeStore(), api: api ?? FakeApi());
  c.mode = mode;
  c.usage = usage;
  c.settings = settings;
  c.history = history ?? [];
  c.error = error;
  c.lastUpdated = lastUpdated;
  c.refreshing = refreshing;
  return c;
}

