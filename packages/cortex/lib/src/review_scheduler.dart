import 'dart:math' as math;
import 'concept_mastery.dart';
import 'review_grade.dart';

/// Cortex scheduler — a compact FSRS-inspired spaced-repetition algorithm.
///
/// This is an intentionally simple, fully deterministic model (no ML weights)
/// that is *byte-for-byte equivalent to the backend implementation*. The client
/// runs it for instant optimistic feedback; the server re-runs it as the source
/// of truth. Keeping a single algorithm in two languages avoids drift.
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

    final int dueDays = stability.ceil();

    return m.copyWith(
      difficulty: difficulty,
      stability: stability,
      masteryScore: mastery,
      reps: m.reps + 1,
      lapses: m.lapses + (again ? 1 : 0),
      lastReviewedAt: now,
      dueAt: now.add(Duration(days: dueDays)),
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
