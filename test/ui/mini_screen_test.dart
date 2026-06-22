import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/state/app_controller.dart';
import 'package:claude_stats/ui/mini_screen.dart';
import 'package:claude_stats/ui/widgets/countdown_text.dart';
import 'package:claude_stats/ui/widgets/window_scaffold.dart';

import '../helpers/fakes.dart';
import '../helpers/test_harness.dart';

void main() {
  setUp(installPluginFakes);

  testWidgets('shows a loading spinner until usage arrives', (tester) async {
    final c = readyController(mode: AppMode.demo, usage: null);
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(MiniScreen(controller: c)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders both window tiles and expands back to full', (tester) async {
    final c = readyController(mode: AppMode.demo, usage: screenSnapshot());
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(MiniScreen(controller: c)));

    expect(find.text('SESSION'), findsOneWidget);
    expect(find.text('WEEKLY'), findsOneWidget);
    // session is maxed (100%) -> RingCountdown; weekly (50%) -> percentage text.
    expect(find.byType(RingCountdown), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    // Expand button -> setMini(false) (already full, so a no-op path).
    await tester.tap(find.widgetWithIcon(TitleBarButton, Icons.open_in_full));
    await tester.pump(const Duration(milliseconds: 350)); // past kDoubleTapTimeout (DragToMoveArea)

    await tester.pumpWidget(const SizedBox()); // dispose countdown timers
  });
}
