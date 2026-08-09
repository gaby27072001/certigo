import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

/// Smoke tests for the Part-2 onboarding primitives added to the "Duo kit":
/// [TypewriterText], [RecommendedOptionCard] and [SignalBars].
void main() {
  group('TypewriterText', () {
    testWidgets('reveals the full string once the animation settles', (WidgetTester tester) async {
      await pumpPrism(tester, const TypewriterText('Salut, moi c\'est Nimbus !'));
      await tester.pumpAndSettle();
      expect(find.text('Salut, moi c\'est Nimbus !'), findsWidgets);
    });

    testWidgets('renders the full string instantly under reduced-motion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Theme(
              data: ThemeData(extensions: <ThemeExtension<dynamic>>[PrismColorScheme.light]),
              child: const Scaffold(body: TypewriterText('Bonjour')),
            ),
          ),
        ),
      );
      await tester.pump();
      // No timers pending: the reduced-motion path shows everything at once.
      expect(find.text('Bonjour'), findsWidgets);
    });

    testWidgets('fires onComplete', (WidgetTester tester) async {
      var done = false;
      await pumpPrism(tester, TypewriterText('Hi', onComplete: () => done = true));
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });
  });

  group('RecommendedOptionCard', () {
    testWidgets('shows the badge when recommended and fires onTap', (WidgetTester tester) async {
      var taps = 0;
      await pumpPrism(
        tester,
        RecommendedOptionCard(
          title: 'Certigo Premium',
          subtitle: 'Leçons illimitées',
          recommended: true,
          onTap: () => taps++,
        ),
      );
      expect(find.text('Certigo Premium'), findsOneWidget);
      expect(find.text('RECOMMANDÉ'), findsOneWidget);

      await tester.tap(find.text('Certigo Premium'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('hides the badge when not recommended', (WidgetTester tester) async {
      await pumpPrism(tester, const RecommendedOptionCard(title: 'Gratuit'));
      expect(find.text('RECOMMANDÉ'), findsNothing);
    });
  });

  group('SignalBars', () {
    testWidgets('paints without exception', (WidgetTester tester) async {
      await pumpPrism(tester, const SignalBars(level: 2, color: Color(0xFF0078D4)));
      expect(find.byType(SignalBars), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
