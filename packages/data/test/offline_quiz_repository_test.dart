import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:test/test.dart';

/// A [QuizRepository] stub that always returns a scripted [Result].
class _ScriptedQuiz implements QuizRepository {
  _ScriptedQuiz(this.result);

  final Result<SubmitQuizResult> result;

  @override
  Future<Result<SubmitQuizResult>> submit({
    required String lessonId,
    required SubmitQuizRequest request,
  }) async =>
      result;
}

SubmitQuizRequest _request(String key) => SubmitQuizRequest(
      clientAttemptId: key,
      trackId: 'az-900',
      startedAt: DateTime.utc(2026),
      answers: const <QuizAnswer>[],
    );

Future<SyncDispatch> _alwaysSucceed(SyncAction _) async => SyncDispatch.success;

SyncEngine _engine({SyncSender? sender}) => SyncEngine(
      store: InMemorySyncQueueStore(),
      sender: sender ?? _alwaysSucceed,
    );

void main() {
  group('OfflineQuizRepository', () {
    test('a successful submission is returned unchanged and never queued', () async {
      final SubmitQuizResult ok = SubmitQuizResult.fromJson(<String, dynamic>{'attemptId': 'x'});
      final _ScriptedQuiz inner = _ScriptedQuiz(Success<SubmitQuizResult>(ok));
      final SyncEngine engine = _engine();
      final OfflineQuizRepository repo = OfflineQuizRepository(inner, engine);

      final Result<SubmitQuizResult> result =
          await repo.submit(lessonId: 'L1', request: _request('k1'));

      expect(result.isSuccess, isTrue);
      expect(engine.pendingCount, 0);
      await engine.dispose();
    });

    test('a transient failure is returned AND queued, keyed by clientAttemptId', () async {
      final _ScriptedQuiz inner = _ScriptedQuiz(const Err<SubmitQuizResult>(NetworkFailure()));
      final SyncEngine engine = _engine();
      final OfflineQuizRepository repo = OfflineQuizRepository(inner, engine);

      final Result<SubmitQuizResult> result =
          await repo.submit(lessonId: 'L1', request: _request('k1'));

      expect(result.isFailure, isTrue);
      expect(engine.pendingCount, 1);

      final SyncAction queued = engine.actions.single;
      expect(queued.kind, kQuizSubmitKind);
      expect(queued.endpoint, '/quiz/L1/submit');
      expect(queued.idempotencyKey, 'k1');
      expect(queued.payload['clientAttemptId'], 'k1');
      await engine.dispose();
    });

    test('a permanent failure is returned but NOT queued', () async {
      final _ScriptedQuiz inner = _ScriptedQuiz(const Err<SubmitQuizResult>(NotFoundFailure()));
      final SyncEngine engine = _engine();
      final OfflineQuizRepository repo = OfflineQuizRepository(inner, engine);

      final Result<SubmitQuizResult> result =
          await repo.submit(lessonId: 'L1', request: _request('k1'));

      expect(result.isFailure, isTrue);
      expect(engine.pendingCount, 0);
      await engine.dispose();
    });

    test('re-submitting the same attempt after a transient failure dedupes', () async {
      final _ScriptedQuiz inner = _ScriptedQuiz(const Err<SubmitQuizResult>(NetworkFailure()));
      final SyncEngine engine = _engine();
      final OfflineQuizRepository repo = OfflineQuizRepository(inner, engine);

      await repo.submit(lessonId: 'L1', request: _request('k1'));
      await repo.submit(lessonId: 'L1', request: _request('k1'));

      expect(engine.pendingCount, 1);
      await engine.dispose();
    });

    test('the engine replays a queued submission to success on reconnect', () async {
      final _ScriptedQuiz inner = _ScriptedQuiz(const Err<SubmitQuizResult>(NetworkFailure()));
      final List<SyncAction> sent = <SyncAction>[];
      final SyncEngine engine = _engine(
        sender: (SyncAction a) async {
          sent.add(a);
          return SyncDispatch.success;
        },
      );
      final OfflineQuizRepository repo = OfflineQuizRepository(inner, engine);

      await repo.submit(lessonId: 'L1', request: _request('k1'));
      expect(engine.pendingCount, 1);

      await engine.flush();
      expect(sent.length, 1);
      expect(sent.single.idempotencyKey, 'k1');
      expect(engine.pendingCount, 0);
      await engine.dispose();
    });
  });
}
