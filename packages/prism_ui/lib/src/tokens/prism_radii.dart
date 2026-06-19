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
  static const double pill = 999;

  static const BorderRadius cardSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius cardMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius cardLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius cardXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}
