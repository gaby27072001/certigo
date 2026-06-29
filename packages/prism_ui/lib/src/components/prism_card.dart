import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_elevation.dart';
import '../tokens/prism_radii.dart';

/// How a [PrismCard] is filled.
///
/// * [surface] — neutral opaque card. The default reading surface.
/// * [tonal]   — opaque card softly washed with an [accent] hue. Colorful but
///   keeps dark body text legible. The workhorse of the playful redesign.
/// * [filled]  — fully saturated accent gradient with light foreground. For
///   hero blocks, celebration and the single most important CTA-like surface.
/// * [outlined]— opaque surface with a confident accent stroke and no shadow.
enum PrismCardVariant { surface, tonal, filled, outlined }

/// The solid, colorful, rounded content surface of Certigo.
///
/// Where [GlassSurface] is reserved for *chrome* (bottom nav, small floating
/// utilities, premium reward overlays), [PrismCard] is the default surface for
/// real content: lesson blocks, dashboard cards, list rows. It is fully opaque
/// so stacked/transitioning surfaces never bleed through one another — which is
/// also what keeps screen transitions clean.
///
/// It mirrors the [GlassSurface] API (child, padding, borderRadius, elevation,
/// onTap) so call sites can swap one for the other with minimal churn; `tint`
/// becomes [accent].
class PrismCard extends StatelessWidget {
  const PrismCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = PrismRadii.cardXl,
    this.variant = PrismCardVariant.surface,
    this.accent,
    this.elevation = 1,
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final PrismCardVariant variant;

  /// Hue used by [PrismCardVariant.tonal], [PrismCardVariant.filled] and
  /// [PrismCardVariant.outlined]. Defaults to the brand primary.
  final Color? accent;

  /// 0 = flat, 1 = resting card, 2 = raised, 3 = hero.
  final int elevation;

  final VoidCallback? onTap;

  /// Optional gradient override (e.g. a bespoke hero). Wins over [variant] fill.
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final bool isDark = p.brightness == Brightness.dark;
    final Color accent = this.accent ?? p.primary;

    Color fill;
    Gradient? grad = gradient;
    Border? border;
    List<BoxShadow> shadow;

    switch (variant) {
      case PrismCardVariant.surface:
        fill = p.surface;
        border = Border.all(color: p.border);
        shadow = _shadowFor(elevation, p.brightness);
      case PrismCardVariant.tonal:
        fill = Color.alphaBlend(
          accent.withOpacity(isDark ? 0.20 : 0.10),
          p.surface,
        );
        border = Border.all(color: accent.withOpacity(isDark ? 0.34 : 0.20));
        shadow = _shadowFor(elevation, p.brightness);
      case PrismCardVariant.outlined:
        fill = p.surface;
        border = Border.all(color: accent.withOpacity(0.55), width: 1.5);
        shadow = const <BoxShadow>[];
      case PrismCardVariant.filled:
        fill = accent;
        grad ??= LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent,
            Color.alphaBlend(Colors.black.withOpacity(0.18), accent),
          ],
        );
        border = null;
        shadow = elevation <= 0
            ? const <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(
                  color: accent.withOpacity(isDark ? 0.40 : 0.30),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                  spreadRadius: -10,
                ),
              ];
    }

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: grad == null ? fill : null,
        gradient: grad,
        borderRadius: borderRadius,
        border: border,
        boxShadow: shadow,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap != null) {
      surface = _PressableCard(
        borderRadius: borderRadius,
        onTap: onTap!,
        child: surface,
      );
    }
    return surface;
  }

  static List<BoxShadow> _shadowFor(int elevation, Brightness b) => switch (elevation) {
        <= 0 => PrismElevation.level0,
        1 => PrismElevation.level1(b),
        2 => PrismElevation.level2(b),
        _ => PrismElevation.level2(b),
      };
}

/// Scale-on-press wrapper for tappable [PrismCard]s, mirroring the glass one.
class _PressableCard extends StatefulWidget {
  const _PressableCard({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
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
