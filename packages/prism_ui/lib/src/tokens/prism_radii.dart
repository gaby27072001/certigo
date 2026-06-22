import 'package:flutter/widgets.dart';

/// Prism corner-radius scale. Soft, optical, premium — never sharp.
///
/// Radii encode hierarchy: chips/pills are fully round, cards step up with
/// importance (sm controls → xl hero/sheets).
@immutable
class PrismRadii {
  const PrismRadii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  /// Extra-large — playful hero cards and full-bleed content surfaces.
  static const double xxl = 30;

  /// Dedicated radius for CTAs: rounder than a card, softer than a pill.
  static const double button = 20;

  static const double pill = 999;

  static const BorderRadius cardSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius cardMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius cardLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius cardXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius cardXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius buttonAll = BorderRadius.all(Radius.circular(button));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}
