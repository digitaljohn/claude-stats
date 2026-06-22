import 'dart:convert';

import 'package:http/http.dart' as http;

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

  // Per-model 7-day windows we surface, in display order.
  static const Map<String, String> _modelWindows = {
    'seven_day_opus': 'Opus',
    'seven_day_sonnet': 'Sonnet',
    'seven_day_cowork': 'Cowork',
    'seven_day_oauth_apps': 'Apps',
  };

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

  /// Picks the best chat-capable organisation id for the account.
  Future<String> resolveOrgId(String sessionKey) async {
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
    final team = pool.where((o) => o['raven_type'] == 'team').toList();
    final chosen = team.isNotEmpty ? team.first : pool.first;
    final id = chosen['uuid'] ?? chosen['id'];
    if (id == null) throw ClaudeApiException('Organization id missing.');
    return '$id';
  }

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

    final models = <UsageWindow>[];
    for (final entry in _modelWindows.entries) {
      final raw = data[entry.key];
      if (raw is Map<String, dynamic>) {
        models.add(UsageWindow.fromJson(entry.key, entry.value, raw));
      }
    }

    final extra = await _fetchExtra(sessionKey, orgId);

    return UsageSnapshot(
      fetchedAt: DateTime.now(),
      session: win('five_hour', 'Session'),
      weekly: win('seven_day', 'Weekly'),
      models: models,
      extra: extra,
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

  void dispose() => _client.close();
}
