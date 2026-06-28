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

    test('level3 shadow is tinted toward the brand primary', () {
      final Color shadow = PrismElevation.level3(Brightness.light).first.color;
      expect(shadow.red, PrismColors.primary.red);
      expect(shadow.green, PrismColors.primary.green);
      expect(shadow.blue, PrismColors.primary.blue);
    });
  });
}
