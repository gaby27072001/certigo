import 'package:data/data.dart';

import 'answer_grading.dart';

/// The graded result of a single inline check.
///
/// In P0 this is produced locally by an [EmbeddedKeyGrader] over bundled sample
/// content, so the player gives immediate feedback fully offline. In P1 grading
/// becomes server-authoritative (the submit endpoint returns the key) and the
/// embedded grader is dropped — the [CheckOutcome] shape is identical, so no UI
/// change is required.
class CheckOutcome {
  const CheckOutcome({
    required this.correct,
    required this.correctAnswer,
    required this.explanation,
  });

  final bool correct;

  /// The correct option ids — revealed after answering, for comprehension.
  final List<String> correctAnswer;

  /// Why the answer is right or wrong. Never empty in real content.
  final String explanation;

  static const CheckOutcome empty = CheckOutcome(
    correct: false,
    correctAnswer: <String>[],
    explanation: '',
  );
}

/// Grades a learner's answer to an inline check.
///
/// The seam that lets P0 grade locally and P1 grade on the server without
/// touching the controller or the UI. [type] selects the comparison semantics
/// (order-sensitive for ordering/cloze, set for the rest) and is optional so
/// existing single/multi callers stay source-compatible.
abstract interface class LessonGrader {
  CheckOutcome grade({
    required String itemId,
    required List<String> selected,
    ItemType type = ItemType.mcq,
  });
}

/// Grades against an in-memory answer key (offline P0 path).
class EmbeddedKeyGrader implements LessonGrader {
  const EmbeddedKeyGrader(this.key);

  /// itemId → the correct option ids + explanation for that check.
  final Map<String, CheckOutcome> key;

  @override
  CheckOutcome grade({
    required String itemId,
    required List<String> selected,
    ItemType type = ItemType.mcq,
  }) {
    final CheckOutcome? template = key[itemId];
    if (template == null) return CheckOutcome.empty;
    final bool correct = gradeSelection(type, selected, template.correctAnswer);
    return CheckOutcome(
      correct: correct,
      correctAnswer: template.correctAnswer,
      explanation: template.explanation,
    );
  }
}
