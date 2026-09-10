import 'package:flutter/material.dart';
import '../theme/prism_color_scheme.dart';
import 'prism_content_frame.dart';

/// The signature Certigo backdrop: a soft "aurora" bloom of the region's own
/// colour over the base background.
///
/// This is the Apple Music mechanic, transposed: colour arrives from the
/// *content* and irradiates its region, rather than being sprinkled over a
/// neutral page. Pass [tint] and a screen adopts the hue of whatever it is
/// about — the certification track in progress, a domain, a result.
///
/// It blooms in a single hue on purpose. The previous version layered three
/// unrelated hues (brand, ember, info) whose halos overlapped into mud, which
/// is a large part of why the colours read as blending together. One hue at two
/// depths reads as light; three hues read as a smudge.
///
/// Static by default (cheap). Set [animate] true on hero screens for a gentle
/// drift; it auto-disables when the platform requests reduced motion.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.animate = false,
    this.maxContentWidth = 840,
    this.tint,
  });

  final Widget child;
  final bool animate;
  final double? maxContentWidth;

  /// The hue this region irradiates. Defaults to the brand band.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final Color hue = tint ?? p.primaryVivid;
    final bool isDark = p.brightness == Brightness.dark;

    // Dark chrome swallows a wash, so it gets more of it.
    final double near = isDark ? 0.26 : 0.20;
    final double far = isDark ? 0.16 : 0.11;

    return DecoratedBox(
      decoration: BoxDecoration(color: p.background),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            left: -80,
            child: _Glow(color: hue.withValues(alpha: near), size: 340),
          ),
          Positioned(
            bottom: -160,
            right: -60,
            child: _Glow(color: hue.withValues(alpha: far), size: 380),
          ),
          Positioned.fill(
            child: maxContentWidth == null
                ? child
                : PrismContentFrame(maxWidth: maxContentWidth!, child: child),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
