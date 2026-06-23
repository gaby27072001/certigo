import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';

/// Where a [SpeechBubble]'s little tail points — toward the mascot it belongs to.
enum SpeechTail { none, down, left, up, right }

/// A rounded "speech bubble" that pairs copy with a mascot, the signature
/// onboarding/coaching device of a playful learning app.
///
/// One [CustomPaint] draws the rounded body **and** the tail as a single shape,
/// so a bordered bubble has no seam where the tail meets the body. Reserves
/// layout space on the tail side so the tail never overlaps neighbouring widgets.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.child,
    this.tail = SpeechTail.down,
    this.tailAlignment = 0.5,
    this.background,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.radius = 20,
    this.tailSize = 11,
    this.maxWidth,
  });

  final Widget child;

  /// Direction the tail points; [SpeechTail.none] renders a plain bubble.
  final SpeechTail tail;

  /// Position of the tail along its edge, 0..1 (0 = start, 1 = end).
  final double tailAlignment;

  final Color? background;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double tailSize;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final Color bg = background ?? p.surface;
    final Color border = borderColor ?? p.border;

    // Reserve room on the tail side so the painted tail sits outside the body.
    final EdgeInsets reserve = switch (tail) {
      SpeechTail.down => EdgeInsets.only(bottom: tailSize),
      SpeechTail.up => EdgeInsets.only(top: tailSize),
      SpeechTail.left => EdgeInsets.only(left: tailSize),
      SpeechTail.right => EdgeInsets.only(right: tailSize),
      SpeechTail.none => EdgeInsets.zero,
    };

    Widget bubble = CustomPaint(
      painter: _BubblePainter(
        tail: tail,
        tailAlignment: tailAlignment.clamp(0.12, 0.88),
        background: bg,
        border: border,
        radius: radius,
        tailSize: tailSize,
      ),
      child: Padding(
        padding: padding.add(reserve),
        child: child,
      ),
    );

    if (maxWidth != null) {
      bubble = ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth!), child: bubble);
    }
    return bubble;
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter({
    required this.tail,
    required this.tailAlignment,
    required this.background,
    required this.border,
    required this.radius,
    required this.tailSize,
  });

  final SpeechTail tail;
  final double tailAlignment;
  final Color background;
  final Color border;
  final double radius;
  final double tailSize;

  @override
  void paint(Canvas canvas, Size size) {
    // Body rect: inset on the tail side to leave room for the tail nub.
    final Rect body = Rect.fromLTRB(
      tail == SpeechTail.left ? tailSize : 0,
      tail == SpeechTail.up ? tailSize : 0,
      size.width - (tail == SpeechTail.right ? tailSize : 0),
      size.height - (tail == SpeechTail.down ? tailSize : 0),
    );
    final double r = radius.clamp(0, body.shortestSide / 2);
    final Path path = Path()..addRRect(RRect.fromRectXY(body, r, r));

    // Tail triangle, merged into the body path so fill+stroke read as one shape.
    final double half = tailSize * 0.9;
    final Path tailPath = Path();
    switch (tail) {
      case SpeechTail.down:
        final double cx = body.left + r + (body.width - 2 * r) * tailAlignment;
        tailPath
          ..moveTo(cx - half, body.bottom - 1)
          ..lineTo(cx + half, body.bottom - 1)
          ..lineTo(cx - half * 0.2, body.bottom + tailSize)
          ..close();
      case SpeechTail.up:
        final double cx = body.left + r + (body.width - 2 * r) * tailAlignment;
        tailPath
          ..moveTo(cx - half, body.top + 1)
          ..lineTo(cx + half, body.top + 1)
          ..lineTo(cx - half * 0.2, body.top - tailSize)
          ..close();
      case SpeechTail.left:
        final double cy = body.top + r + (body.height - 2 * r) * tailAlignment;
        tailPath
          ..moveTo(body.left + 1, cy - half)
          ..lineTo(body.left + 1, cy + half)
          ..lineTo(body.left - tailSize, cy - half * 0.2)
          ..close();
      case SpeechTail.right:
        final double cy = body.top + r + (body.height - 2 * r) * tailAlignment;
        tailPath
          ..moveTo(body.right - 1, cy - half)
          ..lineTo(body.right - 1, cy + half)
          ..lineTo(body.right + tailSize, cy - half * 0.2)
          ..close();
      case SpeechTail.none:
        break;
    }
    path.addPath(tailPath, Offset.zero);

    canvas.drawPath(path, Paint()..color = background);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.tail != tail ||
      old.tailAlignment != tailAlignment ||
      old.background != background ||
      old.border != border ||
      old.radius != radius ||
      old.tailSize != tailSize;
}
