import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Smoke tests for the playful "Duo kit" onboarding primitives.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: PrismTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('SpeechBubble paints and shows its child', (tester) async {
    await tester.pumpWidget(host(const SpeechBubble(child: Text('Salut !'))));
    expect(find.byType(SpeechBubble), findsOneWidget);
    expect(find.text('Salut !'), findsOneWidget);
  });

  testWidgets('ChoiceTile reflects selection and fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        ChoiceTile(
          title: 'Booster ma carrière',
          leading: const Icon(Icons.rocket_launch_rounded),
          selected: true,
          onTap: () => taps++,
        ),
      ),
    );
    expect(find.text('Booster ma carrière'), findsOneWidget);
    // Selected tile shows the check glyph in its box.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.byType(ChoiceTile));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('OnboardingScaffold disables the CTA when onPrimary is null', (tester) async {
    var fired = false;
    await tester.pumpWidget(
      host(
        const OnboardingScaffold(
          progress: 0.5,
          primaryLabel: 'Continuer',
          onPrimary: null,
          child: Text('Question'),
        ),
      ),
    );
    expect(find.text('Continuer'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    expect(fired, isFalse); // null handler ⇒ no-op
  });

  testWidgets('OnboardingScaffold fires the CTA when enabled', (tester) async {
    var fired = false;
    await tester.pumpWidget(
      host(
        OnboardingScaffold(
          progress: 1,
          primaryLabel: 'JE COMMENCE',
          onPrimary: () => fired = true,
          child: const Text('Prêt'),
        ),
      ),
    );
    await tester.tap(find.text('JE COMMENCE'));
    await tester.pump();
    expect(fired, isTrue);
  });
}
