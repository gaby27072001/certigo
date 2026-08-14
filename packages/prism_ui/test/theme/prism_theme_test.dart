import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

void main() {
  group('PrismTheme', () {
    test('light theme is Material 3 with the light scaffold background', () {
      final ThemeData theme = PrismTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, PrismColors.lightBg);
    });

    test('dark theme is Material 3 with the dark scaffold background', () {
      final ThemeData theme = PrismTheme.dark();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, PrismColors.darkBg);
    });

    test('themes register the matching PrismColorScheme extension', () {
      final ThemeData light = PrismTheme.light();
      final ThemeData dark = PrismTheme.dark();
      expect(identical(light.extension<PrismColorScheme>(), PrismColorScheme.light), isTrue);
      expect(identical(dark.extension<PrismColorScheme>(), PrismColorScheme.dark), isTrue);
    });
  });
}
