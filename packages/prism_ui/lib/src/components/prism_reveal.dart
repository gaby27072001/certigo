import 'package:flutter/material.dart';

import '../tokens/prism_motion.dart';

/// Purposeful fade + short slide for occasional content entrances.
class PrismReveal extends StatelessWidget {
  const PrismReveal({
    super.key,
    required this.visible,
    required this.child,
    this.from = const Offset(0, 0.06),
    this.duration = PrismMotion.base,
  });

  final bool visible;
  final Widget child;
  final Offset from;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final Duration effectiveDuration = PrismMotion.resolve(context, duration);
    return AnimatedSlide(
      offset: visible ? Offset.zero : from,
      duration: effectiveDuration,
      curve: PrismMotion.standard,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: effectiveDuration,
        curve: PrismMotion.standard,
        child: child,
      ),
    );
  }
}
