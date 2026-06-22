import 'dart:convert';

/// Normalises Claude's `utilization` field, which arrives as a percentage
/// (0–100) on the live API. Values <= 1 are treated as already-fractional so
/// the model is robust to either representation.
double _normalizeUtil(Object? raw) {
  final v = (raw is num) ? raw.toDouble() : double.tryParse('$raw') ?? 0.0;
  final f = v > 1.0 ? v / 100.0 : v;
  return f.clamp(0.0, 1.0);
}

DateTime? _parseTs(Object? raw) {
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw)?.toLocal();
  return null;
}

/// A single rate-limit window (e.g. the 5-hour session or the 7-day weekly
/// limit), expressed as a 0..1 utilisation plus when it resets.
class UsageWindow {
  const UsageWindow({
    required this.key,
    required this.label,
    required this.utilization,
    this.resetsAt,
  });

  final String key;
  final String label;
  final double utilization; // 0..1
  final DateTime? resetsAt;

  factory UsageWindow.fromJson(String key, String label, Map<String, dynamic> j) {
    return UsageWindow(
      key: key,
      label: label,
      utilization: _normalizeUtil(j['utilization']),
      resetsAt: _parseTs(j['resets_at']),
    );
  }

  int get percent => (utilization * 100).round();
}

/// Overage / prepaid "extra usage" budget, merged from the
/// `overage_spend_limit` and `prepaid/credits` endpoints.
class ExtraUsage {
  const ExtraUsage({
    required this.isEnabled,
    required this.currency,
    required this.usedCents,
    required this.limitCents,
    required this.balanceCents,
  });

  final bool isEnabled;
  final String currency;
  final int usedCents;
  final int limitCents;
  final int balanceCents;

  double get utilization =>
      limitCents > 0 ? (usedCents / limitCents).clamp(0.0, 1.0) : 0.0;

  String get symbol => switch (currency.toUpperCase()) {
        'EUR' => '€',
        'GBP' => '£',
        'USD' => '\$',
        _ => '\$',
      };

  String fmt(int cents) => '$symbol${(cents / 100).toStringAsFixed(2)}';
}

/// One full read of the usage API.
class UsageSnapshot {
  const UsageSnapshot({
    required this.fetchedAt,
    required this.session,
    required this.weekly,
    this.models = const [],
    this.extra,
    this.rawKeys = const [],
  });

  final DateTime fetchedAt;
  final UsageWindow session; // five_hour
  final UsageWindow weekly; // seven_day
  final List<UsageWindow> models; // per-model 7-day windows
  final ExtraUsage? extra;

  /// Top-level keys of the raw `/usage` response — surfaced as a diagnostic when
  /// no per-model windows are found, so it's clear what the API actually sent.
  final List<String> rawKeys;
}

/// A persisted history sample for the 7-day chart.
class HistoryPoint {
  const HistoryPoint({
    required this.t,
    required this.session,
    required this.weekly,
  });

  final DateTime t;
  final double session; // 0..1
  final double weekly; // 0..1

  Map<String, dynamic> toJson() => {
        't': t.toUtc().toIso8601String(),
        's': session,
        'w': weekly,
      };

  factory HistoryPoint.fromJson(Map<String, dynamic> j) => HistoryPoint(
        t: DateTime.parse(j['t'] as String).toLocal(),
        session: (j['s'] as num).toDouble(),
        weekly: (j['w'] as num).toDouble(),
      );

  static String encode(List<HistoryPoint> pts) =>
      jsonEncode(pts.map((p) => p.toJson()).toList());

  static List<HistoryPoint> decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => HistoryPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
