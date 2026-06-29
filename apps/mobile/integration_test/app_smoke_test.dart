import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:certigo/main.dart' as app;

/// Launch-level smoke tests for the real mobile entrypoint.
///
/// We deliberately avoid `pumpAndSettle`: the auth and Prism backgrounds keep
/// subtle animations alive forever, so integration tests advance with a few
/// short, deterministic pumps just like the existing widget tests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(WidgetTester tester) async {
    await app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('signed-out launch lands on the sign-in form', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Microlingo'), findsOneWidget);
    expect(find.byKey(const Key('email-field')), findsOneWidget);
    expect(find.byKey(const Key('password-field')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Se connecter'), findsOneWidget);
  });

  testWidgets('sign-in screen can switch into registration mode', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('toggle-mode')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('name-field')), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Créer un compte'),
      findsOneWidget,
    );
  });
}
