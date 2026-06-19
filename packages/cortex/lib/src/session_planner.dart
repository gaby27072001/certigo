import 'concept_mastery.dart';

/// Builds a balanced practice session from a learner's concept states.
///
/// Cortex sessions interleave four "lanes" so practice is varied and effective
/// (interleaving + retrieval + spacing), rather than blocked repetition:
///   1. **Due**   — concepts past their review date (highest priority).
///   2. **Weak**  — seen but mastery < 0.5 (targeted repair).
///   3. **New**   — never-seen concepts (fresh coverage).
///   4. **Fresh** — recently learned, light reinforcement.
class SessionPlanner {
  const SessionPlanner({
    this.dueWeight = 0.4,
    this.weakWeight = 0.3,
    this.newWeight = 0.2,
    this.reinforceWeight = 0.1,
  });

  final double dueWeight;
  final double weakWeight;
  final double newWeight;
  final double reinforceWeight;

  /// Returns an ordered list of concept ids to practise this session.
  ///
  /// [states] are the learner's known masteries; [candidateNewConceptIds] are
  /// authored concepts the learner has not started yet, already in curriculum
  /// order.
  List<String> plan({
    required List<ConceptMastery> states,
    required List<String> candidateNewConceptIds,
    required DateTime now,
    int size = 12,
  }) {
    final List<ConceptMastery> due = states.where((m) => m.isDue(now)).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final List<ConceptMastery> weak = states.where((m) => m.isWeak && !m.isDue(now)).toList()
      ..sort((a, b) => a.masteryScore.compareTo(b.masteryScore));
    final List<ConceptMastery> reinforce = states.where((m) => !m.isWeak && !m.isDue(now)).toList()
      ..sort((a, b) => a.lastReviewedAt.compareTo(b.lastReviewedAt));

    final int dueN = (size * dueWeight).round();
    final int weakN = (size * weakWeight).round();
    final int newN = (size * newWeight).round();
    final int reinforceN = (size * reinforceWeight).round();

    final List<String> picks = <String>[
      ...due.take(dueN).map((m) => m.conceptId),
      ...weak.take(weakN).map((m) => m.conceptId),
      ...candidateNewConceptIds.take(newN),
      ...reinforce.take(reinforceN).map((m) => m.conceptId),
    ];

    // De-duplicate while preserving order, then backfill from due/new if short.
    final List<String> ordered = _dedup(picks);
    if (ordered.length < size) {
      for (final ConceptMastery m in due) {
        if (ordered.length >= size) break;
        if (!ordered.contains(m.conceptId)) ordered.add(m.conceptId);
      }
      for (final String id in candidateNewConceptIds) {
        if (ordered.length >= size) break;
        if (!ordered.contains(id)) ordered.add(id);
      }
    }
    return ordered.take(size).toList();
  }

  static List<String> _dedup(List<String> input) {
    final Set<String> seen = <String>{};
    final List<String> out = <String>[];
    for (final String id in input) {
      if (seen.add(id)) out.add(id);
    }
    return out;
  }
}
