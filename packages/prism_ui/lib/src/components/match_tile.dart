import 'package:flutter/material.dart';
import '../feedback/prism_haptics.dart';
import '../theme/prism_color_scheme.dart';
import '../tokens/prism_motion.dart';
import '../tokens/prism_radii.dart';
import 'quiz_option_tile.dart';

/// One tappable card in a `matchPairs` exercise (a concept on the left or a
/// definition on the right).
///
/// The parent owns pairing logic; this widget only renders a [state] plus an
/// optional connection [badge] (a colored number that visually links the two
/// halves of a formed pair). Reusing [QuizOptionState] keeps graded coloring
/// consistent with every other exercise type.
class MatchTile extends StatelessWidget {
  const MatchTile({
    super.key,
    required this.label,
    required this.state,
    this.onTap,
    this.badge,
    this.badgeColor,
  });

  final String label;
  final QuizOptionState state;
  final VoidCallback? onTap;

  /// Connection number shared by both halves of a pair (`null` when unpaired).
  final int? badge;

  /// Color of the [badge] — the parent assigns a distinct hue per pair so the
  /// two linked tiles read as belonging together.
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final _TileStyle s = _styleFor(p, state);
    final bool graded = state == QuizOptionState.correct ||
        state == QuizOptionState.incorrect ||
        state == QuizOptionState.missed;
    final Color badgeColor = this.badgeColor ?? p.primary;

    return Semantics(
      button: true,
      selected: state == QuizOptionState.selected,
      label: badge != null ? '$label, paire $badge' : label,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                PrismHaptics.selection();
                onTap!.call();
              },
        child: AnimatedContainer(
          duration: PrismMotion.resolve(context, PrismMotion.fast),
          curve: PrismMotion.standard,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: s.fill,
            borderRadius: PrismRadii.cardMd,
            border: Border.all(color: s.border, width: s.borderWidth),
          ),
          child: Row(
            children: <Widget>[
              if (badge != null) ...<Widget>[
                _PairBadge(value: badge!, color: badgeColor),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (graded) ...<Widget>[
                const SizedBox(width: 6),
                Icon(s.icon, color: s.accent, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _TileStyle _styleFor(PrismColorScheme p, QuizOptionState st) {
    switch (st) {
      case QuizOptionState.idle:
        return _TileStyle(
          fill: p.surface,
          border: p.border,
          borderWidth: 1,
          accent: p.textSecondary,
          icon: Icons.circle_outlined,
        );
      case QuizOptionState.selected:
        return _TileStyle(
          fill: p.primarySoft,
          border: p.primary,
          borderWidth: 2,
          accent: p.primary,
          icon: Icons.radio_button_checked,
        );
      case QuizOptionState.correct:
        return _TileStyle(
          fill: p.success.withOpacity(0.12),
          border: p.success,
          borderWidth: 2,
          accent: p.success,
          icon: Icons.check_circle_rounded,
        );
      case QuizOptionState.incorrect:
        return _TileStyle(
          fill: p.error.withOpacity(0.12),
          border: p.error,
          borderWidth: 2,
          accent: p.error,
          icon: Icons.cancel_rounded,
        );
      case QuizOptionState.missed:
        return _TileStyle(
          fill: p.success.withOpacity(0.06),
          border: p.success.withOpacity(0.5),
          borderWidth: 1.5,
          accent: p.success,
          icon: Icons.check_circle_outline_rounded,
        );
    }
  }
}

class _TileStyle {
  const _TileStyle({
    required this.fill,
    required this.border,
    required this.borderWidth,
    required this.accent,
    required this.icon,
  });

  final Color fill;
  final Color border;
  final double borderWidth;
  final Color accent;
  final IconData icon;
}

class _PairBadge extends StatelessWidget {
  const _PairBadge({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        '$value',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }
}
