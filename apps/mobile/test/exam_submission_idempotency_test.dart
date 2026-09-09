import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:certigo/app/providers.dart';
import 'package:certigo/features/auth/application/auth_controller.dart'
    show authConfiguredProvider, authRequiredProvider, sessionStoreProvider;
import 'package:certigo/features/auth/application/auth_state.dart' show AuthSession;
import 'package:certigo/features/auth/application/session_store.dart';
import 'package:certigo/features/exam/presentation/exam_screen.dart';
import 'package:prism_ui/prism_ui.dart';

/// Idempotency of mock-exam submissions through [ExamScreen].
///
/// The server dedupes on `clientAttemptId` (`ExamService.cs:178` calls
/// `examAttempts.GetByClientAttemptIdAsync` and returns `prior.Result` when
/// a matching record already exists), so the *client* owns the guarantee.
/// A retry after a transport failure — where the server may have already
/// counted the exam attempt — has to replay the same key, otherwise the
/// same exam is booked twice against the learner's history and the
/// readiness score is inflated by that duplicate.
///
/// These tests drive the real [ExamScreen] through the real
/// `examRepositoryProvider` seam and assert on the [SubmitMockExamRequest]s
/// that actually reach the repository. The fixture uses the shape that
/// backend `ExamService.GenerateAsync` emits — a track-scoped [MockExam]
/// with a blueprint domain and a single MCQ item — so the test cannot pass
/// against a payload the server never sends.
///
/// Note on "success then new attempt": once the server accepts an exam,
/// `_ExamRunnerState` sets `_result` and its build switches to the result
/// view; the "Refaire un examen" flow calls `ref.invalidate(examProvider)`,
/// which returns the async to loading and unmounts the runner entirely,
/// re-mounting it fresh on the next data event. The key being released on
/// success is therefore enforced structurally — every subsequent attempt
/// runs against a brand-new state — and cannot be discriminated by a
/// widget-level test.
void main() {
  MockExam fakeExam() => const MockExam(
        examId: 'exam-1',
        trackId: 'az-900',
        trackCode: 'AZ-900',
        trackTitle: 'Fondamentaux Azure',
        timeLimitSeconds: 3600,
        passingScore: 700,
        blueprint: <MockExamBlueprintDomain>[
          MockExamBlueprintDomain(
            domainId: 'd1',
            name: 'Concepts du cloud',
            weight: 0.3,
            itemCount: 1,
          ),
        ],
        items: <MockExamItem>[
          MockExamItem(
            itemId: 'i1',
            lessonId: 'l1',
            domainId: 'd1',
            type: ItemType.mcq,
            stem: 'Quel modèle de service fournit des machines virtuelles ?',
            options: <QuizOption>[
              QuizOption(id: 'a', label: 'IaaS'),
              QuizOption(id: 'b', label: 'SaaS'),
            ],
          ),
        ],
      );

  const MockExamResult granted = MockExamResult(
    attemptId: 'server-exam-attempt-1',
    examId: 'exam-1',
    scaledScore: 800,
    pct: 100,
    passed: true,
    passingScore: 700,
    correct: 1,
    total: 1,
    domains: <ExamDomainScore>[],
    results: <ItemResult>[],
    rewards: QuizRewards(
      xpEarned: 40,
      newXp: 40,
      levelUp: false,
      streakExtended: false,
      gemsEarned: 0,
      achievementsUnlocked: <String>[],
    ),
    weakConcepts: <String>[],
  );

  Future<void> pumpExam(WidgetTester tester, _RecordingExamRepository repo) async {
    final GoRouter router = GoRouter(
      initialLocation: '/exam',
      routes: <RouteBase>[
        GoRoute(
          path: '/exam',
          builder: (BuildContext context, GoRouterState state) => const ExamScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          examProvider.overrideWith((Ref ref) async => fakeExam()),
          examRepositoryProvider.overrideWith((Ref ref) => repo),
          // Keep the auth chain inert so ExamScreen's read of
          // activeTrackProvider (which lives behind AuthController → session
          // storage) doesn't leave secure-storage timers hanging in the test
          // and doesn't require real credentials.
          sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
          authConfiguredProvider.overrideWithValue(false),
          authRequiredProvider.overrideWithValue(false),
        ],
        child: MaterialApp.router(theme: PrismTheme.light(), routerConfig: router),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.tap(find.text('Soumettre'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a retried exam submission after a transport failure replays the same key',
      (tester) async {
    final _RecordingExamRepository repo = _RecordingExamRepository()
      ..enqueue(const Err<MockExamResult>(NetworkFailure()))
      ..enqueue(const Success<MockExamResult>(granted));

    await pumpExam(tester, repo);
    await tapSubmit(tester);
    await tapSubmit(tester);

    // The exam may already have been counted server-side when the transport
    // failed, so the retry has to resolve to that same operation. Minting a
    // new key here is a second attempt — and it inflates the readiness
    // score by counting that same exam twice.
    expect(repo.requests, hasLength(2));
    expect(repo.requests[1].clientAttemptId, repo.requests[0].clientAttemptId);
  });

  testWidgets('a permanent server refusal then a new submission use different keys',
      (tester) async {
    // ServerFailure with a 4xx status is classified as SyncDispatch.permanent
    // (see sync_dispatcher.dart) — a server ruling, not an unknown transport.
    final _RecordingExamRepository repo = _RecordingExamRepository()
      ..enqueue(const Err<MockExamResult>(ServerFailure('bad request', statusCode: 400)))
      ..enqueue(const Success<MockExamResult>(granted));

    await pumpExam(tester, repo);
    await tapSubmit(tester);
    await tapSubmit(tester);

    // A refusal is a decision, not an unknown: the key is spent, so the
    // deliberate retry starts a fresh one.
    expect(repo.requests, hasLength(2));
    expect(repo.requests[1].clientAttemptId, isNot(repo.requests[0].clientAttemptId));
  });
}

/// Records every [SubmitMockExamRequest] the screen issues and replays a
/// scripted sequence of outcomes, so the assertions are about the keys the
/// screen actually sends rather than about its internal state.
class _RecordingExamRepository implements ExamRepository {
  final List<SubmitMockExamRequest> requests = <SubmitMockExamRequest>[];
  final List<Result<MockExamResult>> _outcomes = <Result<MockExamResult>>[];

  void enqueue(Result<MockExamResult> outcome) => _outcomes.add(outcome);

  @override
  Future<Result<MockExam>> generateExam(MockExamRequest request) async =>
      const Err<MockExam>(UnknownFailure('generateExam is served by examProvider override'));

  @override
  Future<Result<MockExamResult>> submitExam(SubmitMockExamRequest request) async {
    requests.add(request);
    if (_outcomes.isEmpty) {
      return const Err<MockExamResult>(UnknownFailure('no scripted outcome left'));
    }
    return _outcomes.removeAt(0);
  }
}

/// Inert session store — never touches secure storage — so [ExamScreen]'s read
/// of `activeTrackProvider` (which transitively initialises `AuthController`
/// and its `_restore` timers) resolves synchronously in a widget test.
class _FakeSessionStore implements SessionStore {
  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> write(AuthSession session) async {}

  @override
  Future<void> clear() async {}
}
