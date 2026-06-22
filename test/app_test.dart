import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/main.dart' as app;
import 'package:claude_stats/state/app_controller.dart';
import 'package:claude_stats/ui/dashboard_screen.dart';
import 'package:claude_stats/ui/mini_screen.dart';
import 'package:claude_stats/ui/sign_in_screen.dart';
import 'package:claude_stats/ui/widgets/window_scaffold.dart';

import 'helpers/fakes.dart';
import 'helpers/test_harness.dart';

void main() {
  setUp(() async {
    installPluginFakes();
    await loadTestFonts();
  });

  testWidgets('ClaudeStatsApp routes every controller mode', (tester) async {
    // ClaudeStatsApp.dispose() disposes the controller on unmount, so no
    // addTearDown here (that would double-dispose the ChangeNotifier).
    final c = AppController(store: FakeStore(), api: FakeApi());

    await tester.pumpWidget(app.ClaudeStatsApp(controller: c));
    // First frame, before bootstrap resolves: the loading scaffold.
    expect(find.byType(WindowScaffold), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // bootstrap (empty store) settles to signed-out.
    await tester.pump();
    expect(find.byType(SignInScreen), findsOneWidget);

    // Demo -> full dashboard.
    await c.enterDemo();
    await tester.pump();
    expect(find.byType(DashboardScreen), findsOneWidget);

    // Mini toggle -> mini screen.
    await c.setMini(true);
    await tester.pump();
    expect(find.byType(MiniScreen), findsOneWidget);

    // Live mode (full) -> dashboard, covering the AppMode.live switch arm.
    c.mode = AppMode.live;
    await c.setMini(false);
    await tester.pump();
    expect(find.byType(DashboardScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
