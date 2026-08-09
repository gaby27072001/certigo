import 'package:flutter/material.dart';

import '../tokens/prism_motion.dart';

/// A drop-in replacement for [AnimatedSwitcher] tuned for *full-page step
/// transitions* (lesson steps, quiz questions) where the default cross-fade
/// causes the outgoing and incoming content to visibly overlap.
///
/// Why the default fails: [AnimatedSwitcher] keeps both the outgoing and the
/// incoming child mounted for the whole duration and, with its default
/// `layoutBuilder`, paints them stacked and centered while cross-fading. If the
/// step surfaces are translucent (glass / aurora bleed-through), the learner
/// sees *two questions superimposed* during the change.
///
/// How this fixes it:
///  * a directional **slide + fade** (incoming enters from the right, outgoing
///    eases out) so the two children occupy different space instead of fading
///    in place;
///  * a **shorter reverse duration** so the previous step clears quickly;
///  * a `layoutBuilder` that keeps the incoming child painted **on top**.
///
/// Contract: give each [child] a stable [Key] (e.g. `ValueKey(stepIndex)`) and
/// make it **opaque** (wrap in a solid surface / [ColoredBox]). With opaque,
/// keyed children there is zero superimposition.
class PrismStepSwitcher extends StatelessWidget {
  const PrismStepSwitcher({
    super.key,
    required this.child,
    this.duration = PrismMotion.base,
    this.reverseDuration = PrismMotion.fast,
    this.alignment = Alignment.topCenter,
    this.slideExtent = 0.08,
  });

  /// The current step. Must carry a unique [Key] to trigger a transition.
  final Widget child;
  final Duration duration;
  final Duration reverseDuration;
  final Alignment alignment;

  /// Horizontal travel of the slide, as a fraction of the child width.
  final double slideExtent;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: reverseDuration,
      switchInCurve: PrismMotion.decelerate,
      switchOutCurve: PrismMotion.standard,
      layoutBuilder: (Widget? current, List<Widget> previous) {
        return Stack(
          alignment: alignment,
          children: <Widget>[...previous, if (current != null) current],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        final Animation<Offset> offset = Tween<Offset>(
          begin: Offset(slideExtent, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: PrismMotion.decelerate));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: child,
    );
  }
}
