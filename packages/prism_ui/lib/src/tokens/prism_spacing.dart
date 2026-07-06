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

  // Semantic tokens (intentionally off the 4pt scale) ---------------------
  //
  // The scale above (xxs..xxxl) stays a pure 4pt grid. The two values below are
  // established, screen-wide constants that don't sit on that grid; tokenising
  // them here gives widgets a single source of truth instead of magic numbers,
  // without diluting the grid.

  /// Intrinsic inner padding of a [PrismCard] — its historical default density.
  ///
  /// Off the strict 4pt grid on purpose: this is the exact value PrismCard has
  /// always shipped with, tokenised so the component and its call sites share
  /// one source of truth instead of a hard-coded `18`. Prefer [cardPadding]
  /// (16, grid-pure) for new grid-aligned surfaces; use [cardInset] when you
  /// must match PrismCard's native density exactly (ISO migrations).
  static const double cardInset = 18;

  /// Bottom clearance reserved under the floating bottom navigation bar.
  ///
  /// Scrollable screen bodies pad their last item by this much so content can
  /// scroll clear of the floating nav. See [scrollBody] for the standard
  /// `fromLTRB(gutter, top, gutter, bottomNavClearance)` padding.
  static const double bottomNavClearance = 120;

  // Convenience EdgeInsets ------------------------------------------------
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: gutter, vertical: lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets listGap = EdgeInsets.only(bottom: sm);

  /// Padding for a scrollable screen body: the screen [gutter] on both sides
  /// and [bottomNavClearance] at the bottom so content clears the floating nav.
  ///
  /// [top] stays a parameter because screens start their scroll region at
  /// different offsets (some have a header, some don't). Replaces the repeated
  /// `EdgeInsets.fromLTRB(gutter, top, gutter, bottomNavClearance)` pattern.
  static EdgeInsets scrollBody({double top = 0}) =>
      EdgeInsets.fromLTRB(gutter, top, gutter, bottomNavClearance);
}
