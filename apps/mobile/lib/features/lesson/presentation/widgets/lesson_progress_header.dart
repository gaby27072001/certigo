import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

/// Slim top bar for the lesson player: a close affordance, the reading
/// progress and the remaining time estimate.
class LessonProgressHeader extends StatelessWidget {
  const LessonProgressHeader({
    super.key,
    required this.progress,
    required this.minutes,
    required this.onClose,
  });

  final double progress;
  final int minutes;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.xs,
        PrismSpacing.xxs,
        PrismSpacing.gutter,
        PrismSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: p.textSecondary,
            onPressed: onClose,
            tooltip: 'Quitter la leçon',
          ),
          Expanded(
            child: PrismProgressBar(
              value: progress.clamp(0.0, 1.0),
              height: 8,
              semanticLabel: 'Progression de la leçon',
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.schedule_rounded, size: 15, color: p.textSecondary),
          const SizedBox(width: 4),
          Text('$minutes min', style: text.labelMedium?.copyWith(color: p.textSecondary)),
        ],
      ),
    );
  }
}
