import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/app_lifecycle_motion.dart';
import '../theme/prism_color_scheme.dart';
import '../tokens/prism_colors.dart';

/// A single element placed on one of an [OrbitField]'s concentric rings.
///
/// Position is polar: an item sits on the ring at [ring] (index into
/// [OrbitField.ringRadii]) — unless an explicit [radius] is provided, which
/// overrides the ring — at the given [angle] (radians, `0` = 3 o'clock,
/// increasing clockwise). [size] is the item's square footprint used for
/// centering and, when floating is enabled, its parallax amplitude.
@immutable
class OrbitItem {
  const OrbitItem({
    required this.child,
    this.ring = 0,
    required this.angle,
    this.size = 56,
    this.radius,
    this.floatAmplitude,
  });

  /// The widget painted at this orbital position.
  final Widget child;

  /// Ring index into [OrbitField.ringRadii]. Ignored when [radius] is set.
  final int ring;

  /// Angular position in radians (`0` = right, π/2 = bottom).
  final double angle;

  /// Square footprint of [child], used to center it on its point.
  final double size;

  /// Optional explicit orbit radius (px) overriding the [ring] lookup.
  final double? radius;

  /// Optional per-item float amplitude override (px). Falls back to
  /// [OrbitField.floatAmplitude] when null.
  final double? floatAmplitude;
}

/// Lays out a set of [OrbitItem]s on **concentric rings** around a [center]
/// widget, draws the thin orbit rings behind them, and (optionally) applies a
/// gentle, continuous **float** to each item so the composition feels alive.
///
/// This is the reusable primitive behind Certigo's Luma-style landing hero: a
/// luminous anchor at the center with mascots and glyph chips orbiting it. It is
/// dependency-free (only Flutter + Prism tokens) and fully testable.
///
/// Motion respects the platform "reduce motion" setting
/// ([MediaQuery.maybeDisableAnimationsOf]): the float is disabled and every item
/// rests exactly on its ring, so the layout stays deterministic in tests and
/// accessible for motion-sensitive users.
class OrbitField extends StatefulWidget {
  const OrbitField({
    super.key,
    required this.center,
    required this.items,
    this.ringRadii = const <double>[78, 132, 186],
    this.centerSize = 104,
    this.float = true,
    this.floatAmplitude = 6,
    this.floatPeriod = const Duration(seconds: 6),
    this.ringColor,
    this.ringStrokeWidth = 1,
    this.diameter,
  });

  /// The luminous anchor widget painted at the field's center.
  final Widget center;

  /// Items to place on the rings.
  final List<OrbitItem> items;

  /// Radius (px) of each concentric ring, indexed by [OrbitItem.ring].
  final List<double> ringRadii;

  /// Footprint of the [center] widget, used for centering.
  final double centerSize;

  /// Whether to apply the gentle float. Auto-disabled under reduced motion.
  final bool float;

  /// Default float amplitude (px) for items that don't override it.
  final double floatAmplitude;

  /// Duration of one full float oscillation.
  final Duration floatPeriod;

  /// Ring stroke color. Defaults to a faint brand-tinted line.
  final Color? ringColor;

  /// Ring stroke width (px).
  final double ringStrokeWidth;

  /// Optional fixed square edge for the field. When null, it is derived from
  /// the largest ring radius plus the largest item footprint.
  final double? diameter;

  @override
  State<OrbitField> createState() => _OrbitFieldState();
}

class _OrbitFieldState extends State<OrbitField>
    with SingleTickerProviderStateMixin, AppLifecycleMotion<OrbitField> {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.floatPeriod,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Largest radius any item reaches (respecting explicit radii).
  double get _maxRadius {
    double maxR = 0;
    for (final OrbitItem item in widget.items) {
      final double r = item.radius ?? _ringRadius(item.ring);
      if (r > maxR) maxR = r;
    }
    for (final double r in widget.ringRadii) {
      if (r > maxR) maxR = r;
    }
    return maxR;
  }

  /// Largest item footprint, so the field is padded enough to avoid clipping.
  double get _maxItemSize {
    double maxS = widget.centerSize;
    for (final OrbitItem item in widget.items) {
      if (item.size > maxS) maxS = item.size;
    }
    return maxS;
  }

  double _ringRadius(int ring) {
    if (widget.ringRadii.isEmpty) return 0;
    final int index = ring.clamp(0, widget.ringRadii.length - 1);
    return widget.ringRadii[index];
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // Trois conditions qui se composent, aucune qui en remplace une autre :
    // l'intention du composant, le mouvement réduit, et la présence à l'écran.
    final bool animate = widget.float && !reduceMotion && motionIsVisible;

    // Start/stop the loop in build so hot-reload, reduced-motion toggles and
    // app backgrounding stay in sync without leaking a running controller.
    if (animate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }

    final double edge = widget.diameter ?? (_maxRadius * 2 + _maxItemSize);
    final Offset origin = Offset(edge / 2, edge / 2);
    final Color ringColor =
        widget.ringColor ?? p.primary.withOpacity(p.brightness == Brightness.dark ? 0.22 : 0.16);

    return SizedBox(
      width: edge,
      height: edge,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) {
          final double t = animate ? _controller.value : 0;
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // Concentric orbit rings, painted behind every item.
              Positioned.fill(
                child: CustomPaint(
                  painter: _OrbitRingsPainter(
                    radii: widget.ringRadii,
                    color: ringColor,
                    strokeWidth: widget.ringStrokeWidth,
                  ),
                ),
              ),
              // Center anchor.
              _positioned(
                origin: origin,
                dx: 0,
                dy: 0,
                size: widget.centerSize,
                child: widget.center,
              ),
              // Orbiting items.
              for (int i = 0; i < widget.items.length; i++)
                _buildItem(widget.items[i], i, origin, t),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItem(OrbitItem item, int index, Offset origin, double t) {
    final double radius = item.radius ?? _ringRadius(item.ring);
    final double baseX = math.cos(item.angle) * radius;
    final double baseY = math.sin(item.angle) * radius;

    // Gentle parallax: each item drifts on its own phase so the field breathes
    // without any two items moving in lockstep.
    double driftX = 0;
    double driftY = 0;
    if (t != 0) {
      final double amp = item.floatAmplitude ?? widget.floatAmplitude;
      final double phase = index * (math.pi / 3);
      driftX = math.cos(2 * math.pi * t + phase) * amp;
      driftY = math.sin(2 * math.pi * t + phase) * amp;
    }

    return _positioned(
      origin: origin,
      dx: baseX + driftX,
      dy: baseY + driftY,
      size: item.size,
      child: item.child,
    );
  }

  Widget _positioned({
    required Offset origin,
    required double dx,
    required double dy,
    required double size,
    required Widget child,
  }) {
    return Positioned(
      left: origin.dx + dx - size / 2,
      top: origin.dy + dy - size / 2,
      width: size,
      height: size,
      child: Center(child: child),
    );
  }
}

/// Paints thin concentric circles for the orbit rings.
class _OrbitRingsPainter extends CustomPainter {
  const _OrbitRingsPainter({required this.radii, required this.color, required this.strokeWidth});

  final List<double> radii;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    for (final double r in radii) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbitRingsPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      !_listEquals(oldDelegate.radii, radii);

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Convenience gradient used by orbit hero surfaces (Azure → violet → ember),
/// exposed so screens can tint anchors/rings consistently with the brand.
const List<Color> kOrbitBrandGradient = <Color>[
  PrismColors.primary,
  Color(0xFF8C5CF6),
  PrismColors.ember,
];
