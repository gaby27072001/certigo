// ignore_for_file: implementation_imports
// ISO contract for the PR7 exam_screen + tutor_sheet + path_screen
// tokenisation (Lot D).
//
// PR7 replaces the hard-coded EdgeInsets/Radius literals below with PrismSpacing
// and PrismRadii tokens, strictly value-for-value:
//   exam_screen.dart
//     * fromLTRB(20, 8, 20, 20)  -> fromLTRB(gutter, xs, gutter, gutter) (x2)
//     * fromLTRB(20, 0, 20, 8)   -> fromLTRB(gutter, 0, gutter, xs)
//     * fromLTRB(20, 8, 20, 24)  -> fromLTRB(gutter, xs, gutter, lg)
//     * fromLTRB(20, 0, 20, 16)  -> fromLTRB(gutter, 0, gutter, md)
//     * fromLTRB(20, 4, 20, 120) -> scrollBody(top: xxs)               (x2)
//     * symmetric(v: 8)          -> symmetric(vertical: xs)
//     * symmetric(h: 12, v: 8)   -> symmetric(horizontal: sm, vertical: xs)
//     * symmetric(h: 12, v: 10)  -> symmetric(horizontal: sm, vertical: debt10)
//     * fromLTRB(8, 4, 20, 4)    -> fromLTRB(xs, xxs, gutter, xxs)
//   tutor_sheet.dart
//     * Radius.circular(26)          -> Radius.circular(debt26)
//     * BorderRadius.circular(3)     -> BorderRadius.circular(debt3)
//     * BorderRadius.circular(12)    -> BorderRadius.circular(md)
//     * only(top: 12, bottom: 6)     -> only(top: sm, bottom: debt6)
//     * fromLTRB(20, 6, 12, 12)      -> fromLTRB(gutter, debt6, sm, sm)
//     * fromLTRB(20, 4, 20, 24)      -> fromLTRB(gutter, xxs, gutter, lg)  (x2)
//     * fromLTRB(20, 4, 20, 28)      -> fromLTRB(gutter, xxs, gutter, debt28)
//     * symmetric(h: 11, v: 6)       -> symmetric(horizontal: debt11, vertical: debt6)
//     * only(top: 6)                 -> only(top: debt6)
//   path_screen.dart
//     * fromLTRB(20, 8, 20, 0)   -> fromLTRB(gutter, xs, gutter, 0)
//     * fromLTRB(16, 20, 16, 0)  -> fromLTRB(md, gutter, md, 0)
//     * fromLTRB(20, 8, 20, 10)  -> fromLTRB(gutter, xs, gutter, debt10)
//     * symmetric(h: 9, v: 3)    -> symmetric(horizontal: debt9, vertical: debt3)
//     * fromLTRB(20, 10, 20, 14) -> fromLTRB(gutter, debt10, gutter, debt14)
//     * symmetric(h: 12, v: 7)   -> symmetric(horizontal: sm, vertical: debt7)
//     * fromLTRB(20, 12, 20, 120)-> scrollBody(top: sm)
//
// Each EdgeInsets test pins the RESOLVED value of its token expression to the
// exact pre-migration literal, in both light and dark themes: it renders a real
// Padding under a MaterialApp and reads back `padding.resolve(...)`, so the net
// is engine-agnostic (no golden PNGs, no colours) and proves the substitution is
// a no-op on geometry. Radii are brightness-independent, so they assert token
// value equality directly. Together this is the ISO guarantee the migration
// must hold.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Direct leaf imports keep this geometry contract independent from unrelated
// theme and component compilation.
import 'package:prism_ui/src/tokens/prism_radii.dart';
import 'package:prism_ui/src/tokens/prism_spacing.dart';

@immutable
class _PaddingCase {
  const _PaddingCase(this.label, this.actual, this.expected);

  final String label;
  final EdgeInsets actual;
  final EdgeInsets expected;
}

Widget _host(Widget child, {required Brightness brightness}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: child),
  );
}

EdgeInsets _resolvedPadding(WidgetTester tester, Key key) {
  final Padding pad = tester.widget<Padding>(find.byKey(key));
  return pad.padding.resolve(TextDirection.ltr);
}

void main() {
  // 22 unique EdgeInsets substitutions across the three Lot D screens.
  final List<_PaddingCase> paddingCases = <_PaddingCase>[
    // exam_screen.dart -----------------------------------------------------
    const _PaddingCase(
      'exam header/footer',
      EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.xs,
        PrismSpacing.gutter,
        PrismSpacing.gutter,
      ),
      EdgeInsets.fromLTRB(20, 8, 20, 20),
    ),
    const _PaddingCase(
      'exam prompt padding',
      EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        0,
        PrismSpacing.gutter,
        PrismSpacing.xs,
      ),
      EdgeInsets.fromLTRB(20, 0, 20, 8),
    ),
    const _PaddingCase(
      'exam section padding',
      EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.xs,
        PrismSpacing.gutter,
        PrismSpacing.lg,
      ),
      EdgeInsets.fromLTRB(20, 8, 20, 24),
    ),
    const _PaddingCase(
      'exam meta padding',
      EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        0,
        PrismSpacing.gutter,
        PrismSpacing.md,
      ),
      EdgeInsets.fromLTRB(20, 0, 20, 16),
    ),
    _PaddingCase(
      'exam scroll body',
      PrismSpacing.scrollBody(top: PrismSpacing.xxs),
      const EdgeInsets.fromLTRB(20, 4, 20, 120),
    ),
    const _PaddingCase(
      'exam vertical chip',
      EdgeInsets.symmetric(vertical: PrismSpacing.xs),
      EdgeInsets.symmetric(vertical: 8),
    ),
    const _PaddingCase(
      'exam pill padding',
      EdgeInsets.symmetric(
        horizontal: PrismSpacing.sm,
        vertical: PrismSpacing.xs,
      ),
      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    const _PaddingCase(
      'exam card md padding',
      EdgeInsets.symmetric(
        horizontal: PrismSpacing.sm,
        vertical: PrismSpacing.debt10,
      ),
      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    const _PaddingCase(
      'exam back-row padding',
      EdgeInsets.fromLTRB(
        PrismSpacing.xs,
        PrismSpacing.xxs,
        PrismSpacing.gutter,
        PrismSpacing.xxs,
      ),
      EdgeInsets.fromLTRB(8, 4, 20, 4),
    ),
    // tutor_sheet.dart -----------------------------------------------------
    const _PaddingCase(
      'tutor grabber padding',
      EdgeInsets.only(top: PrismSpacing.sm, bottom: PrismSpacing.debt6),
      EdgeInsets.only(top: 12, bottom: 6),
    ),
    const _PaddingCase(
      'tutor header padding',
      EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.debt6,
        PrismSpacing.sm,
        PrismSpacing.sm,
      ),
      EdgeInsets.fromLTRB(20, 6, 12, 12),
    ),
    const _PaddingCase(
      'tutor body block',
      EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.xxs,
        PrismSpacing.gutter,
        PrismSpacing.lg,
      ),
      EdgeInsets.fromLTRB(20, 4, 20, 24),
    ),
    const _PaddingCase(
      'tutor callout block',
      EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.xxs,
        PrismSpacing.gutter,
        PrismSpacing.debt28,
      ),
      EdgeInsets.fromLTRB(20, 4, 20, 28),
    ),
    const _PaddingCase(
      'tutor chip padding',
      EdgeInsets.symmetric(
        horizontal: PrismSpacing.debt11,
        vertical: PrismSpacing.debt6,
      ),
      EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    ),
    const _PaddingCase(
      'tutor footer padding',
      EdgeInsets.only(top: PrismSpacing.debt6),
      EdgeInsets.only(top: 6),
    ),
    // path_screen.dart -----------------------------------------------------
    const _PaddingCase(
      'path header padding',
      EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.xs,
        PrismSpacing.gutter,
        0,
      ),
      EdgeInsets.fromLTRB(20, 8, 20, 0),
    ),
    const _PaddingCase(
      'path sliver padding',
      EdgeInsets.fromLTRB(
        PrismSpacing.md,
        PrismSpacing.gutter,
        PrismSpacing.md,
        0,
      ),
      EdgeInsets.fromLTRB(16, 20, 16, 0),
    ),
    const _PaddingCase(
      'path banner padding',
      EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.xs,
        PrismSpacing.gutter,
        PrismSpacing.debt10,
      ),
      EdgeInsets.fromLTRB(20, 8, 20, 10),
    ),
    const _PaddingCase(
      'path badge padding',
      EdgeInsets.symmetric(
        horizontal: PrismSpacing.debt9,
        vertical: PrismSpacing.debt3,
      ),
      EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    ),
    const _PaddingCase(
      'path switcher padding',
      EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.debt10,
        PrismSpacing.gutter,
        PrismSpacing.debt14,
      ),
      EdgeInsets.fromLTRB(20, 10, 20, 14),
    ),
    const _PaddingCase(
      'path tag padding',
      EdgeInsets.symmetric(
        horizontal: PrismSpacing.sm,
        vertical: PrismSpacing.debt7,
      ),
      EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    ),
    _PaddingCase(
      'path scroll body',
      PrismSpacing.scrollBody(top: PrismSpacing.sm),
      const EdgeInsets.fromLTRB(20, 12, 20, 120),
    ),
  ];

  for (final Brightness brightness in Brightness.values) {
    final String mode = brightness == Brightness.dark ? 'dark' : 'light';

    for (final _PaddingCase c in paddingCases) {
      testWidgets('${c.label} padding is token-exact ($mode)', (WidgetTester tester) async {
        const Key key = Key('lot_d_padding');
        await tester.pumpWidget(
          _host(
            Padding(
              key: key,
              padding: c.actual,
              child: const SizedBox.shrink(),
            ),
            brightness: brightness,
          ),
        );

        expect(_resolvedPadding(tester, key), c.expected);
      });
    }
  }

  // Radii are brightness-independent: assert token value equality directly.
  group('Lot D radii are token-exact', () {
    test('tutor sheet top radius (debt26 == 26)', () {
      expect(PrismRadii.debt26, 26);
      expect(
        const Radius.circular(PrismRadii.debt26),
        const Radius.circular(26),
      );
    });

    test('tutor grabber radius (debt3 == 3)', () {
      expect(PrismRadii.debt3, 3);
      expect(
        BorderRadius.circular(PrismRadii.debt3),
        BorderRadius.circular(3),
      );
    });

    test('tutor avatar radius (md == 12)', () {
      expect(PrismRadii.md, 12);
      expect(
        BorderRadius.circular(PrismRadii.md),
        BorderRadius.circular(12),
      );
    });
  });
}
