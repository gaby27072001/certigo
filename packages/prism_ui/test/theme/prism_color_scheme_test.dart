import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

void main() {
  group('PrismColorScheme', () {
    test('light scheme is light with the light background', () {
      expect(PrismColorScheme.light.brightness, Brightness.light);
      expect(PrismColorScheme.light.background, PrismColors.lightBg);
    });

    test('dark scheme is dark with the dark background', () {
      expect(PrismColorScheme.dark.brightness, Brightness.dark);
      expect(PrismColorScheme.dark.background, PrismColors.darkBg);
    });

    test('light and dark differ by background, not brand primary', () {
      expect(PrismColorScheme.light.primary, PrismColorScheme.dark.primary);
      expect(PrismColorScheme.light.background, isNot(PrismColorScheme.dark.background));
    });

    test('accentFor wraps around the six domain accents', () {
      const PrismColorScheme p = PrismColorScheme.light;
      expect(p.accentFor(0), p.accentFor(6));
      expect(p.accentFor(7), p.accentFor(1));
    });

    test('copyWith overrides only the provided field', () {
      const Color hot = Color(0xFF123456);
      final PrismColorScheme p = PrismColorScheme.light.copyWith(primary: hot);
      expect(p.primary, hot);
      expect(p.background, PrismColorScheme.light.background);
      expect(p.brightness, PrismColorScheme.light.brightness);
    });

    test('lerp returns the endpoints at t=0 and t=1', () {
      const PrismColorScheme a = PrismColorScheme.light;
      const PrismColorScheme b = PrismColorScheme.dark;
      expect(a.lerp(b, 0).background, PrismColors.lightBg);
      expect(a.lerp(b, 1).background, PrismColors.darkBg);
    });

    test('lerp with a non-scheme extension returns itself', () {
      const PrismColorScheme a = PrismColorScheme.light;
      expect(identical(a.lerp(null, 0.5), a), isTrue);
    });
  });
}
