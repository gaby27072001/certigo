import 'package:flutter/material.dart';

import '../motion/app_lifecycle_motion.dart';
import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';

/// A shimmering placeholder used for loading states.
///
/// Respects the platform "reduce motion" setting by falling back to a static
/// fill. Compose several to sketch the shape of incoming content (a lesson
/// header, option tiles…) so loading never feels like a blank screen.
class PrismSkeleton extends StatefulWidget {
  const PrismSkeleton({super.key, this.width, this.height = 16, this.radius});

  final double? width;
  final double height;
  final BorderRadius? radius;

  @override
  State<PrismSkeleton> createState() => _PrismSkeletonState();
}

class _PrismSkeletonState extends State<PrismSkeleton>
    with SingleTickerProviderStateMixin, AppLifecycleMotion<PrismSkeleton> {
  // Created lazily, and only when motion is enabled. Constructing it eagerly (or
  // from dispose via a `late` field) would spin up a ticker even in
  // reduced-motion contexts and crash on teardown with an unsafe ancestor
  // lookup. See _ensureController.
  AnimationController? _controller;

  // Ne démarre rien : c'est `build` qui décide si la boucle a le droit de
  // tourner, en composant mouvement réduit et présence à l'écran.
  AnimationController _ensureController() {
    return _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final BorderRadius radius = widget.radius ?? PrismRadii.cardSm;
    final Color base = p.textSecondary.withOpacity(0.12);
    final Color highlight = p.textSecondary.withOpacity(0.22);

    if (reduceMotion) {
      // Une boucle créée avant que l'utilisateur n'active le mouvement réduit
      // continuerait de tourner derrière cet aplat statique.
      _controller?.stop();
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: radius),
      );
    }

    final AnimationController controller = _ensureController();
    if (motionIsVisible) {
      if (!controller.isAnimating) controller.repeat(reverse: true);
    } else {
      controller.stop();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(base, highlight, controller.value),
            borderRadius: radius,
          ),
        );
      },
    );
  }
}
