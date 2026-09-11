import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// A control names its own action.
///
/// [PrismStatusView] used to hardcode [Icons.refresh_rounded] on its action
/// button for every caller, so a status view offering "Voir la bibliothèque"
/// rendered that label beside a refresh glyph. The label said "go somewhere",
/// the glyph said "try again", and the glyph is read first.
///
/// Only [PrismStatusView.error] actually retries, so only it carries refresh.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(theme: PrismTheme.light(), home: Scaffold(body: child)),
    );
    await tester.pump();
  }

  testWidgets('the error state keeps its refresh glyph', (WidgetTester tester) async {
    await pump(tester, PrismStatusView.error(onRetry: () {}));

    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets('a navigating action shows no refresh glyph', (WidgetTester tester) async {
    await pump(
      tester,
      PrismStatusView(
        icon: Icons.school_outlined,
        title: 'Aucune certification sélectionnée',
        message: 'Choisis un parcours publié.',
        actionLabel: 'Voir la bibliothèque',
        onAction: () {},
      ),
    );

    expect(find.text('Voir la bibliothèque'), findsOneWidget);
    expect(
      find.byIcon(Icons.refresh_rounded),
      findsNothing,
      reason: 'this action navigates, it does not retry',
    );
  });

  testWidgets('an action may name itself with its own glyph', (WidgetTester tester) async {
    await pump(
      tester,
      PrismStatusView(
        icon: Icons.school_outlined,
        title: 'Aucune certification sélectionnée',
        actionLabel: 'Voir la bibliothèque',
        actionIcon: Icons.local_library_rounded,
        onAction: () {},
      ),
    );

    expect(find.byIcon(Icons.local_library_rounded), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
  });

  testWidgets('the empty state carries no glyph unless asked', (WidgetTester tester) async {
    await pump(
      tester,
      PrismStatusView.empty(
        title: 'Pas encore de ligue',
        actionLabel: 'Commencer une leçon',
        onAction: () {},
      ),
    );

    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
  });
}
