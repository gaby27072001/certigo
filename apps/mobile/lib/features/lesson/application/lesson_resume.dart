import '../../../app/session_resume_store.dart';

/// The lesson half of a [SessionResumeRecord]: where the learner was, and what
/// they had answered but not yet submitted.
///
/// Typed here rather than inside the shared store so each surface validates
/// its own shape. [fromJson] returns `null` for anything it cannot fully
/// account for — a half-read record would restore a learner into a position
/// that does not match their answers, which is worse than restoring nothing.
///
/// ## What is deliberately absent: the outcomes
///
/// `LessonSessionState.outcomes` is not serialised. It is **derived**: the
/// controller recomputes it by replaying the restored answers through the same
/// [LessonGrader] the session was using. For server content that grader holds
/// no answer key — grading is server-authoritative — so every outcome is
/// `CheckOutcome.empty`, exactly what the interrupted session had. Persisting
/// it would store a value that can be recomputed, and would let a stored
/// outcome contradict the answer it came from.
///
/// Demo sessions, which are the only ones with a real embedded key, are never
/// persisted at all: they are never submitted and earn nothing, so they have
/// no server attempt to protect.
class LessonResumeProgress {
  const LessonResumeProgress({
    required this.index,
    this.selection = const <String>[],
    this.answers = const <String, List<String>>{},
    this.latencies = const <String, int>{},
  });

  /// Position in the lesson's step list.
  final int index;

  /// Working selection on the current check — the lesson's equivalent of
  /// un-sent text left in a field.
  final List<String> selection;

  /// Locked answers per check itemId.
  final Map<String, List<String>> answers;
  final Map<String, int> latencies;

  /// A session worth persisting has moved past the first step, put something
  /// on screen, or locked an answer. Anything less would write a record for a
  /// lesson merely opened.
  bool get isWorthResuming => index > 0 || selection.isNotEmpty || answers.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'index': index,
        'selection': selection,
        'answers': answers,
        'latencies': latencies,
      };

  static LessonResumeProgress? fromJson(Map<String, dynamic> json) {
    final int? index = (json['index'] as num?)?.toInt();
    if (index == null || index < 0) return null;
    return LessonResumeProgress(
      index: index,
      selection: _strings(json['selection']),
      answers: _answers(json['answers']),
      latencies: _latencies(json['latencies']),
    );
  }

  /// Whether this progress can be replayed over a lesson whose check items are
  /// [itemIds] and which has [stepCount] steps.
  ///
  /// The content pin already guards against a republished lesson, but a pin is
  /// only as good as its presence: content that carries none would otherwise
  /// restore answers addressed to items that are no longer there. Refusing an
  /// unmappable record is the reading floor of `docs/GOVERNANCE.md` §7 — an
  /// instrument that cannot account for what it read must not report a result.
  bool fits({required List<String> itemIds, required int stepCount}) {
    if (index >= stepCount) return false;
    final Set<String> known = itemIds.toSet();
    return answers.keys.every(known.contains) && latencies.keys.every(known.contains);
  }
}

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  return value.whereType<String>().toList(growable: false);
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
