import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../application/answer_grading.dart';
import '../../application/check_outcome.dart';

/// Renders a `cloze` check: a sentence with one or more blanks the learner
/// fills from a word bank (which may include distractors). The blanks are
/// **positional and ordered**, so grading is order-sensitive.
///
/// Controlled widget — tapping a bank word drops it into the next empty blank;
/// tapping a filled blank returns the word to the bank (both via [onToggle]).
class ClozeStepWidget extends StatelessWidget {
  const ClozeStepWidget({
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

  QuizOptionState _blankState(int index, String id) {
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
    final List<String> segments = clozeSegments(item.stem);
    final int blanks = segments.length - 1;
    final List<QuizOption> bank =
        item.options.where((QuizOption o) => !selection.contains(o.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.short_text_rounded, color: p.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              'Complète la phrase',
              style: text.labelLarge?.copyWith(
                color: p.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 12,
          children: <Widget>[
            for (int s = 0; s < segments.length; s++) ...<Widget>[
              ..._words(context, segments[s]),
              if (s < blanks)
                if (s < selection.length)
                  AnswerChip(
                    label: _labelFor(selection[s]),
                    state: _blankState(s, selection[s]),
                    onTap: _graded ? null : () => onToggle(selection[s]),
                  )
                else
                  const _EmptyBlank(),
            ],
          ],
        ),
        if (bank.isNotEmpty && !_graded) ...<Widget>[
          const SizedBox(height: 22),
          Text(
            'BANQUE DE MOTS',
            style: text.labelSmall?.copyWith(
              color: p.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
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
            Text(
              'RÉPONSE ATTENDUE',
              style: text.labelSmall?.copyWith(
                color: p.success,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
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
          AnswerFeedbackCard(
            correct: outcome!.correct,
            explanation: outcome!.explanation,
          ),
        ],
      ],
    );
  }

  /// Splits a literal stem segment into word [Text] widgets so the sentence
  /// reflows naturally inside the [Wrap] around the blank slots.
  List<Widget> _words(BuildContext context, String segment) {
    final TextStyle? style =
        Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.4, fontWeight: FontWeight.w500);
    return <Widget>[
      for (final String w in segment.split(RegExp(r'\s+')))
        if (w.isNotEmpty) Text(w, style: style),
    ];
  }
}

/// An unfilled blank — a soft underlined slot awaiting a word.
class _EmptyBlank extends StatelessWidget {
  const _EmptyBlank();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return Container(
      constraints: const BoxConstraints(minWidth: 64),
      height: 38,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: p.primarySoft.withOpacity(0.35),
        borderRadius: PrismRadii.pillAll,
        border: Border.all(color: p.primary.withOpacity(0.45), width: 1.5),
      ),
      child: Icon(Icons.add_rounded, size: 18, color: p.primary.withOpacity(0.7)),
    );
  }
}
