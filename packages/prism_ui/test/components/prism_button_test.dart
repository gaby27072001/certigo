import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
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
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrism(
        tester,
        PrismButton(label: 'Chargement', onPressed: () => taps++, loading: true),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Chargement, chargement'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byType(PrismButton))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );

      await tester.tap(find.byType(PrismButton), warnIfMissed: false);
      await tester.pump();

      expect(taps, 0);
      handle.dispose();
    });

    testWidgets('exposes one label and the disabled state without an onPressed', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrism(tester, const PrismButton(label: 'Indispo'));

      expect(find.bySemanticsLabel('Indispo'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byType(PrismButton))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );
      expect(find.text('Indispo'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('exposes one actionable label when enabled', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrism(tester, PrismButton(label: 'Continuer', onPressed: () {}));

      expect(find.bySemanticsLabel('Continuer'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byType(PrismButton))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );

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
