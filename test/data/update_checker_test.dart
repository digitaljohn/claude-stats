import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:claude_stats/data/update_checker.dart';

void main() {
  group('isNewerVersion', () {
    test('detects newer major / minor / patch', () {
      expect(isNewerVersion('1.0.0', '0.9.9'), isTrue);
      expect(isNewerVersion('0.2.0', '0.1.9'), isTrue);
      expect(isNewerVersion('0.1.2', '0.1.1'), isTrue);
    });

    test('equal or older is not newer', () {
      expect(isNewerVersion('0.1.0', '0.1.0'), isFalse);
      expect(isNewerVersion('0.1.0', '0.2.0'), isFalse);
      expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
    });

    test('ignores pre-release/build suffixes and odd parts', () {
      expect(isNewerVersion('0.2.0-rc.1', '0.1.0'), isTrue);
      expect(isNewerVersion('0.1.0+5', '0.1.0'), isFalse);
      expect(isNewerVersion('1', '0.9'), isTrue); // missing tiers => 0
      expect(isNewerVersion('x.y.z', '0.0.0'), isFalse); // non-numeric => 0
    });
  });

  group('UpdateChecker.latestNewerThan', () {
    UpdateChecker checkerFor(MockClient client) => UpdateChecker(
        client: client, releasesUri: Uri.parse('https://api/latest'));

    test('returns info when the release is newer (with leading v)', () async {
      final c = checkerFor(MockClient((_) async => http.Response(
          jsonEncode({'tag_name': 'v9.9.9', 'html_url': 'https://gh/rel'}), 200)));
      final info = await c.latestNewerThan('0.1.0');
      expect(info, isNotNull);
      expect(info!.version, '9.9.9');
      expect(info.url, 'https://gh/rel');
    });

    test('handles a tag without a leading v', () async {
      final c = checkerFor(MockClient((_) async => http.Response(
          jsonEncode({'tag_name': '9.9.9', 'html_url': 'https://gh/rel'}), 200)));
      expect((await c.latestNewerThan('0.1.0'))!.version, '9.9.9');
    });

    test('null when the latest is not newer', () async {
      final c = checkerFor(MockClient((_) async => http.Response(
          jsonEncode({'tag_name': 'v0.1.0', 'html_url': 'https://gh/rel'}), 200)));
      expect(await c.latestNewerThan('0.1.0'), isNull);
    });

    test('null on a non-200 response', () async {
      final c = checkerFor(MockClient((_) async => http.Response('nope', 404)));
      expect(await c.latestNewerThan('0.1.0'), isNull);
    });

    test('null on a non-map body or missing/!string fields', () async {
      final list = checkerFor(MockClient((_) async => http.Response('[]', 200)));
      expect(await list.latestNewerThan('0.1.0'), isNull);

      final noUrl = checkerFor(MockClient((_) async => http.Response(
          jsonEncode({'tag_name': 'v9.9.9'}), 200)));
      expect(await noUrl.latestNewerThan('0.1.0'), isNull);

      final badTag = checkerFor(MockClient((_) async => http.Response(
          jsonEncode({'tag_name': 123, 'html_url': 'https://gh/rel'}), 200)));
      expect(await badTag.latestNewerThan('0.1.0'), isNull);
    });

    test('null when the request throws', () async {
      final c = checkerFor(
          MockClient((_) async => throw const SocketException('offline')));
      expect(await c.latestNewerThan('0.1.0'), isNull);
    });

    test('default constructor builds a real client; dispose is safe', () {
      expect(UpdateChecker().dispose, returnsNormally);
    });
  });

  test('kAppVersion stays in sync with pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
        .firstMatch(pubspec);
    expect(m, isNotNull, reason: 'a "version:" line should exist in pubspec.yaml');
    expect(kAppVersion, m!.group(1),
        reason: 'bump kAppVersion in update_checker.dart to match pubspec');
  });
}
