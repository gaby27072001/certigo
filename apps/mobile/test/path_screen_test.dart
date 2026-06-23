import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:microlingo/app/providers.dart';
import 'package:microlingo/features/path/presentation/path_screen.dart';
import 'package:prism_ui/prism_ui.dart';

/// Widget tests for the winding [PathScreen].
///
/// The screen lives inside the app shell and reads its data from
/// [pathProvider]; here we override that provider with a deterministic fake
/// path and host the screen under a tiny two-route [GoRouter] (the path itself
/// plus a lesson probe) so we can assert it renders the serpentine trail and
/// that the giant "CONTINUER" CTA and the lesson bubbles route to the right
/// lesson. We never call [WidgetTester.pumpAndSettle] because the active node
/// runs a looping bounce animation that would never settle.
void main() {
  LearningPath fakePath() => const LearningPath(
        trackId: 'az-900',
        trackName: 'Fondamentaux Azure',
        exam: 'Examen AZ-900',
        readinessScore: 72,
        readinessTrend7d: 5,
        units: <PathUnit>[
          PathUnit(
            id: 'u1',
            title: 'Concepts du cloud',
            domainId: 'd1',
            status: NodeStatus.inProgress,
            lessons: <PathLesson>[
              PathLesson(
                id: 'l1',
                title: 'Le cloud',
                status: NodeStatus.completed,
                estMinutes: 5,
                masteryPct: 100,
              ),
              PathLesson(
                id: 'l2',
                title: 'Modèles de service',
                status: NodeStatus.inProgress,
                estMinutes: 5,
                masteryPct: 40,
              ),
              PathLesson(
                id: 'l3',
                title: 'Avantages',
                status: NodeStatus.available,
                estMinutes: 5,
                masteryPct: 0,
              ),
            ],
          ),
          PathUnit(
            id: 'u2',
            title: 'Gouvernance',
            domainId: 'd2',
            status: NodeStatus.locked,
            lessons: <PathLesson>[
              PathLesson(
                id: 'l4',
                title: 'Maîtrise des coûts',
                status: NodeStatus.locked,
                estMinutes: 5,
                masteryPct: 0,
              ),
            ],
          ),
        ],
        domains: <DomainProgress>[
          DomainProgress(id: 'd1', name: 'Concepts cloud', weight: 0.3, score: 70),
          DomainProgress(id: 'd2', name: 'Gouvernance et conformité', weight: 0.3, score: 40),
        ],
      );

  Future<void> pumpPath(WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/path',
      routes: <RouteBase>[
        GoRoute(
          path: '/path',
          builder: (BuildContext context, GoRouterState state) =>
              const PathScreen(trackId: 'az-900'),
        ),
        GoRoute(
          path: '/lesson/:trackId/:lessonId',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(child: Text('LEÇON ${state.pathParameters['lessonId']}')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          pathProvider('az-900').overrideWith((Ref ref) async => fakePath()),
        ],
        child: MaterialApp.router(
          theme: PrismTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    // Resolve the async provider, then advance one short frame so the first
    // build of the trail is laid out — without settling the looping bounce.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('renders the track header, unit headers and lesson bubbles', (tester) async {
    await pumpPath(tester);

    expect(find.text('Fondamentaux Azure'), findsOneWidget);
    expect(find.text('UNITÉ 1'), findsOneWidget);
    expect(find.text('Concepts du cloud'), findsOneWidget);
    expect(find.text('Le cloud'), findsOneWidget);
    // CTA reflects the in-progress active lesson.
    expect(find.text('CONTINUER'), findsOneWidget);
    expect(find.byType(PathNode), findsWidgets);
  });

  testWidgets('the CONTINUER CTA routes to the active lesson', (tester) async {
    await pumpPath(tester);

    await tester.tap(find.text('CONTINUER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('LEÇON l2'), findsOneWidget);
  });

  testWidgets('tapping a lesson bubble routes to that lesson', (tester) async {
    await pumpPath(tester);

    // The first, completed lesson ("Le cloud") wears the check icon; tap it.
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('LEÇON l1'), findsOneWidget);
  });
}
