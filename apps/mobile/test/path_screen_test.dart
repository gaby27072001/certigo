import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microlingo/app/providers.dart';
import 'package:microlingo/features/path/presentation/path_screen.dart';
import 'package:prism_ui/prism_ui.dart';

/// A [PathRepository] that returns a fixed, in-memory path so the Duolingo
/// journey can be rendered with no backend or network in CI.
class _FakePathRepo implements PathRepository {
  _FakePathRepo(this.path);

  final LearningPath path;

  @override
  Future<Result<LearningPath>> getPath(String trackId) async => Success(path);
}

LearningPath _samplePath() => const LearningPath(
      trackId: 'az-900',
      trackName: 'Azure Fundamentals',
      exam: 'AZ-900',
      readinessScore: 62,
      readinessTrend7d: 5,
      domains: <DomainProgress>[
        DomainProgress(id: 'd1', name: 'Cloud concepts', weight: 0.3, score: 80),
        DomainProgress(id: 'd2', name: 'Architecture', weight: 0.7, score: 40),
      ],
      units: <PathUnit>[
        // A fully completed chapter → validated checkpoint.
        PathUnit(
          id: 'u1',
          title: 'Notions du cloud',
          domainId: 'd1',
          status: NodeStatus.completed,
          lessons: <PathLesson>[
            PathLesson(
              id: 'l1',
              title: 'CapEx vs OpEx',
              status: NodeStatus.completed,
              estMinutes: 5,
              masteryPct: 100,
            ),
            PathLesson(
              id: 'l2',
              title: 'Modèles de service',
              status: NodeStatus.mastered,
              estMinutes: 6,
              masteryPct: 100,
            ),
          ],
        ),
        // An in-progress chapter → the first available lesson is the current
        // CTA, and the chapter checkpoint stays locked.
        PathUnit(
          id: 'u2',
          title: 'Architecture Azure',
          domainId: 'd2',
          status: NodeStatus.inProgress,
          lessons: <PathLesson>[
            PathLesson(
              id: 'l3',
              title: 'Régions et zones',
              status: NodeStatus.available,
              estMinutes: 7,
              masteryPct: 0,
            ),
            PathLesson(
              id: 'l4',
              title: 'Groupes de ressources',
              status: NodeStatus.locked,
              estMinutes: 5,
              masteryPct: 0,
            ),
          ],
        ),
      ],
    );

Widget _host(LearningPath path) {
  return ProviderScope(
    overrides: <Override>[
      pathRepositoryProvider.overrideWithValue(_FakePathRepo(path)),
    ],
    child: MaterialApp(
      theme: PrismTheme.light(),
      home: Builder(
        builder: (BuildContext context) {
          // Disable animations so the active-node pulse controller stays idle
          // (no repeating timer) and the test is deterministic.
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const Scaffold(body: PathScreen(trackId: 'az-900')),
          );
        },
      ),
    ),
  );
}

void main() {
  testWidgets('renders the Duolingo journey with chapters, CTA and checkpoints',
      (WidgetTester tester) async {
    // Give the test a tall viewport so every sliver in the lazy CustomScrollView
    // is laid out (the active "COMMENCER" node lives in the second chapter,
    // below the default 800x600 fold). We deliberately do NOT reset the size in
    // a tearDown: a teardown-time relayout would rebuild the active node while
    // the tree is deactivated and spin up a ticker against a dead ancestor.
    await tester.binding.setSurfaceSize(const Size(1200, 3000));

    await tester.pumpWidget(_host(_samplePath()));
    // Resolve the FutureProvider (loading → data).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Chapter banners for each unit.
    expect(find.text('CHAPITRE 1'), findsOneWidget);
    expect(find.text('CHAPITRE 2'), findsOneWidget);

    // The single next-actionable lesson shows the start CTA.
    expect(find.text('COMMENCER'), findsOneWidget);

    // Per-chapter validation: first chapter validated, second still locked.
    expect(find.text('Chapitre validé'), findsOneWidget);
    expect(find.text('Validation du chapitre'), findsOneWidget);

    // Track header.
    expect(find.text('Azure Fundamentals'), findsOneWidget);
  });

  testWidgets('shows a retry state when the path fails to load', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          pathRepositoryProvider.overrideWithValue(_FailingPathRepo()),
        ],
        child: MaterialApp(
          theme: PrismTheme.light(),
          home: const Scaffold(body: PathScreen(trackId: 'az-900')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Réessayer'), findsOneWidget);
  });
}

/// A repository that always fails, to exercise the error/retry branch.
class _FailingPathRepo implements PathRepository {
  @override
  Future<Result<LearningPath>> getPath(String trackId) async =>
      const Err<LearningPath>(NetworkFailure('offline'));
}
