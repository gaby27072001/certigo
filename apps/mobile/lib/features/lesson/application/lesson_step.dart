import 'package:data/data.dart';

/// The kind of a single step in the paginated lesson player.
///
/// Content kinds map 1:1 to [BlockType]; [intro] and [result] are synthetic
/// bookends; [quiz] is reserved for future unit checkpoints and is never emitted
/// by [buildLessonSteps] (kept so the renderer switch stays exhaustive).
enum LessonStepKind {
  intro,
  hook,
  concept,
  example,
  code,
  check,
  recap,
  quiz,
  result,
}

/// One screen in the lesson flow.
class LessonStep {
  const LessonStep({
    required this.kind,
    required this.index,
    this.block,
    this.item,
  });

  final LessonStepKind kind;

  /// Position within the full step list (0-based).
  final int index;

  /// The source block for content / check steps (null for intro & result).
  final LessonBlock? block;

  /// The interactive item for [LessonStepKind.check] steps.
  final QuizItem? item;

  bool get isCheck => kind == LessonStepKind.check && item != null;
}

LessonStepKind _kindFor(BlockType type) => switch (type) {
      BlockType.hook => LessonStepKind.hook,
      BlockType.concept => LessonStepKind.concept,
      BlockType.example => LessonStepKind.example,
      BlockType.code => LessonStepKind.code,
      BlockType.recap => LessonStepKind.recap,
      // A check block with no item is malformed; degrade to read-only concept
      // so the flow never dead-ends.
      BlockType.check => LessonStepKind.concept,
      BlockType.unknown => LessonStepKind.concept,
    };

/// Flattens a [Lesson] into the ordered list of player steps:
/// intro → (one step per block) → result.
///
/// `check` blocks carrying a [QuizItem] become interactive steps; everything
/// else becomes a passive content step.
List<LessonStep> buildLessonSteps(Lesson lesson) {
  final List<LessonStep> steps = <LessonStep>[
    const LessonStep(kind: LessonStepKind.intro, index: 0),
  ];
  for (final LessonBlock block in lesson.blocks) {
    final bool isCheck = block.type == BlockType.check && block.check != null;
    steps.add(
      LessonStep(
        kind: isCheck ? LessonStepKind.check : _kindFor(block.type),
        index: steps.length,
        block: block,
        item: isCheck ? block.check : null,
      ),
    );
  }
  steps.add(LessonStep(kind: LessonStepKind.result, index: steps.length));
  return steps;
}
