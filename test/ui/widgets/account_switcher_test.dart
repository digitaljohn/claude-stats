import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_stats/models/account.dart';
import 'package:claude_stats/ui/widgets/account_switcher.dart';

import '../../helpers/test_harness.dart';

void main() {
  setUp(() async {
    installPluginFakes();
    await loadTestFonts();
  });

  const accounts = [
    Account(id: 'personal', name: 'Personal'), // person glyph
    Account(id: 'team', name: 'Acme', type: 'team'), // groups glyph
    Account(id: 'ent', name: 'BigCo', type: 'enterprise'), // business glyph
  ];

  test('accountIcon maps each org kind to a glyph', () {
    expect(accountIcon(const Account(id: '1', name: 'a')), Icons.person_outline);
    expect(accountIcon(const Account(id: '1', name: 'a', type: 'team')),
        Icons.groups_outlined);
    expect(accountIcon(const Account(id: '1', name: 'a', type: 'enterprise')),
        Icons.business_outlined);
  });

  testWidgets('renders nothing when there are no accounts', (tester) async {
    await tester.pumpWidget(wrap(
      AccountSwitcher(accounts: const [], activeId: null, onSelect: (_) {}),
    ));
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('shows the active org and switches on selection', (tester) async {
    String? picked;
    await tester.pumpWidget(wrap(
      AccountSwitcher(
        accounts: accounts,
        activeId: 'team',
        onSelect: (id) => picked = id,
      ),
    ));

    // Anchor shows the active org + its plan label + the dropdown affordance.
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('TEAM'), findsOneWidget); // SectionLabel upper-cases
    expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);

    // Open the menu.
    await tester.tap(find.byType(AccountSwitcher));
    await tester.pumpAndSettle();
    expect(find.text('Personal'), findsWidgets);
    expect(find.text('BigCo'), findsWidgets);
    // Exactly the active row is checked.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    // Pick a different org.
    await tester.tap(find.text('Personal').last);
    await tester.pumpAndSettle();
    expect(picked, 'personal');
  });

  testWidgets('falls back to the first org when activeId is unknown',
      (tester) async {
    await tester.pumpWidget(wrap(
      AccountSwitcher(
        accounts: accounts,
        activeId: 'ghost',
        onSelect: (_) {},
      ),
    ));
    // The anchor shows the first account rather than rendering blank.
    expect(find.text('Personal'), findsOneWidget);
  });
}
