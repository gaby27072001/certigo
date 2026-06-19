import 'package:flutter/material.dart';

import '../theme/prism_color_scheme.dart';
import '../tokens/prism_radii.dart';

/// A shimmering placeholder used for loading states.
///
/// Respects the platform "reduce motion" setting by falling back to a static
/// fill. Compose several to sketch the shape of incoming content (a lesson
/// header, option tiles…) so loading never feels like a blank screen.
class PrismSkeleton extends StatefulWidget {
  const PrismSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius,
  });

  final double? width;
  final double height;
  final BorderRadius? radius;

  @override
  State<PrismSkeleton> createState() => _PrismSkeletonState();
}

class _PrismSkeletonState extends State<PrismSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
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
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: radius),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(base, highlight, _controller.value),
            borderRadius: radius,
          ),
        );
      },
    );
  }
}
