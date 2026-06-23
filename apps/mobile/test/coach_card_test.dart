import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microlingo/features/home/presentation/coach_section.dart';
import 'package:prism_ui/prism_ui.dart';

/// Widget tests for the AI coach card.
///
/// [CoachCard] is intentionally router-free and presentational, so — like the
/// Prism smoke tests — it pumps without a backend, network or GoRouter. We
/// assert the French kind label, the server-provided reason, the estimated time
/// and urgency affordances render, and that taps fire.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: PrismTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  Recommendation rec({
    RecommendationKind kind = RecommendationKind.review,
    String? lessonId = 'l1',
    String title = 'Révise le stockage Azure',
    String reason = 'Ce concept est dû à la révision.',
    int estMinutes = 5,
    int priority = 80,
    int forgettingRiskPct = 75,
  }) {
    return Recommendation(
      kind: kind,
      lessonId: lessonId,
      unitId: 'u1',
      conceptId: 'c1',
      title: title,
      domainId: 'd1',
      domainName: 'Stockage',
      reason: reason,
      estMinutes: estMinutes,
      priority: priority,
      masteryPct: 40,
      forgettingRiskPct: forgettingRiskPct,
    );
  }

  testWidgets('prominent card shows label, title, reason, time and fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        CoachCard(
          item: rec(),
          prominent: true,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('À RÉVISER'), findsOneWidget);
    expect(find.text('Révise le stockage Azure'), findsOneWidget);
    expect(find.text('Ce concept est dû à la révision.'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    // forgettingRiskPct >= 60 ⇒ urgent affordance.
    expect(find.text('Urgent'), findsOneWidget);

    await tester.tap(find.byType(CoachCard));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('secondary card renders title and reason and taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        CoachCard(
          item: rec(kind: RecommendationKind.practice, title: 'Pratique les réseaux'),
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Pratique les réseaux'), findsOneWidget);
    expect(find.text('Ce concept est dû à la révision.'), findsOneWidget);

    await tester.tap(find.byType(CoachCard));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('start kind hides time when estMinutes is zero', (tester) async {
    await tester.pumpWidget(
      host(
        CoachCard(
          item: rec(
            kind: RecommendationKind.start,
            lessonId: null,
            title: 'Démarre un nouveau domaine',
            estMinutes: 0,
            priority: 40,
            forgettingRiskPct: 0,
          ),
          prominent: true,
          onTap: () {},
        ),
      ),
    );

    expect(find.text('DÉMARRER'), findsOneWidget);
    expect(find.text('Démarre un nouveau domaine'), findsOneWidget);
    expect(find.textContaining('min'), findsNothing);
    // Low risk and priority ⇒ gentle "Recommandé" affordance.
    expect(find.text('Recommandé'), findsOneWidget);
  });
}
