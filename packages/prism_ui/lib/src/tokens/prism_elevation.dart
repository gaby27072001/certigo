import 'package:flutter/widgets.dart';
import 'prism_colors.dart';

/// Prism elevation — depth expressed with soft, colored shadows.
///
/// We avoid Material's grey drop shadows. Prism depth uses a low-spread ambient
/// shadow tinted toward the brand to feel luminous rather than heavy. Glass
/// surfaces add a second, tighter highlight handled by the component itself.
@immutable
class PrismElevation {
  const PrismElevation._();

  static List<BoxShadow> level0 = const <BoxShadow>[];

  static List<BoxShadow> level1(Brightness b) => <BoxShadow>[
        BoxShadow(
          color: _ambient(b, 0.10),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: -6,
        ),
      ];

  static List<BoxShadow> level2(Brightness b) => <BoxShadow>[
        BoxShadow(
          color: _ambient(b, 0.14),
          blurRadius: 28,
          offset: const Offset(0, 12),
          spreadRadius: -8,
        ),
      ];

  /// Floating / hero shadow for primary CTAs and celebration cards.
  static List<BoxShadow> level3(Brightness b) => <BoxShadow>[
        BoxShadow(
          color: PrismColors.primary.withOpacity(b == Brightness.dark ? 0.30 : 0.22),
          blurRadius: 40,
          offset: const Offset(0, 18),
          spreadRadius: -10,
        ),
      ];

  static Color _ambient(Brightness b, double opacity) => b == Brightness.dark
      ? const Color(0xFF000000).withOpacity(opacity + 0.20)
      : const Color(0xFF0B1120).withOpacity(opacity);
}
