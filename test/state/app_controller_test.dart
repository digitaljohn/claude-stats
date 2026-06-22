import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/data/claude_api.dart';
import 'package:claude_stats/data/update_checker.dart';
import 'package:claude_stats/models/usage.dart';
import 'package:claude_stats/state/app_controller.dart';
import 'package:claude_stats/state/settings.dart';

import '../helpers/fakes.dart';
import '../helpers/test_harness.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = installPluginFakes());
  tearDown(() => removePluginFakes(tmp));

  AppController make(FakeStore store, FakeApi api) {
    final c = AppController(store: store, api: api);
    addTearDown(c.dispose);
    return c;
  }

  group('bootstrap', () {
    test('with no stored key lands in signedOut', () async {
      final store = FakeStore();
      final c = make(store, FakeApi());
      await c.bootstrap();
      expect(c.mode, AppMode.signedOut);
    });

    test('with a stored key goes live, fetches and records history', () async {
      final store = FakeStore(sessionKey: 'sk', orgId: 'org-1');
      final api = FakeApi();
      final c = make(store, api);
      await c.bootstrap();
      expect(c.mode, AppMode.live);
      expect(c.usage, isNotNull);
      expect(api.fetchCalls, 1);
      expect(c.history, isNotEmpty);
      expect(c.lastUpdated, isNotNull);
    });

    test('applies the persisted settings', () async {
      final store = FakeStore(settings: const Settings(use24h: true, alwaysOnTop: true));
      final c = make(store, FakeApi());
      await c.bootstrap();
      expect(c.settings.use24h, true);
      expect(c.settings.alwaysOnTop, true);
    });
  });

  group('enterDemo / isDemo', () {
    test('populates synthetic data', () async {
      final c = make(FakeStore(), FakeApi());
      await c.enterDemo();
      expect(c.mode, AppMode.demo);
      expect(c.isDemo, true);
      expect(c.usage, isNotNull);
      expect(c.history, isNotEmpty);
      expect(c.lastUpdated, isNotNull);
    });
  });

  group('signIn', () {
    test('rejects an empty key without calling the API', () async {
      final api = FakeApi();
      final c = make(FakeStore(), api);
      final ok = await c.signIn('   ');
      expect(ok, false);
      expect(c.signInError, contains('Paste your sessionKey'));
      expect(api.resolveCalls, 0);
    });

    test('success resolves the org, persists, and goes live', () async {
      final store = FakeStore();
      final api = FakeApi()..orgId = 'org-9';
      final c = make(store, api);
      final ok = await c.signIn('  sk-trimmed  ');
      expect(ok, true);
      expect(c.mode, AppMode.live);
      expect(store.sessionKey, 'sk-trimmed');
      expect(store.orgId, 'org-9');
      expect(c.usage, isNotNull);
      expect(c.signingIn, false);
    });

    test('surfaces a ClaudeApiException message', () async {
      final api = FakeApi()..resolveError = ClaudeApiException('bad session', 401);
      final c = make(FakeStore(), api);
      final ok = await c.signIn('sk');
      expect(ok, false);
      expect(c.signInError, 'bad session');
      expect(c.signingIn, false);
    });

    test('wraps an unexpected (non-API) error', () async {
      final api = FakeApi()..resolveError = StateError('boom');
      final c = make(FakeStore(), api);
      final ok = await c.signIn('sk');
      expect(ok, false);
      expect(c.signInError, contains('Could not verify session'));
    });
  });

  group('refresh', () {
    test('no-ops when signed out', () async {
      final api = FakeApi();
      final c = make(FakeStore(), api);
      await c.bootstrap(); // signedOut
      await c.refresh();
      expect(api.fetchCalls, 0);
    });

    test('demo refresh re-rolls the snapshot', () async {
      final c = make(FakeStore(), FakeApi());
      await c.enterDemo();
      await c.refresh();
      expect(c.usage, isNotNull);
      expect(c.refreshing, false);
    });

    test('resolves the org lazily when missing', () async {
      final store = FakeStore(sessionKey: 'sk'); // no orgId
      final api = FakeApi();
      final c = make(store, api);
      await c.bootstrap();
      expect(api.resolveCalls, 1);
      expect(api.fetchCalls, 1);
    });

    test('records a ClaudeApiException as the live error', () async {
      final store = FakeStore(sessionKey: 'sk', orgId: 'o');
      final api = FakeApi()..usageError = ClaudeApiException('rate limited', 429);
      final c = make(store, api);
      await c.bootstrap();
      expect(c.error, 'rate limited');
      expect(c.usage, isNull);
    });

    test('records an unexpected error via toString', () async {
      final store = FakeStore(sessionKey: 'sk', orgId: 'o');
      final api = FakeApi()..usageError = StateError('kaboom');
      final c = make(store, api);
      await c.bootstrap();
      expect(c.error, contains('kaboom'));
    });
  });

  group('history accumulation', () {
    test('de-dupes samples taken less than 2 minutes apart', () async {
      final store = FakeStore(sessionKey: 'sk', orgId: 'o');
      final api = FakeApi();
      var t = DateTime(2026, 6, 22, 12, 0);
      api.snapshotBuilder = () => FakeApi.snapshotWith(fetchedAt: t);
      final c = make(store, api);
      await c.bootstrap();
      expect(c.history.length, 1);
      // Second sample only 1 minute later — skipped.
      t = DateTime(2026, 6, 22, 12, 1);
      await c.refresh();
      expect(c.history.length, 1);
      // Third sample 3 minutes after the first — recorded.
      t = DateTime(2026, 6, 22, 12, 3);
      await c.refresh();
      expect(c.history.length, 2);
    });

    test('drops samples older than the 8-day cutoff', () async {
      final old = HistoryPoint(
          t: DateTime.now().subtract(const Duration(days: 9)),
          session: 0.1,
          weekly: 0.1);
      final store = FakeStore(sessionKey: 'sk', orgId: 'o', history: [old]);
      final api = FakeApi()
        ..snapshotBuilder = () => FakeApi.snapshotWith(fetchedAt: DateTime.now());
      final c = make(store, api);
      await c.bootstrap();
      // The 9-day-old point is gone; only the fresh sample remains.
      expect(c.history.every((p) => p.t.isAfter(DateTime.now().subtract(const Duration(days: 8)))), true);
      expect(c.history.length, 1);
    });

    test('caps history at 4000 samples', () async {
      final base = DateTime.now().subtract(const Duration(hours: 1));
      final many = [
        for (var i = 0; i < 4001; i++)
          HistoryPoint(t: base.add(Duration(milliseconds: i)), session: 0.1, weekly: 0.1),
      ];
      final store = FakeStore(sessionKey: 'sk', orgId: 'o', history: many);
      final api = FakeApi()
        ..snapshotBuilder = () => FakeApi.snapshotWith(fetchedAt: DateTime.now());
      final c = make(store, api);
      await c.bootstrap();
      expect(c.history.length, 4000);
    });
  });

  group('threshold notifications', () {
    test('fires once on danger breach, re-arms after cool-off', () async {
      final store = FakeStore(
        sessionKey: 'sk',
        orgId: 'o',
        settings: const Settings(warnThreshold: 0.75, dangerThreshold: 0.90),
      );
      final api = FakeApi();
      var session = 0.95; // over danger
      api.snapshotBuilder = () => FakeApi.snapshotWith(
            session: session,
            weekly: 0.1,
            fetchedAt: DateTime(2026, 6, 22, 12, (session * 100).round()),
          );
      final c = make(store, api);
      await c.bootstrap();
      expect(notifications.length, 1); // session breached once

      // Still over danger -> already armed, no duplicate.
      session = 0.96;
      await c.refresh();
      expect(notifications.length, 1);

      // Drops below warn -> re-arms.
      session = 0.50;
      await c.refresh();
      // Back over danger -> fires again.
      session = 0.97;
      await c.refresh();
      expect(notifications.length, 2);
    });

    test('does nothing when notifications are disabled', () async {
      final store = FakeStore(
        sessionKey: 'sk',
        orgId: 'o',
        settings: const Settings(notificationsEnabled: false),
      );
      final api = FakeApi()..snapshotBuilder = () => FakeApi.snapshotWith(session: 0.99, weekly: 0.99);
      final c = make(store, api);
      await c.bootstrap();
      expect(notifications, isEmpty);
    });
  });

  group('settings + window mode', () {
    test('updateSettings persists and reacts to on-top + interval changes', () async {
      final store = FakeStore(sessionKey: 'sk', orgId: 'o');
      final c = make(store, FakeApi());
      await c.bootstrap();
      final writesBefore = store.settingsWrites;
      await c.updateSettings(
          c.settings.copyWith(alwaysOnTop: true, refreshSeconds: 60));
      expect(store.settingsWrites, writesBefore + 1);
      expect(c.settings.refreshSeconds, 60);
      expect(c.settings.alwaysOnTop, true);
    });

    test('setMini is a no-op when unchanged, toggles otherwise', () async {
      final store = FakeStore();
      final c = make(store, FakeApi());
      await c.setMini(false); // already false -> no write
      expect(store.settingsWrites, 0);
      await c.setMini(true);
      expect(c.settings.mini, true);
      expect(store.settingsWrites, 1);
      await c.setMini(false);
      expect(c.settings.mini, false);
      expect(store.settingsWrites, 2);
    });
  });

  group('signOut + dispose', () {
    test('signOut clears state and credentials', () async {
      final store = FakeStore(sessionKey: 'sk', orgId: 'o');
      final api = FakeApi();
      final c = make(store, api);
      await c.bootstrap();
      await c.signOut();
      expect(c.mode, AppMode.signedOut);
      expect(c.usage, isNull);
      expect(store.sessionKey, isNull);
      expect(store.orgId, isNull);
    });

    test('dispose closes the API client', () async {
      final api = FakeApi();
      final c = AppController(store: FakeStore(), api: api);
      c.dispose();
      expect(api.disposed, true);
    });

    test('default constructor builds its own store + API client', () {
      // Exercises the `?? SessionStore()` / `?? ClaudeApiClient()` defaults.
      final c = AppController();
      expect(c.mode, AppMode.loading);
      c.dispose();
    });
  });

  test('auto-refresh timer fires after the configured interval', () {
    fakeAsync((async) {
      final store = FakeStore(
        sessionKey: 'sk',
        orgId: 'o',
        settings: const Settings(refreshSeconds: 60),
      );
      final api = FakeApi();
      final c = AppController(store: store, api: api);
      c.bootstrap();
      async.flushMicrotasks();
      expect(api.fetchCalls, 1); // initial refresh
      async.elapse(const Duration(seconds: 60));
      async.flushMicrotasks();
      expect(api.fetchCalls, 2); // timer-driven refresh
      c.dispose();
    });
  });

  group('update check', () {
    test('checkForUpdates surfaces a newer release and notifies', () async {
      final c = AppController(
        store: FakeStore(),
        api: FakeApi(),
        updateChecker: FakeUpdateChecker(
            result: const UpdateInfo(version: '9.9.9', url: 'https://gh/rel')),
      );
      addTearDown(c.dispose);
      var notified = 0;
      c.addListener(() => notified++);
      await c.checkForUpdates();
      expect(c.availableUpdate?.version, '9.9.9');
      expect(notified, greaterThan(0));
    });

    test('checkForUpdates leaves availableUpdate null when none is newer',
        () async {
      final c = AppController(
        store: FakeStore(),
        api: FakeApi(),
        updateChecker: FakeUpdateChecker(),
      );
      addTearDown(c.dispose);
      await c.checkForUpdates();
      expect(c.availableUpdate, isNull);
    });

    test('openDownloadUrl launches the release page, no-ops without an update',
        () async {
      final launched = <Uri>[];
      final c = AppController(
        store: FakeStore(),
        api: FakeApi(),
        urlLauncher: (u) async {
          launched.add(u);
          return true;
        },
      );
      addTearDown(c.dispose);

      await c.openDownloadUrl(); // no pending update -> no-op
      expect(launched, isEmpty);

      c.availableUpdate = const UpdateInfo(version: '9.9.9', url: 'https://gh/rel');
      await c.openDownloadUrl();
      expect(launched.single.toString(), 'https://gh/rel');
    });

    test('openUrl launches an arbitrary url', () async {
      final launched = <Uri>[];
      final c = AppController(
        store: FakeStore(),
        api: FakeApi(),
        urlLauncher: (u) async {
          launched.add(u);
          return true;
        },
      );
      addTearDown(c.dispose);
      await c.openUrl('https://example.com/x');
      expect(launched.single.toString(), 'https://example.com/x');
    });
  });
}
