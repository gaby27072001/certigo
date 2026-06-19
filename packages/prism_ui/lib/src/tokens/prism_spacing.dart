import 'package:flutter/widgets.dart';

/// Prism spacing scale — a strict 4pt baseline grid.
///
/// Using a fixed scale keeps vertical rhythm consistent across every screen
/// and makes density decisions explicit (no magic numbers in widgets).
@immutable
class PrismSpacing {
  const PrismSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Default horizontal screen gutter (mobile-first).
  static const double gutter = 20;

  // Convenience EdgeInsets ------------------------------------------------
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: gutter, vertical: lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets listGap = EdgeInsets.only(bottom: sm);
}
