import 'package:flutter/widgets.dart';

/// A small "signal strength" glyph — ascending bars where the first [level]
/// bars are filled with [color] and the rest are muted.
///
/// Used as the leading art on the knowledge-level tiles so a growing knowledge
/// reads at a glance (1 bar = beginner … 4 bars = expert), the way a signal
/// meter conveys strength.
class SignalBars extends StatelessWidget {
  const SignalBars({
    super.key,
    required this.level,
    required this.color,
    this.total = 4,
    this.inactiveColor,
    this.size = 26,
  });

  /// Number of filled bars (1-based), clamped to [total].
  final int level;

  /// Total number of bars drawn.
  final int total;

  final Color color;
  final Color? inactiveColor;

  /// Target square extent of the glyph.
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color inactive = inactiveColor ?? color.withOpacity(0.22);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SignalBarsPainter(
          level: level.clamp(0, total),
          total: total,
          active: color,
          inactive: inactive,
        ),
      ),
    );
  }
}

class _SignalBarsPainter extends CustomPainter {
  const _SignalBarsPainter({
    required this.level,
    required this.total,
    required this.active,
    required this.inactive,
  });

  final int level;
  final int total;
  final Color active;
  final Color inactive;

  @override
  void paint(Canvas canvas, Size size) {
    final double gap = size.width * 0.12;
    final double barWidth = (size.width - gap * (total - 1)) / total;
    final double radius = barWidth * 0.4;

    for (int i = 0; i < total; i++) {
      // Bars grow from ~35% to 100% of the height.
      final double factor = 0.35 + 0.65 * (i / (total - 1));
      final double barHeight = size.height * factor;
      final double left = i * (barWidth + gap);
      final double top = size.height - barHeight;
      final Rect rect = Rect.fromLTWH(left, top, barWidth, barHeight);
      final Paint paint = Paint()..color = i < level ? active : inactive;
      canvas.drawRRect(RRect.fromRectXY(rect, radius, radius), paint);
    }
  }

  @override
  bool shouldRepaint(_SignalBarsPainter old) =>
      old.level != level || old.total != total || old.active != active || old.inactive != inactive;
}
