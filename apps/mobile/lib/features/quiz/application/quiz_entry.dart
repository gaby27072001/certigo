import 'package:data/data.dart';

/// Pairs a public [QuizItem] with optional local answer-key metadata used only
/// in offline fallback mode.
class QuizEntry {
  QuizEntry({required this.item, this.correctOptionId, this.explanation});

  final QuizItem item;
  final String? correctOptionId;
  final String? explanation;

  bool get hasLocalCorrection => correctOptionId != null && explanation != null;
  bool lastAnswerCorrect = false;
}
