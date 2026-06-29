import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

void main() {
  group('PrismColors', () {
    test('brand primary is the Certigo blue', () {
      expect(PrismColors.primary, const Color(0xFF0078D4));
      expect(PrismColors.primaryDark, const Color(0xFF005A9E));
    });

    test('exposes exactly six domain accents', () {
      expect(PrismColors.domainAccents, hasLength(6));
    });

    test('domain accents are all distinct', () {
      final Set<int> unique =
          PrismColors.domainAccents.map((Color c) => c.value).toSet();
      expect(unique, hasLength(PrismColors.domainAccents.length));
    });

    test('first domain accent matches the brand primary', () {
      expect(PrismColors.domainAccents.first, PrismColors.primary);
    });

    test('semantic status colors are stable', () {
      expect(PrismColors.success, const Color(0xFF1FB87A));
      expect(PrismColors.warning, const Color(0xFFF5A524));
      expect(PrismColors.error, const Color(0xFFF0476A));
      expect(PrismColors.info, const Color(0xFF3BA0F0));
    });

    test('light and dark backgrounds differ', () {
      expect(PrismColors.lightBg, isNot(PrismColors.darkBg));
    });
  });
}
