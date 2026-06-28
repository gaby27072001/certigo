import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    disableGoogleFontsFetching();
  });

  group('PrismTheme', () {
    test('light theme is Material 3 with the light scaffold background',
        () async {
      late ThemeData theme;
      await runSwallowingFontErrors(() async {
        theme = PrismTheme.light();
      });
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, PrismColors.lightBg);
    });

    test('dark theme is Material 3 with the dark scaffold background',
        () async {
      late ThemeData theme;
      await runSwallowingFontErrors(() async {
        theme = PrismTheme.dark();
      });
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, PrismColors.darkBg);
    });

    test('themes register the matching PrismColorScheme extension', () async {
      late ThemeData light;
      late ThemeData dark;
      await runSwallowingFontErrors(() async {
        light = PrismTheme.light();
        dark = PrismTheme.dark();
      });
      expect(
        identical(light.extension<PrismColorScheme>(), PrismColorScheme.light),
        isTrue,
      );
      expect(
        identical(dark.extension<PrismColorScheme>(), PrismColorScheme.dark),
        isTrue,
      );
    });
  });
}
