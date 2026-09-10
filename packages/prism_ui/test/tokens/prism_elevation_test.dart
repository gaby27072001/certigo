import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

void main() {
  group('PrismElevation', () {
    test('level0 is flat (no shadows)', () {
      expect(PrismElevation.level0, isEmpty);
    });

    test('level1..level3 each produce a shadow', () {
      expect(PrismElevation.level1(Brightness.light), isNotEmpty);
      expect(PrismElevation.level2(Brightness.light), isNotEmpty);
      expect(PrismElevation.level3(Brightness.light), isNotEmpty);
    });

    test('blur radius grows with elevation level', () {
      final double b1 = PrismElevation.level1(Brightness.light).first.blurRadius;
      final double b2 = PrismElevation.level2(Brightness.light).first.blurRadius;
      final double b3 = PrismElevation.level3(Brightness.light).first.blurRadius;
      expect(b2, greaterThan(b1));
      expect(b3, greaterThan(b2));
    });

    test('dark elevation differs from light at the same level', () {
      final Color light = PrismElevation.level1(Brightness.light).first.color;
      final Color dark = PrismElevation.level1(Brightness.dark).first.color;
      expect(dark, isNot(light));
    });

    test('every shadow has direction and softness, never a flat halo', () {
      for (final Brightness b in Brightness.values) {
        for (final List<BoxShadow> level in <List<BoxShadow>>[
          PrismElevation.level1(b),
          PrismElevation.level2(b),
          PrismElevation.level3(b),
        ]) {
          expect(level, isNotEmpty);
          // The key shadow carries the light source: it falls downward and is
          // soft. A zero-offset shadow is decoration, not depth.
          expect(level.first.offset.dy, greaterThan(0));
          expect(level.first.blurRadius, greaterThan(0));
        }
      }
    });

    test('toned() takes its colour from the caller, not the brand', () {
      // Previously level3 hard-coded the brand primary, so a CTA tinted with
      // any other accent was given a blue glow that matched nothing on screen.
      const Color rose = Color(0xFFB51C6D);
      final Color glow = PrismElevation.toned(Brightness.light, rose).first.color;
      expect(glow.r, rose.r);
      expect(glow.g, rose.g);
      expect(glow.b, rose.b);
      expect(glow.a, lessThan(1.0));
    });

    test('toned() follows whichever accent it is given', () {
      const Color green = Color(0xFF1A7C36);
      const Color amber = Color(0xFF9C5015);
      final Color a = PrismElevation.toned(Brightness.dark, green).first.color;
      final Color b = PrismElevation.toned(Brightness.dark, amber).first.color;
      expect(a, isNot(b));
    });
  });
}
