/// Pure, widget-free progression rules for the certification **path**.
///
/// The server is authoritative for every lesson/unit [NodeStatus]; this layer
/// derives only the purely presentational concepts the API does not send — the
/// learner's single "next" lesson and the state of each unit's review gate — so
/// the winding-path screen stays a thin renderer and these rules can be
/// unit-tested without pumping a single widget.
library;

import 'package:data/data.dart';

/// The id of the learner's "next" lesson: the first lesson, scanning units
/// top-to-bottom then lessons in order, whose status is [NodeStatus.inProgress]
/// or [NodeStatus.available]. Mirrors `HomeData.nextLesson` so Home and Path
/// agree on what "continue" means. Null when nothing is actionable.
String? currentLessonIdOf(LearningPath path) {
  for (final PathUnit unit in path.units) {
    for (final PathLesson lesson in unit.lessons) {
      if (lesson.status == NodeStatus.inProgress || lesson.status == NodeStatus.available) {
        return lesson.id;
      }
    }
  }
  return null;
}

/// Derives a unit gate's status purely from its lessons.
///
/// [NodeStatus.locked] until the unit is itself unlocked AND every lesson is
/// completed-or-mastered; [NodeStatus.mastered] (legendary/gold) when every
/// lesson is mastered; otherwise [NodeStatus.available] — the review boss is
/// unlocked and ready to attempt.
NodeStatus gateStatusOf(PathUnit unit) {
  if (unit.lessons.isEmpty || unit.status == NodeStatus.locked) {
    return NodeStatus.locked;
  }
  final bool allDone = unit.lessons.every(
    (PathLesson l) => l.status == NodeStatus.completed || l.status == NodeStatus.mastered,
  );
  if (!allDone) return NodeStatus.locked;
  final bool allMastered = unit.lessons.every((PathLesson l) => l.status == NodeStatus.mastered);
  return allMastered ? NodeStatus.mastered : NodeStatus.available;
}

/// The lesson the gate's checkpoint quiz reviews (the unit's last lesson), or
/// null while the gate is locked.
String? gateCheckpointLessonId(PathUnit unit) {
  if (gateStatusOf(unit) == NodeStatus.locked) return null;
  return unit.lessons.isEmpty ? null : unit.lessons.last.id;
}
