import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/platform/platform_support.dart';

void main() {
  group('PlatformSupport capabilities', () {
    test('macOS: embedded webview + integrated chrome + status-item title', () {
      const p = PlatformSupport(HostOs.macos);
      expect(p.isMacOS, isTrue);
      expect(p.isWindows, isFalse);
      expect(p.isLinux, isFalse);
      expect(p.hasEmbeddedWebview, isTrue);
      expect(p.trayShowsTitle, isTrue);
      expect(p.trayIconIsTemplate, isTrue);
      expect(p.usesTrafficLights, isTrue);
    });

    test('Windows: embedded webview, but native chrome + tooltip-only tray', () {
      const p = PlatformSupport(HostOs.windows);
      expect(p.isMacOS, isFalse);
      expect(p.isWindows, isTrue);
      expect(p.isLinux, isFalse);
      expect(p.hasEmbeddedWebview, isTrue);
      expect(p.trayShowsTitle, isFalse);
      expect(p.trayIconIsTemplate, isFalse);
      expect(p.usesTrafficLights, isFalse);
    });

    test('Linux: no embedded webview → browser fallback; native chrome', () {
      const p = PlatformSupport(HostOs.linux);
      expect(p.isMacOS, isFalse);
      expect(p.isWindows, isFalse);
      expect(p.isLinux, isTrue);
      expect(p.hasEmbeddedWebview, isFalse);
      expect(p.trayShowsTitle, isFalse);
      expect(p.trayIconIsTemplate, isFalse);
      expect(p.usesTrafficLights, isFalse);
    });

    test('current resolves to the real host (macOS on the CI test runner)', () {
      expect(PlatformSupport.current.os, HostOs.macos);
    });
  });
}
