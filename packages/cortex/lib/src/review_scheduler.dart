import 'dart:math' as math;
import 'concept_mastery.dart';
import 'review_grade.dart';

/// Cortex scheduler — a compact FSRS-inspired spaced-repetition algorithm.
///
/// Intentionally simple and fully deterministic (no ML weights). It is the exact
/// twin of the backend `ReviewScheduler` — same constants, same formulae and the
/// same fractional-day scheduling — so the client's optimistic projection matches
/// the server's authoritative result. Parity is pinned by golden vectors shared
/// across both languages (cortex_golden_test.dart ↔ CortexParityTests.cs).
class ReviewScheduler {
  const ReviewScheduler._();

  /// Apply a graded review to [m] and return the updated memory state.
  static ConceptMastery apply(
    ConceptMastery m,
    ReviewGrade grade,
    DateTime now,
  ) {
    final bool again = grade == ReviewGrade.again;

    final double difficulty = (m.difficulty + (again ? 0.8 : -0.15)).clamp(1.0, 10.0);

    final double factor = switch (grade) {
      ReviewGrade.again => 0.5,
      ReviewGrade.hard => 1.1,
      ReviewGrade.good => 1.6,
      ReviewGrade.easy => 2.1,
    };

    final double stability = again ? math.max(0.5, m.stability * 0.4) : m.stability * factor;

    // Recall probability proxy → saturates toward 1 as stability grows.
    final double mastery = (1 - math.exp(-stability / 20)).clamp(0.0, 1.0);

    return m.copyWith(
      difficulty: difficulty,
      stability: stability,
      masteryScore: mastery,
      reps: m.reps + 1,
      lapses: m.lapses + (again ? 1 : 0),
      lastReviewedAt: now,
      // Fractional-day scheduling — identical to the backend's
      // `now.AddDays(stability)` (was `ceil()`, which drifted from the server).
      dueAt: now.add(Duration(microseconds: (stability * Duration.microsecondsPerDay).round())),
    );
  }

  /// Convenience: grade from an answer then apply in one step.
  static ConceptMastery review(
    ConceptMastery m, {
    required bool correct,
    required int latencyMs,
    required DateTime now,
  }) {
    return apply(m, gradeFromAnswer(correct: correct, latencyMs: latencyMs), now);
  }
}
