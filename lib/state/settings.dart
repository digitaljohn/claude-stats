import 'dart:convert';

/// User-tunable preferences, persisted as JSON.
class Settings {
  const Settings({
    this.warnThreshold = 0.75,
    this.dangerThreshold = 0.90,
    this.use24h = false,
    this.refreshSeconds = 300,
    this.alwaysOnTop = false,
    this.showResetDate = false,
    this.notificationsEnabled = true,
    this.mini = false,
  });

  final double warnThreshold; // 0..1
  final double dangerThreshold; // 0..1
  final bool use24h;
  final int refreshSeconds;
  final bool alwaysOnTop;
  final bool showResetDate;
  final bool notificationsEnabled;
  final bool mini; // compact floating-widget window mode

  Settings copyWith({
    double? warnThreshold,
    double? dangerThreshold,
    bool? use24h,
    int? refreshSeconds,
    bool? alwaysOnTop,
    bool? showResetDate,
    bool? notificationsEnabled,
    bool? mini,
  }) =>
      Settings(
        warnThreshold: warnThreshold ?? this.warnThreshold,
        dangerThreshold: dangerThreshold ?? this.dangerThreshold,
        use24h: use24h ?? this.use24h,
        refreshSeconds: refreshSeconds ?? this.refreshSeconds,
        alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
        showResetDate: showResetDate ?? this.showResetDate,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        mini: mini ?? this.mini,
      );

  Map<String, dynamic> toJson() => {
        'warn': warnThreshold,
        'danger': dangerThreshold,
        'use24h': use24h,
        'refresh': refreshSeconds,
        'onTop': alwaysOnTop,
        'resetDate': showResetDate,
        'notify': notificationsEnabled,
        'mini': mini,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        warnThreshold: (j['warn'] as num?)?.toDouble() ?? 0.75,
        dangerThreshold: (j['danger'] as num?)?.toDouble() ?? 0.90,
        use24h: j['use24h'] as bool? ?? false,
        refreshSeconds: (j['refresh'] as num?)?.toInt() ?? 300,
        alwaysOnTop: j['onTop'] as bool? ?? false,
        showResetDate: j['resetDate'] as bool? ?? false,
        notificationsEnabled: j['notify'] as bool? ?? true,
        mini: j['mini'] as bool? ?? false,
      );

  String encode() => jsonEncode(toJson());

  static Settings decode(String? raw) {
    if (raw == null || raw.isEmpty) return const Settings();
    try {
      return Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const Settings();
    }
  }
}
