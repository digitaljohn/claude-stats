import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A [PathProviderPlatform] that points every directory at a throwaway temp
/// folder, so [SessionStore] (and anything else using path_provider) can read
/// and write real files in tests without a host platform.
class FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  FakePathProvider(this.root);
  final Directory root;

  @override
  Future<String?> getTemporaryPath() async => root.path;
  @override
  Future<String?> getApplicationSupportPath() async => root.path;
  @override
  Future<String?> getLibraryPath() async => root.path;
  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;
  @override
  Future<String?> getApplicationCachePath() async => root.path;
  @override
  Future<String?> getExternalStoragePath() async => root.path;
  @override
  Future<List<String>?> getExternalCachePaths() async => [root.path];
  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) async =>
      [root.path];
  @override
  Future<String?> getDownloadsPath() async => root.path;
}

bool _fontsLoaded = false;

/// Registers a real proportional font (the Flutter SDK's bundled Roboto) under
/// the families the app actually asks for, so text has realistic metrics in
/// tests. Without this, the default test font renders every glyph at a full em
/// square, which blows out tight rows (e.g. the sign-in ghost-button row) into
/// spurious overflow errors. Loaded once per isolate; a no-op if the SDK font
/// can't be located.
Future<void> loadTestFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;

  final file = _locateRoboto();
  if (file == null) return;

  final bytes = await file.readAsBytes();
  ByteData toData() => ByteData.view(Uint8List.fromList(bytes).buffer);

  // google_fonts names each style `Family_<weight>` (e.g. HankenGrotesk_500)
  // and lists the bare family as a fallback. The test font substitutes for the
  // unknown *primary*, so register the proportional Roboto under both the bare
  // names and every weight variant the app uses.
  final families = <String>[];
  for (final base in const [
    'HankenGrotesk', 'JetBrainsMono', 'Inter', 'Roboto'
  ]) {
    families.add(base);
    for (final w in const [100, 200, 300, 400, 500, 600, 700, 800, 900]) {
      families.add('${base}_$w');
    }
  }
  for (final family in families) {
    final loader = FontLoader(family)..addFont(Future.value(toData()));
    await loader.load();
  }
}

/// Locates the SDK's bundled Roboto regardless of which executable
/// (`dart` vs `flutter_tester`, at different depths) is running the test, by
/// walking up from the executable and probing the known relative locations.
File? _locateRoboto() {
  const rels = [
    'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf', // from flutter root
    'artifacts/material_fonts/Roboto-Regular.ttf', // from .../cache
    'material_fonts/Roboto-Regular.ttf', // from .../artifacts
  ];
  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      Platform.environment['FLUTTER_ROOT']!,
  ];
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 10; i++) {
    roots.add(dir.path);
    dir = dir.parent;
  }
  for (final root in roots) {
    for (final rel in rels) {
      final f = File('$root/$rel');
      if (f.existsSync()) return f;
    }
  }
  return null;
}

/// Records the title/body of every desktop notification the app attempts to
/// raise via local_notifier, so threshold-notification logic can be asserted.
final List<Map<String, Object?>> notifications = [];

/// Installs all the plugin fakes/mocks the app relies on at the method-channel
/// boundary: path_provider (real temp dir), window_manager (no-op success so
/// the multi-step window-mode calls all run), and local_notifier (records
/// shown notifications). Returns the temp directory backing storage.
///
/// Call from `setUp`; the binding is created here if needed.
Directory installPluginFakes() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Don't hit the network for fonts in tests. google_fonts kicks off a fetch
  // the moment a style is used; point its client at a request that never
  // completes, so the loader future just stays pending (harmless — it's not a
  // Timer, so it neither blocks pumpAndSettle nor trips the pending-timer check)
  // while the requested TextStyle returns immediately with a fallback family.
  // Real (Roboto) metrics come from loadTestFonts(). google_fonts 8 exposes this
  // through the public `config.httpClient` hook (its old src-level stub is gone).
  GoogleFonts.config.httpClient =
      MockClient((_) => Completer<http.Response>().future);

  final tmp = Directory.systemTemp.createTempSync('claude_stats_test');
  PathProviderPlatform.instance = FakePathProvider(tmp);

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // window_manager — succeed silently so sequences of awaited calls all run.
  // `is*` queries (isMaximized/isFocused/…) are cast to bool by the plugin, so
  // answer those with `false` rather than null.
  messenger.setMockMethodCallHandler(
    const MethodChannel('window_manager'),
    (call) async {
      // getBounds/getSize parse the reply as a Rect map of doubles.
      if (call.method == 'getBounds') {
        return {'x': 0.0, 'y': 0.0, 'width': 420.0, 'height': 800.0};
      }
      // `is*` queries (isMaximized/isFocused/…) are cast to bool.
      if (call.method.startsWith('is')) return false;
      return null;
    },
  );

  // local_notifier — record show() calls; succeed for setup/everything else.
  notifications.clear();
  messenger.setMockMethodCallHandler(
    const MethodChannel('local_notifier'),
    (call) async {
      if (call.method == 'notify') {
        notifications.add(Map<String, Object?>.from(call.arguments as Map));
      }
      return null;
    },
  );

  return tmp;
}

/// Wraps [child] in a sized [MaterialApp] so widgets that need a
/// Directionality / MediaQuery / bounded constraints (LayoutBuilder, custom
/// painters, etc.) render in a realistic frame.
Widget wrap(Widget child, {Size size = const Size(400, 760)}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );
}

/// Grows the test window so ListView-based screens lay out all their cards
/// (the default 800×600 surface clips long scroll views, leaving lower rows
/// un-built and therefore un-findable). Auto-resets after the test.
Future<void> useTallSurface(WidgetTester tester,
    {Size size = const Size(440, 1600)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Tears down the method-channel handlers and removes the temp directory.
void removePluginFakes(Directory tmp) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'), null);
  messenger.setMockMethodCallHandler(
      const MethodChannel('local_notifier'), null);
  if (tmp.existsSync()) {
    tmp.deleteSync(recursive: true);
  }
}
