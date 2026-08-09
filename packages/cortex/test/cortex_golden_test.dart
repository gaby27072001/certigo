import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cortex/cortex.dart';
import 'package:test/test.dart';

/// Data-driven Cortex golden tests.
///
/// The `parity` vectors are the single source of truth shared with the backend
/// (`backend/tests/Certigo.Domain.Tests/CortexParityTests.cs`): the exact same
/// JSON is asserted on both sides, and the `ci-cortex-parity` workflow fails if
/// Dart and .NET diverge. The `cortexOnly` vectors cover the SessionPlanner,
/// which has no .NET twin, so only Dart asserts them.
///
/// Hermetic by construction — no Flutter, no fonts, no network: it reads the
/// JSON off disk and exercises pure `package:cortex/src/...` math.
void main() {
  final DateTime now = DateTime.utc(2025, 1, 1);
  final Map<String, dynamic> vectors = _loadVectors();

  const Map<String, ReviewGrade> gradeByName = <String, ReviewGrade>{
    'again': ReviewGrade.again,
    'hard': ReviewGrade.hard,
    'good': ReviewGrade.good,
    'easy': ReviewGrade.easy,
  };

  test('algo version matches the shared golden vector', () {
    expect(cortexAlgoVersion, vectors['algoVersion']);
  });

  final Map<String, dynamic> parity = vectors['parity'] as Map<String, dynamic>;

  group('parity/scheduler', () {
    for (final dynamic raw in parity['scheduler'] as List<dynamic>) {
      final Map<String, dynamic> v = raw as Map<String, dynamic>;
      test(v['name'] as String, () {
        ConceptMastery m = ConceptMastery.fresh(conceptId: 'c', trackId: 't', now: now);
        for (final dynamic g in v['grades'] as List<dynamic>) {
          m = ReviewScheduler.apply(m, gradeByName[g as String]!, now);
        }

        final Map<String, dynamic> expected = v['expected'] as Map<String, dynamic>;
        final double stability = _d(expected['stability']);
        expect(m.stability, closeTo(stability, 1e-9), reason: 'stability');
        expect(m.difficulty, closeTo(_d(expected['difficulty']), 1e-9), reason: 'difficulty');
        expect(m.reps, expected['reps'], reason: 'reps');
        expect(m.lapses, expected['lapses'], reason: 'lapses');
        // Mastery is derived from stability; pin it the same way both sides do.
        expect(m.masteryScore, closeTo(1 - math.exp(-stability / 20), 1e-9), reason: 'mastery');

        if (v['checkDueAt'] as bool) {
          // Fractional-day scheduling. Tolerance (1ms) absorbs cross-language
          // float rounding while still ruling out whole-day ceil() drift.
          final int actualMicros = m.dueAt.difference(now).inMicroseconds;
          final int expectedMicros = (_d(v['dueAtOffsetSeconds']) * Duration.microsecondsPerSecond)
              .round();
          expect((actualMicros - expectedMicros).abs(), lessThanOrEqualTo(1000), reason: 'dueAt');
        }
      });
    }
  });

  group('parity/weakness', () {
    for (final dynamic raw in parity['weakness'] as List<dynamic>) {
      final Map<String, dynamic> v = raw as Map<String, dynamic>;
      test(v['name'] as String, () {
        final ConceptMastery m = ConceptMastery.fresh(
          conceptId: 'c',
          trackId: 't',
          now: now,
        ).copyWith(reps: v['reps'] as int, masteryScore: _d(v['masteryScore']));
        expect(m.isWeak, v['expectedIsWeak'] as bool);
      });
    }
  });

  group('parity/readiness', () {
    for (final dynamic raw in parity['readiness'] as List<dynamic>) {
      final Map<String, dynamic> v = raw as Map<String, dynamic>;
      test(v['name'] as String, () {
        final List<dynamic> masteryVectors = v['masteries'] as List<dynamic>;
        final Map<String, int> expectedDomainScores =
            (v['expectedDomainScores'] as Map<String, dynamic>).map(
              (String k, dynamic val) => MapEntry<String, int>(k, val as int),
            );

        final List<DomainReadiness> domains = <DomainReadiness>[];
        for (final dynamic dRaw in v['domains'] as List<dynamic>) {
          final Map<String, dynamic> dv = dRaw as Map<String, dynamic>;
          final String domainId = dv['domainId'] as String;
          final List<ConceptMastery> masteries = masteryVectors
              .cast<Map<String, dynamic>>()
              .where((Map<String, dynamic> mv) => mv['domainId'] == domainId)
              .map((Map<String, dynamic> mv) => _mastery(mv, now))
              .toList();

          final DomainReadiness dr = ReadinessCalculator.domain(
            domainId: domainId,
            weight: _d(dv['weight']),
            conceptsInDomain: dv['conceptsInDomain'] as int,
            masteries: masteries,
            now: now,
          );
          expect(dr.score, expectedDomainScores[domainId], reason: 'domain $domainId');
          domains.add(dr);
        }

        expect(ReadinessCalculator.track(domains), v['expectedTrackScore'] as int, reason: 'track');
      });
    }
  });

  final Map<String, dynamic> cortexOnly = vectors['cortexOnly'] as Map<String, dynamic>;

  group('cortexOnly/sessionPlanner', () {
    const SessionPlanner planner = SessionPlanner();
    for (final dynamic raw in cortexOnly['sessionPlanner'] as List<dynamic>) {
      final Map<String, dynamic> v = raw as Map<String, dynamic>;
      test(v['name'] as String, () {
        final List<ConceptMastery> states = (v['states'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((Map<String, dynamic> sv) => _plannerState(sv, now))
            .toList();
        final List<String> candidateNew = (v['candidateNewConceptIds'] as List<dynamic>)
            .cast<String>();
        final List<String> expectedOrder = (v['expectedOrder'] as List<dynamic>).cast<String>();

        final List<String> order = planner.plan(
          states: states,
          candidateNewConceptIds: candidateNew,
          now: now,
          size: v['size'] as int,
        );
        expect(order, expectedOrder);
      });
    }
  });
}

double _d(dynamic v) => (v as num).toDouble();

DateTime _shift(DateTime now, double offsetDays) =>
    now.add(Duration(microseconds: (offsetDays * Duration.microsecondsPerDay).round()));

/// Build a readiness mastery from a vector: `lastReviewedAtOffsetDays` is how
/// long ago it was reviewed (positive = in the past).
ConceptMastery _mastery(Map<String, dynamic> mv, DateTime now) {
  return ConceptMastery.fresh(
    conceptId: mv['conceptId'] as String,
    trackId: 't',
    now: now,
  ).copyWith(
    masteryScore: _d(mv['masteryScore']),
    reps: mv['reps'] as int,
    lastReviewedAt: _shift(now, -_d(mv['lastReviewedAtOffsetDays'])),
  );
}

/// Build a session-planner state: `dueAtOffsetDays` is signed (negative = due in
/// the past); `lastReviewedAtOffsetDays` is how long ago it was reviewed.
ConceptMastery _plannerState(Map<String, dynamic> sv, DateTime now) {
  return ConceptMastery.fresh(
    conceptId: sv['conceptId'] as String,
    trackId: 't',
    now: now,
  ).copyWith(
    masteryScore: _d(sv['masteryScore']),
    reps: sv['reps'] as int,
    dueAt: _shift(now, _d(sv['dueAtOffsetDays'])),
    lastReviewedAt: _shift(now, -_d(sv['lastReviewedAtOffsetDays'])),
  );
}

Map<String, dynamic> _loadVectors() {
  const List<String> candidates = <String>[
    'test/golden/cortex_golden_vectors.json',
    'packages/cortex/test/golden/cortex_golden_vectors.json',
  ];
  for (final String path in candidates) {
    final File f = File(path);
    if (f.existsSync()) {
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    }
  }
  throw StateError('cortex_golden_vectors.json not found (cwd: ${Directory.current.path})');
}
