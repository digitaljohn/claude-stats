import 'dart:convert';

/// One Claude organisation reachable from the signed-in session.
///
/// A single claude.ai login frequently exposes more than one org — e.g. a
/// **personal** workspace alongside a **corporate/team** one — and each has its
/// own usage limits. We surface them all so the user can switch which org's
/// numbers the app is watching, instead of silently locking onto whichever one
/// the API happened to list first.
class Account {
  const Account({
    required this.id,
    required this.name,
    this.type,
    this.chatCapable = true,
  });

  /// The org's `uuid` (or legacy `id`) — the value used in every `/usage` call.
  final String id;

  /// Human-readable label shown in the switcher. Falls back to a type-derived
  /// name ("Personal" / "Team") when the API omits one.
  final String name;

  /// The API's `raven_type` (e.g. `team`); null / empty means a personal org.
  final String? type;

  /// Whether the org advertises the `chat` capability.
  final bool chatCapable;

  /// Humanised plan label shown beneath the name and in the menu.
  String get typeLabel {
    final t = type?.trim().toLowerCase();
    if (t == null || t.isEmpty || t == 'default') return 'Personal';
    if (t == 'team') return 'Team';
    if (t == 'enterprise') return 'Enterprise';
    return _titleCase(t);
  }

  static String _titleCase(String raw) => raw
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (type != null) 'type': type,
        'chat': chatCapable,
      };

  factory Account.fromJson(Map<String, dynamic> j) {
    final name = (j['name'] as String?)?.trim();
    return Account(
      id: '${j['id']}',
      name: (name != null && name.isNotEmpty) ? name : 'Account',
      type: j['type'] as String?,
      chatCapable: j['chat'] as bool? ?? true,
    );
  }

  /// Parses one raw `/organizations` entry. Returns null when the org carries no
  /// usable id, so the caller can skip it rather than crash the switcher.
  static Account? fromApi(Map<String, dynamic> o) {
    final id = o['uuid'] ?? o['id'];
    if (id == null) return null;
    final type = o['raven_type'] as String?;
    final rawName = (o['name'] as String?)?.trim();
    final caps = o['capabilities'];
    return Account(
      id: '$id',
      name: (rawName != null && rawName.isNotEmpty)
          ? rawName
          : _fallbackName(type),
      type: type,
      chatCapable: caps is List && caps.contains('chat'),
    );
  }

  static String _fallbackName(String? type) {
    final t = type?.trim().toLowerCase();
    if (t == 'team') return 'Team';
    if (t == 'enterprise') return 'Enterprise';
    return 'Personal';
  }

  static String encode(List<Account> accounts) =>
      jsonEncode(accounts.map((a) => a.toJson()).toList());

  static List<Account> decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Account.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.chatCapable == chatCapable;

  @override
  int get hashCode => Object.hash(id, name, type, chatCapable);
}
