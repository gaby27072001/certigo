import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_motion.dart';
import '../tokens/prism_radii.dart';

/// A premium, animated linear progress bar — the horizontal counterpart to
/// [ReadinessGauge].
///
/// The track reads as a soft glass groove; the fill is a brand gradient that
/// animates to [value] whenever it changes, so progress always feels earned.
/// Used for daily-goal XP, exam-domain readiness and lesson progress.
class PrismProgressBar extends StatelessWidget {
  const PrismProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.gradient,
    this.trackColor,
    this.semanticLabel,
  }) : assert(value >= 0 && value <= 1, 'value must be 0..1');

  /// Progress in the 0..1 range.
  final double value;

  /// Thickness of the bar.
  final double height;

  /// Fill gradient. Defaults to the primary brand ramp.
  final List<Color>? gradient;

  /// Track (unfilled) color. Defaults to [PrismColorScheme.surfaceAlt].
  final Color? trackColor;

  /// Optional accessibility label describing what is progressing.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final double clamped = value.clamp(0.0, 1.0);
    final List<Color> colors = gradient ?? <Color>[p.primary, p.primaryDark];

    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()}%',
      child: ClipRRect(
        borderRadius: PrismRadii.pillAll,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(color: trackColor ?? p.surfaceAlt),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: clamped),
                duration: PrismMotion.slow,
                curve: PrismMotion.standard,
                builder: (BuildContext context, double v, _) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: v.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: colors),
                          borderRadius: PrismRadii.pillAll,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
