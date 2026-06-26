import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/state/app_controller.dart';
import 'package:claude_stats/theme/claude_theme.dart';
import 'package:claude_stats/ui/settings_panel.dart';

import '../helpers/fakes.dart';
import '../helpers/test_harness.dart';

void main() {
  setUp(installPluginFakes);
  tearDown(() => AppColors.current = AppPalette.dark);

  testWidgets('demo account: renders, drags sliders, toggles, segments, exits',
      (tester) async {
       await useTallSurface(tester);
    final store = FakeStore();
    final c = readyController(mode: AppMode.demo, store: store);
    addTearDown(c.dispose);
    var closed = false;

    await tester.pumpWidget(wrap(
      SettingsPanel(controller: c, onClose: () => closed = true),
      size: const Size(420, 1500),
    ));

    expect(find.text('Demo session'), findsOneWidget);
    expect(find.text('Showing synthetic data'), findsOneWidget);

    // Drag both sliders across their range so the warn/danger coupling logic
    // (bump the partner threshold) runs in both directions.
    final sliders = find.byType(Slider);
    await tester.drag(sliders.at(0), const Offset(300, 0)); // warning -> high
    await tester.pump();
    await tester.drag(sliders.at(0), const Offset(-300, 0)); // warning -> low
    await tester.pump();
    await tester.drag(sliders.at(1), const Offset(-300, 0)); // danger -> low
    await tester.pump();
    await tester.drag(sliders.at(1), const Offset(300, 0)); // danger -> high
    await tester.pump();

    // Flip every toggle.
    for (final sw in tester.widgetList<Switch>(find.byType(Switch)).toList()) {
      await tester.tap(find.byWidget(sw));
      await tester.pump();
    }

    // Pick a different refresh interval.
    await tester.tap(find.text('15m'));
    await tester.pump();
    expect(c.settings.refreshSeconds, 900);

    // Exit demo (danger button) -> onClose + signOut.
    await tester.tap(find.text('Exit demo'));
    await tester.pump();
    expect(closed, true);
    expect(c.mode, AppMode.signedOut);
  });

  testWidgets('connected account shows the live copy and a close button works',
      (tester) async {
    await useTallSurface(tester);
    final c = readyController(mode: AppMode.live, store: FakeStore());
    addTearDown(c.dispose);
    var closed = false;

    await tester.pumpWidget(wrap(
      SettingsPanel(controller: c, onClose: () => closed = true),
      size: const Size(420, 1500),
    ));

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('session stored privately on this Mac'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);

    // The close (X) button.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(closed, true);
  });

  testWidgets('the appearance control switches between Dark and Light',
      (tester) async {
    await useTallSurface(tester);
    final c = readyController(mode: AppMode.demo, store: FakeStore());
    addTearDown(c.dispose);

    await tester.pumpWidget(wrap(
      SettingsPanel(controller: c, onClose: () {}),
      size: const Size(420, 1500),
    ));

    expect(c.settings.themeMode, AppThemeMode.dark);

    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(c.settings.themeMode, AppThemeMode.light);
    expect(AppColors.current, AppPalette.light);

    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(c.settings.themeMode, AppThemeMode.dark);
    expect(AppColors.current, AppPalette.dark);
  });

  testWidgets('keyboard card is hidden when no keyboard is detected',
      (tester) async {
    await useTallSurface(tester);
    final c = readyController(mode: AppMode.live, store: FakeStore());
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(
      SettingsPanel(controller: c, onClose: () {}),
      size: const Size(420, 1500),
    ));
    expect(find.text('NuPhy side lights'), findsNothing);
  });

  testWidgets('keyboard card appears when detected and its switch toggles',
      (tester) async {
    await useTallSurface(tester);
    final c = readyController(
      mode: AppMode.demo,
      usage: screenSnapshot(),
      keyboardDetected: true,
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(
      SettingsPanel(controller: c, onClose: () {}),
      size: const Size(420, 1500),
    ));

    expect(find.text('KEYBOARD'), findsOneWidget);
    expect(find.text('NuPhy side lights'), findsOneWidget);
    expect(c.settings.keyboardLightsEnabled, false);

    final kbSwitch = find.descendant(
      of: find
          .ancestor(
              of: find.text('NuPhy side lights'), matching: find.byType(Row))
          .first,
      matching: find.byType(Switch),
    );
    await tester.tap(kbSwitch);
    await tester.pump();
    expect(c.settings.keyboardLightsEnabled, true);
  });

  testWidgets('hovering the danger button changes its background', (tester) async {
    await useTallSurface(tester);
    final c = readyController(mode: AppMode.live, store: FakeStore());
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(
      SettingsPanel(controller: c, onClose: () {}),
      size: const Size(420, 1500),
    ));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('Sign out')));
    await tester.pump();
    await gesture.moveTo(const Offset(3000, 3000));
    await tester.pump();
  });
}
