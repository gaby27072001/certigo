import '../../../app/session_resume_store.dart';

/// The quiz half of a [SessionResumeRecord]: where the learner was, and what
/// they had answered but not yet submitted.
///
/// Typed here rather than inside the shared store so each surface validates
/// its own shape. [fromJson] returns `null` for anything it cannot fully
/// account for — a half-read record would restore a learner into a position
/// that does not match their answers, which is worse than restoring nothing.
class QuizResumeProgress {
  const QuizResumeProgress({
    required this.index,
    this.selectedId,
    this.graded = false,
    this.correctCount = 0,
    this.answers = const <String, List<String>>{},
    this.latencies = const <String, int>{},
  });

  /// Position in the series of questions.
  final int index;

  /// The pick the learner had made but not yet graded — the quiz equivalent of
  /// un-sent text left in a field.
  final String? selectedId;

  final bool graded;

  /// Locally-corrected score. Only demo content carries an answer key, so this
  /// is 0 for server content, where the server alone scores.
  final int correctCount;

  final Map<String, List<String>> answers;
  final Map<String, int> latencies;

  /// A session worth persisting has moved past the first question, put
  /// something on screen, or already graded an answer. Anything less would
  /// write a record for a quiz merely opened and immediately abandoned.
  bool get isWorthResuming => index > 0 || selectedId != null || graded || answers.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'index': index,
        'selectedId': selectedId,
        'graded': graded,
        'correctCount': correctCount,
        'answers': answers,
        'latencies': latencies,
      };

  static QuizResumeProgress? fromJson(Map<String, dynamic> json) {
    final int? index = (json['index'] as num?)?.toInt();
    if (index == null || index < 0) return null;
    return QuizResumeProgress(
      index: index,
      selectedId: _text(json['selectedId']),
      graded: json['graded'] as bool? ?? false,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      answers: _answers(json['answers']),
      latencies: _latencies(json['latencies']),
    );
  }

  /// Whether this progress can be replayed over [itemIds].
  ///
  /// The content pin already guards against a republished lesson, but a pin is
  /// only as good as its presence: content that carries none would otherwise
  /// restore answers addressed to items that are no longer there. Refusing an
  /// unmappable record is the reading floor of `docs/GOVERNANCE.md` §7 —
  /// an instrument that cannot account for what it read must not report a
  /// result.
  bool fits(List<String> itemIds) {
    if (index >= itemIds.length) return false;
    final Set<String> known = itemIds.toSet();
    return answers.keys.every(known.contains) && latencies.keys.every(known.contains);
  }
}

String? _text(Object? value) {
  if (value is! String) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Map<String, List<String>> _answers(Object? value) {
  if (value is! Map) return const <String, List<String>>{};
  final Map<String, List<String>> parsed = <String, List<String>>{};
  value.forEach((Object? key, Object? selected) {
    if (key is! String || selected is! List) return;
    parsed[key] = selected.whereType<String>().toList(growable: false);
  });
  return parsed;
}

Map<String, int> _latencies(Object? value) {
  if (value is! Map) return const <String, int>{};
  final Map<String, int> parsed = <String, int>{};
  value.forEach((Object? key, Object? latency) {
    if (key is! String || latency is! num) return;
    parsed[key] = latency.toInt();
  });
  return parsed;
}
