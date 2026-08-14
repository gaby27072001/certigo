import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import 'prism_card.dart';
import 'prism_rich_text.dart';

/// Post-answer explanatory feedback — the heart of "learning, not testing".
///
/// Shown after a check is graded: a clear verdict header plus the *why*. Tinted
/// success / error so the learner gets instant affective feedback, but the
/// explanation always reads regardless of right or wrong — that is what builds
/// real comprehension and corrects misconceptions.
class AnswerFeedbackCard extends StatelessWidget {
  const AnswerFeedbackCard({
    super.key,
    required this.correct,
    required this.explanation,
    this.correctTitle = 'Bien vu',
    this.incorrectTitle = 'À clarifier',
  });

  final bool correct;
  final String explanation;
  final String correctTitle;
  final String incorrectTitle;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final Color color = correct ? p.success : p.error;
    return PrismCard(
      variant: PrismCardVariant.tonal,
      accent: color,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(correct ? Icons.verified_rounded : Icons.info_rounded, color: color),
              const SizedBox(width: 8),
              Text(
                correct ? correctTitle : incorrectTitle,
                style: t.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PrismRichText(explanation, style: t.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
