import 'dart:math' as math;

import 'package:cortex/cortex.dart';
import 'package:test/test.dart';

/// Golden vectors shared with the backend (`CortexParityTests.cs`). They pin the
/// client/server Cortex parity claimed in the architecture docs: any change here
/// MUST be mirrored there, or the client's optimistic projection drifts from the
/// server's authoritative result.
void main() {
  final DateTime now = DateTime.utc(2025, 1, 1);

  test('ReviewScheduler.apply(fresh, good) matches the shared golden vector', () {
    final ConceptMastery next = ReviewScheduler.apply(
      ConceptMastery.fresh(conceptId: 'c', trackId: 'az-900', now: now),
      ReviewGrade.good,
      now,
    );

    expect(next.stability, closeTo(1.6, 1e-12));
    expect(next.difficulty, closeTo(4.85, 1e-12));
    expect(next.masteryScore, closeTo(1 - math.exp(-1.6 / 20), 1e-12));
    // Fractional-day scheduling: 1.6 days (= 38h24m), NOT the old ceil() = 2 days.
    expect(next.dueAt, now.add(const Duration(hours: 38, minutes: 24)));
    expect(next.dueAt, isNot(now.add(const Duration(days: 2))));
  });

  test('Readiness recency uses fractional days (golden vector)', () {
    // One fully-mastered concept last reviewed 2.9 days ago (2d 21h36m).
    final ConceptMastery m = ConceptMastery.fresh(conceptId: 'd:c', trackId: 'az-900', now: now)
        .copyWith(
      masteryScore: 1.0,
      reps: 5,
      lastReviewedAt: now.subtract(const Duration(days: 2, hours: 21, minutes: 36)),
    );

    final DomainReadiness d = ReadinessCalculator.domain(
      domainId: 'd',
      weight: 1,
      conceptsInDomain: 1,
      masteries: <ConceptMastery>[m],
      now: now,
    );

    // recency = exp(-2.9/30); score = round(100 * recency^0.3) = 97. The old
    // truncated-to-2-days behaviour scored 98 — this proves fractional parity.
    expect(d.score, 97);
  });
}
