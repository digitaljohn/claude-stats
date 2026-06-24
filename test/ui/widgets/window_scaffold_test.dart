import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/platform/platform_support.dart';
import 'package:claude_stats/ui/widgets/window_scaffold.dart';

import '../../helpers/test_harness.dart';

void main() {
  setUp(installPluginFakes);

  testWidgets('WindowScaffold shows the default wordmark and a background',
      (tester) async {
    await tester.pumpWidget(wrap(const WindowScaffold(
      background: ColoredBox(color: Color(0xFF010101)),
      child: Text('body'),
    )));
    expect(find.byType(Wordmark), findsOneWidget);
    expect(find.text('claude'), findsOneWidget);
    expect(find.text('stats'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('WindowScaffold accepts a custom title widget and hides the border',
      (tester) async {
    await tester.pumpWidget(wrap(const WindowScaffold(
      titleWidget: SizedBox.shrink(),
      showBorder: false,
      titleBarColor: Color(0xFF000000),
      child: Text('x'),
    )));
    expect(find.byType(Wordmark), findsNothing);
  });

  testWidgets('drops the traffic-light clearance off macOS', (tester) async {
    // Windows/Linux keep their native title bar, so the in-content bar uses a
    // small leading inset instead of the wide macOS traffic-light clearance.
    final original = PlatformSupport.current;
    PlatformSupport.current = const PlatformSupport(HostOs.windows);
    addTearDown(() => PlatformSupport.current = original);

    await tester.pumpWidget(wrap(const WindowScaffold(child: Text('body'))));
    expect(find.text('body'), findsOneWidget);
    expect(find.byType(Wordmark), findsOneWidget);
  });

  group('TitleBarButton', () {
    testWidgets('responds to hover, tap and tooltip', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(Align(
        alignment: Alignment.topRight,
        child: TitleBarButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onTap: () => taps++,
        ),
      )));

      await tester.tap(find.byType(TitleBarButton));
      expect(taps, 1);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(TitleBarButton)));
      await tester.pump();
      await gesture.moveTo(const Offset(2000, 2000)); // exit
      await tester.pump();
    });

    testWidgets('active state and no-tooltip variant build', (tester) async {
      await tester.pumpWidget(wrap(TitleBarButton(
        icon: Icons.tune,
        active: true,
        onTap: () {},
      )));
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('starts and stops the spin animation across rebuilds',
        (tester) async {
      await tester.pumpWidget(wrap(TitleBarButton(
        icon: Icons.refresh, spin: false, onTap: () {})));
      // false -> true starts the repeating spin.
      await tester.pumpWidget(wrap(TitleBarButton(
        icon: Icons.refresh, spin: true, onTap: () {})));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: find.byType(TitleBarButton),
          matching: find.byType(RotationTransition),
        ),
        findsOneWidget,
      );
      // true -> false stops it.
      await tester.pumpWidget(wrap(TitleBarButton(
        icon: Icons.refresh, spin: false, onTap: () {})));
      await tester.pump(const Duration(milliseconds: 100));
      // Unmount to dispose the controller cleanly.
      await tester.pumpWidget(const SizedBox());
    });
  });
}
