import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

void main() {
  group('PrismSpacing', () {
    test('follows an increasing 4pt-based scale', () {
      expect(PrismSpacing.xxs, 4);
      expect(PrismSpacing.xs, 8);
      expect(PrismSpacing.sm, 12);
      expect(PrismSpacing.md, 16);
      expect(PrismSpacing.lg, 24);
      expect(PrismSpacing.xl, 32);
      expect(PrismSpacing.xxl, 48);
      expect(PrismSpacing.xxxl, 64);
    });

    test('scale steps are strictly increasing', () {
      final List<double> scale = <double>[
        PrismSpacing.xxs,
        PrismSpacing.xs,
        PrismSpacing.sm,
        PrismSpacing.md,
        PrismSpacing.lg,
        PrismSpacing.xl,
        PrismSpacing.xxl,
        PrismSpacing.xxxl,
      ];
      for (int i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('screen padding uses the gutter and lg tokens', () {
      expect(
        PrismSpacing.screen,
        const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      );
    });

    test('card padding is a symmetric md inset', () {
      expect(PrismSpacing.cardPadding, const EdgeInsets.all(16));
    });

    test('list gap only spaces the bottom edge', () {
      expect(PrismSpacing.listGap, const EdgeInsets.only(bottom: 12));
    });
  });
}
