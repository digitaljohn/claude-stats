import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/models/account.dart';

void main() {
  group('typeLabel', () {
    test('null / empty / "default" read as Personal', () {
      expect(const Account(id: '1', name: 'A').typeLabel, 'Personal');
      expect(const Account(id: '1', name: 'A', type: '').typeLabel, 'Personal');
      expect(
          const Account(id: '1', name: 'A', type: 'default').typeLabel, 'Personal');
    });

    test('known kinds are humanised', () {
      expect(const Account(id: '1', name: 'A', type: 'team').typeLabel, 'Team');
      expect(const Account(id: '1', name: 'A', type: 'enterprise').typeLabel,
          'Enterprise');
    });

    test('unknown kinds are title-cased', () {
      expect(const Account(id: '1', name: 'A', type: 'pro_max').typeLabel,
          'Pro Max');
    });
  });

  group('fromApi', () {
    test('reads uuid, name, raven_type and chat capability', () {
      final a = Account.fromApi({
        'uuid': 'u-1',
        'name': '  Acme  ',
        'raven_type': 'team',
        'capabilities': ['chat', 'foo'],
      })!;
      expect(a.id, 'u-1');
      expect(a.name, 'Acme'); // trimmed
      expect(a.type, 'team');
      expect(a.chatCapable, true);
    });

    test('falls back to the legacy id and marks non-chat orgs', () {
      final a = Account.fromApi({'id': 'legacy', 'capabilities': []})!;
      expect(a.id, 'legacy');
      expect(a.chatCapable, false);
    });

    test('returns null when no id is present', () {
      expect(Account.fromApi({'name': 'x'}), isNull);
    });

    test('derives a name from the type when the API omits one', () {
      expect(Account.fromApi({'uuid': '1', 'raven_type': 'team'})!.name, 'Team');
      expect(
          Account.fromApi({'uuid': '1', 'raven_type': 'enterprise'})!.name,
          'Enterprise');
      expect(Account.fromApi({'uuid': '1', 'name': '   '})!.name, 'Personal');
    });
  });

  group('json', () {
    test('toJson omits a null type and round-trips through decode', () {
      const personal = Account(id: 'p', name: 'Me');
      expect(personal.toJson().containsKey('type'), false);

      const team = Account(id: 't', name: 'Acme', type: 'team');
      final back = Account.decode(Account.encode([personal, team]));
      expect(back, [personal, team]);
      expect(back[1].toJson()['type'], 'team');
    });

    test('fromJson defaults a missing/blank name and chat flag', () {
      final blank = Account.fromJson({'id': 'x', 'name': '  '});
      expect(blank.name, 'Account');
      expect(blank.chatCapable, true); // default when absent
    });

    test('decode tolerates null, empty and garbage', () {
      expect(Account.decode(null), isEmpty);
      expect(Account.decode(''), isEmpty);
      expect(Account.decode('{not a list}'), isEmpty);
    });
  });

  test('equality is by all fields', () {
    const a = Account(id: '1', name: 'A', type: 'team');
    const b = Account(id: '1', name: 'A', type: 'team');
    const c = Account(id: '1', name: 'A', type: 'enterprise');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, false);
  });
}
