// ignore_for_file: implementation_imports
// ISO contract for the PR4 home_screen tokenisation (Lot A).
//
// PR4 replaces four hard-coded EdgeInsets literals in home_screen.dart with
// PrismSpacing tokens, strictly value-for-value:
//   * fromLTRB(20, 12, 20, 120)        -> scrollBody(top: sm)          (x2)
//   * symmetric(vertical: 24)          -> symmetric(vertical: lg)
//   * symmetric(horizontal: 16, v: 18) -> symmetric(h: md, v: cardInset)
//
// These tests pin the RESOLVED value of each token expression to the exact
// pre-migration literal, in both light and dark themes. They render a real
// Padding under a MaterialApp and read back `padding.resolve(...)`, so the net
// is engine-agnostic (no golden PNGs, no colours) and proves the substitution
// is a no-op on geometry — the ISO guarantee the migration must hold.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Direct src import (not the barrel) so this test never compiles
// prism_typography.dart, whose google_fonts dependency has a const-eval bug that
// breaks compilation on some local toolchains. prism_spacing.dart is a leaf
// token file importing only flutter, so the net stays green locally and in CI.
import 'package:prism_ui/src/tokens/prism_spacing.dart';

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
  for (final Brightness brightness in Brightness.values) {
    final String mode = brightness == Brightness.dark ? 'dark' : 'light';

    testWidgets('home scroll body padding is token-exact ($mode)', (WidgetTester tester) async {
      const Key key = Key('home_scroll_body');
      await tester.pumpWidget(
        _host(
          Padding(
            key: key,
            padding: PrismSpacing.scrollBody(top: PrismSpacing.sm),
            child: const SizedBox.shrink(),
          ),
          brightness: brightness,
        ),
      );

      // ISO: pre-migration literal was fromLTRB(20, 12, 20, 120).
      expect(
        _resolvedPadding(tester, key),
        const EdgeInsets.fromLTRB(20, 12, 20, 120),
      );
    });

    testWidgets('home readiness hero vertical padding is token-exact ($mode)',
        (WidgetTester tester) async {
      const Key key = Key('home_readiness_card');
      await tester.pumpWidget(
        _host(
          const Padding(
            key: key,
            padding: EdgeInsets.symmetric(vertical: PrismSpacing.lg),
            child: SizedBox.shrink(),
          ),
          brightness: brightness,
        ),
      );

      // ISO: pre-migration literal was symmetric(vertical: 24).
      expect(
        _resolvedPadding(tester, key),
        const EdgeInsets.symmetric(vertical: 24),
      );
    });

    testWidgets('home explore card padding is token-exact ($mode)', (WidgetTester tester) async {
      const Key key = Key('home_explore_card');
      await tester.pumpWidget(
        _host(
          const Padding(
            key: key,
            padding: EdgeInsets.symmetric(
              horizontal: PrismSpacing.md,
              vertical: PrismSpacing.cardInset,
            ),
            child: SizedBox.shrink(),
          ),
          brightness: brightness,
        ),
      );

      // ISO: pre-migration literal was symmetric(horizontal: 16, vertical: 18).
      expect(
        _resolvedPadding(tester, key),
        const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      );
    });
  }
}
