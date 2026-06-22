import 'dart:convert';

import 'package:http/http.dart' as http;

/// The running app version, without build metadata. Kept in lock-step with
/// pubspec's `version:` by a test (see test/data/update_checker_test.dart), so
/// it can never silently drift out of sync.
const String kAppVersion = '1.0.0';

/// A newer release found on GitHub.
class UpdateInfo {
  const UpdateInfo({required this.version, required this.url});

  /// Release version without the leading `v` (e.g. "0.2.0").
  final String version;

  /// The release's GitHub page, where the `.dmg` asset is attached.
  final String url;
}

/// Checks GitHub for a newer published release of claude-stats.
///
/// Uses the `releases/latest` endpoint, which already excludes drafts and
/// **pre-releases** — so release-candidate tags (e.g. `v0.1.0-rc.1`) never
/// prompt anyone to "update".
class UpdateChecker {
  UpdateChecker({http.Client? client, Uri? releasesUri})
      : _client = client ?? http.Client(),
        _uri = releasesUri ??
            Uri.parse('https://api.github.com/repos/'
                'digitaljohn/claude-stats/releases/latest');

  final http.Client _client;
  final Uri _uri;

  /// Returns the latest release iff it is strictly newer than [currentVersion],
  /// otherwise null. Best-effort: every network/parse failure resolves to null
  /// (it never throws — a flaky check should never disrupt the app).
  Future<UpdateInfo?> latestNewerThan(String currentVersion) async {
    try {
      final res = await _client.get(
        _uri,
        headers: const {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) return null;
      final tag = body['tag_name'];
      final url = body['html_url'];
      if (tag is! String || url is! String) return null;
      final version = tag.startsWith('v') ? tag.substring(1) : tag;
      if (!isNewerVersion(version, currentVersion)) return null;
      return UpdateInfo(version: version, url: url);
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}

/// True iff semantic version [latest] is strictly newer than [current].
///
/// Compares the first three dotted numeric components; any pre-release/build
/// suffix is ignored and missing or non-numeric parts count as 0. So
/// "0.2.0" > "0.1.9", "1.0.0" > "0.9.9", and equal versions return false.
bool isNewerVersion(String latest, String current) {
  List<int> nums(String v) {
    final core = v.split(RegExp(r'[-+]')).first; // drop -rc.1 / +build
    final out = <int>[0, 0, 0];
    final parts = core.split('.');
    for (var i = 0; i < 3 && i < parts.length; i++) {
      out[i] = int.tryParse(parts[i]) ?? 0;
    }
    return out;
  }

  final a = nums(latest);
  final b = nums(current);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}
