import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

void main() {
  group('PrismRadii', () {
    test('scalar radii cover the documented scale', () {
      expect(PrismRadii.sm, 8);
      expect(PrismRadii.md, 12);
      expect(PrismRadii.lg, 16);
      expect(PrismRadii.xl, 24);
      expect(PrismRadii.xxl, 30);
      expect(PrismRadii.button, 20);
    });

    test('pill radius is effectively fully rounded', () {
      expect(PrismRadii.pill, 999);
    });

    test('BorderRadius helpers map to their scalar tokens', () {
      expect(PrismRadii.cardLg, const BorderRadius.all(Radius.circular(PrismRadii.lg)));
      expect(PrismRadii.buttonAll, const BorderRadius.all(Radius.circular(PrismRadii.button)));
      expect(PrismRadii.pillAll, const BorderRadius.all(Radius.circular(PrismRadii.pill)));
    });
  });
}
