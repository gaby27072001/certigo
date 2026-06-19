import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../application/check_outcome.dart';

/// Renders an inline comprehension check (the graded part of a lesson).
///
/// This is a *controlled* widget: the working [selection] and the post-grade
/// [outcome] are owned by the controller, so the same tap path works whether
/// the learner is choosing or reviewing their answer.
class CheckStepWidget extends StatelessWidget {
  const CheckStepWidget({
    super.key,
    required this.item,
    required this.selection,
    required this.outcome,
    required this.onToggle,
  });

  final QuizItem item;
  final List<String> selection;
  final CheckOutcome? outcome;
  final void Function(String optionId) onToggle;

  bool get _graded => outcome != null;

  QuizOptionState _stateFor(String optionId) {
    if (!_graded) {
      return selection.contains(optionId) ? QuizOptionState.selected : QuizOptionState.idle;
    }
    final bool isCorrect = outcome!.correctAnswer.contains(optionId);
    final bool picked = selection.contains(optionId);
    if (isCorrect && picked) return QuizOptionState.correct;
    if (isCorrect && !picked) return QuizOptionState.missed;
    if (!isCorrect && picked) return QuizOptionState.incorrect;
    return QuizOptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final bool multi = item.type == ItemType.multi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.psychology_rounded, color: p.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              'Vérifie ta compréhension',
              style: text.labelLarge?.copyWith(
                color: p.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(item.stem, style: text.titleLarge?.copyWith(height: 1.3)),
        if (multi) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Plusieurs réponses possibles',
            style: text.bodySmall?.copyWith(color: p.textSecondary),
          ),
        ],
        const SizedBox(height: 18),
        for (int i = 0; i < item.options.length; i++) ...<Widget>[
          QuizOptionTile(
            label: item.options[i].label,
            leading: String.fromCharCode(65 + i),
            state: _stateFor(item.options[i].id),
            onTap: _graded ? null : () => onToggle(item.options[i].id),
          ),
          if (i < item.options.length - 1) const SizedBox(height: 12),
        ],
        if (_graded) ...<Widget>[
          const SizedBox(height: 20),
          AnswerFeedbackCard(
            correct: outcome!.correct,
            explanation: outcome!.explanation,
          ),
        ],
      ],
    );
  }
}
