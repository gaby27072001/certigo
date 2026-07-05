import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../application/quiz_entry.dart';

class FeedbackCard extends StatelessWidget {
  const FeedbackCard({super.key, required this.item});
  final QuizEntry item;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    if (!item.hasLocalCorrection) {
      return PrismCard(
        variant: PrismCardVariant.tonal,
        accent: p.primary,
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.info_outline_rounded, color: p.primary),
                const SizedBox(width: 8),
                Text('Réponse enregistrée', style: t.titleMedium?.copyWith(color: p.primary)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Le corrigé détaillé sera affiché après la soumission.',
              style: t.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ),
      );
    }
    final bool ok = item.lastAnswerCorrect;
    final Color accent = ok ? p.success : p.error;
    return PrismCard(
      variant: PrismCardVariant.tonal,
      accent: accent,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(ok ? Icons.check_circle_rounded : Icons.school_rounded, color: accent),
              const SizedBox(width: 8),
              Text(ok ? 'Bien vu' : 'À clarifier', style: t.titleMedium?.copyWith(color: accent)),
            ],
          ),
          const SizedBox(height: 8),
          PrismRichText(item.explanation!, style: t.bodyLarge?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
