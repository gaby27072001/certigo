import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';
import '../tokens/prism_elevation.dart';

/// The foundational "Liquid-Glass inspired" surface of Certigo.
///
/// A [GlassSurface] is a translucent, blurred panel with a subtle top
/// highlight and a hairline stroke — it reads as frosted material floating
/// above the aurora background. It is the base for cards, sheets and nav bars.
///
/// Performance: backdrop blur is expensive. We expose [blurEnabled] so callers
/// (and the global low-power path) can downgrade to a solid translucent fill on
/// constrained devices or inside long scrolling lists.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = PrismRadii.cardLg,
    this.blurSigma = 18,
    this.blurEnabled = true,
    this.elevation = 1,
    this.tint,
    this.strokeOpacity = 1,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blurSigma;
  final bool blurEnabled;

  /// 0 = flat, 1 = resting card, 2 = raised, 3 = hero.
  final int elevation;

  /// Optional brand tint blended into the glass fill (e.g. domain accent).
  final Color? tint;
  final double strokeOpacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bool useBlur = blurEnabled && !reduceMotion;

    Color fill = p.glassFill;
    if (tint != null) fill = Color.alphaBlend(tint!.withOpacity(0.14), fill);

    final List<BoxShadow> shadow = switch (elevation) {
      0 => PrismElevation.level0,
      1 => PrismElevation.level1(p.brightness),
      2 => PrismElevation.level2(p.brightness),
      _ => PrismElevation.level3(p.brightness),
    };

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(color: p.glassStroke.withOpacity(strokeOpacity)),
        // A faint vertical highlight sells the "glass catching light" effect.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withOpacity(p.brightness == Brightness.dark ? 0.06 : 0.35),
            Colors.white.withOpacity(0.0),
          ],
          stops: const <double>[0.0, 0.55],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (useBlur) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: surface,
      );
    }

    Widget clipped = ClipRRect(borderRadius: borderRadius, child: surface);

    if (shadow.isNotEmpty) {
      clipped = DecoratedBox(
        decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadow),
        child: clipped,
      );
    }

    if (onTap != null) {
      clipped = _Pressable(borderRadius: borderRadius, onTap: onTap!, child: clipped);
    }
    return clipped;
  }
}

/// Lightweight scale-on-press wrapper used across tappable glass surfaces.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
