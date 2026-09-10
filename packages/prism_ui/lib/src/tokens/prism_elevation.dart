import 'package:flutter/material.dart';

/// Prism elevation — depth expressed with soft, directional shadows.
///
/// Two rules, both from measurement rather than taste:
///
/// * **Every level carries an offset and a blur.** A zero-offset coloured halo
///   is decoration, not depth; light comes from above, so shadows fall below.
/// * **The shadow is tinted toward the chrome's own hue**, never neutral grey,
///   so depth reads as luminous rather than dirty.
///
/// Light mode leans on these shadows harder than dark mode does, because the
/// lit-edge highlight that separates a dark surface from its background simply
/// does not work on a light one: white at 0.55–0.85 alpha over the light glass
/// fill was measured at 1.00:1 — literally invisible. On light chrome, depth is
/// carried by the shadow and the darker edge instead.
@immutable
class PrismElevation {
  const PrismElevation._();

  static List<BoxShadow> level0 = const <BoxShadow>[];

  /// Resting card.
  static List<BoxShadow> level1(Brightness b) => <BoxShadow>[
        BoxShadow(
          color: _ambient(b, 0.10),
          blurRadius: 14,
          offset: const Offset(0, 4),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: _ambient(b, 0.06),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  /// Raised — sheets, popovers, anything that has left the page plane.
  static List<BoxShadow> level2(Brightness b) => <BoxShadow>[
        BoxShadow(
          color: _ambient(b, 0.14),
          blurRadius: 28,
          offset: const Offset(0, 12),
          spreadRadius: -8,
        ),
        BoxShadow(
          color: _ambient(b, 0.08),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  /// Floating — the control layer that rides above content: tab bars, primary
  /// CTAs, celebration cards.
  static List<BoxShadow> level3(Brightness b) => <BoxShadow>[
        BoxShadow(
          color: _ambient(b, 0.20),
          blurRadius: 44,
          offset: const Offset(0, 20),
          spreadRadius: -12,
        ),
        BoxShadow(
          color: _ambient(b, 0.10),
          blurRadius: 10,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
      ];

  /// Coloured lift for a control that owns its region — a track-tinted CTA
  /// glowing in its own hue.
  ///
  /// [tone] is required. The previous implementation hard-coded the brand
  /// primary here, so a CTA tinted with any other colour was given a blue glow
  /// that matched nothing on screen.
  static List<BoxShadow> toned(Brightness b, Color tone) => <BoxShadow>[
        BoxShadow(
          color: tone.withValues(alpha: b == Brightness.dark ? 0.44 : 0.30),
          blurRadius: 30,
          offset: const Offset(0, 12),
          spreadRadius: -8,
        ),
        BoxShadow(
          color: _ambient(b, 0.10),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  /// Violet-tinted ambient. Dark mode needs more of it because the shadow has
  /// less range to work with against an already-dark canvas.
  static Color _ambient(Brightness b, double opacity) => b == Brightness.dark
      ? const Color(0xFF05070F).withValues(alpha: (opacity + 0.26).clamp(0.0, 1.0))
      : const Color(0xFF0D1331).withValues(alpha: opacity);
}
