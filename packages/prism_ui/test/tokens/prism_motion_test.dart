import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

void main() {
  group('PrismMotion', () {
    test('durations are strictly increasing', () {
      expect(PrismMotion.instant, lessThan(PrismMotion.fast));
      expect(PrismMotion.fast, lessThan(PrismMotion.base));
      expect(PrismMotion.base, lessThan(PrismMotion.slow));
      expect(PrismMotion.slow, lessThan(PrismMotion.celebrate));
    });

    test('exposes named easing curves', () {
      expect(PrismMotion.standard, isA<Curve>());
      expect(PrismMotion.emphasized, isA<Curve>());
      expect(PrismMotion.spring, isA<Curve>());
      expect(PrismMotion.decelerate, isA<Curve>());
    });
  });
}
