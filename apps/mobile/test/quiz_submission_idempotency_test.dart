import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:certigo/features/quiz/application/quiz_controller.dart';

/// Idempotency of quiz submissions through [QuizController].
///
/// The server dedupes on `clientAttemptId` (`QuizService.cs:46,56` — the
/// durable economy operation and the attempt record are both keyed by it),
/// so the *client* owns the guarantee: it must replay the same key when it
/// retries, and it must mint a fresh key when the previous outcome was
/// final. Without this, a transport retry inflates the readiness score by
/// double-counting one attempt, or a deliberate second attempt is swallowed
/// as a replay of the first.
///
/// These tests drive [QuizController] with a valid lesson so we hit the real
/// (non-demo) submission path, and assert on the [SubmitQuizRequest]s that
/// actually reach the repository. The fixture uses the shape that the
/// backend `LessonService` emits — one lesson with a single check block, an
/// MCQ item — so the test cannot pass against a payload the server never
/// sends. `NetworkFailure` and `ServerFailure(statusCode: 400)` are the
/// wire-typed failures used by `ApiClient` for a transport error and a
/// permanent server refusal (see `packages/core/lib/src/failures.dart` and
/// `packages/data/lib/src/sync/sync_dispatcher.dart`).
void main() {
  const Lesson lesson = Lesson(
    id: 'l1',
    trackId: 'az-900',
    unitId: 'u1',
    domainId: 'd1',
    title: 'Modèles de service',
    estMinutes: 3,
    blocks: <LessonBlock>[
      LessonBlock(
        type: BlockType.check,
        conceptId: 'c1',
        check: QuizItem(
          id: 'i1',
          conceptId: 'c1',
          type: ItemType.mcq,
          stem: 'Quel modèle fournit des machines virtuelles ?',
          options: <QuizOption>[
            QuizOption(id: 'a', label: 'IaaS'),
            QuizOption(id: 'b', label: 'SaaS'),
          ],
        ),
      ),
    ],
    publicManifestId: 'pm-1',
  );

  const SubmitQuizResult granted = SubmitQuizResult(
    attemptId: 'server-attempt-1',
    scorePct: 100,
    results: <ItemResult>[],
    rewards: QuizRewards(
      xpEarned: 10,
      newXp: 10,
      levelUp: false,
      streakExtended: false,
      gemsEarned: 0,
      achievementsUnlocked: <String>[],
    ),
    weakConcepts: <String>[],
  );

  Future<QuizController> loadedController(
    _RecordingQuizRepository quiz, {
    _StubLessonRepository? lessons,
  }) async {
    final QuizController controller = QuizController(
      lessons: lessons ?? _StubLessonRepository(lesson),
      quiz: quiz,
      trackId: 'az-900',
      lessonId: 'l1',
    );
    addTearDown(controller.dispose);
    // Let the constructor's loadItems() complete.
    await Future<void>.delayed(Duration.zero);
    // Answer the one item so the submission carries at least one answer.
    controller.select('a');
    controller.grade();
    return controller;
  }

  test('a retried submission after a transport failure replays the same key', () async {
    final _RecordingQuizRepository quiz = _RecordingQuizRepository()
      ..enqueue(const Err<SubmitQuizResult>(NetworkFailure()))
      ..enqueue(const Success<SubmitQuizResult>(granted));
    final QuizController controller = await loadedController(quiz);

    await controller.submit();
    await controller.submit();

    // The server may already have applied the attempt when the transport
    // failed, so the retry has to resolve to that same operation. Minting
    // a new key here is a second attempt — and it feeds the readiness
    // score a second time.
    expect(quiz.requests, hasLength(2));
    expect(quiz.requests[1].clientAttemptId, quiz.requests[0].clientAttemptId);
  });

  test('an accepted submission then a deliberate new one use different keys', () async {
    final _RecordingQuizRepository quiz = _RecordingQuizRepository()
      ..enqueue(const Success<SubmitQuizResult>(granted))
      ..enqueue(const Success<SubmitQuizResult>(granted));
    final QuizController controller = await loadedController(quiz);

    await controller.submit();
    await controller.submit();

    // Otherwise a deliberate next attempt is swallowed as a replay of the
    // first and the second submission returns the first attempt's rewards.
    expect(quiz.requests, hasLength(2));
    expect(quiz.requests[1].clientAttemptId, isNot(quiz.requests[0].clientAttemptId));
  });

  test('a permanent server refusal then a new submission use different keys', () async {
    // ServerFailure with a 4xx status is classified as SyncDispatch.permanent
    // (see sync_dispatcher.dart) — a server ruling, not an unknown transport.
    final _RecordingQuizRepository quiz = _RecordingQuizRepository()
      ..enqueue(const Err<SubmitQuizResult>(ServerFailure('bad request', statusCode: 400)))
      ..enqueue(const Success<SubmitQuizResult>(granted));
    final QuizController controller = await loadedController(quiz);

    await controller.submit();
    await controller.submit();

    // A permanent refusal is a decision, not an unknown: the key is spent.
    expect(quiz.requests, hasLength(2));
    expect(quiz.requests[1].clientAttemptId, isNot(quiz.requests[0].clientAttemptId));
  });
}

/// Serves a canned [Lesson] to the controller so we're on the real (non-demo)
/// submission path.
class _StubLessonRepository implements LessonRepository {
  _StubLessonRepository(this._lesson);

  final Lesson _lesson;

  @override
  Future<Result<Lesson>> getLesson({
    required String trackId,
    required String lessonId,
  }) async =>
      Success<Lesson>(_lesson);
}

/// Records every [SubmitQuizRequest] the controller issues and replays a
/// scripted sequence of outcomes, so the assertions are about the keys the
/// controller actually sends rather than about its internal state.
class _RecordingQuizRepository implements QuizRepository {
  final List<SubmitQuizRequest> requests = <SubmitQuizRequest>[];
  final List<Result<SubmitQuizResult>> _outcomes = <Result<SubmitQuizResult>>[];

  void enqueue(Result<SubmitQuizResult> outcome) => _outcomes.add(outcome);

  @override
  Future<Result<SubmitQuizResult>> submit({
    required String lessonId,
    required SubmitQuizRequest request,
  }) async {
    requests.add(request);
    if (_outcomes.isEmpty) {
      return const Err<SubmitQuizResult>(UnknownFailure('no scripted outcome left'));
    }
    return _outcomes.removeAt(0);
  }
}
