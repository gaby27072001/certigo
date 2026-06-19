/// Per-concept memory state tracked by the Cortex engine.
///
/// One [ConceptMastery] exists per (user, concept). It is the atomic unit the
/// Readiness Score and the review queue are built from. Immutable — scheduling
/// returns a new instance via [copyWith].
class ConceptMastery {
  const ConceptMastery({
    required this.conceptId,
    required this.trackId,
    required this.masteryScore,
    required this.stability,
    required this.difficulty,
    required this.dueAt,
    required this.reps,
    required this.lapses,
    required this.lastReviewedAt,
  });

  /// Fresh, never-seen concept. Matches backend `ConceptMastery.New`.
  factory ConceptMastery.fresh({
    required String conceptId,
    required String trackId,
    DateTime? now,
  }) {
    final DateTime ts = now ?? DateTime.now().toUtc();
    return ConceptMastery(
      conceptId: conceptId,
      trackId: trackId,
      masteryScore: 0,
      stability: 1,
      difficulty: 5,
      dueAt: ts,
      reps: 0,
      lapses: 0,
      lastReviewedAt: ts,
    );
  }

  final String conceptId;
  final String trackId;

  /// 0..1 — probability-of-recall proxy. Drives Readiness + weakness detection.
  final double masteryScore;

  /// FSRS stability (days). Higher ⇒ memory decays slower.
  final double stability;

  /// FSRS difficulty (1..10). Higher ⇒ harder for this user.
  final double difficulty;

  /// When this concept next becomes due for review.
  final DateTime dueAt;
  final int reps;
  final int lapses;
  final DateTime lastReviewedAt;

  bool isDue(DateTime now) => !dueAt.isAfter(now);

  /// A concept is "weak" if mastery is low despite being seen at least once.
  bool get isWeak => reps > 0 && masteryScore < 0.5;

  ConceptMastery copyWith({
    double? masteryScore,
    double? stability,
    double? difficulty,
    DateTime? dueAt,
    int? reps,
    int? lapses,
    DateTime? lastReviewedAt,
  }) {
    return ConceptMastery(
      conceptId: conceptId,
      trackId: trackId,
      masteryScore: masteryScore ?? this.masteryScore,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      dueAt: dueAt ?? this.dueAt,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }
}
