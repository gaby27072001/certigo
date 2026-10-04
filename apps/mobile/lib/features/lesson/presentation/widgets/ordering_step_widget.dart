import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
    required this.onMove,
  });

  final QuizItem item;
  final List<String> selection;
  final CheckOutcome? outcome;
  final void Function(String optionId) onToggle;
  final void Function({required int fromIndex, required int toIndex}) onMove;

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
    final bool applied = item.type == ItemType.applied;
    final List<QuizOption> bank =
        item.options.where((QuizOption o) => !selection.contains(o.id)).toList();
    final String title = applied ? 'Construis la réponse appliquée' : 'Mets dans le bon ordre';
    final String instruction = applied
        ? 'Choisis les bonnes actions et range-les dans l\'ordre. Certaines sont des pièges.'
        : 'Place chaque élément dans le bon ordre.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.format_list_numbered_rounded, color: p.primary, size: 18),
            const SizedBox(width: PrismSpacing.xs),
            Flexible(
              child: Text(
                title,
                style: text.labelLarge?.copyWith(color: p.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: PrismSpacing.sm),
        Text(item.stem, style: text.titleLarge?.copyWith(height: 1.3)),
        const SizedBox(height: PrismSpacing.xs),
        Text(instruction, style: text.bodyMedium?.copyWith(color: p.textSecondary, height: 1.35)),
        if (applied && !_graded) ...<Widget>[
          const SizedBox(height: PrismSpacing.xs),
          Text(
            selection.length < 2
                ? 'Place au moins 2 étapes pour valider.'
                : '${selection.length} étapes placées : tu peux valider ou continuer à ajuster.',
            style: text.bodySmall?.copyWith(
              color: selection.length < 2 ? p.textSecondary : p.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: PrismSpacing.lg),
        _SectionLabel(text: 'Tes étapes, dans l\'ordre', color: p.textSecondary),
        const SizedBox(height: PrismSpacing.xs),
        _AnswerTray(
          empty: selection.isEmpty,
          child: Wrap(
            spacing: PrismSpacing.xs,
            runSpacing: PrismSpacing.xs,
            children: <Widget>[
              for (int i = 0; i < selection.length; i++)
                _PlacedStepChip(
                  key: Key('placed-step-${selection[i]}'),
                  label: _labelFor(selection[i]),
                  position: i + 1,
                  total: selection.length,
                  state: _placedState(i, selection[i]),
                  enabled: !_graded,
                  onRemove: () => onToggle(selection[i]),
                  onMoveUp: i == 0 ? null : () => onMove(fromIndex: i, toIndex: i - 1),
                  onMoveDown:
                      i == selection.length - 1 ? null : () => onMove(fromIndex: i, toIndex: i + 1),
                ),
            ],
          ),
        ),
        if (bank.isNotEmpty && !_graded) ...<Widget>[
          const SizedBox(height: PrismSpacing.lg),
          _SectionLabel(text: 'Actions disponibles', color: p.textSecondary),
          const SizedBox(height: PrismSpacing.xs),
          Wrap(
            spacing: PrismSpacing.xs,
            runSpacing: PrismSpacing.xs,
            children: <Widget>[
              for (final QuizOption o in bank)
                _AvailableActionChip(
                  key: Key('available-action-${o.id}'),
                  label: o.label,
                  onAdd: () => onToggle(o.id),
                ),
            ],
          ),
        ],
        if (_graded) ...<Widget>[
          if (!outcome!.correct) ...<Widget>[
            const SizedBox(height: PrismSpacing.lg),
            _SectionLabel(text: 'Ordre attendu', color: p.success),
            const SizedBox(height: PrismSpacing.xs),
            Wrap(
              spacing: PrismSpacing.xs,
              runSpacing: PrismSpacing.xs,
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
          const SizedBox(height: PrismSpacing.gutter),
          AnswerFeedbackCard(correct: outcome!.correct, explanation: outcome!.explanation),
        ],
      ],
    );
  }
}

class _PlacedStepChip extends StatelessWidget {
  const _PlacedStepChip({
    super.key,
    required this.label,
    required this.position,
    required this.total,
    required this.state,
    required this.enabled,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final String label;
  final int position;
  final int total;
  final QuizOptionState state;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final Map<CustomSemanticsAction, VoidCallback> actions =
        <CustomSemanticsAction, VoidCallback>{};
    if (enabled) {
      if (onMoveUp != null) {
        actions[const CustomSemanticsAction(label: 'Monter')] = onMoveUp!;
      }
      if (onMoveDown != null) {
        actions[const CustomSemanticsAction(label: 'Descendre')] = onMoveDown!;
      }
      actions[const CustomSemanticsAction(label: 'Retirer')] = onRemove;
    }

    return Semantics(
      button: enabled,
      selected: true,
      label: 'Étape $position sur $total : $label',
      onTap: enabled ? onRemove : null,
      customSemanticsActions: actions,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: AnswerChip(
            label: label,
            order: position,
            state: state,
            onTap: enabled ? onRemove : null,
          ),
        ),
      ),
    );
  }
}

class _AvailableActionChip extends StatelessWidget {
  const _AvailableActionChip({super.key, required this.label, required this.onAdd});

  final String label;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Action disponible : $label. Peut être ajoutée.',
      onTap: onAdd,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: AnswerChip(
            label: label,
            state: QuizOptionState.idle,
            onTap: onAdd,
          ),
        ),
      ),
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
