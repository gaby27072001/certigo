import 'package:flutter/material.dart';

/// Prism typography — a three-voice type system.
///
/// * Display / headings: **Plus Jakarta Sans** (geometric, confident).
/// * Body / UI: **Inter** (neutral, highly legible at small sizes).
/// * Code / tokens: **JetBrains Mono** (used in code blocks & inline `kbd`).
///
/// Sizes follow a modular-ish scale tuned for mobile reading comfort. Line
/// heights are generous because lessons are explanation-heavy.
@immutable
class PrismTypography {
  const PrismTypography._();

  static const String _displayFontFamily = 'PlusJakartaSans';
  static const String _bodyFontFamily = 'Inter';
  static const String _monoFontFamily = 'JetBrainsMono';

  static TextTheme build(Color primary, Color secondary) {
    TextStyle display(double size, FontWeight weight, double height, double tracking) => TextStyle(
          fontFamily: _displayFontFamily,
          package: 'prism_ui',
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: primary,
          letterSpacing: tracking,
        );

    TextStyle body(
      double size,
      FontWeight weight,
      Color color,
      double height, {
      double tracking = 0,
    }) =>
        TextStyle(
          fontFamily: _bodyFontFamily,
          package: 'prism_ui',
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color,
          letterSpacing: tracking,
        );

    return TextTheme(
      displayLarge: display(34, FontWeight.w800, 1.10, -0.8),
      displayMedium: display(28, FontWeight.w800, 1.14, -0.6),
      headlineMedium: display(24, FontWeight.w700, 1.18, -0.4),
      titleLarge: display(20, FontWeight.w700, 1.22, -0.25),
      titleMedium: body(17, FontWeight.w600, primary, 1.30, tracking: -0.1),
      titleSmall: body(15, FontWeight.w600, primary, 1.30),
      bodyLarge: body(17, FontWeight.w400, primary, 1.50),
      bodyMedium: body(15, FontWeight.w400, primary, 1.50),
      bodySmall: body(13, FontWeight.w400, secondary, 1.48, tracking: 0.1),
      labelLarge: body(15, FontWeight.w600, primary, 1.20, tracking: 0.1),
      labelMedium: body(13, FontWeight.w600, secondary, 1.22, tracking: 0.15),
      labelSmall: body(11, FontWeight.w600, secondary, 1.15, tracking: 0.25),
    );
  }

  /// Monospace style for code blocks and inline tokens.
  static TextStyle mono(Color color, {double size = 14}) => TextStyle(
        fontFamily: _monoFontFamily,
        package: 'prism_ui',
        fontSize: size,
        height: 1.5,
        color: color,
      );
}
