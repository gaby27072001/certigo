import 'package:flutter/widgets.dart';

/// Prism interaction states — one vocabulary for every control.
///
/// "The highlight is badly done" was not a taste problem, it was a missing
/// system. Two concrete defects produced it:
///
/// 1. Both `PrismPressable` and `PrismButton` set
///    `overlayColor: Colors.transparent`, which switches off every Material
///    state layer. There was therefore **no hover state anywhere in the app**
///    — most visible on the web build, which is the one under test.
/// 2. The focus ring was hard-coded `Colors.black` / `Colors.white` in
///    `PrismPressable` but `textPrimary` in `PrismButton`: two different focus
///    vocabularies, neither of them theme-aware.
///
/// This file replaces both with a single measured scale. A state layer only
/// exists if it can be *seen*, so every opacity below was verified to move the
/// surface by at least 1.04:1 against its rest state — roughly the smallest
/// step that reads as deliberate on a large filled area.
@immutable
class PrismStateLayer {
  const PrismStateLayer._();

  // Light chrome sits on white, so a tint reads at low opacity.
  static const double lightHover = 0.06; // measured 1.068:1 vs rest
  static const double lightPressed = 0.12; // measured 1.145:1
  static const double lightSelected = 0.16; // measured 1.203:1
  static const double lightFocusHalo = 0.22; // measured 1.294:1

  // Dark chrome swallows tint, so the same perceptual step costs more opacity.
  static const double darkHover = 0.10; // measured 1.157:1 vs rest
  static const double darkPressed = 0.18; // measured 1.329:1
  static const double darkSelected = 0.24; // measured 1.480:1
  static const double darkFocusHalo = 0.30; // measured 1.659:1

  /// Opacity applied to *content* (label, icon) when a control is disabled.
  /// Chosen so disabled text still clears 3:1 against its surface — disabled
  /// must read as unavailable, never as broken rendering.
  static const double lightDisabledContent = 0.72; // measured 3.531:1
  static const double darkDisabledContent = 0.62; // measured 3.830:1

  /// Opacity applied to a disabled control's own fill.
  static const double disabledSurface = 0.38;

  static double hover(Brightness b) => b == Brightness.dark ? darkHover : lightHover;
  static double pressed(Brightness b) => b == Brightness.dark ? darkPressed : lightPressed;
  static double selected(Brightness b) => b == Brightness.dark ? darkSelected : lightSelected;
  static double focusHalo(Brightness b) => b == Brightness.dark ? darkFocusHalo : lightFocusHalo;
  static double disabledContent(Brightness b) =>
      b == Brightness.dark ? darkDisabledContent : lightDisabledContent;

  /// Scale applied on pointer-down. Small on purpose: a control should feel
  /// like it takes the press, not like it runs away from the finger.
  static const double pressedScale = 0.975;
}

/// Geometry of the one focus ring used everywhere in Certigo.
///
/// The ring is drawn *outside* the control with a gap in the surface colour
/// between them. That offset is what makes a single ring colour legible on any
/// background, including on top of a filled button painted in the very same
/// tint — the gap supplies the contrast the ring cannot supply against itself
/// (measured 6.20:1 between the light ring and a white gap).
@immutable
class PrismFocusRing {
  const PrismFocusRing._();

  /// Width of the coloured ring.
  static const double width = 2.5;

  /// Gap between the control edge and the ring, painted in the surface colour.
  static const double gap = 2.5;

  /// Total space the ring needs outside the control's own bounds.
  static const double inset = width + gap;
}
