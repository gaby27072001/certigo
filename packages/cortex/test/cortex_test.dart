import 'package:cortex/cortex.dart';
import 'package:test/test.dart';

void main() {
  final DateTime now = DateTime.utc(2025, 1, 1);

  group('gradeFromAnswer', () {
    test('wrong answer is always Again', () {
      expect(gradeFromAnswer(correct: false, latencyMs: 100), ReviewGrade.again);
    });
    test('fast correct is Easy, slow correct is Hard', () {
      expect(gradeFromAnswer(correct: true, latencyMs: 1000), ReviewGrade.easy);
      expect(gradeFromAnswer(correct: true, latencyMs: 6000), ReviewGrade.good);
      expect(gradeFromAnswer(correct: true, latencyMs: 20000), ReviewGrade.hard);
    });
  });

  group('ReviewScheduler.apply', () {
    test('Again reduces stability, increments lapses and brings due closer', () {
      final ConceptMastery m = ConceptMastery.fresh(
        conceptId: 'c1',
        trackId: 'az-900',
        now: now,
      ).copyWith(stability: 10, masteryScore: 0.6);

      final ConceptMastery next = ReviewScheduler.apply(m, ReviewGrade.again, now);

      expect(next.stability, lessThan(m.stability));
      expect(next.lapses, m.lapses + 1);
      expect(next.reps, m.reps + 1);
      expect(next.difficulty, greaterThan(m.difficulty));
    });

    test('Good increases stability and schedules due in the future', () {
      final ConceptMastery m = ConceptMastery.fresh(conceptId: 'c2', trackId: 'az-900', now: now);

      final ConceptMastery next = ReviewScheduler.apply(m, ReviewGrade.good, now);

      expect(next.stability, greaterThan(m.stability));
      expect(next.dueAt.isAfter(now), isTrue);
      expect(next.masteryScore, greaterThan(0));
    });

    test('mastery is monotonic across repeated Good reviews', () {
      ConceptMastery m = ConceptMastery.fresh(conceptId: 'c3', trackId: 'az-900', now: now);
      double last = m.masteryScore;
      // Six sustained "Good" reviews should push mastery past the 0.5 line at
      // which a concept stops being "weak" (see ConceptMastery.isWeak).
      for (int i = 0; i < 6; i++) {
        m = ReviewScheduler.apply(m, ReviewGrade.good, now);
        expect(m.masteryScore, greaterThanOrEqualTo(last));
        last = m.masteryScore;
      }
      expect(m.masteryScore, greaterThan(0.5));
    });
  });

  group('ReadinessCalculator', () {
    test('empty progress yields zero readiness', () {
      final DomainReadiness d = ReadinessCalculator.domain(
        domainId: 'd1',
        weight: 1,
        conceptsInDomain: 10,
        masteries: <ConceptMastery>[],
        now: now,
      );
      expect(d.score, 0);
      expect(ReadinessCalculator.track(<DomainReadiness>[d]), 0);
    });

    test('full mastered coverage approaches a high score', () {
      final List<ConceptMastery> mastered = List<ConceptMastery>.generate(
        10,
        (int i) => ConceptMastery.fresh(
          conceptId: 'c$i',
          trackId: 'az-900',
          now: now,
        ).copyWith(masteryScore: 0.95, reps: 5, lastReviewedAt: now),
      );

      final DomainReadiness d = ReadinessCalculator.domain(
        domainId: 'd1',
        weight: 1,
        conceptsInDomain: 10,
        masteries: mastered,
        now: now,
      );
      expect(d.coverage, 1.0);
      expect(d.score, greaterThan(80));
    });
  });

  group('SessionPlanner', () {
    test('prioritizes due concepts and fills to requested size', () {
      final List<ConceptMastery> states = <ConceptMastery>[
        ConceptMastery.fresh(
          conceptId: 'due1',
          trackId: 't',
          now: now,
        ).copyWith(reps: 2, dueAt: now.subtract(const Duration(days: 1))),
        ConceptMastery.fresh(
          conceptId: 'weak1',
          trackId: 't',
          now: now,
        ).copyWith(reps: 2, masteryScore: 0.2, dueAt: now.add(const Duration(days: 5))),
      ];

      final List<String> plan = const SessionPlanner().plan(
        states: states,
        candidateNewConceptIds: <String>['new1', 'new2', 'new3'],
        now: now,
        size: 4,
      );

      expect(plan.first, 'due1');
      expect(plan.length, 4);
      expect(plan.toSet().length, plan.length, reason: 'no duplicates');
    });
  });
}
