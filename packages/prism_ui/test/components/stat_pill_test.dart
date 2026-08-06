import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  group('StatPill', () {
    testWidgets('streak factory shows the day count, flame and semantics',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrism(tester, StatPill.streak(3));

      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Série de 3 jours')), findsOneWidget);

      handle.dispose();
    });

    testWidgets('xp factory abbreviates thousands', (WidgetTester tester) async {
      await pumpPrism(tester, StatPill.xp(1500));

      expect(find.text('1.5k'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    });

    testWidgets('xp factory abbreviates millions', (WidgetTester tester) async {
      await pumpPrism(tester, StatPill.xp(2000000));

      expect(find.text('2.0M'), findsOneWidget);
    });
  });
}
