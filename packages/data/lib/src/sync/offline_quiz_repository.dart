import 'package:core/core.dart';

import '../models/quiz.dart';
import '../repositories/repositories.dart';
import 'sync_dispatcher.dart';
import 'sync_engine.dart';

/// Action kind for a queued quiz submission.
const String kQuizSubmitKind = 'quizSubmit';

/// A [QuizRepository] decorator that makes lesson submission offline-durable.
///
/// It delegates to the real [_inner] repository. On success it returns the
/// authoritative server result unchanged. On a *transient* failure it enqueues
/// the submission in the [SyncEngine] (keyed by `clientAttemptId`, which the
/// backend uses to dedupe) and still returns the original failure — so the
/// lesson UI falls back to its locally-computed result and the learner is never
/// blocked. When connectivity returns, the engine replays the submission and
/// the server reconciles XP/streak/gems exactly once.
///
/// Permanent failures (e.g. 404 unknown lesson) are NOT queued: replaying them
/// could never succeed.
class OfflineQuizRepository implements QuizRepository {
  OfflineQuizRepository(this._inner, this._engine);

  final QuizRepository _inner;
  final SyncEngine _engine;

  @override
  Future<Result<SubmitQuizResult>> submit({
    required String lessonId,
    required SubmitQuizRequest request,
  }) async {
    final String? ownerId = _engine.currentOwnerId;
    final Result<SubmitQuizResult> result = await _inner.submit(
      lessonId: lessonId,
      request: request,
    );

    if (result.isSuccess) return result;

    final Failure failure = (result as Err<SubmitQuizResult>).failure;
    if (ownerId != null && classifyFailure(failure) == SyncDispatch.retryable) {
      await _engine.enqueue(
        kind: kQuizSubmitKind,
        endpoint: '/quiz/$lessonId/submit',
        payload: request.toJson(),
        idempotencyKey: request.clientAttemptId,
        ownerId: ownerId,
        publicManifestId: request.publicManifestId,
      );
    }

    return result;
  }
}
