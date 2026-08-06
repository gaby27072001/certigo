// ignore_for_file: implementation_imports
// Token contract snapshots — the value-for-value ISO net for the malleability
// tooling work (Levier 1).
//
// These tests pin every Prism spacing and radius token to its exact documented
// value. They are the pivot of the ISO-visual proof: a screen migration replaces
// a hard-coded literal (e.g. `EdgeInsets.all(24)`) with the matching token
// (`PrismSpacing.lg`). Because these tests guarantee `token == literal`, each
// such swap is proven value-for-value without rendering a single pixel —
// engine-independent, zero-dependency, and CI-safe (they run under the existing
// `flutter test`, no golden baselines, no extra tooling).
//
// If a future edit silently changes a token, it would shift the spacing/radius of
// every screen that adopted it; these tests fail fast so that drift is a
// deliberate, reviewed decision — never an accident.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// Direct leaf imports keep these token contracts independent from unrelated
// theme and component compilation.
import 'package:prism_ui/src/tokens/prism_radii.dart';
import 'package:prism_ui/src/tokens/prism_spacing.dart';

void main() {
  group('PrismSpacing scale is frozen (4pt grid)', () {
    test('scalar steps hold their exact values', () {
      expect(PrismSpacing.xxs, 4);
      expect(PrismSpacing.xs, 8);
      expect(PrismSpacing.sm, 12);
      expect(PrismSpacing.md, 16);
      expect(PrismSpacing.lg, 24);
      expect(PrismSpacing.xl, 32);
      expect(PrismSpacing.xxl, 48);
      expect(PrismSpacing.xxxl, 64);
      expect(PrismSpacing.gutter, 20);
    });

    test('convenience EdgeInsets resolve to their scalar tokens', () {
      expect(
        PrismSpacing.screen,
        const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      );
      expect(PrismSpacing.cardPadding, const EdgeInsets.all(16));
      expect(PrismSpacing.listGap, const EdgeInsets.only(bottom: 12));
    });
  });

  group('PrismRadii scale is frozen', () {
    test('scalar steps hold their exact values', () {
      expect(PrismRadii.sm, 8);
      expect(PrismRadii.md, 12);
      expect(PrismRadii.lg, 16);
      expect(PrismRadii.xl, 24);
      expect(PrismRadii.xxl, 30);
      expect(PrismRadii.button, 20);
      expect(PrismRadii.pill, 999);
    });

    test('convenience BorderRadius resolve to their scalar tokens', () {
      expect(PrismRadii.cardSm, const BorderRadius.all(Radius.circular(8)));
      expect(PrismRadii.cardMd, const BorderRadius.all(Radius.circular(12)));
      expect(PrismRadii.cardLg, const BorderRadius.all(Radius.circular(16)));
      expect(PrismRadii.cardXl, const BorderRadius.all(Radius.circular(24)));
      expect(PrismRadii.cardXxl, const BorderRadius.all(Radius.circular(30)));
      expect(PrismRadii.buttonAll, const BorderRadius.all(Radius.circular(20)));
      expect(PrismRadii.pillAll, const BorderRadius.all(Radius.circular(999)));
    });
  });
}
