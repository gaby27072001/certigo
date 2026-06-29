import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  setUpAll(disableGoogleFontsFetching);

  group('XpChip', () {
    testWidgets('abbreviates large totals', (WidgetTester tester) async {
      await pumpPrism(tester, const XpChip(xp: 1200));

      expect(find.text('1.2k'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    });

    testWidgets('shows a positive delta', (WidgetTester tester) async {
      await pumpPrism(tester, const XpChip(xp: 1200, delta: 30));

      expect(find.text('+30'), findsOneWidget);
    });

    testWidgets('hides the delta when null', (WidgetTester tester) async {
      await pumpPrism(tester, const XpChip(xp: 1200));

      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('exposes an experience semantics label', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrism(tester, const XpChip(xp: 1200));

      expect(
        find.bySemanticsLabel(RegExp("1200 points d'expérience")),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
