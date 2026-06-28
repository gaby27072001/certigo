import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/prism_color_scheme.dart';

/// The hero progress signature of Certigo: a 270° arc gauge that renders a
/// track's **Readiness Score** (0–100, the product's North-Star metric).
///
/// The arc fills with a brand gradient and animates from the previous value so
/// progress feels earned. A center slot shows the score and an optional label.
class ReadinessGauge extends StatelessWidget {
  const ReadinessGauge({
    super.key,
    required this.score,
    this.label = 'Préparation',
    this.size = 168,
    this.previousScore,
  }) : assert(score >= 0 && score <= 100);

  /// Current readiness score, 0–100.
  final int score;

  /// Caption rendered under the number.
  final String label;
  final double size;

  /// If provided, the gauge animates from this value to [score].
  final int? previousScore;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final Color zone = _zoneColor(p, score);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: (previousScore ?? score).toDouble(),
        end: score.toDouble(),
      ),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GaugePainter(
              value: value / 100,
              track: p.surfaceAlt,
              gradient: <Color>[p.primary, zone],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    value.round().toString(),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    label,
                    style:
                        Theme.of(context).textTheme.labelMedium?.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Color _zoneColor(PrismColorScheme p, int score) {
    if (score >= 75) return p.success;
    if (score >= 45) return p.xpGold;
    return p.ember;
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.track,
    required this.gradient,
  });

  final double value; // 0..1
  final Color track;
  final List<Color> gradient;

  static const double _startAngle = math.pi * 0.75; // 135°
  static const double _sweep = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2 - 10;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, _startAngle, _sweep, false, base);

    final Paint progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + _sweep,
        colors: gradient,
      ).createShader(rect);
    canvas.drawArc(rect, _startAngle, _sweep * value.clamp(0, 1), false, progress);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value || old.track != track;
}
