import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';

/// Visual + interaction states a quiz answer option can be in.
enum QuizOptionState {
  /// Default, not yet selected.
  idle,

  /// Selected by the user but not yet graded.
  selected,

  /// Graded — this option is the correct answer.
  correct,

  /// Graded — user picked this and it is wrong.
  incorrect,

  /// Graded — correct answer the user did NOT pick (revealed for learning).
  missed,
}

/// A single selectable answer in a quiz. Designed for comprehension feedback,
/// not just right/wrong: after grading, the *missed* correct answer is also
/// highlighted so the learner sees what they should have chosen.
class QuizOptionTile extends StatelessWidget {
  const QuizOptionTile({
    super.key,
    required this.label,
    required this.state,
    this.onTap,
    this.leading,
  });

  final String label;
  final QuizOptionState state;
  final VoidCallback? onTap;

  /// Optional leading glyph (A/B/C/D or an index chip).
  final String? leading;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final _OptionStyle s = _styleFor(p, state);
    final bool graded = state == QuizOptionState.correct ||
        state == QuizOptionState.incorrect ||
        state == QuizOptionState.missed;

    return Semantics(
      button: true,
      selected: state == QuizOptionState.selected,
      label: label,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!.call();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: s.fill,
            borderRadius: PrismRadii.cardMd,
            border: Border.all(color: s.border, width: s.borderWidth),
          ),
          child: Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                _LeadingChip(text: leading!, color: s.accent),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (graded) ...<Widget>[
                const SizedBox(width: 8),
                Icon(s.icon, color: s.accent, size: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _OptionStyle _styleFor(PrismColorScheme p, QuizOptionState st) {
    switch (st) {
      case QuizOptionState.idle:
        return _OptionStyle(
          fill: p.surface,
          border: p.border,
          borderWidth: 1,
          accent: p.textSecondary,
          icon: Icons.circle_outlined,
        );
      case QuizOptionState.selected:
        return _OptionStyle(
          fill: p.primarySoft,
          border: p.primary,
          borderWidth: 2,
          accent: p.primary,
          icon: Icons.radio_button_checked,
        );
      case QuizOptionState.correct:
        return _OptionStyle(
          fill: p.success.withOpacity(0.12),
          border: p.success,
          borderWidth: 2,
          accent: p.success,
          icon: Icons.check_circle_rounded,
        );
      case QuizOptionState.incorrect:
        return _OptionStyle(
          fill: p.error.withOpacity(0.12),
          border: p.error,
          borderWidth: 2,
          accent: p.error,
          icon: Icons.cancel_rounded,
        );
      case QuizOptionState.missed:
        return _OptionStyle(
          fill: p.success.withOpacity(0.06),
          border: p.success.withOpacity(0.5),
          borderWidth: 1.5,
          accent: p.success,
          icon: Icons.check_circle_outline_rounded,
        );
    }
  }
}

class _OptionStyle {
  const _OptionStyle({
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

class _LeadingChip extends StatelessWidget {
  const _LeadingChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: PrismRadii.cardSm),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
