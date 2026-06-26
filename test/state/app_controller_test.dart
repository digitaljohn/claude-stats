import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/data/claude_api.dart';
import 'package:claude_stats/data/update_checker.dart';
import 'package:claude_stats/models/account.dart';
import 'package:claude_stats/models/usage.dart';
import 'package:claude_stats/state/app_controller.dart';
import 'package:claude_stats/state/settings.dart';
import 'package:claude_stats/theme/claude_theme.dart';

import '../helpers/fakes.dart';
import '../helpers/test_harness.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = installPluginFakes());
  tearDown(() {
    AppColors.current = AppPalette.dark; // don't leak theme state across tests
    removePluginFakes(tmp);
  });

  AppController make(FakeStore store, FakeApi api, [FakeSideLightDriver? lights]) {
    final c = AppController(
        store: store, api: api, sideLights: lights ?? FakeSideLightDriver());
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
      // Demo seeds a couple of orgs so the switcher is visible.
      expect(c.hasMultipleAccounts, true);
      expect(c.activeAccount, isNotNull);
    });
  });

  group('accounts + switching', () {
    List<Account> twoOrgs() => const [
          Account(id: 'team', name: 'Acme', type: 'team'),
          Account(id: 'personal', name: 'Me'),
        ];

    test('bootstrap refreshes + persists the org list, keeping a valid org',
        () async {
      final store = FakeStore(sessionKey: 'sk', orgId: 'team');
      final api = FakeApi()..accounts = twoOrgs();
      final c = make(store, api);
      await c.bootstrap();
      expect(c.accounts.length, 2);
      expect(c.hasMultipleAccounts, true);
      expect(c.activeAccountId, 'team');
      expect(c.activeAccount?.name, 'Acme');
      expect(store.accounts.length, 2); // cached for next launch
    });

    test('bootstrap re-picks the default when the stored org is gone', () async {
      final store = FakeStore(sessionKey: 'sk', orgId: 'gone');
      final api = FakeApi()..accounts = twoOrgs();
      final c = make(store, api);
      await c.bootstrap();
      expect(c.activeAccountId, 'team'); // first of the list
      expect(store.orgId, 'team');
    });

    test('bootstrap keeps the cached list when the network resolve fails',
        () async {
      final store = FakeStore(
        sessionKey: 'sk',
        orgId: 'cached',
        accounts: const [
          Account(id: 'cached', name: 'Cached'),
          Account(id: 'other', name: 'Other'),
        ],
      );
      final api = FakeApi()..resolveError = ClaudeApiException('offline');
      final c = make(store, api);
      await c.bootstrap();
      expect(c.accounts.length, 2); // cached list retained
      expect(c.activeAccountId, 'cached');
      expect(c.usage, isNotNull); // usage refresh still ran
      expect(api.fetchCalls, 1);
    });

    test('refresh bails when the org is unknown and resolve fails', () async {
      final store = FakeStore(sessionKey: 'sk'); // no org, no cache
      final api = FakeApi()..resolveError = ClaudeApiException('offline');
      final c = make(store, api);
      await c.bootstrap();
      expect(c.mode, AppMode.live);
      expect(c.activeAccountId, isNull);
      expect(c.usage, isNull);
      expect(c.activeAccount, isNull);
      expect(api.fetchCalls, 0); // never reached fetchUsage
    });

    test('switchAccount (live) resets state, loads org history and refreshes',
        () async {
      final store = FakeStore(sessionKey: 'sk', orgId: 'team');
      final api = FakeApi()..accounts = twoOrgs();
      final c = make(store, api);
      await c.bootstrap();
      final fetchesBefore = api.fetchCalls;
      var notified = 0;
      c.addListener(() => notified++);

      await c.switchAccount('personal');
      expect(c.activeAccountId, 'personal');
      expect(store.orgId, 'personal'); // persisted
      expect(api.fetchCalls, fetchesBefore + 1); // refreshed
      expect(c.usage, isNotNull);
      expect(notified, greaterThan(0));
    });

    test('switchAccount no-ops for the current or an unknown org', () async {
      final store = FakeStore(sessionKey: 'sk', orgId: 'team');
      final api = FakeApi()..accounts = twoOrgs();
      final c = make(store, api);
      await c.bootstrap();
      final fetchesBefore = api.fetchCalls;

      await c.switchAccount('team'); // already active
      await c.switchAccount('nope'); // not in the list
      expect(c.activeAccountId, 'team');
      expect(api.fetchCalls, fetchesBefore); // nothing refreshed
    });

    test('switchAccount in demo just re-highlights without persisting',
        () async {
      final store = FakeStore();
      final c = make(store, FakeApi());
      await c.enterDemo();
      final target = c.accounts.last.id;
      await c.switchAccount(target);
      expect(c.activeAccountId, target);
      expect(c.usage, isNotNull); // synthetic data retained
      expect(store.orgId, isNull); // demo never writes the org
    });

    test('migrates legacy global history onto the active org', () async {
      final recent = HistoryPoint(
          t: DateTime.now().subtract(const Duration(hours: 1)),
          session: 0.3,
          weekly: 0.4);
      final store = FakeStore(
        sessionKey: 'sk',
        orgId: 'o',
        legacyHistory: [recent],
      );
      final api = FakeApi()..accounts = const [Account(id: 'o', name: 'Org')];
      final c = make(store, api);
      await c.bootstrap();
      expect(store.legacyCleared, true); // legacy file dropped after migration
      expect(c.history, isNotEmpty); // migrated points carried over
    });

    test('signIn discovers multiple orgs and picks the default', () async {
      final store = FakeStore();
      final api = FakeApi()..accounts = twoOrgs();
      final c = make(store, api);
      final ok = await c.signIn('sk');
      expect(ok, true);
      expect(c.hasMultipleAccounts, true);
      expect(c.activeAccountId, 'team');
      expect(store.orgId, 'team');
      expect(store.accounts.length, 2);
    });
  });

  group('signIn', () {
    test('rejects an empty key without calling the API', () async {
      final api = FakeApi();
      final c = make(FakeStore(), api);
      final ok = await c.signIn('   ');
      expect(ok, false);
      expect(c.signInError, contains('Paste your sessionKey'));
      expect(api.fetchAccountsCalls, 0);
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

    test('resolves the org from the account list when missing', () async {
      final store = FakeStore(sessionKey: 'sk'); // no orgId
      final api = FakeApi();
      final c = make(store, api);
      await c.bootstrap();
      expect(api.fetchAccountsCalls, 1);
      expect(api.fetchCalls, 1);
      expect(c.activeAccountId, 'org-1'); // default org persisted
      expect(store.orgId, 'org-1');
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

    test('bootstrap applies the persisted theme to AppColors.current', () async {
      final store = FakeStore(
          settings: const Settings(themeMode: AppThemeMode.light));
      final c = make(store, FakeApi());
      await c.bootstrap();
      expect(c.settings.themeMode, AppThemeMode.light);
      expect(AppColors.current, AppPalette.light);
    });

    test('updateSettings switches the live palette without a restart', () async {
      final store = FakeStore();
      final c = make(store, FakeApi());
      await c.bootstrap();
      expect(AppColors.current, AppPalette.dark);

      await c.updateSettings(
          c.settings.copyWith(themeMode: AppThemeMode.light));
      expect(AppColors.current, AppPalette.light);

      await c.updateSettings(
          c.settings.copyWith(themeMode: AppThemeMode.dark));
      expect(AppColors.current, AppPalette.dark);
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
      final c = AppController(
          store: store, api: api, sideLights: FakeSideLightDriver());
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

  group('keyboard side lights', () {
    test('bootstrap records whether a keyboard was detected', () async {
      final lights = FakeSideLightDriver(present: true);
      final c = make(FakeStore(), FakeApi(), lights);
      await c.bootstrap();
      expect(lights.detectCalls, greaterThan(0));
      expect(c.keyboardDetected, true);
    });

    test('enabling pushes a zone-coloured gauge; disabling releases', () async {
      final store = FakeStore(sessionKey: 'sk', orgId: 'o');
      final api = FakeApi()
        ..snapshotBuilder = () => FakeApi.snapshotWith(session: 0.95, weekly: 0.5);
      final lights = FakeSideLightDriver(present: true);
      final c = make(store, api, lights);
      await c.bootstrap();
      expect(lights.gauges, isEmpty); // off by default

      await c.setKeyboardLights(true);
      expect(store.settings.keyboardLightsEnabled, true);
      final g = lights.gauges.last;
      expect(g.leftPct, 95); // session fill
      expect((g.left.r, g.left.g, g.left.b), (255, 0, 0)); // danger → red
      expect(g.rightPct, 50); // weekly fill
      expect((g.right.r, g.right.g, g.right.b), (0xF5, 0xF4, 0xEE)); // good → cream

      await c.setKeyboardLights(false);
      expect(lights.releaseCalls, greaterThan(0));
    });

    test('setKeyboardLights is a no-op when unchanged', () async {
      final lights = FakeSideLightDriver(present: true);
      final c = make(FakeStore(), FakeApi(), lights);
      await c.setKeyboardLights(false); // already false
      expect(lights.gauges, isEmpty);
      expect(lights.releaseCalls, 0);
    });

    test('refresh pushes the gauge when enabled + detected', () async {
      final store = FakeStore(
        sessionKey: 'sk',
        orgId: 'o',
        settings: const Settings(keyboardLightsEnabled: true),
      );
      final lights = FakeSideLightDriver(present: true);
      final c = make(store, FakeApi(), lights);
      await c.bootstrap(); // live → refresh → push
      expect(lights.gauges, isNotEmpty);
    });

    test('pushes nothing when the feature is off or no keyboard', () async {
      // feature on, but no keyboard present
      final noKb = FakeSideLightDriver(present: false);
      final cA = make(
        FakeStore(
            sessionKey: 'sk',
            orgId: 'o',
            settings: const Settings(keyboardLightsEnabled: true)),
        FakeApi(),
        noKb,
      );
      await cA.bootstrap();
      expect(noKb.gauges, isEmpty);

      // keyboard present, but feature off
      final off = FakeSideLightDriver(present: true);
      final cB = make(FakeStore(sessionKey: 'sk', orgId: 'o'), FakeApi(), off);
      await cB.bootstrap();
      expect(off.gauges, isEmpty);
    });

    test('enabling with no usage loaded pushes nothing', () async {
      final lights = FakeSideLightDriver(present: true);
      final c = make(FakeStore(), FakeApi(), lights); // signedOut → usage null
      await c.bootstrap();
      await c.setKeyboardLights(true);
      expect(lights.gauges, isEmpty);
    });

    test('enterDemo pushes the gauge when enabled', () async {
      final lights = FakeSideLightDriver(present: true);
      final c = make(
        FakeStore(settings: const Settings(keyboardLightsEnabled: true)),
        FakeApi(),
        lights,
      );
      await c.bootstrap(); // signedOut path still detects the keyboard
      await c.enterDemo();
      expect(lights.gauges, isNotEmpty);
    });

    test('signOut releases the LEDs', () async {
      final lights = FakeSideLightDriver(present: true);
      final c = make(FakeStore(sessionKey: 'sk', orgId: 'o'), FakeApi(), lights);
      await c.bootstrap();
      await c.signOut();
      expect(lights.releaseCalls, greaterThan(0));
    });

    test('dispose releases the LEDs', () async {
      final lights = FakeSideLightDriver(present: true);
      final c =
          AppController(store: FakeStore(), api: FakeApi(), sideLights: lights);
      c.dispose();
      expect(lights.releaseCalls, 1);
    });
  });
}
