import 'package:flutter/material.dart';
import '../feedback/prism_haptics.dart';
import '../theme/prism_color_scheme.dart';
import '../tokens/prism_motion.dart';
import '../tokens/prism_radii.dart';
import 'quiz_option_tile.dart';

/// A compact, tappable pill for word-bank and ordering exercises.
///
/// Shares [QuizOptionState] with [QuizOptionTile] so graded coloring is
/// identical across every exercise type:
/// * **idle** — sitting in the bank, available to place;
/// * **selected** — placed into the answer (optionally numbered via [order]);
/// * **correct / incorrect / missed** — revealed after grading.
///
/// Fires a selection haptic on tap (iOS + Android) and animates state changes,
/// keeping interactions "juicy" without per-screen boilerplate.
class AnswerChip extends StatelessWidget {
  const AnswerChip({super.key, required this.label, required this.state, this.onTap, this.order});

  final String label;
  final QuizOptionState state;
  final VoidCallback? onTap;

  /// 1-based position shown as a leading badge when this chip is placed in an
  /// ordered answer (ordering / cloze). `null` hides the badge.
  final int? order;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final _ChipStyle s = _styleFor(p, state);
    final bool graded = state == QuizOptionState.correct ||
        state == QuizOptionState.incorrect ||
        state == QuizOptionState.missed;

    return Semantics(
      button: true,
      selected: state == QuizOptionState.selected,
      label: order != null ? '$order. $label' : label,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: s.fill,
            borderRadius: PrismRadii.pillAll,
            border: Border.all(color: s.border, width: s.borderWidth),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (order != null) ...<Widget>[
                _OrderBadge(order: order!, color: s.accent),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w700,
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

  _ChipStyle _styleFor(PrismColorScheme p, QuizOptionState st) {
    switch (st) {
      case QuizOptionState.idle:
        return _ChipStyle(
          fill: p.surfaceAlt,
          border: p.border,
          borderWidth: 1,
          accent: p.textSecondary,
          icon: Icons.circle_outlined,
        );
      case QuizOptionState.selected:
        return _ChipStyle(
          fill: p.primarySoft,
          border: p.primary,
          borderWidth: 2,
          accent: p.primary,
          icon: Icons.radio_button_checked,
        );
      case QuizOptionState.correct:
        return _ChipStyle(
          fill: p.success.withOpacity(0.14),
          border: p.success,
          borderWidth: 2,
          accent: p.success,
          icon: Icons.check_circle_rounded,
        );
      case QuizOptionState.incorrect:
        return _ChipStyle(
          fill: p.error.withOpacity(0.14),
          border: p.error,
          borderWidth: 2,
          accent: p.error,
          icon: Icons.cancel_rounded,
        );
      case QuizOptionState.missed:
        return _ChipStyle(
          fill: p.success.withOpacity(0.06),
          border: p.success.withOpacity(0.5),
          borderWidth: 1.5,
          accent: p.success,
          icon: Icons.check_circle_outline_rounded,
        );
    }
  }
}

class _ChipStyle {
  const _ChipStyle({
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

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.order, required this.color});

  final int order;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withOpacity(0.16), shape: BoxShape.circle),
      child: Text(
        '$order',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
