import 'dart:convert';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:certigo/app/session_resume_store.dart';
import 'package:certigo/features/quiz/application/quiz_controller.dart';

/// Resumption of a quiz session across an **iOS process death**.
///
/// On iOS a backgrounded app is killed without notice as soon as the system
/// needs memory, so "the app was killed mid-quiz" is the platform's normal
/// behaviour, not an edge case. Two distinct things have to survive it, and
/// only one of them is about comfort:
///
/// 1. **The learner's progress** — position, graded answers, per-item latency.
///    Losing it restarts a twenty-question run from zero.
/// 2. **The `clientAttemptId`** — the server's dedupe key. `QuizService.cs:56`
///    returns the *first* stored result for a known key and never re-grades,
///    and `SyncEngine` collapses queue replays by that key alone. It is
///    therefore the only thing standing between one learner intent and two
///    counted attempts.
///
/// ## Why these tests simulate death instead of rebuilding a widget
///
/// The easy version of this test rebuilds the controller while the previous
/// store object is still reachable in memory — and then it passes even when
/// nothing is ever serialised, because the "restored" value was never encoded
/// at all. `DESIGN.md` §10: *une garde qui ne peut pas échouer est une
/// décoration*.
///
/// So the boundary here is a **`String`**. Everything a second session gets
/// travels through `jsonEncode`/`jsonDecode` in a local variable standing in
/// for bytes on disk; the first session's controller, store, engine and
/// repository are all dropped. Nothing but text crosses. A field that is not
/// serialised cannot survive — which is the property the production
/// `SharedPreferences` store has, and the property a shared in-memory object
/// would silently fake.
///
/// [_ProcessBoundary] additionally refuses to rewrite bytes that were never
/// written, so a test that believes it is exercising restoration cannot pass
/// against a store that persists nothing. That is the reading floor of
/// `docs/GOVERNANCE.md` §7 — *un instrument qui n'a rien lu échoue, au lieu de
/// rendre zéro* — applied to a fixture.
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
      LessonBlock(
        type: BlockType.check,
        conceptId: 'c2',
        check: QuizItem(
          id: 'i2',
          conceptId: 'c2',
          type: ItemType.mcq,
          stem: 'Quel modèle livre une application prête à l’emploi ?',
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

  // Controllers disposed by hand (the "process death") must not be disposed
  // again by the teardown.
  final Set<QuizController> killed = <QuizController>{};

  /// Simulates the process death for one session: the controller is torn down
  /// and nothing of it is reachable afterwards.
  void kill(QuizController controller) {
    killed.add(controller);
    controller.dispose();
  }

  Future<QuizController> session(
    QuizRepository quiz,
    _ProcessBoundary disk, {
    String ownerId = 'user-1',
  }) async {
    final QuizController controller = QuizController(
      lessons: _StubLessonRepository(lesson),
      quiz: quiz,
      trackId: 'az-900',
      lessonId: 'l1',
      resumeStore: disk.store(),
      resumeOwnerId: ownerId,
    );
    addTearDown(() {
      if (!killed.contains(controller)) controller.dispose();
    });
    await pumpEventQueue();
    return controller;
  }

  group('progress survives a process death', () {
    test('position and the un-submitted pick come back', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      QuizController quiz = await session(server.repository, disk);
      quiz.select('a');
      quiz.grade();
      quiz.next();
      quiz.select('b');
      await pumpEventQueue();
      expect(quiz.index, 1, reason: 'the first session really did advance');

      // ---- process death: the controller and its store are dropped; only
      // the bytes in `disk` cross ----
      kill(quiz);
      quiz = await session(server.repository, disk);

      expect(quiz.index, 1, reason: 'position in the series was restored');
      expect(quiz.selectedId, 'b', reason: 'the un-submitted pick was restored');
    });

    test('answers already graded reach the server after the resume', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      QuizController quiz = await session(server.repository, disk);
      quiz.select('a');
      quiz.grade();
      quiz.next();
      await pumpEventQueue();
      kill(quiz);

      // The resumed session only answers the SECOND question, so the first
      // one's answer can only come from the restored record.
      quiz = await session(server.repository, disk);
      quiz.select('b');
      quiz.grade();
      await quiz.submit();

      expect(server.requests, hasLength(1));
      final Map<String, List<String>> sent = <String, List<String>>{
        for (final QuizAnswer a in server.requests.single.answers) a.itemId: a.selected,
      };
      expect(sent['i1'], <String>['a'], reason: 'the pre-death answer survived');
      expect(sent['i2'], <String>['b']);
    });

    test('a session that was merely opened writes nothing', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      await session(server.repository, disk);

      expect(
        disk.bytes,
        isNull,
        reason: 'an untouched quiz must not leave a resume record behind',
      );
    });

    test('a demo run is never persisted', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      final QuizController demo = QuizController(
        lessons: _FailingLessonRepository(),
        quiz: server.repository,
        trackId: 'az-900',
        lessonId: 'l1',
        resumeStore: disk.store(),
        resumeOwnerId: 'user-1',
      );
      addTearDown(demo.dispose);
      await pumpEventQueue();
      demo.startDemo();
      demo.select(demo.current.item.options.first.id);
      demo.grade();
      demo.next();
      await pumpEventQueue();

      expect(demo.isDemo, isTrue, reason: 'the fixture really is on the demo path');
      expect(
        disk.bytes,
        isNull,
        reason: 'bundled demo content is never submitted, so it has no attempt to protect',
      );
    });
  });

  group('the server stays authoritative', () {
    // Same reconciliation vocabulary as the active certification
    // (`active_track_test.dart`): a record is scoped to the context it was
    // written in, and is discarded rather than adapted when that context no
    // longer holds.
    test('another account does not inherit the previous learner’s answers', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      QuizController quiz = await session(server.repository, disk);
      quiz.select('a');
      quiz.grade();
      quiz.next();
      await pumpEventQueue();
      expect(disk.bytes, isNotNull, reason: 'the first learner really did leave a record');
      kill(quiz);

      quiz = await session(server.repository, disk, ownerId: 'user-b');

      expect(quiz.index, 0, reason: 'answers are account-scoped');
      expect(quiz.selectedId, isNull);
    });

    test('a republished lesson discards answers pinned to the previous one', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      final QuizController first = await session(server.repository, disk);
      first.select('a');
      first.grade();
      first.next();
      await pumpEventQueue();
      kill(first);

      // The lesson is republished while the app is dead: item ids in the
      // record may now designate different questions, so replaying them would
      // score the wrong items.
      disk.rewriteField('publicManifestId', 'pm-2');
      final QuizController second = await session(server.repository, disk);

      expect(second.index, 0, reason: 'answers are pinned to a content manifest');
      expect(second.selectedId, isNull);
    });

    test('a record naming an item the lesson no longer has is refused', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      final QuizController first = await session(server.repository, disk);
      first.select('a');
      first.grade();
      first.next();
      await pumpEventQueue();
      kill(first);

      // Same pin, but the answers no longer map onto the items on screen. A
      // record that cannot be accounted for must not be replayed.
      disk.rewriteProgressAnswers(<String, List<String>>{
        'ghost-item': <String>['a'],
      });
      final QuizController second = await session(server.repository, disk);

      expect(second.index, 0);
      expect(second.selectedId, isNull);
    });

    test('a settled submission leaves nothing to resume', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      final QuizController quiz = await session(server.repository, disk);
      quiz.select('a');
      quiz.grade();
      quiz.next();
      quiz.select('b');
      quiz.grade();
      await quiz.submit();
      await pumpEventQueue();

      expect(
        disk.bytes,
        isNull,
        reason: 'the server has ruled; replaying this session would be a second attempt',
      );
    });
  });

  group('one learner intent is one server attempt', () {
    /// The data-integrity half of the lot.
    ///
    /// `SyncEngine` collapses replays **by idempotency key**, and
    /// `OfflineQuizRepository` uses `request.clientAttemptId` as that key, so
    /// the collapse holds exactly as long as the key does. The queue holding a
    /// failed submission is `SharedPreferences`-backed (`bootstrap.dart:105`)
    /// and survives a process death; before this change the key that
    /// de-duplicates it lived in a controller field and did not.
    ///
    /// Server retention is not the limiting factor: the `attempts` container is
    /// declared `DefaultTimeToLive: -1` and `AttemptRecord` carries no per-item
    /// `ttl`, so a key stays dedupe-able indefinitely — a replay after days
    /// offline still collapses.
    test('a queued attempt is not re-counted after the app is killed', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..refuseWith(const NetworkFailure());

      // ---- session 1: answer, submit, lose the network, get queued ----
      SyncEngine engine = disk.engine(server);
      QuizController quiz = await session(
        OfflineQuizRepository(server.repository, engine),
        disk,
      );
      quiz.select('a');
      quiz.grade();
      quiz.next();
      quiz.select('b');
      quiz.grade();
      await quiz.submit();
      await pumpEventQueue();

      expect(server.keysSeen, hasLength(1), reason: 'the attempt reached the repository once');
      expect(disk.queueBytes, isNotNull, reason: 'and it really was queued to disk');

      // ---- process death ----
      kill(quiz);
      await engine.dispose();

      // ---- session 2: the learner comes back and finishes ----
      server.accept(granted);
      engine = disk.engine(server);
      quiz = await session(OfflineQuizRepository(server.repository, engine), disk);
      if (!quiz.graded) {
        quiz.select('b');
        quiz.grade();
      }
      await quiz.submit();
      await pumpEventQueue();

      // ---- and the queue drains the attempt that outlived the crash ----
      await engine.flush();
      await pumpEventQueue();

      expect(
        server.distinctKeys,
        hasLength(1),
        reason: 'one learner intent must reach the server as exactly one attempt; '
            'a second key here is a second attempt, and QuizService scores, '
            'rewards and feeds readiness from it a second time',
      );
    });
  });
}

/// The only thing that crosses a process death: bytes.
///
/// Deliberately **not** one object shared by both sessions. Each [store] call
/// builds a store whose entire knowledge of the past is the string in [bytes],
/// so a field that is never serialised cannot come back.
///
/// The rewrite helpers throw rather than no-op when nothing was ever written,
/// so a test that believes it is exercising restoration cannot quietly assert
/// against an empty fixture.
class _ProcessBoundary {
  String? bytes;
  String? queueBytes;

  SessionResumeStore store() => JsonSessionResumeStore(
        readJson: (ResumeSurface _) => bytes,
        writeJson: (ResumeSurface _, String? json) async => bytes = json,
      );

  SyncEngine engine(_Server server) => SyncEngine(
        store: JsonSyncQueueStore(
          read: () async => queueBytes,
          write: (String json) async => queueBytes = json,
        ),
        sender: server.send,
        ownerIdProvider: () => 'user-1',
      );

  Map<String, dynamic> _decoded() {
    final String? raw = bytes;
    if (raw == null || raw.isEmpty) {
      throw StateError(
        'No resume record was ever persisted — this test would otherwise '
        'assert on a restoration that never happened.',
      );
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  void rewriteField(String field, Object? value) {
    final Map<String, dynamic> json = _decoded();
    json[field] = value;
    bytes = jsonEncode(json);
  }

  void rewriteProgressAnswers(Map<String, List<String>> answers) {
    final Map<String, dynamic> json = _decoded();
    final Map<String, dynamic> progress = json['progress'] as Map<String, dynamic>;
    progress['answers'] = answers;
    bytes = jsonEncode(json);
  }
}

/// Stands in for the backend across BOTH paths a submission can take — the
/// direct repository call and the offline queue replay — so "how many attempts
/// did the server see?" is answerable in one place.
class _Server {
  final List<String> keysSeen = <String>[];
  final List<SubmitQuizRequest> requests = <SubmitQuizRequest>[];
  Result<SubmitQuizResult>? _outcome;

  Set<String> get distinctKeys => keysSeen.toSet();

  QuizRepository get repository => _ServerQuizRepository(this);

  void refuseWith(Failure failure) => _outcome = Err<SubmitQuizResult>(failure);

  void accept(SubmitQuizResult result) => _outcome = Success<SubmitQuizResult>(result);

  Result<SubmitQuizResult> receive(SubmitQuizRequest request) {
    keysSeen.add(request.clientAttemptId);
    requests.add(request);
    return _outcome ?? const Err<SubmitQuizResult>(UnknownFailure('no scripted outcome'));
  }

  Future<SyncDispatch> send(SyncAction action) async {
    keysSeen.add(action.idempotencyKey);
    return SyncDispatch.success;
  }
}

class _ServerQuizRepository implements QuizRepository {
  _ServerQuizRepository(this._server);

  final _Server _server;

  @override
  Future<Result<SubmitQuizResult>> submit({
    required String lessonId,
    required SubmitQuizRequest request,
  }) async =>
      _server.receive(request);
}

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

class _FailingLessonRepository implements LessonRepository {
  @override
  Future<Result<Lesson>> getLesson({
    required String trackId,
    required String lessonId,
  }) async =>
      const Err<Lesson>(NetworkFailure());
}
