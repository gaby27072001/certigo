import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';
import '../tokens/prism_elevation.dart';
import '../tokens/prism_spacing.dart';
import 'prism_pressable.dart';

/// The foundational Liquid-Glass surface of Certigo.
///
/// A [GlassSurface] is a translucent panel that reads as material floating
/// above the background: a fill, a real edge, a lit top edge where the chrome
/// can carry one, and a shadow with direction.
///
/// The edge is the part that matters, and it is directional. In light mode the
/// stroke is **darker** than the fill; in dark mode it is **lighter**. The
/// previous implementation used a white stroke in both, which measured 1.008:1
/// against its own fill in light mode — 1.000 being literally the same colour.
/// That is the whole of "the buttons are badly outlined", and it is why the
/// stroke colour now comes from the scheme rather than from white.
///
/// For the same reason the top highlight is only painted where it can be seen:
/// white at 0.55–0.85 over the light fill measures 1.00:1, so light mode gets
/// no lit edge and leans on the shadow instead.
///
/// Performance: backdrop blur is expensive. We expose [blurEnabled] so callers
/// (and the global low-power path) can downgrade to a solid translucent fill on
/// constrained devices or inside long scrolling lists.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(PrismSpacing.md),
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
    final bool useBlur = blurEnabled;
    final bool isDark = p.brightness == Brightness.dark;

    Color fill = p.glassFill;
    if (tint != null) {
      fill = Color.alphaBlend(tint!.withValues(alpha: isDark ? 0.20 : 0.12), fill);
    }

    // A tinted surface takes its edge from the tint so the region reads as one
    // material rather than a coloured fill inside a neutral frame.
    final Color stroke = tint == null
        ? p.glassStroke
        : Color.alphaBlend(tint!.withValues(alpha: isDark ? 0.45 : 0.55), p.glassStroke);

    final List<BoxShadow> shadow = switch (elevation) {
      0 => PrismElevation.level0,
      1 => PrismElevation.level1(p.brightness),
      2 => PrismElevation.level2(p.brightness),
      _ => PrismElevation.level3(p.brightness),
    };

    Widget material = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(color: stroke.withValues(alpha: stroke.a * strokeOpacity)),
        // The lit edge of the material. `litEdge` is fully transparent in light
        // mode on purpose — see the class doc.
        gradient: p.litEdge.a == 0
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[p.litEdge, p.litEdge.withValues(alpha: 0)],
                stops: const <double>[0, 0.55],
              ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (useBlur) {
      material = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: material,
      );
    }

    Widget clipped = ClipRRect(borderRadius: borderRadius, child: material);

    if (shadow.isNotEmpty) {
      clipped = DecoratedBox(
        decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadow),
        child: clipped,
      );
    }

    if (onTap != null) {
      clipped = PrismPressable(borderRadius: borderRadius, onPressed: onTap!, child: clipped);
    }
    return clipped;
  }
}
