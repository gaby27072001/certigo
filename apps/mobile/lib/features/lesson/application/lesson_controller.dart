import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:cortex/cortex.dart';
import 'package:data/data.dart';
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
/// Grading is injected via a [LessonGrader] seam: P0 grades offline with an
/// [EmbeddedKeyGrader] over [sampleLesson]; P1 swaps to server grading with no
/// UI change. The optimistic FSRS [ReviewGrade] is computed with the shared
/// `cortex` package so client and backend mastery never diverge.
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

  /// Fetch the lesson; fall back to bundled sample content (with its answer key)
  /// when the backend is unreachable, so the player always runs.
  Future<void> load() async {
    state = state.copyWith(status: LessonStatus.loading);
    final Result<Lesson> res = await _lessons.getLesson(
      trackId: args.trackId,
      lessonId: args.lessonId,
    );

    final Lesson lesson = res.when(
      success: (Lesson remote) {
        // Server content is graded server-side; no embedded answer key.
        _grader = const EmbeddedKeyGrader(<String, CheckOutcome>{});
        return remote;
      },
      failure: (Failure _) {
        // Offline skeleton: bundled lesson + its key for local grading.
        _grader = EmbeddedKeyGrader(sampleAnswerKey());
        return sampleLesson(args.lessonId);
      },
    );

    state = state.copyWith(
      status: LessonStatus.ready,
      lesson: lesson,
      steps: buildLessonSteps(lesson),
      index: 0,
      selection: const <String>[],
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

    final Result<SubmitQuizResult> res = await _quiz.submit(
      lessonId: args.lessonId,
      request: SubmitQuizRequest(
        clientAttemptId: _clientAttemptId,
        trackId: args.trackId,
        startedAt: _startedAt,
        answers: answers,
      ),
    );

    final SubmitQuizResult result = res.valueOrNull ?? _localResult(lesson, answers);
    _feedback.completed();
    state = state.copyWith(
      status: LessonStatus.finished,
      index: state.steps.length - 1,
      result: result,
    );
  }

  /// Compute a result locally from embedded outcomes (offline P0 path), reusing
  /// the shared Cortex grade so mastery deltas match the backend's intent.
  SubmitQuizResult _localResult(Lesson lesson, List<QuizAnswer> answers) {
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
    final int xpEarned = 20 + correctCount * 10;
    return SubmitQuizResult(
      attemptId: 'local-$_clientAttemptId',
      scorePct: scorePct,
      results: results,
      rewards: QuizRewards(
        xpEarned: xpEarned,
        newXp: 1240 + xpEarned,
        levelUp: false,
        streakExtended: true,
        gemsEarned: 0,
        achievementsUnlocked: const <String>[],
      ),
      weakConcepts: weak,
      nextReviewDueAt: DateTime.now().toUtc().add(const Duration(days: 1)),
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
