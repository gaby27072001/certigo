import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Smoke tests for the Prism design system primitives.
///
/// These run in CI (`ci-mobile`) without a backend or network. They assert that
/// the core glass-inspired components build and render their content, which is
/// the cheapest guard against a broken design-system API.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: PrismTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('PrismButton renders its label and fires onPressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        PrismButton(
          label: 'Continuer',
          onPressed: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Continuer'), findsOneWidget);

    await tester.tap(find.byType(PrismButton));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('GlassSurface composes and shows its child', (tester) async {
    await tester.pumpWidget(
      host(
        const GlassSurface(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Readiness'),
          ),
        ),
      ),
    );

    expect(find.byType(GlassSurface), findsOneWidget);
    expect(find.text('Readiness'), findsOneWidget);
  });

  testWidgets('ReadinessGauge renders its score', (tester) async {
    await tester.pumpWidget(host(const ReadinessGauge(score: 72)));

    expect(find.byType(ReadinessGauge), findsOneWidget);
    expect(find.textContaining('72'), findsOneWidget);
  });

  testWidgets('PrismProgressBar builds and settles', (tester) async {
    await tester.pumpWidget(host(const PrismProgressBar(value: 0.5)));
    await tester.pumpAndSettle();

    expect(find.byType(PrismProgressBar), findsOneWidget);
  });

  testWidgets('StreakBadge shows the day count', (tester) async {
    await tester.pumpWidget(host(const StreakBadge(days: 12)));

    expect(find.byType(StreakBadge), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('XpChip abbreviates large totals', (tester) async {
    await tester.pumpWidget(host(const XpChip(xp: 2500)));

    expect(find.byType(XpChip), findsOneWidget);
    expect(find.text('2.5k'), findsOneWidget);
  });

  testWidgets('LessonTile renders and taps when available', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        LessonTile(
          title: 'Modèles de service cloud',
          status: LessonTileStatus.available,
          minutes: 4,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Modèles de service cloud'), findsOneWidget);

    await tester.tap(find.byType(LessonTile));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('LessonTile ignores taps when locked', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        LessonTile(
          title: 'Gouvernance Azure',
          status: LessonTileStatus.locked,
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(LessonTile));
    await tester.pump();
    expect(tapped, isFalse);
  });
}
