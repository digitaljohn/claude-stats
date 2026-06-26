import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/account.dart';
import '../models/usage.dart';
import '../state/settings.dart';

/// App-private persistence (session key, resolved org, settings, usage
/// history) backed by a single JSON file inside the macOS sandbox container —
/// readable only by this app / the signed-in user. The session key is
/// base64-wrapped so it isn't sitting as grep-able plaintext; this is not
/// Keychain-grade, but matches the reference widget's plain-storage fallback.
class SessionStore {
  File? _file;
  Map<String, dynamic> _data = {};
  bool _loaded = false;

  static const _kKey = 'session_key';
  static const _kOrg = 'org_id';
  static const _kAccounts = 'accounts';
  static const _kSettings = 'settings';
  static const _kHistory = 'history'; // legacy single-account history
  static const _kHistoryByOrg = 'history_by_org'; // { orgId: encoded points }

  Future<void> _ensure() async {
    if (_loaded) return;
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/claude_stats.json');
      if (await _file!.exists()) {
        _data = (jsonDecode(await _file!.readAsString()) as Map)
            .cast<String, dynamic>();
      }
    } catch (_) {
      _data = {};
    }
    _loaded = true;
  }

  Future<void> _flush() async {
    try {
      await _file?.writeAsString(jsonEncode(_data));
    } catch (_) {/* best-effort */}
  }

  String? _wrap(String v) => base64.encode(utf8.encode(v));
  String? _unwrap(Object? v) {
    if (v is! String || v.isEmpty) return null;
    try {
      return utf8.decode(base64.decode(v));
    } catch (_) {
      return null;
    }
  }

  Future<String?> readSessionKey() async {
    await _ensure();
    return _unwrap(_data[_kKey]);
  }

  Future<void> writeSessionKey(String value) async {
    await _ensure();
    _data[_kKey] = _wrap(value);
    await _flush();
  }

  Future<String?> readOrgId() async {
    await _ensure();
    return _data[_kOrg] as String?;
  }

  Future<void> writeOrgId(String value) async {
    await _ensure();
    _data[_kOrg] = value;
    await _flush();
  }

  /// The org list discovered last time we talked to the API — cached so the
  /// switcher can render immediately on launch, before the network refresh.
  Future<List<Account>> readAccounts() async {
    await _ensure();
    return Account.decode(_data[_kAccounts] as String?);
  }

  Future<void> writeAccounts(List<Account> accounts) async {
    await _ensure();
    _data[_kAccounts] = Account.encode(accounts);
    await _flush();
  }

  Future<Settings> readSettings() async {
    await _ensure();
    return Settings.decode(_data[_kSettings] as String?);
  }

  Future<void> writeSettings(Settings s) async {
    await _ensure();
    _data[_kSettings] = s.encode();
    await _flush();
  }

  /// Legacy global history (pre multi-account). Retained only so a one-time
  /// migration can re-home it under the active org; new writes go per-org.
  Future<List<HistoryPoint>> readHistory() async {
    await _ensure();
    return HistoryPoint.decode(_data[_kHistory] as String?);
  }

  Future<void> writeHistory(List<HistoryPoint> pts) async {
    await _ensure();
    _data[_kHistory] = HistoryPoint.encode(pts);
    await _flush();
  }

  Future<void> clearLegacyHistory() async {
    await _ensure();
    _data.remove(_kHistory);
    await _flush();
  }

  /// Per-org history: each org keeps its own 7-day chart so switching accounts
  /// never mixes one org's usage into another's.
  Future<List<HistoryPoint>> readHistoryFor(String orgId) async {
    await _ensure();
    final map = _data[_kHistoryByOrg];
    if (map is Map && map[orgId] is String) {
      return HistoryPoint.decode(map[orgId] as String);
    }
    return [];
  }

  Future<void> writeHistoryFor(String orgId, List<HistoryPoint> pts) async {
    await _ensure();
    final raw = _data[_kHistoryByOrg];
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    map[orgId] = HistoryPoint.encode(pts);
    _data[_kHistoryByOrg] = map;
    await _flush();
  }

  /// Wipes credentials + the cached org list on sign-out; settings and per-org
  /// history are kept (so signing back into the same org restores its chart).
  Future<void> clearCredentials() async {
    await _ensure();
    _data.remove(_kKey);
    _data.remove(_kOrg);
    _data.remove(_kAccounts);
    await _flush();
  }
}
