import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/data/update_checker.dart';
import 'package:claude_stats/models/account.dart';
import 'package:claude_stats/models/usage.dart';
import 'package:claude_stats/state/app_controller.dart';
import 'package:claude_stats/ui/dashboard_screen.dart';
import 'package:claude_stats/ui/settings_panel.dart';
import 'package:claude_stats/ui/widgets/account_switcher.dart';
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

    // Demo banner + the two window cards + extra + footer.
    expect(find.textContaining('Demo data'), findsOneWidget);
    // SectionLabel upper-cases its text.
    expect(find.text('5-HOUR WINDOW'), findsOneWidget);
    expect(find.text('7-DAY WINDOW'), findsOneWidget);
    expect(find.text('EXTRA USAGE'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsOneWidget);

    // Toggle the chart series to WEEKLY and zoom to 1 day.
    await tester.tap(find.text('WEEKLY').first);
    await tester.pump();
    await tester.tap(find.text('1D'));
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

  testWidgets('error banner, no last-update time, maxed session ring',
      (tester) async {
    await useTallSurface(tester);
    final c = readyController(
      mode: AppMode.live,
      // session maxed → RingCountdown in its window card; weekly mid → UsageRing.
      usage: screenSnapshot(session: 1.0, weekly: 0.2, models: false, extra: null),
      error: 'Session rejected (401).',
      history: someHistory(),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(DashboardScreen(controller: c),
        size: const Size(420, 1500)));

    expect(find.textContaining('Session rejected'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.textContaining('UPDATED —'), findsOneWidget);
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

  testWidgets('shows an update banner; Download opens the release page',
      (tester) async {
    await useTallSurface(tester);
    final launched = <Uri>[];
    final c = readyController(
      mode: AppMode.demo,
      usage: screenSnapshot(),
      history: someHistory(),
      availableUpdate: const UpdateInfo(version: '9.9.9', url: 'https://gh/rel'),
      urlLauncher: (u) async {
        launched.add(u);
        return true;
      },
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(DashboardScreen(controller: c),
        size: const Size(420, 1500)));

    expect(find.textContaining('Update available'), findsOneWidget);
    await tester.tap(find.text('Download'));
    await tester.pump();
    expect(launched.single.toString(), 'https://gh/rel');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('coffee button opens Buy Me a Coffee in the browser',
      (tester) async {
    await useTallSurface(tester);
    final launched = <Uri>[];
    final c = readyController(
      mode: AppMode.demo,
      usage: screenSnapshot(),
      history: someHistory(),
      urlLauncher: (u) async {
        launched.add(u);
        return true;
      },
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(DashboardScreen(controller: c),
        size: const Size(420, 1500)));

    await tester.tap(find.widgetWithIcon(TitleBarButton, Icons.coffee_rounded));
    await tester.pump(const Duration(milliseconds: 350)); // DragToMoveArea arena
    expect(launched.single.toString(), 'https://www.buymeacoffee.com/digitaljohn');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('multi-account: switcher appears and switches the active org',
      (tester) async {
    await useTallSurface(tester);
    final c = readyController(
      mode: AppMode.live,
      usage: screenSnapshot(),
      history: someHistory(),
      accounts: const [
        Account(id: 'personal', name: 'Personal'),
        Account(id: 'team', name: 'Acme', type: 'team'),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(DashboardScreen(controller: c),
        size: const Size(420, 1500)));

    expect(find.byType(AccountSwitcher), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget); // default (first) org

    await tester.tap(find.byType(AccountSwitcher));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acme').last);
    await tester.pumpAndSettle();
    expect(c.activeAccountId, 'team');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('switching org while the menu closes does not crash', (tester) async {
    await useTallSurface(tester);
    final c = readyController(
      mode: AppMode.live,
      usage: screenSnapshot(),
      history: someHistory(),
      accounts: const [
        Account(id: 'personal', name: 'Personal'),
        Account(id: 'team', name: 'Acme', type: 'team'),
      ],
    );
    addTearDown(c.dispose);
    // Mirror main.dart: rebuild the screen on every notify, so selecting an org
    // (which nulls `usage`) actually swaps the body while the menu animates
    // closed — the exact sequence that used to throw a deactivated-ancestor.
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ListenableBuilder(
        listenable: c,
        builder: (_, _) => DashboardScreen(controller: c),
      ),
    ));

    await tester.tap(find.byType(AccountSwitcher));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acme').last);
    // usage is now null → loading spinner spins forever, so step frames by hand
    // rather than pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(c.activeAccountId, 'team');
    expect(find.byType(AccountSwitcher), findsOneWidget); // still mounted
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('single account: no switcher is shown', (tester) async {
    await useTallSurface(tester);
    final c = readyController(
      mode: AppMode.live,
      usage: screenSnapshot(),
      history: someHistory(),
      accounts: const [Account(id: 'solo', name: 'Solo')],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(DashboardScreen(controller: c),
        size: const Size(420, 1500)));
    expect(find.byType(AccountSwitcher), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
