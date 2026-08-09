import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';

/// Lifecycle state of a lesson within a learning path.
///
/// Drives the leading icon, accent color and interactivity of [LessonTile].
enum LessonTileStatus {
  /// Prerequisites not met — not tappable.
  locked,

  /// Unlocked and ready to start.
  available,

  /// Started but not finished.
  inProgress,

  /// Finished at least once.
  completed,

  /// Completed and the underlying concepts are mastered (spaced-repetition).
  mastered,
}

/// A reusable row representing a single lesson in a unit / learning path.
///
/// Encodes the lesson's [status] (icon + color), title, an optional [subtitle]
/// (e.g. concept count) and estimated [minutes]. Locked lessons are visually
/// dimmed and ignore taps. This is the shared building block for the Path
/// screen and any "continue / up next" surfaces.
class LessonTile extends StatelessWidget {
  const LessonTile({
    super.key,
    required this.title,
    required this.status,
    this.subtitle,
    this.minutes,
    this.onTap,
  });

  final String title;
  final LessonTileStatus status;

  /// Optional secondary line (e.g. "3 concepts").
  final String? subtitle;

  /// Estimated duration; shown as "N min" when the lesson is reachable.
  final int? minutes;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final bool locked = status == LessonTileStatus.locked;
    final (IconData icon, Color color) = _visual(p);

    return Semantics(
      button: !locked,
      enabled: !locked,
      label: '$title — ${_statusLabel()}',
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: PrismRadii.cardSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: t.bodyLarge?.copyWith(
                        color: locked ? p.textSecondary : p.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: t.labelSmall?.copyWith(color: p.textSecondary)),
                  ],
                ),
              ),
              if (!locked && minutes != null)
                Text('$minutes min', style: t.labelSmall?.copyWith(color: p.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _visual(PrismColorScheme p) {
    return switch (status) {
      LessonTileStatus.mastered => (Icons.workspace_premium_rounded, p.xpGold),
      LessonTileStatus.completed => (Icons.check_circle_rounded, p.success),
      LessonTileStatus.inProgress => (Icons.pending_rounded, p.primary),
      LessonTileStatus.available => (Icons.play_circle_fill_rounded, p.primary),
      LessonTileStatus.locked => (Icons.lock_rounded, p.textSecondary),
    };
  }

  String _statusLabel() {
    return switch (status) {
      LessonTileStatus.mastered => 'maîtrisée',
      LessonTileStatus.completed => 'terminée',
      LessonTileStatus.inProgress => 'en cours',
      LessonTileStatus.available => 'disponible',
      LessonTileStatus.locked => 'verrouillée',
    };
  }
}
