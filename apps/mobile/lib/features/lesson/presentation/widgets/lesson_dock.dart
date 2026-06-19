import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../application/lesson_session_state.dart';
import '../../application/lesson_step.dart';

/// Single persistent CTA that drives the whole lesson flow.
///
/// The label/action are derived from the current step: an unanswered check
/// shows "Valider" (disabled until something is selected); everything else
/// advances ("Commencer", "Continuer", or "Voir mon résultat").
class LessonDock extends StatelessWidget {
  const LessonDock({
    super.key,
    required this.state,
    required this.onValidate,
    required this.onAdvance,
  });

  final LessonSessionState state;
  final VoidCallback onValidate;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final LessonStep? step = state.current;
    if (step == null) return const SizedBox.shrink();

    final bool submitting = state.status == LessonStatus.submitting;
    final bool isCheck = step.kind == LessonStepKind.check && step.item != null;
    final bool validating = isCheck && !state.currentAnswered;

    final String label;
    final VoidCallback? onPressed;
    if (validating) {
      label = 'Valider';
      onPressed = state.selection.isEmpty ? null : onValidate;
    } else if (step.kind == LessonStepKind.intro) {
      label = 'Commencer';
      onPressed = onAdvance;
    } else if (state.nextIsResult) {
      label = 'Voir mon résultat';
      onPressed = onAdvance;
    } else {
      label = 'Continuer';
      onPressed = onAdvance;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: PrismButton(
        label: label,
        icon: validating ? Icons.check_rounded : Icons.arrow_forward_rounded,
        loading: submitting,
        onPressed: submitting ? null : onPressed,
      ),
    );
  }
}
