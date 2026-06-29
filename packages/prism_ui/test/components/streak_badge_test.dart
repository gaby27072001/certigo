import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  setUpAll(disableGoogleFontsFetching);

  group('StreakBadge', () {
    testWidgets('renders the day count with a flame',
        (WidgetTester tester) async {
      await pumpPrism(tester, const StreakBadge(days: 7));

      expect(find.text('7'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    });

    testWidgets('active streak has a plain semantics label',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrism(tester, const StreakBadge(days: 7));

      expect(find.bySemanticsLabel(RegExp('Série de 7 jours')), findsOneWidget);

      handle.dispose();
    });

    testWidgets('inactive streak nudges the user to secure today',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrism(tester, const StreakBadge(days: 7, active: false));

      expect(find.bySemanticsLabel(RegExp('à sécuriser')), findsOneWidget);

      handle.dispose();
    });
  });
}
