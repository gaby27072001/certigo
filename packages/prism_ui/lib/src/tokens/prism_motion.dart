import 'package:flutter/widgets.dart';

/// Prism motion tokens — durations and curves for a calm, premium feel.
///
/// Motion in Certigo is *informative*, never decorative noise: it confirms
/// actions (answer correct/incorrect), reveals depth (glass layering) and
/// rewards progress (XP, mastery rings). All timings respect
/// `MediaQuery.disableAnimations` at call sites.
@immutable
class PrismMotion {
  const PrismMotion._();

  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration celebrate = Duration(milliseconds: 720);

  /// Strong ease-out for direct UI feedback and entrances.
  static const Curve standard = Cubic(0.23, 1.0, 0.32, 1.0);

  /// Strong ease-in-out for elements already moving on screen.
  static const Curve emphasized = Cubic(0.77, 0.0, 0.175, 1.0);

  /// Springy overshoot for taps and "pop" feedback.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Decelerate — for content settling into place.
  static const Curve decelerate = Cubic(0.32, 0.72, 0.0, 1.0);

  /// Returns zero duration when the platform requests reduced motion.
  static Duration resolve(BuildContext context, Duration duration) {
    return (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? Duration.zero : duration;
  }
}
