import 'package:data/data.dart';

import 'answer_grading.dart';
import 'check_outcome.dart';
import 'lesson_step.dart';

/// Lifecycle of a lesson-playing session.
enum LessonStatus { idle, loading, ready, graded, submitting, finished, error }

/// Immutable snapshot of an in-progress lesson. The controller swaps whole
/// instances; the UI is a pure function of this state.
class LessonSessionState {
  const LessonSessionState({
    this.status = LessonStatus.idle,
    this.lesson,
    this.steps = const <LessonStep>[],
    this.index = 0,
    this.selection = const <String>[],
    this.answers = const <String, List<String>>{},
    this.latencies = const <String, int>{},
    this.outcomes = const <String, CheckOutcome>{},
    this.result,
    this.errorMessage,
    this.isDemo = false,
    this.pendingSync = false,
    this.submissionFailed = false,
  });

  final LessonStatus status;
  final Lesson? lesson;
  final List<LessonStep> steps;
  final int index;

  /// Working selection for the current check step (option ids).
  final List<String> selection;

  /// Locked answers per check itemId.
  final Map<String, List<String>> answers;
  final Map<String, int> latencies;
  final Map<String, CheckOutcome> outcomes;

  /// Server (or locally computed) result, once submitted.
  final SubmitQuizResult? result;
  final String? errorMessage;
  final bool isDemo;
  final bool pendingSync;
  final bool submissionFailed;

  LessonStep? get current =>
      (index >= 0 && index < steps.length) ? steps[index] : null;

  QuizItem? get currentItem => current?.item;

  bool get currentAnswered {
    final QuizItem? item = currentItem;
    return item != null && outcomes.containsKey(item.id);
  }

  /// Outcome for the current check step, if it has been graded.
  CheckOutcome? get currentOutcome {
    final QuizItem? item = currentItem;
    return item == null ? null : outcomes[item.id];
  }

  /// Whether the current check has enough input to be submitted.
  ///
  /// The single CTA is gated on this, so completeness is defined per exercise
  /// type instead of the naive "something is selected":
  ///
  /// * ordering / applied / matchPairs — every slot filled (one token per item).
  /// * cloze — every blank in the stem filled.
  /// * select family (mcq/multi/scenario/spotTheIssue) — at least one pick.
  bool get canSubmitCurrent {
    final QuizItem? item = currentItem;
    if (item == null || currentAnswered) return false;
    switch (item.type) {
      case ItemType.ordering:
      case ItemType.applied:
        return item.options.isNotEmpty &&
            selection.length == item.options.length;
      case ItemType.matchPairs:
        return item.options.isNotEmpty &&
            selection.length == item.options.length;
      case ItemType.cloze:
        final int blanks = clozeBlankCount(item.stem);
        return blanks > 0 && selection.length == blanks;
      case ItemType.mcq:
      case ItemType.multi:
      case ItemType.scenario:
      case ItemType.spotTheIssue:
      case ItemType.unknown:
        return selection.isNotEmpty;
    }
  }

  /// Whether advancing one step lands on the synthetic result step.
  bool get nextIsResult {
    final int next = index + 1;
    return next < steps.length && steps[next].kind == LessonStepKind.result;
  }

  /// 0..1 reading progress (the result step is the denominator's end point).
  double get progress {
    if (steps.length <= 1) return 0;
    final int last = steps.length - 1;
    return (index / last).clamp(0.0, 1.0);
  }

  int get checksTotal => steps.where((LessonStep step) => step.isCheck).length;

  LessonSessionState copyWith({
    LessonStatus? status,
    Lesson? lesson,
    List<LessonStep>? steps,
    int? index,
    List<String>? selection,
    Map<String, List<String>>? answers,
    Map<String, int>? latencies,
    Map<String, CheckOutcome>? outcomes,
    SubmitQuizResult? result,
    String? errorMessage,
    bool? isDemo,
    bool? pendingSync,
    bool? submissionFailed,
  }) {
    return LessonSessionState(
      status: status ?? this.status,
      lesson: lesson ?? this.lesson,
      steps: steps ?? this.steps,
      index: index ?? this.index,
      selection: selection ?? this.selection,
      answers: answers ?? this.answers,
      latencies: latencies ?? this.latencies,
      outcomes: outcomes ?? this.outcomes,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      isDemo: isDemo ?? this.isDemo,
      pendingSync: pendingSync ?? this.pendingSync,
      submissionFailed: submissionFailed ?? this.submissionFailed,
    );
  }
}
