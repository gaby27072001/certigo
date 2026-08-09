import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

void main() {
  group('PrismTypography.build', () {
    const Color primary = Color(0xFF101418);
    const Color secondary = Color(0xFF6B7280);

    test('populates the core text styles', () {
      final TextTheme theme = PrismTypography.build(primary, secondary);
      expect(theme.displayLarge, isNotNull);
      expect(theme.bodyLarge, isNotNull);
      expect(theme.labelSmall, isNotNull);
      expect(theme.displayLarge?.fontFamily, isNotEmpty);
      expect(theme.bodyLarge?.fontFamily, isNotEmpty);
      expect(theme.displayLarge?.fontFamily, isNot(theme.bodyLarge?.fontFamily));
    });

    test('body text uses the primary color', () {
      final TextTheme theme = PrismTypography.build(primary, secondary);
      expect(theme.bodyLarge?.color, primary);
      expect(theme.bodyMedium?.color, primary);
    });

    test('secondary roles use the secondary color', () {
      final TextTheme theme = PrismTypography.build(primary, secondary);
      expect(theme.bodySmall?.color, secondary);
      expect(theme.labelMedium?.color, secondary);
      expect(theme.labelSmall?.color, secondary);
    });

    test('font sizes descend from display to label', () {
      final TextTheme theme = PrismTypography.build(primary, secondary);
      expect(theme.displayLarge!.fontSize, greaterThan(theme.bodyLarge!.fontSize!));
      expect(theme.bodyLarge!.fontSize, greaterThan(theme.labelSmall!.fontSize!));
    });
  });

  group('PrismTypography.mono', () {
    test('applies the requested color and size', () {
      const Color ink = Color(0xFF223344);
      final TextStyle style = PrismTypography.mono(ink, size: 18);
      final TextTheme theme = PrismTypography.build(ink, ink);
      expect(style.color, ink);
      expect(style.fontSize, 18);
      expect(style.fontFamily, isNotEmpty);
      expect(style.fontFamily, isNot(theme.bodyMedium?.fontFamily));
    });
  });
}
