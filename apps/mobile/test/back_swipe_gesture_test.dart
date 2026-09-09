import 'package:certigo/app/step_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Vérifie que le geste iOS de retour par balayage depuis le bord gauche
/// dépile bien la route sommet, **et** qu'il reste inerte quand la pile est
/// vidée (protection des flux « en cours » comme `/quiz`, `/lesson`, `/exam`
/// qui sont atteints par `context.go(...)`).
///
/// Contrat de test : les deux cas s'appuient sur la vraie `stepPage` de
/// production (pas un miroir). Le test 1 échoue si `stepPage` renvoie un
/// `CustomTransitionPage` au lieu d'un `CupertinoPage` — c'est la
/// discrimination demandée par le mandat.
void main() {
  group('geste iOS de retour par balayage depuis le bord', () {
    GoRouter buildRouter() => GoRouter(
          initialLocation: '/a',
          routes: <RouteBase>[
            GoRoute(
              path: '/a',
              pageBuilder: (_, GoRouterState state) => stepPage(
                state: state,
                child: const Scaffold(body: Center(child: Text('ECRAN A'))),
              ),
            ),
            GoRoute(
              path: '/b',
              pageBuilder: (_, GoRouterState state) => stepPage(
                state: state,
                child: const Scaffold(body: Center(child: Text('ECRAN B'))),
              ),
            ),
          ],
        );

    Future<void> swipeFromLeftEdge(WidgetTester tester) async {
      final TestGesture gesture = await tester.startGesture(const Offset(2, 300));
      await gesture.moveBy(const Offset(400, 0));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    /// Sans cet override, `defaultTargetPlatform` vaut `TargetPlatform.android`
    /// dans un test lancé sur Windows/Linux/macOS et `stepPage` renverrait
    /// `CustomTransitionPage` — le test resterait vert sans le correctif et ne
    /// discriminerait rien. Le reset doit intervenir AVANT que le body du test
    /// se termine (le vérificateur d'invariants tourne avant `tearDown`) — d'où
    /// le pattern try/finally dans chaque test.
    Future<void> runOnIos(
      Future<void> Function() body,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    testWidgets(
      "empile A→B via push, puis un balayage depuis le bord ramène A",
      (WidgetTester tester) async {
        await runOnIos(() async {
          final GoRouter router = buildRouter();
          await tester.pumpWidget(MaterialApp.router(routerConfig: router));
          await tester.pumpAndSettle();
          expect(find.text('ECRAN A'), findsOneWidget);

          // Empiler B au-dessus de A (comme /register/name → /register/email).
          router.push('/b');
          await tester.pumpAndSettle();
          expect(find.text('ECRAN B'), findsOneWidget);

          await swipeFromLeftEdge(tester);

          expect(
            find.text('ECRAN A'),
            findsOneWidget,
            reason: 'Le geste de retour par balayage doit dépiler B et rendre A visible.',
          );
          expect(find.text('ECRAN B'), findsNothing);
        });
      },
    );

    testWidgets(
      "va A→B via go (pile vidée), le balayage ne fait rien — non-régression /quiz",
      (WidgetTester tester) async {
        await runOnIos(() async {
          final GoRouter router = buildRouter();
          await tester.pumpWidget(MaterialApp.router(routerConfig: router));
          await tester.pumpAndSettle();

          // Aller sur B via .go — remplace la pile, canPop() sera false. C'est
          // le mécanisme utilisé aujourd'hui par /lesson, /quiz, /exam.
          router.go('/b');
          await tester.pumpAndSettle();
          expect(find.text('ECRAN B'), findsOneWidget);

          await swipeFromLeftEdge(tester);

          expect(
            find.text('ECRAN B'),
            findsOneWidget,
            reason: 'Sans pile empilée, le geste doit être inerte : pas de perte silencieuse.',
          );
          expect(find.text('ECRAN A'), findsNothing);
        });
      },
    );
  });
}
