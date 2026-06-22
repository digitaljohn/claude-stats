import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/data/session_store.dart';
import 'package:claude_stats/models/usage.dart';
import 'package:claude_stats/state/settings.dart';

import '../helpers/test_harness.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = installPluginFakes());
  tearDown(() => removePluginFakes(tmp));

  File storeFile() => File('${tmp.path}/claude_stats.json');

  test('reads null/defaults when no file exists yet', () async {
    final store = SessionStore();
    expect(await store.readSessionKey(), isNull);
    expect(await store.readOrgId(), isNull);
    expect(await store.readSettings().then((s) => s.refreshSeconds), 300);
    expect(await store.readHistory(), isEmpty);
  });

  test('session key is wrapped on disk and unwrapped on read', () async {
    final store = SessionStore();
    await store.writeSessionKey('sk-ant-secret');
    // Persisted form is base64, not plaintext.
    final raw = jsonDecode(storeFile().readAsStringSync()) as Map;
    expect(raw['session_key'], isNot(contains('secret')));
    // A fresh store reads it back from disk (exercises the load branch).
    final reopened = SessionStore();
    expect(await reopened.readSessionKey(), 'sk-ant-secret');
  });

  test('org id, settings and history persist and reload', () async {
    final store = SessionStore();
    await store.writeOrgId('org-123');
    await store.writeSettings(const Settings(refreshSeconds: 900, use24h: true));
    await store.writeHistory([
      HistoryPoint(t: DateTime(2026, 6, 22, 10), session: 0.4, weekly: 0.6),
    ]);

    final reopened = SessionStore();
    expect(await reopened.readOrgId(), 'org-123');
    final s = await reopened.readSettings();
    expect(s.refreshSeconds, 900);
    expect(s.use24h, true);
    final h = await reopened.readHistory();
    expect(h.single.session, 0.4);
  });

  test('clearCredentials wipes key + org but keeps settings/history', () async {
    final store = SessionStore();
    await store.writeSessionKey('sk');
    await store.writeOrgId('org');
    await store.writeSettings(const Settings(refreshSeconds: 120));
    await store.clearCredentials();

    final reopened = SessionStore();
    expect(await reopened.readSessionKey(), isNull);
    expect(await reopened.readOrgId(), isNull);
    expect((await reopened.readSettings()).refreshSeconds, 120);
  });

  test('_unwrap returns null for non-string and invalid base64', () async {
    storeFile().writeAsStringSync(jsonEncode({'session_key': 123}));
    expect(await SessionStore().readSessionKey(), isNull);

    storeFile().writeAsStringSync(jsonEncode({'session_key': '@@@not base64@@@'}));
    expect(await SessionStore().readSessionKey(), isNull);

    storeFile().writeAsStringSync(jsonEncode({'session_key': ''}));
    expect(await SessionStore().readSessionKey(), isNull);
  });

  test('corrupt store file is tolerated (falls back to empty)', () async {
    storeFile().writeAsStringSync('{ this is not json');
    final store = SessionStore();
    expect(await store.readSessionKey(), isNull);
    // And writing still works afterwards.
    await store.writeSessionKey('sk');
    expect(await SessionStore().readSessionKey(), 'sk');
  });

  test('flush failure is swallowed (best-effort write)', () async {
    // Make the target path a directory so writeAsString throws and is caught.
    Directory('${tmp.path}/claude_stats.json').createSync();
    final store = SessionStore();
    // Should not throw despite the un-writable target.
    await store.writeSessionKey('sk');
    expect(await store.readSessionKey(), 'sk'); // still served from memory
  });
}
