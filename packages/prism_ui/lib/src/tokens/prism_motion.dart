import 'package:flutter/widgets.dart';

/// Prism motion tokens — durations and curves for a calm, premium feel.
///
/// Motion in Microlingo is *informative*, never decorative noise: it confirms
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

  /// Standard easing for entrances/exits — smooth, slightly eager.
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Emphasized easing for reward / celebration moments.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Springy overshoot for taps and "pop" feedback.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Decelerate — for content settling into place.
  static const Curve decelerate = Cubic(0.0, 0.0, 0.2, 1.0);
}
