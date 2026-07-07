import 'package:data/data.dart';
import 'package:prism_ui/prism_ui.dart';

import 'lesson_step.dart';

/// Feature flag for the dynamic content renderer (ADR-003).
///
/// When `true`, passive content steps (hook / concept / example / code / recap)
/// are rendered through [lessonRendererRegistry], which guarantees a visible
/// fallback for unknown block types, malformed data or an unsupported
/// `schemaVersion` — the player never crashes on bad content.
///
/// Flip this to `false` to roll back to the frozen static switch in
/// `StepRenderer` (the pre-ADR-003 behaviour) without touching any other code.
const bool kUseDynamicRenderer = true;

/// The app-wide registry wiring content block `type`s to the Prism pedagogical
/// widgets. Built once from the standard renderers shipped by `prism_ui`.
final RendererRegistry lessonRendererRegistry = standardRendererRegistry();

/// Whether [kind] is a passive content step eligible for the dynamic renderer.
///
/// Interactive / synthetic kinds ([LessonStepKind.intro],
/// [LessonStepKind.check], [LessonStepKind.quiz], [LessonStepKind.result]) keep
/// their bespoke widgets and are intentionally excluded.
bool isDynamicContentKind(LessonStepKind kind) => switch (kind) {
      LessonStepKind.hook ||
      LessonStepKind.concept ||
      LessonStepKind.example ||
      LessonStepKind.code ||
      LessonStepKind.recap =>
        true,
      LessonStepKind.intro ||
      LessonStepKind.check ||
      LessonStepKind.quiz ||
      LessonStepKind.result =>
        false,
    };

/// The registered content block `type` for a passive [kind].
///
/// Anything that is not a known passive kind maps to `'unknown'`, which the
/// registry resolves to a visible fallback rather than a crash.
String dynamicBlockType(LessonStepKind kind) => switch (kind) {
      LessonStepKind.hook => 'hook',
      LessonStepKind.concept => 'concept',
      LessonStepKind.example => 'example',
      LessonStepKind.code => 'code',
      LessonStepKind.recap => 'recap',
      LessonStepKind.intro ||
      LessonStepKind.check ||
      LessonStepKind.quiz ||
      LessonStepKind.result =>
        'unknown',
    };

/// Projects a [LessonStep] onto the schema-tagged [ContentBlock] consumed by
/// [lessonRendererRegistry].
///
/// Only fields that are present on the source [LessonBlock] are copied; missing
/// required fields (e.g. an empty `body`) surface downstream as a fallback via
/// the renderer's `requireString` guard rather than an exception here.
ContentBlock contentBlockFor(LessonStep step) {
  final LessonBlock? block = step.block;
  return ContentBlock(
    type: dynamicBlockType(step.kind),
    data: <String, dynamic>{
      if (block?.title != null) 'title': block!.title,
      if (block?.body != null) 'body': block!.body,
      if (block?.code != null) 'code': block!.code,
      if (block?.language != null) 'language': block!.language,
    },
  );
}
