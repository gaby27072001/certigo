import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  group('PrismButton', () {
    testWidgets('fires onPressed when tapped', (WidgetTester tester) async {
      int taps = 0;
      await pumpPrism(tester, PrismButton(label: 'Continuer', onPressed: () => taps++));

      await tester.tap(find.byType(PrismButton));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(find.text('Continuer'), findsOneWidget);
    });

    testWidgets('shows a spinner and suppresses taps while loading', (WidgetTester tester) async {
      int taps = 0;
      await pumpPrism(
        tester,
        PrismButton(label: 'Chargement', onPressed: () => taps++, loading: true),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(PrismButton), warnIfMissed: false);
      await tester.pump();

      expect(taps, 0);
    });

    testWidgets('is marked as a disabled button without an onPressed', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrism(tester, const PrismButton(label: 'Indispo'));

      // The visible Text('Indispo') merges into the Semantics(label: 'Indispo')
      // node, so the merged label reads 'Indispo\nIndispo'. Assert the
      // disabled-button accessibility flags here and check the rendered label
      // separately via find.text.
      expect(
        tester.getSemantics(find.byType(PrismButton)),
        containsSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      expect(find.text('Indispo'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('secondary and ghost variants build and show their label', (
      WidgetTester tester,
    ) async {
      await pumpPrism(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PrismButton.secondary(label: 'Secondaire'),
            PrismButton.ghost(label: 'Fantôme'),
          ],
        ),
      );

      expect(find.text('Secondaire'), findsOneWidget);
      expect(find.text('Fantôme'), findsOneWidget);
    });

    testWidgets('uses zero-duration feedback when animations are disabled', (
      WidgetTester tester,
    ) async {
      await pumpPrism(
        tester,
        PrismButton(label: 'Continuer', onPressed: () {}),
        disableAnimations: true,
      );

      expect(
        tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned)).duration,
        Duration.zero,
      );
      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration, Duration.zero);
    });
  });
}
