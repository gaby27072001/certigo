import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../application/check_outcome.dart';

/// Renders an `ordering` (or `applied`) check: the learner arranges step chips
/// into the correct sequence. The **order is the answer**, so grading is
/// position-sensitive.
///
/// Controlled widget — the working order ([selection]) and post-grade [outcome]
/// live in the controller. Tapping a bank chip appends it to the answer; tapping
/// a placed chip returns it to the bank (both via [onToggle]).
class OrderingStepWidget extends StatelessWidget {
  const OrderingStepWidget({
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

  String _labelFor(String id) {
    for (final QuizOption o in item.options) {
      if (o.id == id) return o.label;
    }
    return id;
  }

  /// Position-aware state for a placed chip at [index].
  QuizOptionState _placedState(int index, String id) {
    if (!_graded) return QuizOptionState.selected;
    final List<String> correct = outcome!.correctAnswer;
    if (index < correct.length && correct[index] == id) {
      return QuizOptionState.correct;
    }
    return QuizOptionState.incorrect;
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final List<QuizOption> bank =
        item.options.where((QuizOption o) => !selection.contains(o.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.format_list_numbered_rounded, color: p.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              'Mets dans le bon ordre',
              style: text.labelLarge?.copyWith(color: p.primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(item.stem, style: text.titleLarge?.copyWith(height: 1.3)),
        const SizedBox(height: 18),
        _SectionLabel(text: 'Ta séquence', color: p.textSecondary),
        const SizedBox(height: 10),
        _AnswerTray(
          empty: selection.isEmpty,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (int i = 0; i < selection.length; i++)
                AnswerChip(
                  label: _labelFor(selection[i]),
                  order: i + 1,
                  state: _placedState(i, selection[i]),
                  onTap: _graded ? null : () => onToggle(selection[i]),
                ),
            ],
          ),
        ),
        if (bank.isNotEmpty && !_graded) ...<Widget>[
          const SizedBox(height: 18),
          _SectionLabel(text: 'À placer', color: p.textSecondary),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final QuizOption o in bank)
                AnswerChip(
                  label: o.label,
                  state: QuizOptionState.idle,
                  onTap: () => onToggle(o.id),
                ),
            ],
          ),
        ],
        if (_graded) ...<Widget>[
          if (!outcome!.correct) ...<Widget>[
            const SizedBox(height: 18),
            _SectionLabel(text: 'Ordre attendu', color: p.success),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (int i = 0; i < outcome!.correctAnswer.length; i++)
                  AnswerChip(
                    label: _labelFor(outcome!.correctAnswer[i]),
                    order: i + 1,
                    state: QuizOptionState.correct,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          AnswerFeedbackCard(correct: outcome!.correct, explanation: outcome!.explanation),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
    );
  }
}

/// A soft dashed-feel container that frames the building answer, with a hint
/// when nothing has been placed yet.
class _AnswerTray extends StatelessWidget {
  const _AnswerTray({required this.empty, required this.child});

  final bool empty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.all(PrismSpacing.debt14),
      decoration: BoxDecoration(
        color: p.surfaceAlt.withOpacity(0.5),
        borderRadius: PrismRadii.cardLg,
        border: Border.all(color: p.border),
      ),
      child: empty
          ? Text(
              'Touche un élément ci-dessous pour le placer ici.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: p.textSecondary),
            )
          : child,
    );
  }
}
