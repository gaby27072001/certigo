import 'package:flutter/material.dart';

/// Prism typography — one variable family, two axes.
///
/// The previous system paired Plus Jakarta Sans for display with Inter for
/// body. Both are on the generative-default list, and the pairing bought
/// nothing: two neutral geometric sans faces that read as the same voice at a
/// glance, so the hierarchy had to be carried by size alone.
///
/// Certigo now runs on **Archivo** (SIL OFL 1.1), a grotesque with a weight
/// axis (100–900) *and* a width axis (62–125). One family carries headings,
/// buttons, labels, body and data — which is what product UI wants — while the
/// width axis supplies the wide, heavy display register that size alone cannot.
/// Hierarchy comes from weight and width, not from a second typeface.
///
/// Sizes are unchanged and deliberately so: 17 pt body and an 11 pt floor
/// already match the iOS metrics, and this change is about voice, not layout.
/// JetBrains Mono is kept for code, where a monospace is a measurement tool
/// rather than a costume.
@immutable
class PrismTypography {
  const PrismTypography._();

  static const String _uiFontFamily = 'Archivo';
  static const String _monoFontFamily = 'JetBrainsMono';

  /// Legacy families, still bundled so nothing that referenced them breaks.
  static const String legacyDisplayFontFamily = 'PlusJakartaSans';
  static const String legacyBodyFontFamily = 'Inter';

  // Width axis. Display runs wide because a wide grotesque at heavy weight is
  // the register the brief asked for; UI stays at normal width so labels keep
  // their expected rhythm and never look stretched.
  static const double _displayWidth = 112;
  static const double _titleWidth = 104;
  static const double _uiWidth = 100;

  static List<FontVariation> _axes(double weight, double width) => <FontVariation>[
        FontVariation('wght', weight),
        FontVariation('wdth', width),
      ];

  static TextTheme build(Color primary, Color secondary) {
    TextStyle display(double size, double weight, double height, double tracking) => TextStyle(
          fontFamily: _uiFontFamily,
          package: 'prism_ui',
          fontSize: size,
          fontWeight: _nearestWeight(weight),
          fontVariations: _axes(weight, _displayWidth),
          height: height,
          color: primary,
          letterSpacing: tracking,
        );

    TextStyle title(double size, double weight, double height, double tracking) => TextStyle(
          fontFamily: _uiFontFamily,
          package: 'prism_ui',
          fontSize: size,
          fontWeight: _nearestWeight(weight),
          fontVariations: _axes(weight, _titleWidth),
          height: height,
          color: primary,
          letterSpacing: tracking,
        );

    TextStyle body(
      double size,
      double weight,
      Color color,
      double height, {
      double tracking = 0,
    }) =>
        TextStyle(
          fontFamily: _uiFontFamily,
          package: 'prism_ui',
          fontSize: size,
          fontWeight: _nearestWeight(weight),
          fontVariations: _axes(weight, _uiWidth),
          height: height,
          color: color,
          letterSpacing: tracking,
        );

    return TextTheme(
      // Every one of Flutter's fifteen slots is defined here on purpose.
      // Previously `displaySmall`, `headlineLarge` and `headlineSmall` were
      // left out; `ThemeData` merges over the platform default, so those three
      // silently rendered in San Francisco / Roboto instead of the brand face.
      // Eleven call sites were affected, including both hero lines of the
      // landing screen — the very first text the user sees. `textThemeIsTotal`
      // in the tests now fails if a slot is ever dropped again.
      displayLarge: display(34, 800, 1.06, -1.0),
      displayMedium: display(28, 800, 1.10, -0.8),
      displaySmall: display(26, 800, 1.12, -0.7),
      headlineLarge: display(25, 780, 1.14, -0.6),
      headlineMedium: display(24, 750, 1.16, -0.5),
      headlineSmall: display(20, 750, 1.20, -0.4),
      titleLarge: title(20, 700, 1.22, -0.3),
      titleMedium: title(17, 650, 1.30, -0.15),
      titleSmall: title(15, 650, 1.30, -0.05),
      bodyLarge: body(17, 400, primary, 1.50),
      bodyMedium: body(15, 400, primary, 1.50),
      bodySmall: body(13, 400, secondary, 1.48, tracking: 0.1),
      labelLarge: body(15, 600, primary, 1.20, tracking: 0.1),
      labelMedium: body(13, 600, secondary, 1.22, tracking: 0.15),
      labelSmall: body(11, 600, secondary, 1.15, tracking: 0.25),
    );
  }

  /// Variable axes drive the real rendering; [FontWeight] is still set so that
  /// fallback faces and the test font pick a sane weight.
  static FontWeight _nearestWeight(double weight) {
    final int index = ((weight / 100).round().clamp(1, 9)) - 1;
    return FontWeight.values[index];
  }

  /// Display style at an explicit weight/width, for one-off brand moments.
  static TextStyle displayVariant({
    required double size,
    required Color color,
    double weight = 800,
    double width = _displayWidth,
    double height = 1.06,
    double tracking = -1.0,
  }) =>
      TextStyle(
        fontFamily: _uiFontFamily,
        package: 'prism_ui',
        fontSize: size,
        fontWeight: _nearestWeight(weight),
        fontVariations: _axes(weight, width),
        height: height,
        color: color,
        letterSpacing: tracking,
      );

  /// Monospace style for code blocks and inline tokens.
  static TextStyle mono(Color color, {double size = 14}) => TextStyle(
        fontFamily: _monoFontFamily,
        package: 'prism_ui',
        fontSize: size,
        height: 1.5,
        color: color,
      );
}
