import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/models/usage.dart';
import 'package:claude_stats/state/app_controller.dart';
import 'package:claude_stats/state/settings.dart';
import 'package:claude_stats/ui/dashboard_screen.dart';
import 'package:claude_stats/ui/settings_panel.dart';
import 'package:claude_stats/ui/widgets/window_scaffold.dart';

import '../helpers/fakes.dart';
import '../helpers/test_harness.dart';

void main() {
  setUp(installPluginFakes);

  List<HistoryPoint> someHistory() => [
        for (var i = 0; i < 50; i++)
          HistoryPoint(
              t: DateTime(2026, 6, 20).add(Duration(hours: i)),
              session: (i % 10) / 10,
              weekly: 0.4 + i / 200),
      ];

  testWidgets('loading state when usage is null', (tester) async {
    final c = readyController(usage: null);
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(DashboardScreen(controller: c)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('full demo layout: cards, chart toggle, mini + settings buttons',
      (tester) async {
    await useTallSurface(tester);
    final c = readyController(
      mode: AppMode.demo,
      usage: screenSnapshot(),
      history: someHistory(),
      lastUpdated: DateTime.now().subtract(const Duration(seconds: 12)),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(DashboardScreen(controller: c),
        size: const Size(420, 1500)));

    // Demo banner + the two window cards + per-model + extra + footer.
    expect(find.textContaining('Demo data'), findsOneWidget);
    // SectionLabel upper-cases its text.
    expect(find.text('5-HOUR WINDOW'), findsOneWidget);
    expect(find.text('7-DAY WINDOW'), findsOneWidget);
    expect(find.text('PER-MODEL · WEEKLY'), findsOneWidget);
    expect(find.text('EXTRA USAGE'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsOneWidget);

    // Toggle the chart series to WEEKLY.
    await tester.tap(find.text('WEEKLY').first);
    await tester.pump();

    // Open and close the settings panel. Title-bar buttons sit inside a
    // DragToMoveArea, so their tap resolves through the gesture arena (~40ms).
    await tester.tap(find.widgetWithIcon(TitleBarButton, Icons.tune));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(SettingsPanel), findsOneWidget);
    // Close via the panel's own X button -> exercises the onClose callback.
    await tester.tap(find.descendant(
        of: find.byType(SettingsPanel), matching: find.byIcon(Icons.close)));
    await tester.pump();
    expect(find.byType(SettingsPanel), findsNothing);

    // Mini-mode button -> setMini(true) (async window resize, mocked). Spaced
    // past kDoubleTapTimeout so it isn't fused with the next tap into a
    // title-bar double-tap.
    await tester.tap(find.widgetWithIcon(TitleBarButton, Icons.close_fullscreen));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('compact layout with an error banner and no last-update time',
      (tester) async {
    await useTallSurface(tester);
    final c = readyController(
      mode: AppMode.live,
      // session maxed (RingCountdown in the compact ring tile), weekly mid.
      usage: screenSnapshot(session: 1.0, weekly: 0.2, models: false, extra: null),
      settings: const Settings(compactMode: true),
      error: 'Session rejected (401).',
      history: someHistory(),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(DashboardScreen(controller: c)));

    expect(find.textContaining('Session rejected'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.textContaining('UPDATED —'), findsOneWidget);
    // No optional cards.
    expect(find.text('PER-MODEL · WEEKLY'), findsNothing);
    expect(find.text('EXTRA USAGE'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('extra present but disabled is hidden', (tester) async {
    await useTallSurface(tester);
    final c = readyController(
      mode: AppMode.live,
      usage: screenSnapshot(
        extra: const ExtraUsage(
          isEnabled: false,
          currency: 'USD',
          usedCents: 0,
          limitCents: 0,
          balanceCents: 0,
        ),
      ),
      history: someHistory(),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(DashboardScreen(controller: c),
        size: const Size(420, 1500)));
    expect(find.text('EXTRA USAGE'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
