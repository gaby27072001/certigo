import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  setUpAll(disableGoogleFontsFetching);

  group('GemCounter', () {
    testWidgets('renders the gem total verbatim under a thousand',
        (WidgetTester tester) async {
      await pumpPrism(tester, const GemCounter(gems: 500));

      expect(find.text('500'), findsOneWidget);
      expect(find.byIcon(Icons.diamond_rounded), findsOneWidget);
    });

    testWidgets('shows a positive delta', (WidgetTester tester) async {
      await pumpPrism(tester, const GemCounter(gems: 500, delta: 5));

      expect(find.text('+5'), findsOneWidget);
    });

    testWidgets('exposes a gems semantics label',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrism(tester, const GemCounter(gems: 500));

      expect(find.bySemanticsLabel(RegExp('500 gemmes')), findsOneWidget);

      handle.dispose();
    });
  });
}
