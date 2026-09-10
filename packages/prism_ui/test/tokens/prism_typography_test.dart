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
    });

    test('one family carries the whole UI', () {
      // Product UI does not need a display/body pairing, and the pairing this
      // replaced bought nothing: two neutral geometric sans faces reading as
      // the same voice. Hierarchy now comes from weight and width instead.
      final TextTheme theme = PrismTypography.build(primary, secondary);
      expect(theme.displayLarge?.fontFamily, theme.bodyLarge?.fontFamily);
      expect(theme.labelSmall?.fontFamily, theme.bodyLarge?.fontFamily);
    });

    test('hierarchy is carried by the weight and width axes', () {
      final TextTheme theme = PrismTypography.build(primary, secondary);

      double axis(TextStyle? s, String tag) =>
          s!.fontVariations!.firstWhere((FontVariation v) => v.axis == tag).value;

      // Display is both heavier and wider than body — the two axes together
      // are what a single family uses to build a franker hierarchy.
      expect(axis(theme.displayLarge, 'wght'), greaterThan(axis(theme.bodyLarge, 'wght')));
      expect(axis(theme.displayLarge, 'wdth'), greaterThan(axis(theme.bodyLarge, 'wdth')));
      expect(axis(theme.titleLarge, 'wght'), greaterThan(axis(theme.bodyLarge, 'wght')));
      expect(axis(theme.bodyLarge, 'wdth'), 100);
    });

    test('display tracking stays above the -0.04em floor', () {
      final TextTheme theme = PrismTypography.build(primary, secondary);
      for (final TextStyle? s in <TextStyle?>[
        theme.displayLarge,
        theme.displayMedium,
        theme.headlineMedium,
      ]) {
        expect(s!.letterSpacing! / s.fontSize!, greaterThan(-0.04));
      }
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

  group('PrismTypography covers every TextTheme slot', () {
    const Color primary = Color(0xFF101418);
    const Color secondary = Color(0xFF6B7280);

    // The regression this guards: `displaySmall`, `headlineLarge` and
    // `headlineSmall` were previously undefined. `ThemeData` merges the app
    // theme over the platform default, so an undefined slot does not fail —
    // it silently renders in San Francisco or Roboto instead of the brand
    // face. Eleven call sites were affected, including both hero lines of the
    // landing screen, the first text a user ever sees.
    test('no slot falls through to the platform font', () {
      final TextTheme t = PrismTypography.build(primary, secondary);
      final Map<String, TextStyle?> slots = <String, TextStyle?>{
        'displayLarge': t.displayLarge,
        'displayMedium': t.displayMedium,
        'displaySmall': t.displaySmall,
        'headlineLarge': t.headlineLarge,
        'headlineMedium': t.headlineMedium,
        'headlineSmall': t.headlineSmall,
        'titleLarge': t.titleLarge,
        'titleMedium': t.titleMedium,
        'titleSmall': t.titleSmall,
        'bodyLarge': t.bodyLarge,
        'bodyMedium': t.bodyMedium,
        'bodySmall': t.bodySmall,
        'labelLarge': t.labelLarge,
        'labelMedium': t.labelMedium,
        'labelSmall': t.labelSmall,
      };
      slots.forEach((String name, TextStyle? style) {
        expect(style, isNotNull, reason: '$name is undefined and will inherit the platform font');
        // Asserted as a package prefix, not a font name: replacing the brand
        // face must keep this green, while a slot falling back to the system
        // font must not. The contract is locked, not the aesthetic choice.
        expect(
          style!.fontFamily,
          startsWith('packages/prism_ui/'),
          reason: '$name must render in a family served by prism_ui',
        );
      });
    });

    test('the resolved theme keeps every slot on the brand face', () {
      // Guards the merge itself, not just the builder: this is the step where
      // an undefined slot would pick up the platform default. The
      // platform-parameterised version of this guard lives in
      // test/theme/prism_typography_contract_test.dart.
      for (final ThemeData theme in <ThemeData>[PrismTheme.light(), PrismTheme.dark()]) {
        final TextTheme t = theme.textTheme;
        for (final TextStyle? style in <TextStyle?>[
          t.displayLarge,
          t.displayMedium,
          t.displaySmall,
          t.headlineLarge,
          t.headlineMedium,
          t.headlineSmall,
          t.titleLarge,
          t.titleMedium,
          t.titleSmall,
          t.bodyLarge,
          t.bodyMedium,
          t.bodySmall,
          t.labelLarge,
          t.labelMedium,
          t.labelSmall,
        ]) {
          expect(style?.fontFamily, startsWith('packages/prism_ui/'));
        }
      }
    });

    test('the scale descends without inversion', () {
      final TextTheme t = PrismTypography.build(primary, secondary);
      final List<double> scale = <double>[
        t.displayLarge!.fontSize!,
        t.displayMedium!.fontSize!,
        t.displaySmall!.fontSize!,
        t.headlineLarge!.fontSize!,
        t.headlineMedium!.fontSize!,
        t.headlineSmall!.fontSize!,
      ];
      for (int i = 1; i < scale.length; i++) {
        expect(scale[i], lessThan(scale[i - 1]), reason: 'scale is $scale');
      }
    });

    test('nothing falls below the 11pt floor', () {
      final TextTheme t = PrismTypography.build(primary, secondary);
      expect(t.labelSmall!.fontSize, greaterThanOrEqualTo(11));
      expect(t.bodyLarge!.fontSize, 17);
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
