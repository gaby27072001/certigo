import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:cortex/cortex.dart';
import 'package:data/data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/content/runtime_content_providers.dart';
import '../../../app/session_resume_store.dart';
import 'answer_grading.dart';
import 'check_outcome.dart';
import 'lesson_args.dart';
import 'lesson_feedback.dart';
import 'lesson_resume.dart';
import 'lesson_session_state.dart';
import 'lesson_step.dart';
import 'sample_lesson.dart';

/// Drives one lesson-playing session as a small state machine:
/// load → (read content · answer checks) → submit → result.
///
/// Grading is injected via a [LessonGrader] seam. Server or genuinely cached
/// content remains synchronizable; bundled content is confined to explicit demo
/// mode and never reaches the submission repository.
class LessonController extends StateNotifier<LessonSessionState> {
  LessonController({
    required this._lessons,
    required this._quiz,
    required this.args,
    this._feedback = const HapticLessonFeedback(),
    RuntimeContentPinRegistry? contentPins,
    String? contentOwnerId,
    SessionResumeStore? resumeStore,
    String? resumeOwnerId,
  })  : // Keep the optional dependency source-compatible with direct controller tests.
        // ignore: prefer_initializing_formals
        _contentPins = contentPins,
        // ignore: prefer_initializing_formals
        _contentOwnerId = contentOwnerId,
        // Same reason: the store and its owner stay ordinary named parameters
        // so a controller test can inject them directly.
        // ignore: prefer_initializing_formals
        _resumeStore = resumeStore,
        // ignore: prefer_initializing_formals
        _resumeOwnerId = resumeOwnerId,
        super(const LessonSessionState()) {
    unawaited(load());
  }

  final LessonRepository _lessons;
  final QuizRepository _quiz;
  final LessonFeedback _feedback;
  final RuntimeContentPinRegistry? _contentPins;
  final String? _contentOwnerId;

  /// Where an interrupted session is kept so it can be resumed after the app
  /// is killed. Absent in compositions that have not opted in, in which case
  /// the controller behaves exactly as before.
  final SessionResumeStore? _resumeStore;
  final String? _resumeOwnerId;
  final LessonArgs args;

  LessonGrader _grader = const EmbeddedKeyGrader(<String, CheckOutcome>{});

  /// Server dedupe key for this session.
  ///
  /// Not `final`: a resumed session adopts the key its interrupted predecessor
  /// had already claimed, so the submission resolves to the SAME server-side
  /// attempt. `QuizService.cs:56` returns the first stored result for a known
  /// key, and `SyncEngine` collapses queue replays by that key alone — so a
  /// freshly minted key here would be counted as a second attempt, scored and
  /// rewarded again.
  String _clientAttemptId = _generateAttemptId();
  DateTime _startedAt = DateTime.now().toUtc();
  DateTime _stepShownAt = DateTime.now();
  bool _disposed = false;
  RuntimeContentPin? _contentPin;

  /// Fetches server or genuinely cached content. A failure stays visible until
  /// retry or an explicit [startDemo] action.
  Future<void> load() async {
    state = state.copyWith(status: LessonStatus.loading);
    final Result<Lesson> res = await _lessons.getLesson(
      trackId: args.trackId,
      lessonId: args.lessonId,
    );
    if (_disposed) return;

    final Lesson? lesson = res.when(
      success: (Lesson remote) {
        _contentPin?.release();
        _contentPin = _contentPins?.pin(
          remote.publicManifestId,
          ownerId: _contentOwnerId,
        );
        // Server content is graded server-side; no embedded answer key.
        _grader = const EmbeddedKeyGrader(<String, CheckOutcome>{});
        return remote;
      },
      failure: (Failure _) {
        _contentPin?.release();
        _contentPin = null;
        return null;
      },
    );

    if (lesson == null) {
      state = state.copyWith(
        status: LessonStatus.error,
        errorMessage: 'Le contenu est indisponible. Réessaie ou lance la démo.',
      );
      return;
    }

    final List<QuizItem?> checks = lesson.blocks
        .where((LessonBlock block) => block.type == BlockType.check)
        .map((LessonBlock block) => block.check)
        .toList();
    if (lesson.blocks.isEmpty ||
        checks.isEmpty ||
        checks.any((QuizItem? check) => check == null || !isAnswerableCheck(check))) {
      state = state.copyWith(
        status: LessonStatus.error,
        errorMessage: 'Le contenu est indisponible. Réessaie ou lance la démo.',
      );
      return;
    }

    final List<LessonStep> steps = buildLessonSteps(lesson);
    state = state.copyWith(
      status: LessonStatus.ready,
      lesson: lesson,
      steps: steps,
      index: 0,
      selection: const <String>[],
      isDemo: false,
      pendingSync: false,
      submissionFailed: false,
    );
    _stepShownAt = DateTime.now();
    _restoreInterruptedSession();
  }

  void startDemo() {
    if (state.status != LessonStatus.error) return;
    final Lesson lesson = sampleLesson('certigo-demo');
    _contentPin?.release();
    _contentPin = null;
    _grader = EmbeddedKeyGrader(sampleAnswerKey());
    state = state.copyWith(
      status: LessonStatus.ready,
      lesson: lesson,
      steps: buildLessonSteps(lesson),
      index: 0,
      selection: const <String>[],
      isDemo: true,
      pendingSync: false,
      submissionFailed: false,
    );
    _stepShownAt = DateTime.now();
    // Demo runs are never submitted and never rewarded, so there is nothing
    // for the server to reconcile and nothing worth outliving the process.
    _discardResume();
  }

  /// Toggle an option for the current check.
  ///
  /// Semantics are type-aware but all funnel into the one `selection` list:
  /// * multi — order-free set toggle;
  /// * ordering / applied / cloze — **ordered** place/remove (the order is the
  ///   answer), capped at the number of slots so we never over-fill;
  /// * mcq / scenario / spotTheIssue — single replace.
  void toggleOption(String optionId) {
    final QuizItem? item = state.currentItem;
    if (item == null || state.currentAnswered) return;
    final List<String> next = List<String>.from(state.selection);
    switch (item.type) {
      case ItemType.multi:
        if (next.contains(optionId)) {
          next.remove(optionId);
        } else {
          next.add(optionId);
        }
      case ItemType.ordering:
      case ItemType.applied:
      case ItemType.cloze:
        if (next.contains(optionId)) {
          next.remove(optionId);
        } else {
          final int cap =
              item.type == ItemType.cloze ? clozeBlankCount(item.stem) : item.options.length;
          if (next.length < cap) next.add(optionId);
        }
      case ItemType.mcq:
      case ItemType.scenario:
      case ItemType.spotTheIssue:
      case ItemType.matchPairs:
      case ItemType.unknown:
        next
          ..clear()
          ..add(optionId);
    }
    state = state.copyWith(selection: next);
    _persistResume();
  }

  /// Toggle a `matchPairs` connection between a left [leftId] and right
  /// [rightId]. The selection is a set of canonical `"left:right"` tokens; each
  /// left and each right may appear at most once, so re-pairing either side
  /// first releases its previous link.
  void toggleMatch(String leftId, String rightId) {
    final QuizItem? item = state.currentItem;
    if (item == null || state.currentAnswered) return;
    final String token = matchToken(leftId, rightId);
    final List<String> next = List<String>.from(state.selection);
    if (next.contains(token)) {
      next.remove(token);
    } else {
      next
        ..removeWhere((String t) => t.startsWith('$leftId:'))
        ..removeWhere((String t) => t.endsWith(':$rightId'))
        ..add(token);
    }
    state = state.copyWith(selection: next);
    _persistResume();
  }

  /// Grade the current check and reveal feedback in place.
  void submitCheck() {
    final QuizItem? item = state.currentItem;
    if (item == null || !state.canSubmitCurrent) return;

    final int latencyMs = DateTime.now().difference(_stepShownAt).inMilliseconds;
    final List<String> selected = List<String>.unmodifiable(state.selection);
    final CheckOutcome outcome = _grader.grade(
      itemId: item.id,
      selected: selected,
      type: item.type,
    );

    _feedback.graded(correct: outcome.correct);

    state = state.copyWith(
      status: LessonStatus.graded,
      answers: <String, List<String>>{...state.answers, item.id: selected},
      latencies: <String, int>{...state.latencies, item.id: latencyMs},
      outcomes: <String, CheckOutcome>{...state.outcomes, item.id: outcome},
    );
    _persistResume();
  }

  /// Advance to the next step. When the next step is the result, submit first.
  Future<void> advance() async {
    if (state.nextIsResult) {
      await _finishAndSubmit();
      return;
    }
    final int next = state.index + 1;
    if (next >= state.steps.length) return;
    state = state.copyWith(status: LessonStatus.ready, index: next, selection: const <String>[]);
    _stepShownAt = DateTime.now();
    _persistResume();
  }

  Future<void> _finishAndSubmit() async {
    final Lesson? lesson = state.lesson;
    if (lesson == null) return;
    state = state.copyWith(status: LessonStatus.submitting);

    final List<QuizAnswer> answers = <QuizAnswer>[];
    for (final LessonStep step in state.steps) {
      final QuizItem? item = step.item;
      if (!step.isCheck || item == null) continue;
      answers.add(
        QuizAnswer(
          itemId: item.id,
          type: item.type,
          selected: state.answers[item.id] ?? const <String>[],
          latencyMs: state.latencies[item.id] ?? 0,
        ),
      );
    }

    if (state.isDemo) {
      _feedback.completed();
      state = state.copyWith(
        status: LessonStatus.finished,
        index: state.steps.length - 1,
        result: _localDemoResult(lesson, answers),
        pendingSync: false,
      );
      return;
    }

    // Put the key on disk BEFORE the request leaves. If the process dies while
    // the submission is in flight, the server may already have counted this
    // attempt; the next session has to present the same key rather than mint a
    // second one.
    await _writeResume();

    late final Result<SubmitQuizResult> res;
    try {
      res = await _quiz.submit(
        lessonId: args.lessonId,
        request: SubmitQuizRequest(
          clientAttemptId: _clientAttemptId,
          trackId: args.trackId,
          startedAt: _startedAt,
          answers: answers,
          publicManifestId: lesson.publicManifestId,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (_disposed) return;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'certigo.lesson',
          context: ErrorDescription('while submitting a lesson attempt'),
        ),
      );
      state = state.copyWith(
        status: LessonStatus.finished,
        index: state.steps.length - 1,
        result: _pendingResult(),
        pendingSync: false,
        submissionFailed: true,
      );
      return;
    }
    if (_disposed) return;

    final Failure? failure = res.when(
      success: (SubmitQuizResult _) => null,
      failure: (Failure failure) => failure,
    );
    final bool pendingSync = failure != null && classifyFailure(failure) == SyncDispatch.retryable;
    final bool submissionFailed = failure != null && !pendingSync;
    final SubmitQuizResult result = res.valueOrNull ?? _pendingResult();
    if (!pendingSync) {
      // The server has ruled: this session is over and must not be replayed
      // into a second attempt. A queued one is deliberately kept — its key is
      // the only thing that will collapse the replay with whatever the learner
      // does next.
      _discardResume();
    }
    _feedback.completed();
    state = state.copyWith(
      status: LessonStatus.finished,
      index: state.steps.length - 1,
      result: result,
      pendingSync: pendingSync,
      submissionFailed: submissionFailed,
    );
  }

  SubmitQuizResult _localDemoResult(Lesson lesson, List<QuizAnswer> answers) {
    final List<ItemResult> results = <ItemResult>[];
    final List<String> weak = <String>[];
    int correctCount = 0;

    for (final QuizAnswer answer in answers) {
      final CheckOutcome outcome = state.outcomes[answer.itemId] ?? CheckOutcome.empty;
      final ReviewGrade grade = gradeFromAnswer(
        correct: outcome.correct,
        latencyMs: answer.latencyMs,
      );
      final double masteryDelta = switch (grade) {
        ReviewGrade.again => -0.08,
        ReviewGrade.hard => 0.04,
        ReviewGrade.good => 0.10,
        ReviewGrade.easy => 0.16,
      };
      final String conceptId = _conceptForItem(lesson, answer.itemId);
      if (outcome.correct) {
        correctCount++;
      } else {
        weak.add(conceptId);
      }
      results.add(
        ItemResult(
          itemId: answer.itemId,
          conceptId: conceptId,
          correct: outcome.correct,
          correctAnswer: outcome.correctAnswer,
          explanation: outcome.explanation,
          masteryDelta: masteryDelta,
        ),
      );
    }

    final int total = results.length;
    final int scorePct = total == 0 ? 100 : ((correctCount / total) * 100).round();
    return SubmitQuizResult(
      attemptId: 'demo-$_clientAttemptId',
      scorePct: scorePct,
      results: results,
      rewards: const QuizRewards(
        xpEarned: 0,
        newXp: 0,
        levelUp: false,
        streakExtended: false,
        gemsEarned: 0,
        achievementsUnlocked: <String>[],
      ),
      weakConcepts: weak,
    );
  }

  SubmitQuizResult _pendingResult() {
    return SubmitQuizResult(
      attemptId: 'pending-$_clientAttemptId',
      scorePct: 0,
      results: const <ItemResult>[],
      rewards: const QuizRewards(
        xpEarned: 0,
        newXp: 0,
        levelUp: false,
        streakExtended: false,
        gemsEarned: 0,
        achievementsUnlocked: <String>[],
      ),
      weakConcepts: const <String>[],
    );
  }

  String _conceptForItem(Lesson lesson, String itemId) {
    for (final LessonBlock block in lesson.blocks) {
      if (block.check?.id == itemId) return block.check!.conceptId;
    }
    return '';
  }

  static String _generateAttemptId() {
    final int micros = DateTime.now().microsecondsSinceEpoch;
    final int rand = Random().nextInt(0x7fffffff);
    return '${micros.toRadixString(16)}-${rand.toRadixString(16)}';
  }

  // --- interrupted-session handling -------------------------------------
  //
  // Same shape as the quiz, and deliberately the same store: iOS kills a
  // backgrounded app without notice, and the attempt key has to outlive that
  // or one learner intent becomes two counted attempts. See
  // [SessionResumeRecord].

  ResumeSurface get _surface => ResumeSurface.lesson;

  String get _sessionId => '${args.trackId}/${args.lessonId}';

  bool get _canResume =>
      _resumeStore != null && (_resumeOwnerId != null && _resumeOwnerId.isNotEmpty);

  List<String> get _checkItemIds => <String>[
        for (final LessonStep step in state.steps)
          if (step.isCheck && step.item != null) step.item!.id,
      ];

  /// Replays an interrupted session, if one was left in exactly this context.
  ///
  /// Called once the steps are known, because a record can only be trusted
  /// against the content it was captured on: a republished lesson may reuse
  /// item ids for different questions.
  void _restoreInterruptedSession() {
    final SessionResumeStore? store = _resumeStore;
    if (!_canResume || store == null || state.isDemo || state.steps.isEmpty) return;

    final SessionResumeRecord? record = store.read(_surface);
    if (record == null) return;
    if (!record.matches(
      surface: _surface,
      ownerId: _resumeOwnerId!,
      sessionId: _sessionId,
      publicManifestId: state.lesson?.publicManifestId,
    )) {
      // Another account, another lesson, or content republished since.
      // Dropping is the safe direction; adapting would be a guess.
      _discardResume();
      return;
    }

    final LessonResumeProgress? progress = LessonResumeProgress.fromJson(record.progress);
    if (progress == null || !progress.fits(itemIds: _checkItemIds, stepCount: state.steps.length)) {
      _discardResume();
      return;
    }

    // Outcomes are derived, not stored: replaying the restored answers through
    // the session's own grader reproduces exactly what the interrupted session
    // held, and cannot contradict the answer it came from.
    final Map<String, CheckOutcome> outcomes = <String, CheckOutcome>{};
    for (final LessonStep step in state.steps) {
      final QuizItem? item = step.item;
      if (!step.isCheck || item == null) continue;
      final List<String>? selected = progress.answers[item.id];
      if (selected == null) continue;
      outcomes[item.id] = _grader.grade(
        itemId: item.id,
        selected: selected,
        type: item.type,
      );
    }

    state = state.copyWith(
      // A restored step whose check is already answered is a graded step; the
      // dock reads this to show feedback instead of an unanswered prompt.
      status: outcomes.containsKey(state.steps[progress.index].item?.id)
          ? LessonStatus.graded
          : LessonStatus.ready,
      index: progress.index,
      selection: progress.selection,
      answers: progress.answers,
      latencies: progress.latencies,
      outcomes: outcomes,
    );
    // The key the interrupted session had already claimed. Reusing it is what
    // makes a resumed submission the SAME server attempt rather than a second.
    _clientAttemptId = record.clientAttemptId;
    _startedAt = record.startedAt;
    _stepShownAt = DateTime.now();
  }

  /// Persists the session without blocking the interaction that triggered it.
  void _persistResume() => unawaited(_writeResume());

  Future<void> _writeResume() async {
    final SessionResumeStore? store = _resumeStore;
    if (!_canResume || store == null || state.isDemo || state.steps.isEmpty) return;
    final LessonResumeProgress progress = LessonResumeProgress(
      index: state.index,
      selection: state.selection,
      answers: state.answers,
      latencies: state.latencies,
    );
    if (!progress.isWorthResuming) return;

    await store.write(
      SessionResumeRecord(
        surface: _surface,
        ownerId: _resumeOwnerId!,
        sessionId: _sessionId,
        publicManifestId: state.lesson?.publicManifestId,
        clientAttemptId: _clientAttemptId,
        startedAt: _startedAt,
        progress: progress.toJson(),
      ),
    );
  }

  void _discardResume() {
    final SessionResumeStore? store = _resumeStore;
    if (store == null) return;
    unawaited(store.clear(_surface));
  }

  @override
  void dispose() {
    _disposed = true;
    _contentPin?.release();
    super.dispose();
  }
}

/// Family provider keyed by [LessonArgs]; auto-disposed so leaving a lesson
/// resets its session.
final lessonControllerProvider = StateNotifierProvider.autoDispose
    .family<LessonController, LessonSessionState, LessonArgs>((Ref ref, LessonArgs args) {
  return LessonController(
    lessons: ref.watch(lessonRepositoryProvider),
    quiz: ref.watch(quizRepositoryProvider),
    args: args,
    feedback: ref.watch(lessonFeedbackProvider),
    contentPins: ref.watch(runtimeContentPinRegistryProvider),
    contentOwnerId: ref.watch(activeTrackOwnerIdProvider),
    resumeStore: ref.watch(sessionResumeStoreProvider),
    resumeOwnerId: ref.watch(activeTrackOwnerIdProvider),
  );
});
