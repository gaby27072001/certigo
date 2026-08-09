import 'package:flutter/material.dart';
import '../theme/prism_color_scheme.dart';

/// The signature Certigo backdrop: a soft, slow "aurora" of brand-tinted
/// radial glows over the base background. It gives the glass surfaces something
/// luminous to refract without competing with content (very low opacity).
///
/// Static by default (cheap). Set [animate] true on hero screens for a gentle
/// drift; it auto-disables when the platform requests reduced motion.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child, this.animate = false});

  final Widget child;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return DecoratedBox(
      decoration: BoxDecoration(color: p.background),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            left: -80,
            child: _Glow(color: p.primary.withOpacity(0.18), size: 320),
          ),
          Positioned(
            top: 40,
            right: -100,
            child: _Glow(color: p.ember.withOpacity(0.12), size: 280),
          ),
          Positioned(
            bottom: -140,
            left: 20,
            child: _Glow(color: p.info.withOpacity(0.12), size: 360),
          ),
          Positioned.fill(child: child),
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
          gradient: RadialGradient(colors: <Color>[color, color.withOpacity(0)]),
        ),
      ),
    );
  }
}
