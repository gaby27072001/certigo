import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../application/lesson_session_state.dart';
import '../../application/lesson_step.dart';
import 'check_step_widget.dart';
import 'cloze_step_widget.dart';
import 'lesson_intro_view.dart';
import 'match_pairs_step_widget.dart';
import 'ordering_step_widget.dart';

/// Renders the body of the current lesson step by delegating to the right Prism
/// pedagogical block. The synthetic `result` step is rendered by `LessonScreen`
/// (it needs routing), so here it is a deliberate no-op.
class StepRenderer extends StatelessWidget {
  const StepRenderer({
    super.key,
    required this.state,
    required this.onToggleOption,
    required this.onToggleMatch,
  });

  final LessonSessionState state;
  final void Function(String optionId) onToggleOption;
  final void Function(String leftId, String rightId) onToggleMatch;

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
      LessonStepKind.check => _buildCheck(step.item!),
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

  /// Dispatches a comprehension check to the interaction widget that matches the
  /// item's [ItemType]. Every variant funnels its answer back through the same
  /// controller (`onToggleOption` for id lists, `onToggleMatch` for pairs).
  Widget _buildCheck(QuizItem item) {
    switch (item.type) {
      case ItemType.ordering:
      case ItemType.applied:
        return OrderingStepWidget(
          item: item,
          selection: state.selection,
          outcome: state.currentOutcome,
          onToggle: onToggleOption,
        );
      case ItemType.cloze:
        return ClozeStepWidget(
          item: item,
          selection: state.selection,
          outcome: state.currentOutcome,
          onToggle: onToggleOption,
        );
      case ItemType.matchPairs:
        return MatchPairsStepWidget(
          item: item,
          selection: state.selection,
          outcome: state.currentOutcome,
          onToggleMatch: onToggleMatch,
        );
      case ItemType.mcq:
      case ItemType.multi:
      case ItemType.scenario:
      case ItemType.spotTheIssue:
      case ItemType.unknown:
        return CheckStepWidget(
          item: item,
          selection: state.selection,
          outcome: state.currentOutcome,
          onToggle: onToggleOption,
        );
    }
  }
}
