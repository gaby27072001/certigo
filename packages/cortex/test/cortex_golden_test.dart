import 'dart:math' as math;

import 'package:cortex/cortex.dart';
import 'package:test/test.dart';

/// Golden vectors shared with the backend (`ReviewSchedulerGoldenTests.cs` and
/// `CortexParityTests.cs`). They pin the client/server Cortex parity claimed in
/// the architecture docs: any change here MUST be mirrored there, or the
/// client's optimistic projection drifts from the server's authoritative result.
///
/// Fractional-day scheduling: dueAt = now + stability (in microseconds), NOT
/// ceil(stability). This is the key invariant both sides must preserve.
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

  test('ReviewScheduler.apply(fresh, easy) — 2.1-day fractional scheduling', () {
    final ConceptMastery next = ReviewScheduler.apply(
      ConceptMastery.fresh(conceptId: 'c', trackId: 'az-900', now: now),
      ReviewGrade.easy,
      now,
    );

    expect(next.stability, closeTo(2.1, 1e-12));
    // 2.1 days = 50h24m — must NOT be ceil() = 3 days.
    expect(next.dueAt, now.add(const Duration(hours: 50, minutes: 24)));
    expect(next.dueAt, isNot(now.add(const Duration(days: 3))));
  });

  test('ReviewScheduler.apply(fresh, hard) — 1.1-day fractional scheduling', () {
    final ConceptMastery next = ReviewScheduler.apply(
      ConceptMastery.fresh(conceptId: 'c', trackId: 'az-900', now: now),
      ReviewGrade.hard,
      now,
    );

    expect(next.stability, closeTo(1.1, 1e-12));
    // 1.1 days = 26h24m — NOT ceil() = 2 days.
    expect(next.dueAt, now.add(const Duration(hours: 26, minutes: 24)));
    expect(next.dueAt, isNot(now.add(const Duration(days: 2))));
  });

  test('ReviewScheduler.apply(fresh, again) — stability clamped to 0.5 (12h)', () {
    final ConceptMastery next = ReviewScheduler.apply(
      ConceptMastery.fresh(conceptId: 'c', trackId: 'az-900', now: now),
      ReviewGrade.again,
      now,
    );

    // max(0.5, 1.0 × 0.4) = max(0.5, 0.4) = 0.5
    expect(next.stability, closeTo(0.5, 1e-12));
    expect(next.dueAt, now.add(const Duration(hours: 12)));
    expect(next.lapses, 1);
  });

  test('ReviewScheduler.apply(stability=2.0, good) — non-unit start', () {
    final ConceptMastery seed =
        ConceptMastery.fresh(conceptId: 'c', trackId: 'az-900', now: now)
            .copyWith(stability: 2.0);

    final ConceptMastery next = ReviewScheduler.apply(seed, ReviewGrade.good, now);

    expect(next.stability, closeTo(3.2, 1e-12));
    // 3.2 days = 76h48m — not ceil()=4 days.
    expect(next.dueAt, now.add(const Duration(hours: 76, minutes: 48)));
    expect(next.dueAt, isNot(now.add(const Duration(days: 4))));
  });

  test('ReviewScheduler.apply(stability=3.0, easy) — 6.3-day fractional result', () {
    final ConceptMastery seed =
        ConceptMastery.fresh(conceptId: 'c', trackId: 'az-900', now: now)
            .copyWith(stability: 3.0);

    final ConceptMastery next = ReviewScheduler.apply(seed, ReviewGrade.easy, now);

    // 3.0 × 2.1 = ~6.3; round-to-microsecond gives Duration(hours:151, minutes:12)
    expect(next.stability, closeTo(6.3, 1e-10));
    expect(next.dueAt, now.add(const Duration(hours: 151, minutes: 12)));
    expect(next.dueAt, isNot(now.add(const Duration(days: 7))));
  });

  test('ReviewScheduler.apply(stability=0.5, good) — sub-day fractional (0.8 days)', () {
    final ConceptMastery seed =
        ConceptMastery.fresh(conceptId: 'c', trackId: 'az-900', now: now)
            .copyWith(stability: 0.5);

    final ConceptMastery next = ReviewScheduler.apply(seed, ReviewGrade.good, now);

    expect(next.stability, closeTo(0.8, 1e-12));
    // 0.8 days = 19h12m
    expect(next.dueAt, now.add(const Duration(hours: 19, minutes: 12)));
  });

  test('ReviewScheduler.apply(stability=5.0, again) — floor at max(0.5, 5.0*0.4)=2.0', () {
    final ConceptMastery seed =
        ConceptMastery.fresh(conceptId: 'c', trackId: 'az-900', now: now)
            .copyWith(stability: 5.0);

    final ConceptMastery next = ReviewScheduler.apply(seed, ReviewGrade.again, now);

    expect(next.stability, closeTo(2.0, 1e-12));
    expect(next.dueAt, now.add(const Duration(days: 2)));
  });

  test('Readiness recency uses fractional days (golden vector)', () {
    // One fully-mastered concept last reviewed 2.9 days ago (2d 21h36m).
    final ConceptMastery m =
        ConceptMastery.fresh(conceptId: 'd:c', trackId: 'az-900', now: now).copyWith(
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
