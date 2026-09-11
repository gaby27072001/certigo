import 'dart:convert';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:certigo/app/session_resume_store.dart';
import 'package:certigo/features/lesson/application/lesson_args.dart';
import 'package:certigo/features/lesson/application/lesson_controller.dart';
import 'package:certigo/features/lesson/application/lesson_feedback.dart';
import 'package:certigo/features/lesson/application/lesson_session_state.dart';

/// Resumption of a lesson session across an **iOS process death**.
///
/// The lesson submits through the same `QuizService` path as the quiz, which
/// dedupes on `clientAttemptId` **and nothing else** (`QuizService.cs:46,56` —
/// both the durable economy operation and the attempt record are keyed by it).
/// A lesson is repeatable by design, so there is no lesson-scoped dedupe layer
/// to fall back on: the key is the only protection, and before this change it
/// lived in a controller field and nowhere else.
///
/// The exam is deliberately NOT given the same treatment — see
/// `exam_resume_is_not_needed_test.dart`, which measures why.
///
/// ## Why these tests simulate death instead of rebuilding a widget
///
/// The boundary here is a **`String`**: everything the second session receives
/// travels through `jsonEncode`/`jsonDecode`, and the first session's
/// controller and store are dropped. A field that is not serialised cannot
/// survive. Sharing one in-memory store between the two sessions would pass
/// even when nothing is ever encoded — `DESIGN.md` §10, *une garde qui ne peut
/// pas échouer est une décoration*.
///
/// ## Why the fixture never assumes the step layout
///
/// `buildLessonSteps` emits `intro → one step per block → result`, so index 0
/// is **not** a check. An earlier version of this file answered index 0,
/// silently did nothing, and still passed its position assertion — a test
/// green for the wrong reason. The helpers below drive the controller through
/// whatever steps it actually has, and [_answeredCheck] fails loudly if it is
/// asked to answer something that is not an answerable check.
void main() {
  const QuizItem itemOne = QuizItem(
    id: 'i1',
    conceptId: 'c1',
    type: ItemType.mcq,
    stem: 'Quel modèle fournit des machines virtuelles ?',
    options: <QuizOption>[
      QuizOption(id: 'a', label: 'IaaS'),
      QuizOption(id: 'b', label: 'SaaS'),
    ],
  );
  const QuizItem itemTwo = QuizItem(
    id: 'i2',
    conceptId: 'c2',
    type: ItemType.mcq,
    stem: 'Quel modèle livre une application prête à l’emploi ?',
    options: <QuizOption>[
      QuizOption(id: 'a', label: 'IaaS'),
      QuizOption(id: 'b', label: 'SaaS'),
    ],
  );

  const Lesson lesson = Lesson(
    id: 'l1',
    trackId: 'az-900',
    unitId: 'u1',
    domainId: 'd1',
    title: 'Modèles de service',
    estMinutes: 3,
    blocks: <LessonBlock>[
      LessonBlock(type: BlockType.check, conceptId: 'c1', check: itemOne),
      LessonBlock(type: BlockType.check, conceptId: 'c2', check: itemTwo),
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

  final Set<LessonController> killed = <LessonController>{};

  /// Simulates the process death for one session.
  void kill(LessonController controller) {
    killed.add(controller);
    controller.dispose();
  }

  Future<LessonController> session(
    QuizRepository quiz,
    _ProcessBoundary disk, {
    String ownerId = 'user-1',
  }) async {
    final LessonController controller = LessonController(
      lessons: _StubLessonRepository(lesson),
      quiz: quiz,
      args: const LessonArgs(trackId: 'az-900', lessonId: 'l1'),
      // The controller defaults to haptics, which reach a platform channel that
      // does not exist in a plain `test()`; the silent seam is what the other
      // lesson tests use.
      feedback: const SilentLessonFeedback(),
      resumeStore: disk.store(),
      resumeOwnerId: ownerId,
    );
    addTearDown(() {
      if (!killed.contains(controller)) controller.dispose();
    });
    await pumpEventQueue();
    return controller;
  }

  /// Advances past any passive step until the player is on an unanswered
  /// check, then returns that check's item.
  Future<QuizItem> reachCheck(LessonController c) async {
    for (int guard = 0; guard < 10; guard++) {
      if (c.state.status == LessonStatus.finished) {
        fail('the run finished before an unanswered check was reached');
      }
      final QuizItem? item = c.state.currentItem;
      if (item != null && !c.state.currentAnswered) return item;
      await c.advance();
      await pumpEventQueue();
    }
    fail('the fixture never reached an unanswered check');
  }

  /// Answers the current check with [pick] and moves on, failing loudly rather
  /// than silently no-op'ing if the player is not on an answerable check.
  Future<void> answerCheck(LessonController c, String pick) async {
    final QuizItem item = await reachCheck(c);
    c.toggleOption(pick);
    expect(
      c.state.canSubmitCurrent,
      isTrue,
      reason: 'option "$pick" did not produce a submittable answer for ${item.id}',
    );
    c.submitCheck();
    await c.advance();
    await pumpEventQueue();
  }

  group('progress survives a process death', () {
    test('position and the un-submitted pick come back', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      LessonController play = await session(server.repository, disk);
      await answerCheck(play, 'a');
      final QuizItem second = await reachCheck(play);
      final int reached = play.state.index;
      play.toggleOption('b');
      await pumpEventQueue();
      expect(second.id, 'i2', reason: 'the fixture really is on the second check');

      // ---- process death: only the bytes in `disk` cross ----
      kill(play);
      play = await session(server.repository, disk);

      expect(play.state.index, reached, reason: 'position in the lesson was restored');
      expect(
        play.state.selection,
        <String>['b'],
        reason: 'the un-submitted pick was restored',
      );
    });

    test('a locked answer stays locked and reaches the server', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      LessonController play = await session(server.repository, disk);
      await answerCheck(play, 'a');
      kill(play);

      play = await session(server.repository, disk);
      expect(
        play.state.answers['i1'],
        <String>['a'],
        reason: 'the locked answer survived the death',
      );
      expect(
        play.state.outcomes.containsKey('i1'),
        isTrue,
        reason: 'outcomes are recomputed from the restored answers rather than stored, '
            'so an answered check comes back answered',
      );

      // The resumed session answers only the SECOND check, so the first one's
      // answer can only reach the server from the restored record.
      await answerCheck(play, 'b');
      await pumpEventQueue();

      expect(server.requests, hasLength(1));
      final Map<String, List<String>> sent = <String, List<String>>{
        for (final QuizAnswer a in server.requests.single.answers) a.itemId: a.selected,
      };
      expect(sent['i1'], <String>['a'], reason: 'the pre-death answer reached the server');
      expect(sent['i2'], <String>['b']);
    });

    test('a lesson that was merely opened writes nothing', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      await session(server.repository, disk);

      expect(disk.bytes, isNull, reason: 'an untouched lesson leaves no record');
    });

    test('a demo run is never persisted', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      final LessonController demo = LessonController(
        lessons: _FailingLessonRepository(),
        quiz: server.repository,
        args: const LessonArgs(trackId: 'az-900', lessonId: 'l1'),
        feedback: const SilentLessonFeedback(),
        resumeStore: disk.store(),
        resumeOwnerId: 'user-1',
      );
      addTearDown(demo.dispose);
      await pumpEventQueue();
      demo.startDemo();
      expect(demo.state.isDemo, isTrue, reason: 'the fixture really is on the demo path');

      final QuizItem item = await reachCheck(demo);
      demo.toggleOption(item.options.first.id);
      demo.submitCheck();
      await demo.advance();
      await pumpEventQueue();

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
    // written in and is discarded, not adapted, when that context is gone.
    test('another account does not inherit the previous learner’s answers', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      LessonController play = await session(server.repository, disk);
      await answerCheck(play, 'a');
      expect(disk.bytes, isNotNull, reason: 'the first learner really did leave a record');
      kill(play);

      play = await session(server.repository, disk, ownerId: 'user-b');

      expect(play.state.answers, isEmpty, reason: 'answers are account-scoped');
      expect(play.state.index, 0);
    });

    test('a republished lesson discards answers pinned to the previous one', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      final LessonController first = await session(server.repository, disk);
      await answerCheck(first, 'a');
      kill(first);

      disk.rewriteField('publicManifestId', 'pm-2');
      final LessonController second = await session(server.repository, disk);

      expect(second.state.answers, isEmpty, reason: 'answers are pinned to a manifest');
      expect(second.state.index, 0);
    });

    test('a record naming an item the lesson no longer has is refused', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      final LessonController first = await session(server.repository, disk);
      await answerCheck(first, 'a');
      kill(first);

      disk.rewriteProgressAnswers(<String, List<String>>{
        'ghost-item': <String>['a'],
      });
      final LessonController second = await session(server.repository, disk);

      expect(second.state.answers, isEmpty);
      expect(second.state.index, 0);
    });

    test('a settled submission leaves nothing to resume', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..accept(granted);

      final LessonController play = await session(server.repository, disk);
      await answerCheck(play, 'a');
      await answerCheck(play, 'b');
      await pumpEventQueue();

      expect(play.state.status, LessonStatus.finished, reason: 'the run really did finish');
      expect(
        disk.bytes,
        isNull,
        reason: 'the server has ruled; replaying this session would be a second attempt',
      );
    });
  });

  group('one learner intent is one server attempt', () {
    /// `SyncEngine` collapses replays **by idempotency key**, and
    /// `OfflineQuizRepository` uses `request.clientAttemptId` as that key, so
    /// the collapse holds exactly as long as the key does. The queue holding a
    /// failed submission is `SharedPreferences`-backed (`bootstrap.dart:105`)
    /// and survives a process death; before this change the key did not.
    ///
    /// Server retention is not the limiting factor: the `attempts` container is
    /// declared `DefaultTimeToLive: -1` and `AttemptRecord` carries no per-item
    /// `ttl`, so a replay after days offline still collapses.
    test('a queued attempt is not re-counted after the app is killed', () async {
      final _ProcessBoundary disk = _ProcessBoundary();
      final _Server server = _Server()..refuseWith(const NetworkFailure());

      // ---- session 1: answer, finish, lose the network, get queued ----
      SyncEngine engine = disk.engine(server);
      LessonController play = await session(
        OfflineQuizRepository(server.repository, engine),
        disk,
      );
      await answerCheck(play, 'a');
      await answerCheck(play, 'b');
      await pumpEventQueue();

      expect(play.state.status, LessonStatus.finished);
      expect(server.keysSeen, hasLength(1), reason: 'the attempt reached the repository once');
      expect(disk.queueBytes, isNotNull, reason: 'and it really was queued to disk');
      expect(
        disk.bytes,
        isNotNull,
        reason: 'a queued attempt keeps its record — the key is what collapses the replay',
      );

      // ---- process death ----
      kill(play);
      await engine.dispose();

      // ---- session 2: the learner comes back and finishes again ----
      // The resumed session finds every check already answered — that is the
      // point — so it only has to tap through to the end and resubmit.
      server.accept(granted);
      engine = disk.engine(server);
      play = await session(OfflineQuizRepository(server.repository, engine), disk);
      for (int guard = 0; play.state.status != LessonStatus.finished; guard++) {
        expect(guard, lessThan(10), reason: 'the resumed run never reached its result');
        final QuizItem? item = play.state.currentItem;
        if (item != null && !play.state.currentAnswered) {
          play.toggleOption(item.options.first.id);
          play.submitCheck();
        }
        await play.advance();
        await pumpEventQueue();
      }

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
/// Deliberately **not** one object shared by both sessions. The rewrite helpers
/// throw rather than no-op when nothing was ever written, so a test that
/// believes it is exercising restoration cannot quietly assert against an empty
/// fixture.
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
/// direct repository call and the offline queue replay.
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
