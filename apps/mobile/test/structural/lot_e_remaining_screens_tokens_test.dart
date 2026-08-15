// ignore_for_file: implementation_imports
// ISO contract for the PR8 "Lot E" tokenisation: the final Levier 1 slice that
// migrates the remaining safe screens' hard-coded spacing/radius literals to
// PrismSpacing / PrismRadii tokens, strictly value-for-value.
//
// Screens covered (21 files):
//   achievements_screen, leaderboard_screen, seasons_screen, daily_share_screen,
//   profile_screen (+ account_section, app_info_section, preference_rows,
//   profile_loading, sign_out_section, stat_tile, tappable_row), quiz_screen
//   (+ results_sheet), and the lesson widgets (cloze_step_widget, lesson_dock,
//   lesson_intro_view, lesson_progress_header, match_pairs_step_widget,
//   ordering_step_widget, result_feedback_widget).
//
// Each EdgeInsets case pins the RESOLVED value of its token expression to the
// exact pre-migration literal, in both light and dark themes: it renders a real
// Padding under a MaterialApp and reads back `padding.resolve(...)`, so the net
// is engine-agnostic (no golden PNGs, no colours) and proves the substitution is
// a geometric no-op. Radii are brightness-independent, so they assert token
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
  // Distinct EdgeInsets substitutions across the Lot E screens. Identical
  // (token, literal) pairs are represented once; every token used by the
  // migration appears at least once.
  final List<_PaddingCase> paddingCases = <_PaddingCase>[
    // scrollBody(...) — the fromLTRB(20, top, 20, 120) list-body helper --------
    _PaddingCase(
      'scroll body top xxs',
      PrismSpacing.scrollBody(top: PrismSpacing.xxs),
      const EdgeInsets.fromLTRB(20, 4, 20, 120),
    ),
    _PaddingCase(
      'scroll body no top',
      PrismSpacing.scrollBody(),
      const EdgeInsets.fromLTRB(20, 0, 20, 120),
    ),
    _PaddingCase(
      'scroll body top sm',
      PrismSpacing.scrollBody(top: PrismSpacing.sm),
      const EdgeInsets.fromLTRB(20, 12, 20, 120),
    ),
    // fromLTRB — non-list-body (bottom != 120) --------------------------------
    const _PaddingCase(
      'leaderboard header fromLTRB',
      EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.sm,
        PrismSpacing.gutter,
        PrismSpacing.xs,
      ),
      EdgeInsets.fromLTRB(20, 12, 20, 8),
    ),
    const _PaddingCase(
      'back-row fromLTRB',
      EdgeInsets.fromLTRB(PrismSpacing.xs, PrismSpacing.xxs, PrismSpacing.gutter, PrismSpacing.xs),
      EdgeInsets.fromLTRB(8, 4, 20, 8),
    ),
    const _PaddingCase(
      'lesson dock fromLTRB',
      EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.xs,
        PrismSpacing.gutter,
        PrismSpacing.sm,
      ),
      EdgeInsets.fromLTRB(20, 8, 20, 12),
    ),
    const _PaddingCase(
      'quiz section fromLTRB',
      EdgeInsets.fromLTRB(
        PrismSpacing.gutter,
        PrismSpacing.xs,
        PrismSpacing.gutter,
        PrismSpacing.lg,
      ),
      EdgeInsets.fromLTRB(20, 8, 20, 24),
    ),
    const _PaddingCase(
      'quiz footer fromLTRB',
      EdgeInsets.fromLTRB(PrismSpacing.gutter, 0, PrismSpacing.gutter, PrismSpacing.md),
      EdgeInsets.fromLTRB(20, 0, 20, 16),
    ),
    const _PaddingCase(
      'results sheet fromLTRB',
      EdgeInsets.fromLTRB(PrismSpacing.lg, PrismSpacing.md, PrismSpacing.lg, PrismSpacing.debt28),
      EdgeInsets.fromLTRB(24, 16, 24, 28),
    ),
    // symmetric ---------------------------------------------------------------
    const _PaddingCase(
      'symmetric debt10/xxs',
      EdgeInsets.symmetric(horizontal: PrismSpacing.debt10, vertical: PrismSpacing.xxs),
      EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    const _PaddingCase(
      'symmetric debt14/sm',
      EdgeInsets.symmetric(horizontal: PrismSpacing.debt14, vertical: PrismSpacing.sm),
      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    const _PaddingCase(
      'symmetric vertical debt10',
      EdgeInsets.symmetric(vertical: PrismSpacing.debt10),
      EdgeInsets.symmetric(vertical: 10),
    ),
    const _PaddingCase(
      'symmetric horizontal debt10',
      EdgeInsets.symmetric(horizontal: PrismSpacing.debt10),
      EdgeInsets.symmetric(horizontal: 10),
    ),
    const _PaddingCase(
      'symmetric debt14/debt14',
      EdgeInsets.symmetric(horizontal: PrismSpacing.debt14, vertical: PrismSpacing.debt14),
      EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    const _PaddingCase(
      'symmetric sm/debt10',
      EdgeInsets.symmetric(horizontal: PrismSpacing.sm, vertical: PrismSpacing.debt10),
      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    const _PaddingCase(
      'symmetric debt10/debt6',
      EdgeInsets.symmetric(horizontal: PrismSpacing.debt10, vertical: PrismSpacing.debt6),
      EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    const _PaddingCase(
      'symmetric xs/debt3',
      EdgeInsets.symmetric(horizontal: PrismSpacing.xs, vertical: PrismSpacing.debt3),
      EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    ),
    const _PaddingCase(
      'symmetric md/sm',
      EdgeInsets.symmetric(vertical: PrismSpacing.md, horizontal: PrismSpacing.sm),
      EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    ),
    const _PaddingCase(
      'symmetric sm/debt6',
      EdgeInsets.symmetric(horizontal: PrismSpacing.sm, vertical: PrismSpacing.debt6),
      EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    const _PaddingCase(
      'symmetric sm/xs',
      EdgeInsets.symmetric(horizontal: PrismSpacing.sm, vertical: PrismSpacing.xs),
      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    const _PaddingCase(
      'symmetric horizontal sm',
      EdgeInsets.symmetric(horizontal: PrismSpacing.sm),
      EdgeInsets.symmetric(horizontal: 12),
    ),
    const _PaddingCase(
      'symmetric sm/debt7',
      EdgeInsets.symmetric(horizontal: PrismSpacing.sm, vertical: PrismSpacing.debt7),
      EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    ),
    const _PaddingCase(
      'symmetric vertical xxs',
      EdgeInsets.symmetric(vertical: PrismSpacing.xxs),
      EdgeInsets.symmetric(vertical: 4),
    ),
    // only --------------------------------------------------------------------
    const _PaddingCase(
      'only top debt6',
      EdgeInsets.only(top: PrismSpacing.debt6),
      EdgeInsets.only(top: 6),
    ),
    const _PaddingCase(
      'only top lg',
      EdgeInsets.only(top: PrismSpacing.lg),
      EdgeInsets.only(top: 24),
    ),
    const _PaddingCase(
      'only bottom xs',
      EdgeInsets.only(bottom: PrismSpacing.xs),
      EdgeInsets.only(bottom: 8),
    ),
    const _PaddingCase(
      'only top debt7',
      EdgeInsets.only(top: PrismSpacing.debt7),
      EdgeInsets.only(top: 7),
    ),
    const _PaddingCase(
      'only bottom debt10',
      EdgeInsets.only(bottom: PrismSpacing.debt10),
      EdgeInsets.only(bottom: 10),
    ),
    const _PaddingCase(
      'only bottom debt6',
      EdgeInsets.only(bottom: PrismSpacing.debt6),
      EdgeInsets.only(bottom: 6),
    ),
    const _PaddingCase(
      'only left debt30',
      EdgeInsets.only(left: PrismSpacing.debt30),
      EdgeInsets.only(left: 30),
    ),
    // all ---------------------------------------------------------------------
    const _PaddingCase('all debt14', EdgeInsets.all(PrismSpacing.debt14), EdgeInsets.all(14)),
  ];

  for (final Brightness brightness in Brightness.values) {
    final String mode = brightness == Brightness.dark ? 'dark' : 'light';

    for (final _PaddingCase c in paddingCases) {
      testWidgets('${c.label} padding is token-exact ($mode)', (WidgetTester tester) async {
        const Key key = Key('lot_e_padding');
        await tester.pumpWidget(
          _host(
            Padding(key: key, padding: c.actual, child: const SizedBox.shrink()),
            brightness: brightness,
          ),
        );

        expect(_resolvedPadding(tester, key), c.expected);
      });
    }
  }

  // Radii are brightness-independent: assert token value equality directly.
  group('Lot E radii are token-exact', () {
    test('circular sm == 8', () {
      expect(PrismRadii.sm, 8);
      expect(BorderRadius.circular(PrismRadii.sm), BorderRadius.circular(8));
    });

    test('circular md == 12', () {
      expect(PrismRadii.md, 12);
      expect(BorderRadius.circular(PrismRadii.md), BorderRadius.circular(12));
    });

    test('results sheet radius debt28 == 28', () {
      expect(PrismRadii.debt28, 28);
      expect(const Radius.circular(PrismRadii.debt28), const Radius.circular(28));
    });
  });
}
