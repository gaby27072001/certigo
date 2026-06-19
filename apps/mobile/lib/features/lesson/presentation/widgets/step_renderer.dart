import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../application/lesson_session_state.dart';
import '../../application/lesson_step.dart';
import 'check_step_widget.dart';
import 'lesson_intro_view.dart';

/// Renders the body of the current lesson step by delegating to the right Prism
/// pedagogical block. The synthetic `result` step is rendered by `LessonScreen`
/// (it needs routing), so here it is a deliberate no-op.
class StepRenderer extends StatelessWidget {
  const StepRenderer({
    super.key,
    required this.state,
    required this.onToggleOption,
  });

  final LessonSessionState state;
  final void Function(String optionId) onToggleOption;

  @override
  Widget build(BuildContext context) {
    final LessonStep? step = state.current;
    final Lesson? lesson = state.lesson;
    if (step == null || lesson == null) return const SizedBox.shrink();
    final LessonBlock? block = step.block;

    final Widget content = switch (step.kind) {
      LessonStepKind.intro => LessonIntroView(lesson: lesson),
      LessonStepKind.hook => HookBlock(text: block?.body ?? ''),
      LessonStepKind.concept => ConceptBlock(title: block?.title, body: block?.body ?? ''),
      LessonStepKind.example => ScenarioBlock(body: block?.body ?? ''),
      LessonStepKind.code => CodeBlock(code: block?.code ?? '', language: block?.language),
      LessonStepKind.recap => KeyTakeawayBlock(body: block?.body ?? ''),
      LessonStepKind.check => CheckStepWidget(
          item: step.item!,
          selection: state.selection,
          outcome: state.currentOutcome,
          onToggle: onToggleOption,
        ),
      LessonStepKind.quiz => const CalloutBlock(
          kind: CalloutKind.info,
          title: 'Checkpoint',
          text: 'Le checkpoint d\'unité arrive bientôt.',
        ),
      LessonStepKind.result => const SizedBox.shrink(),
    };

    return ListView(
      padding: PrismSpacing.screen,
      physics: const BouncingScrollPhysics(),
      children: <Widget>[content],
    );
  }
}
