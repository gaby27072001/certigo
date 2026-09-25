/// Cortex — Certigo's adaptive learning engine (pure Dart).
///
/// Spaced repetition (FSRS-inspired), mastery tracking, session planning, the
/// Readiness Score math and the per-type answer grading. Deliberately free of
/// Flutter and I/O so it is fully unit-testable and mirrors the .NET backend
/// implementation 1:1.
library cortex;

export 'src/cortex_algo_version.dart';
export 'src/answer_grading.dart';
export 'src/review_grade.dart';
export 'src/concept_mastery.dart';
export 'src/review_scheduler.dart';
export 'src/readiness_calculator.dart';
export 'src/session_planner.dart';
