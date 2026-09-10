import 'package:flutter/widgets.dart';

/// Prism motion tokens — the continuous register.
///
/// Motion in Certigo is *informative*, never decorative noise: it confirms
/// actions (answer correct/incorrect), reveals depth (glass layering) and
/// rewards progress (XP, mastery rings). All timings respect
/// `MediaQuery.disableAnimations` at call sites via [resolve].
///
/// The register is **continuous**: an element stretches toward its next state
/// rather than disappearing and being replaced. That is why the curves below
/// are asymmetric ease-outs — motion leaves quickly and arrives slowly, which
/// is what makes a surface feel like it has mass instead of like it was
/// swapped. Product transitions stay in the 150–250 ms band so a user in a
/// task never waits on choreography; only [celebrate] is allowed to be seen.
@immutable
class PrismMotion {
  const PrismMotion._();

  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration celebrate = Duration(milliseconds: 720);

  /// State-layer feedback (hover, press). Short enough to feel attached to the
  /// pointer rather than trailing it.
  static const Duration state = Duration(milliseconds: 120);

  /// One element becoming another — a card growing into a sheet, a chip
  /// settling into a selected row. The continuous move.
  static const Duration morph = Duration(milliseconds: 280);

  /// Strong ease-out for direct UI feedback and entrances.
  static const Curve standard = Cubic(0.23, 1.0, 0.32, 1.0);

  /// Strong ease-in-out for elements already moving on screen.
  static const Curve emphasized = Cubic(0.77, 0.0, 0.175, 1.0);

  /// Springy overshoot for taps and "pop" feedback.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Decelerate — for content settling into place.
  static const Curve decelerate = Cubic(0.32, 0.72, 0.0, 1.0);

  /// Exponential ease-out. The continuous curve: an element leaves its old
  /// state immediately and eases a long way into the new one, so the two states
  /// read as one movement rather than two frames.
  static const Curve continuous = Cubic(0.16, 1.0, 0.30, 1.0);

  /// Returns zero duration when the platform requests reduced motion.
  static Duration resolve(BuildContext context, Duration duration) {
    return (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? Duration.zero : duration;
  }
}
