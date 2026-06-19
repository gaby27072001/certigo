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
/// touching the controller or the UI.
abstract interface class LessonGrader {
  CheckOutcome grade({required String itemId, required List<String> selected});
}

/// Grades against an in-memory answer key (offline P0 path).
class EmbeddedKeyGrader implements LessonGrader {
  const EmbeddedKeyGrader(this.key);

  /// itemId → the correct option ids + explanation for that check.
  final Map<String, CheckOutcome> key;

  @override
  CheckOutcome grade({required String itemId, required List<String> selected}) {
    final CheckOutcome? template = key[itemId];
    if (template == null) return CheckOutcome.empty;
    final bool correct = _unorderedEquals(selected, template.correctAnswer);
    return CheckOutcome(
      correct: correct,
      correctAnswer: template.correctAnswer,
      explanation: template.explanation,
    );
  }
}

/// Order-independent set equality over option ids (mcq has a single element).
bool _unorderedEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final Set<String> other = b.toSet();
  for (final String id in a) {
    if (!other.contains(id)) return false;
  }
  return true;
}
