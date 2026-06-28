import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    disableGoogleFontsFetching();
  });

  group('PrismTypography.build', () {
    const Color primary = Color(0xFF101418);
    const Color secondary = Color(0xFF6B7280);

    test('populates the core text styles', () async {
      late TextTheme theme;
      await runSwallowingFontErrors(() async {
        theme = PrismTypography.build(primary, secondary);
      });
      expect(theme.displayLarge, isNotNull);
      expect(theme.bodyLarge, isNotNull);
      expect(theme.labelSmall, isNotNull);
    });

    test('body text uses the primary color', () async {
      late TextTheme theme;
      await runSwallowingFontErrors(() async {
        theme = PrismTypography.build(primary, secondary);
      });
      expect(theme.bodyLarge?.color, primary);
      expect(theme.bodyMedium?.color, primary);
    });

    test('secondary roles use the secondary color', () async {
      late TextTheme theme;
      await runSwallowingFontErrors(() async {
        theme = PrismTypography.build(primary, secondary);
      });
      expect(theme.bodySmall?.color, secondary);
      expect(theme.labelMedium?.color, secondary);
      expect(theme.labelSmall?.color, secondary);
    });

    test('font sizes descend from display to label', () async {
      late TextTheme theme;
      await runSwallowingFontErrors(() async {
        theme = PrismTypography.build(primary, secondary);
      });
      expect(
        theme.displayLarge!.fontSize,
        greaterThan(theme.bodyLarge!.fontSize!),
      );
      expect(
        theme.bodyLarge!.fontSize,
        greaterThan(theme.labelSmall!.fontSize!),
      );
    });
  });

  group('PrismTypography.mono', () {
    test('applies the requested color and size', () async {
      const Color ink = Color(0xFF223344);
      late TextStyle style;
      await runSwallowingFontErrors(() async {
        style = PrismTypography.mono(ink, size: 18);
      });
      expect(style.color, ink);
      expect(style.fontSize, 18);
    });
  });
}
