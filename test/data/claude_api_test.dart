import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:claude_stats/data/claude_api.dart';

/// Builds a client that routes by URL-path suffix to the supplied [routes] map
/// (suffix-matched so callers needn't repeat the `/api` base segment); an
/// unmatched path returns 404. Each route value is `(body, statusCode)`.
ClaudeApiClient clientFor(Map<String, (String, int)> routes) {
  final mock = MockClient((req) async {
    for (final entry in routes.entries) {
      if (req.url.path.endsWith(entry.key)) {
        return http.Response(entry.value.$1, entry.value.$2);
      }
    }
    return http.Response('not found', 404);
  });
  return ClaudeApiClient(client: mock);
}

void main() {
  group('resolveOrgId', () {
    test('prefers a chat-capable team org and reads its uuid', () async {
      final api = clientFor({
        '/organizations': (
          jsonEncode([
            {'uuid': 'personal', 'capabilities': ['chat']},
            {'uuid': 'team-1', 'capabilities': ['chat'], 'raven_type': 'team'},
          ]),
          200,
        ),
      });
      expect(await api.resolveOrgId('key'), 'team-1');
    });

    test('falls back to the first chat org when none are teams', () async {
      final api = clientFor({
        '/organizations': (
          jsonEncode([
            {'uuid': 'a', 'capabilities': ['chat']},
            {'uuid': 'b', 'capabilities': ['chat']},
          ]),
          200,
        ),
      });
      expect(await api.resolveOrgId('key'), 'a');
    });

    test('falls back to all orgs when none are chat-capable, using id', () async {
      final api = clientFor({
        '/organizations': (
          jsonEncode([
            {'id': 'only-one', 'capabilities': []},
          ]),
          200,
        ),
      });
      expect(await api.resolveOrgId('key'), 'only-one');
    });

    test('throws when the list is empty or not a list', () async {
      final empty = clientFor({'/organizations': ('[]', 200)});
      expect(() => empty.resolveOrgId('k'), throwsA(isA<ClaudeApiException>()));

      final notList = clientFor({'/organizations': ('{}', 200)});
      expect(() => notList.resolveOrgId('k'), throwsA(isA<ClaudeApiException>()));
    });

    test('throws when the chosen org has no id', () async {
      final api = clientFor({
        '/organizations': (jsonEncode([{'capabilities': ['chat']}]), 200),
      });
      expect(() => api.resolveOrgId('k'),
          throwsA(predicate((e) => e is ClaudeApiException && e.statusCode == null)));
    });
  });

  group('_get error handling', () {
    test('network error is wrapped', () async {
      final api = ClaudeApiClient(client: MockClient((_) => throw Exception('boom')));
      await expectLater(
        api.resolveOrgId('k'),
        throwsA(predicate((e) => e is ClaudeApiException && e.message.contains('Network error'))),
      );
    });

    test('401/403 reports a rejected session with status code', () async {
      final api = clientFor({'/organizations': ('nope', 401)});
      await expectLater(
        api.resolveOrgId('k'),
        throwsA(predicate((e) => e is ClaudeApiException && e.statusCode == 401)),
      );
      final api403 = clientFor({'/organizations': ('nope', 403)});
      await expectLater(
        api403.resolveOrgId('k'),
        throwsA(predicate((e) => e is ClaudeApiException && e.statusCode == 403)),
      );
    });

    test('other >=400 reports a failed request', () async {
      final api = clientFor({'/organizations': ('oops', 500)});
      await expectLater(
        api.resolveOrgId('k'),
        throwsA(predicate((e) => e is ClaudeApiException && e.statusCode == 500)),
      );
    });

    test('non-JSON success body throws', () async {
      final api = clientFor({'/organizations': ('<html>not json</html>', 200)});
      await expectLater(
        api.resolveOrgId('k'),
        throwsA(predicate((e) => e is ClaudeApiException && e.message.contains('not JSON'))),
      );
    });

    test('ClaudeApiException.toString is its message', () {
      expect(ClaudeApiException('hi', 401).toString(), 'hi');
    });
  });

  group('fetchUsage', () {
    test('throws when the usage payload is not a map', () async {
      final api = clientFor({'/organizations/o/usage': ('[]', 200)});
      expect(
        () => api.fetchUsage(sessionKey: 'k', orgId: 'o'),
        throwsA(isA<ClaudeApiException>()),
      );
    });

    test('parses windows + models, missing windows default to 0', () async {
      final api = clientFor({
        '/organizations/o/usage': (
          jsonEncode({
            'five_hour': {'utilization': 64, 'resets_at': '2026-06-22T12:00:00Z'},
            // seven_day intentionally absent -> defaults to 0.
            'seven_day_opus': {'utilization': 88},
            'seven_day_sonnet': {'utilization': 42},
            // not-a-map entry is skipped by the models loop.
            'seven_day_cowork': 'bogus',
          }),
          200,
        ),
        // overage + prepaid both 404 -> extra is null.
      });
      final snap = await api.fetchUsage(sessionKey: 'k', orgId: 'o');
      expect(snap.session.percent, 64);
      expect(snap.weekly.utilization, 0); // defaulted
      expect(snap.models.map((m) => m.label), ['Opus', 'Sonnet']);
      expect(snap.extra, isNull);
      // Raw top-level keys are retained for the diagnostic empty-state.
      expect(snap.rawKeys,
          ['five_hour', 'seven_day_opus', 'seven_day_sonnet', 'seven_day_cowork']);
    });

    test('discovers every seven_day_* model, humanising unknown keys', () async {
      final api = clientFor({
        '/organizations/o/usage': (
          jsonEncode({
            'five_hour': {'utilization': 10},
            'seven_day': {'utilization': 20}, // bare weekly, not a model
            'seven_day_oauth_apps': {'utilization': 5},
            'seven_day_opus': {'utilization': 88},
            'seven_day_omelette': {'utilization': 3},
            'seven_day_zeta_max': {'utilization': 1}, // unknown -> humanised
          }),
          200,
        ),
      });
      final snap = await api.fetchUsage(sessionKey: 'k', orgId: 'o');
      // Sorted by preferred order; unknown sorts last and is title-cased.
      expect(snap.models.map((m) => m.label).toList(),
          ['Opus', 'Haiku', 'Apps', 'Zeta Max']);
    });

    test('per-model prefers the limits array (weekly_scoped, named models)',
        () async {
      final api = clientFor({
        '/organizations/o/usage': (
          jsonEncode({
            'five_hour': {'utilization': 76},
            'seven_day': {'utilization': 34},
            'seven_day_opus': null, // legacy key present but null
            'seven_day_sonnet': {'utilization': 0}, // legacy map -> superseded
            'limits': [
              {'kind': 'session', 'percent': 76},
              {'kind': 'weekly_all', 'percent': 34},
              {
                'kind': 'weekly_scoped',
                'percent': 12,
                'resets_at': '2026-06-27T12:00:00Z',
                'scope': {'model': {'display_name': 'Opus'}},
              },
              {
                'kind': 'weekly_scoped',
                'percent': 0,
                'scope': {'model': {'display_name': 'Sonnet'}},
              },
              {'kind': 'weekly_scoped', 'percent': 5, 'scope': null}, // skipped
              {
                'kind': 'weekly_scoped',
                'percent': 5,
                'scope': {'model': {'display_name': ''}}, // empty -> skipped
              },
              'not-a-map', // skipped
            ],
          }),
          200,
        ),
      });
      final snap = await api.fetchUsage(sessionKey: 'k', orgId: 'o');
      expect(snap.models.map((m) => m.label).toList(), ['Opus', 'Sonnet']);
      expect(snap.models.first.percent, 12);
      expect(snap.models.first.resetsAt, isNotNull);
    });

    test('falls back to flat seven_day_* when limits has no scoped models',
        () async {
      final api = clientFor({
        '/organizations/o/usage': (
          jsonEncode({
            'five_hour': {'utilization': 10},
            'limits': [
              {'kind': 'session', 'percent': 10},
            ], // present but no weekly_scoped -> fall back to flat keys
            'seven_day_opus': {'utilization': 88},
          }),
          200,
        ),
      });
      final snap = await api.fetchUsage(sessionKey: 'k', orgId: 'o');
      expect(snap.models.map((m) => m.label).toList(), ['Opus']);
    });

    test('merges overage + prepaid into ExtraUsage', () async {
      final api = clientFor({
        '/organizations/o/usage': (jsonEncode({'five_hour': {'utilization': 10}}), 200),
        '/organizations/o/overage_spend_limit': (
          jsonEncode({
            'is_enabled': true,
            'currency': 'EUR',
            'used_credits': 1840,
            'monthly_credit_limit': 5000,
          }),
          200,
        ),
        '/organizations/o/prepaid/credits': (
          jsonEncode({'amount': 3160, 'currency': 'EUR'}),
          200,
        ),
      });
      final snap = await api.fetchUsage(sessionKey: 'k', orgId: 'o');
      expect(snap.extra, isNotNull);
      expect(snap.extra!.isEnabled, true);
      expect(snap.extra!.currency, 'EUR');
      expect(snap.extra!.usedCents, 1840);
      expect(snap.extra!.limitCents, 5000);
      expect(snap.extra!.balanceCents, 3160);
    });

    test('derives is_enabled from a positive limit + numeric-string fields', () async {
      final api = clientFor({
        '/organizations/o/usage': (jsonEncode({'five_hour': {'utilization': 10}}), 200),
        '/organizations/o/overage_spend_limit': (
          jsonEncode({
            // no is_enabled key, no currency -> defaults to USD
            'balance_cents': '1200',
            'spend_limit_amount_cents': '5000',
          }),
          200,
        ),
        // prepaid 404 -> caught, balance falls back to overage balance_cents.
      });
      final snap = await api.fetchUsage(sessionKey: 'k', orgId: 'o');
      expect(snap.extra!.isEnabled, true); // derived from limit > 0
      expect(snap.extra!.currency, 'USD');
      expect(snap.extra!.usedCents, 1200);
      expect(snap.extra!.limitCents, 5000);
      expect(snap.extra!.balanceCents, 1200);
    });

    test('prepaid-only response still yields ExtraUsage (limit 0 => disabled)', () async {
      final api = clientFor({
        '/organizations/o/usage': (jsonEncode({'five_hour': {'utilization': 10}}), 200),
        '/organizations/o/prepaid/credits': (jsonEncode({'amount': 500}), 200),
      });
      final snap = await api.fetchUsage(sessionKey: 'k', orgId: 'o');
      expect(snap.extra, isNotNull);
      expect(snap.extra!.isEnabled, false);
      expect(snap.extra!.balanceCents, 500);
    });
  });

  test('dispose closes the underlying client without throwing', () {
    final api = clientFor({});
    expect(api.dispose, returnsNormally);
  });
}
