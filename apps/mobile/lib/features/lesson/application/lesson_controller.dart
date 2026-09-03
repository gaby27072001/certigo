import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:cortex/cortex.dart';
import 'package:data/data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import 'answer_grading.dart';
import 'check_outcome.dart';
import 'lesson_args.dart';
import 'lesson_feedback.dart';
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
  }) : super(const LessonSessionState()) {
    unawaited(load());
  }

  final LessonRepository _lessons;
  final QuizRepository _quiz;
  final LessonFeedback _feedback;
  final LessonArgs args;

  LessonGrader _grader = const EmbeddedKeyGrader(<String, CheckOutcome>{});
  final String _clientAttemptId = _generateAttemptId();
  final DateTime _startedAt = DateTime.now().toUtc();
  DateTime _stepShownAt = DateTime.now();
  bool _disposed = false;

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
        // Server content is graded server-side; no embedded answer key.
        _grader = const EmbeddedKeyGrader(<String, CheckOutcome>{});
        return remote;
      },
      failure: (Failure _) => null,
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
  }

  void startDemo() {
    if (state.status != LessonStatus.error) return;
    final Lesson lesson = sampleLesson('certigo-demo');
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
          final int cap = item.type == ItemType.cloze
              ? clozeBlankCount(item.stem)
              : item.options.length;
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

  @override
  void dispose() {
    _disposed = true;
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
      );
    });
