import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/account.dart';
import '../models/usage.dart';

class ClaudeApiException implements Exception {
  ClaudeApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Talks to the (unofficial) claude.ai usage API the same way the reference
/// widget does: authenticate with the `sessionKey` cookie, resolve the org,
/// then read `/usage` plus the optional overage/prepaid budgets.
class ClaudeApiClient {
  ClaudeApiClient({http.Client? client, this.baseUrl = 'https://claude.ai/api'})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  // Friendly labels for the per-model 7-day windows we recognise. Any *other*
  // `seven_day_*` window the API returns is still surfaced (label humanised),
  // so a model like Opus never silently disappears just because its key wasn't
  // hard-coded here.
  static const Map<String, String> _knownModels = {
    'seven_day_opus': 'Opus',
    'seven_day_sonnet': 'Sonnet',
    'seven_day_haiku': 'Haiku',
    'seven_day_omelette': 'Haiku', // internal codename for the small/fast model
    'seven_day_cowork': 'Cowork',
    'seven_day_oauth_apps': 'Apps',
  };

  // Preferred display order; unknown models sort after these.
  static const List<String> _modelOrder = [
    'seven_day_opus',
    'seven_day_sonnet',
    'seven_day_haiku',
    'seven_day_omelette',
    'seven_day_cowork',
    'seven_day_oauth_apps',
  ];

  Map<String, String> _headers(String sessionKey) => {
        'Cookie': 'sessionKey=$sessionKey',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://claude.ai/',
        'Origin': 'https://claude.ai',
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      };

  Future<dynamic> _get(String path, String sessionKey) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response res;
    try {
      res = await _client
          .get(uri, headers: _headers(sessionKey))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw ClaudeApiException('Network error: $e');
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw ClaudeApiException(
        'Session rejected (${res.statusCode}). Your sessionKey may be expired.',
        res.statusCode,
      );
    }
    if (res.statusCode >= 400) {
      throw ClaudeApiException('Request failed (${res.statusCode}).', res.statusCode);
    }
    try {
      return jsonDecode(res.body);
    } catch (_) {
      throw ClaudeApiException('Unexpected response (not JSON).');
    }
  }

  /// Lists every organisation the session can reach, ordered with the best
  /// default first.
  ///
  /// A single login can expose several orgs (personal + team/corporate); we want
  /// them all so the user can switch between them. Selection mirrors the old
  /// single-org pick: prefer the chat-capable orgs, and within those put `team`
  /// orgs first — so `accounts.first` is the same org the app would have locked
  /// onto before, while the rest stay available. Orgs without a usable id are
  /// dropped (they can't be queried). Throws when nothing usable is found.
  Future<List<Account>> fetchAccounts(String sessionKey) async {
    final data = await _get('/organizations', sessionKey);
    if (data is! List || data.isEmpty) {
      throw ClaudeApiException('No organizations found for this session.');
    }
    final orgs = data.cast<Map<String, dynamic>>();
    bool chatCapable(Map<String, dynamic> o) {
      final caps = o['capabilities'];
      return caps is List && caps.contains('chat');
    }

    final chat = orgs.where(chatCapable).toList();
    final pool = chat.isNotEmpty ? chat : orgs;
    // Teams first, otherwise preserve the API's order (stable).
    final ordered = [
      ...pool.where((o) => o['raven_type'] == 'team'),
      ...pool.where((o) => o['raven_type'] != 'team'),
    ];
    final accounts = [
      for (final o in ordered) ?Account.fromApi(o),
    ];
    if (accounts.isEmpty) {
      throw ClaudeApiException('No usable organization id in the response.');
    }
    return accounts;
  }

  /// Reads `/organizations/{orgId}/usage` and returns the session (5-hour) and
  /// weekly (7-day) windows, every per-model `seven_day_*` window the API
  /// exposes, plus best-effort extra-usage budget.
  Future<UsageSnapshot> fetchUsage({
    required String sessionKey,
    required String orgId,
  }) async {
    final data = await _get('/organizations/$orgId/usage', sessionKey);
    if (data is! Map<String, dynamic>) {
      throw ClaudeApiException('Malformed usage response.');
    }

    UsageWindow win(String key, String label) {
      final raw = data[key];
      if (raw is Map<String, dynamic>) return UsageWindow.fromJson(key, label, raw);
      return UsageWindow(key: key, label: label, utilization: 0);
    }

    final models = _perModel(data);

    final extra = await _fetchExtra(sessionKey, orgId);

    return UsageSnapshot(
      fetchedAt: DateTime.now(),
      session: win('five_hour', 'Session'),
      weekly: win('seven_day', 'Weekly'),
      models: models,
      extra: extra,
      rawKeys: data.keys.toList(),
    );
  }

  /// Best-effort overage + prepaid budget. Never throws — extra usage is
  /// optional and not all plans expose it.
  Future<ExtraUsage?> _fetchExtra(String sessionKey, String orgId) async {
    Map<String, dynamic>? overage;
    Map<String, dynamic>? prepaid;
    try {
      final o = await _get('/organizations/$orgId/overage_spend_limit', sessionKey);
      if (o is Map<String, dynamic>) overage = o;
    } catch (_) {}
    try {
      final p = await _get('/organizations/$orgId/prepaid/credits', sessionKey);
      if (p is Map<String, dynamic>) prepaid = p;
    } catch (_) {}

    if (overage == null && prepaid == null) return null;

    int asInt(Object? v) =>
        (v is num) ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

    final used = asInt(overage?['used_credits'] ?? overage?['balance_cents']);
    final limit = asInt(
        overage?['monthly_credit_limit'] ?? overage?['spend_limit_amount_cents']);
    final balance = asInt(prepaid?['amount'] ?? overage?['balance_cents']);
    final currency =
        (overage?['currency'] ?? prepaid?['currency'] ?? 'USD').toString();

    return ExtraUsage(
      isEnabled: overage?['is_enabled'] as bool? ?? (limit > 0),
      currency: currency,
      usedCents: used,
      limitCents: limit,
      balanceCents: balance,
    );
  }

  /// Per-model weekly limits.
  ///
  /// Prefers the modern `limits` array — each `weekly_scoped` entry names its
  /// model via `scope.model.display_name` and carries a `percent`. The flat
  /// top-level `seven_day_<model>` keys are unreliable on current accounts
  /// (often `null` even for models you've used), so they're only a fallback for
  /// older API shapes that don't send `limits`.
  List<UsageWindow> _perModel(Map<String, dynamic> data) {
    final limits = data['limits'];
    if (limits is List) {
      final scoped = <UsageWindow>[];
      for (final entry in limits) {
        if (entry is! Map<String, dynamic>) continue;
        if (entry['kind'] != 'weekly_scoped') continue;
        final scope = entry['scope'];
        final model = scope is Map<String, dynamic> ? scope['model'] : null;
        final name = model is Map<String, dynamic> ? model['display_name'] : null;
        if (name is! String || name.isEmpty) continue;
        scoped.add(UsageWindow.fromJson(
          'weekly_scoped_$name',
          name,
          {'utilization': entry['percent'], 'resets_at': entry['resets_at']},
        ));
      }
      if (scoped.isNotEmpty) return scoped;
    }

    // Legacy fallback: flat `seven_day_<model>` map windows.
    final flat = <UsageWindow>[];
    for (final entry in data.entries) {
      if (entry.key.startsWith('seven_day_') &&
          entry.value is Map<String, dynamic>) {
        flat.add(UsageWindow.fromJson(entry.key, _modelLabel(entry.key),
            entry.value as Map<String, dynamic>));
      }
    }
    flat.sort((a, b) => _modelRank(a.key).compareTo(_modelRank(b.key)));
    return flat;
  }

  /// Friendly label for a `seven_day_*` model window; humanises unknown keys
  /// (`seven_day_new_model` → "New Model").
  String _modelLabel(String key) {
    final known = _knownModels[key];
    if (known != null) return known;
    final raw = key.substring('seven_day_'.length);
    return raw
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  int _modelRank(String key) {
    final i = _modelOrder.indexOf(key);
    return i < 0 ? _modelOrder.length : i;
  }

  void dispose() => _client.close();
}
