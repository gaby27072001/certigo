import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microlingo/features/path/application/path_rules.dart';

PathLesson _lesson(String id, NodeStatus status) =>
    PathLesson(id: id, title: id, status: status, estMinutes: 5, masteryPct: 0);

PathUnit _unit(String id, NodeStatus status, List<PathLesson> lessons) =>
    PathUnit(id: id, title: id, domainId: 'd', status: status, lessons: lessons);

LearningPath _path(List<PathUnit> units) => LearningPath(
      trackId: 'az-900',
      trackName: 'AZ-900',
      exam: 'AZ-900',
      readinessScore: 0,
      readinessTrend7d: 0,
      units: units,
      domains: const <DomainProgress>[],
    );

void main() {
  group('currentLessonIdOf', () {
    test('returns the first in-progress lesson, skipping completed ones', () {
      final LearningPath path = _path(<PathUnit>[
        _unit('u1', NodeStatus.available, <PathLesson>[
          _lesson('l1', NodeStatus.completed),
          _lesson('l2', NodeStatus.inProgress),
          _lesson('l3', NodeStatus.available),
        ]),
      ]);

      expect(currentLessonIdOf(path), 'l2');
    });

    test('prefers an earlier available lesson over a later in-progress one (Home order)', () {
      // Guards against the old Path-only rule that let an in-progress lesson
      // anywhere win: order must decide so Path agrees with Home's nextLesson.
      final LearningPath path = _path(<PathUnit>[
        _unit('u1', NodeStatus.available, <PathLesson>[
          _lesson('l1', NodeStatus.available),
          _lesson('l2', NodeStatus.inProgress),
        ]),
      ]);

      expect(currentLessonIdOf(path), 'l1');
    });

    test('crosses units and skips completed, mastered and locked lessons', () {
      final LearningPath path = _path(<PathUnit>[
        _unit('u1', NodeStatus.completed, <PathLesson>[
          _lesson('l1', NodeStatus.completed),
          _lesson('l2', NodeStatus.mastered),
        ]),
        _unit('u2', NodeStatus.available, <PathLesson>[
          _lesson('l3', NodeStatus.locked),
          _lesson('l4', NodeStatus.available),
        ]),
      ]);

      expect(currentLessonIdOf(path), 'l4');
    });

    test('returns null when nothing is actionable', () {
      final LearningPath path = _path(<PathUnit>[
        _unit('u1', NodeStatus.completed, <PathLesson>[
          _lesson('l1', NodeStatus.completed),
          _lesson('l2', NodeStatus.mastered),
        ]),
        _unit('u2', NodeStatus.locked, <PathLesson>[
          _lesson('l3', NodeStatus.locked),
        ]),
      ]);

      expect(currentLessonIdOf(path), isNull);
    });
  });

  group('gateStatusOf', () {
    test('is locked while the unit itself is locked, even if lessons are done', () {
      final PathUnit unit = _unit('u1', NodeStatus.locked, <PathLesson>[
        _lesson('l1', NodeStatus.completed),
      ]);

      expect(gateStatusOf(unit), NodeStatus.locked);
    });

    test('is locked when the unit has no lessons', () {
      final PathUnit unit = _unit('u1', NodeStatus.available, <PathLesson>[]);

      expect(gateStatusOf(unit), NodeStatus.locked);
    });

    test('is locked while any lesson is still unfinished', () {
      final PathUnit unit = _unit('u1', NodeStatus.available, <PathLesson>[
        _lesson('l1', NodeStatus.completed),
        _lesson('l2', NodeStatus.available),
      ]);

      expect(gateStatusOf(unit), NodeStatus.locked);
    });

    test('is available (ready to attempt) when all lessons are done but not all mastered', () {
      final PathUnit unit = _unit('u1', NodeStatus.available, <PathLesson>[
        _lesson('l1', NodeStatus.completed),
        _lesson('l2', NodeStatus.mastered),
      ]);

      expect(gateStatusOf(unit), NodeStatus.available);
    });

    test('is mastered (legendary) only when every lesson is mastered', () {
      final PathUnit unit = _unit('u1', NodeStatus.available, <PathLesson>[
        _lesson('l1', NodeStatus.mastered),
        _lesson('l2', NodeStatus.mastered),
      ]);

      expect(gateStatusOf(unit), NodeStatus.mastered);
    });
  });

  group('gateCheckpointLessonId', () {
    test('is null while the gate is locked', () {
      final PathUnit unit = _unit('u1', NodeStatus.available, <PathLesson>[
        _lesson('l1', NodeStatus.available),
      ]);

      expect(gateCheckpointLessonId(unit), isNull);
    });

    test('points at the last lesson once the gate is open', () {
      final PathUnit unit = _unit('u1', NodeStatus.available, <PathLesson>[
        _lesson('l1', NodeStatus.completed),
        _lesson('l2', NodeStatus.completed),
      ]);

      expect(gateCheckpointLessonId(unit), 'l2');
    });

    test('points at the last lesson when the unit is fully mastered', () {
      final PathUnit unit = _unit('u1', NodeStatus.available, <PathLesson>[
        _lesson('l1', NodeStatus.mastered),
        _lesson('l2', NodeStatus.mastered),
      ]);

      expect(gateCheckpointLessonId(unit), 'l2');
    });
  });
}
