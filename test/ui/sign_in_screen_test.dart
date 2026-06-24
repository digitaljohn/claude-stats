import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/platform/platform_support.dart';
import 'package:claude_stats/state/app_controller.dart';
import 'package:claude_stats/ui/sign_in_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/test_harness.dart';

void main() {
  setUp(() async {
    installPluginFakes();
    await loadTestFonts();
  });

  testWidgets('renders the connect card and enters demo mode', (tester) async {
    final c = readyController(mode: AppMode.signedOut);
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(SignInScreen(controller: c)));

    expect(find.text('CONNECT'), findsOneWidget);
    expect(find.text('Log in with Claude'), findsOneWidget);

    await tester.tap(find.text('Try demo data'));
    await tester.pump();
    expect(c.mode, AppMode.demo);
  });

  testWidgets('reveals + hides the paste section and toggles obscure',
      (tester) async {
    final c = readyController(mode: AppMode.signedOut);
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(SignInScreen(controller: c)));

    await tester.tap(find.text('Paste a key instead'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Connect with key'), findsOneWidget);

    // Toggle the obscure-text eye.
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // Hide it again.
    await tester.tap(find.text('Hide'));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('connects with a pasted key (button + submit)', (tester) async {
    final c = readyController(mode: AppMode.signedOut, api: FakeApi()..orgId = 'o');
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(SignInScreen(controller: c)));

    await tester.tap(find.text('Paste a key instead'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'sk-pasted');
    await tester.tap(find.text('Connect with key'));
    await tester.pump();
    // signIn drove the controller live.
    await tester.pump();
    expect(c.mode, AppMode.live);

    await c.signOut(); // cancel the auto-refresh timer signIn started
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('submitting the field also connects', (tester) async {
    final c = readyController(mode: AppMode.signedOut, api: FakeApi()..orgId = 'o');
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(SignInScreen(controller: c)));
    await tester.tap(find.text('Paste a key instead'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'sk-2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(c.mode, AppMode.live);
    await c.signOut(); // cancel the auto-refresh timer signIn started
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows the busy state and an error box', (tester) async {
    final c = readyController(mode: AppMode.signedOut);
    c.signingIn = true;
    c.signInError = 'Session rejected (401).';
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(SignInScreen(controller: c)));

    expect(find.text('Verifying…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.textContaining('Session rejected'), findsOneWidget);
  });

  testWidgets('browser-fallback sign-in when there is no embedded webview',
      (tester) async {
    final original = PlatformSupport.current;
    PlatformSupport.current = const PlatformSupport(HostOs.linux);
    addTearDown(() => PlatformSupport.current = original);

    final opened = <Uri>[];
    final c = readyController(
      mode: AppMode.signedOut,
      urlLauncher: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(SignInScreen(controller: c)));

    // The embedded-login CTA is replaced by a browser launcher, and the paste
    // field stands in for the cookie capture — shown up-front, no reveal toggle.
    expect(find.text('Open claude.ai'), findsOneWidget);
    expect(find.text('Log in with Claude'), findsNothing);
    expect(find.text('Paste a key instead'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('Open claude.ai'));
    await tester.pump();
    expect(opened.single.toString(), 'https://claude.ai/login');
  });

  testWidgets('hover states on the primary and ghost buttons', (tester) async {
    final c = readyController(mode: AppMode.signedOut);
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(SignInScreen(controller: c)));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('Log in with Claude')));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('Try demo data')));
    await tester.pump();
    await gesture.moveTo(const Offset(3000, 3000));
    await tester.pump();
  });
}
