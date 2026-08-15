// ignore_for_file: implementation_imports
// ISO contract for the PR5 library_screen + shop_screen tokenisation (Lot B).
//
// PR5 replaces six hard-coded EdgeInsets literals with PrismSpacing tokens,
// strictly value-for-value:
//   library_screen.dart
//     * fromLTRB(20, 12, 20, 120) -> scrollBody(top: sm)   (ListView padding)
//     * all(16)                   -> all(md)                (x3: skeleton /
//                                                            _TipCard / _DomainCard)
//   shop_screen.dart
//     * fromLTRB(20, 4, 20, 120)  -> scrollBody(top: xxs)  (x2: content / loading)
//
// These tests pin the RESOLVED value of each token expression to the exact
// pre-migration literal, in both light and dark themes. They render a real
// Padding under a MaterialApp and read back `padding.resolve(...)`, so the net
// is engine-agnostic (no golden PNGs, no colours) and proves the substitution
// is a no-op on geometry — the ISO guarantee the migration must hold.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Direct leaf import keeps this geometry contract independent from unrelated
// theme and component compilation.
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

    testWidgets('library scroll body padding is token-exact ($mode)', (WidgetTester tester) async {
      const Key key = Key('library_scroll_body');
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
      expect(_resolvedPadding(tester, key), const EdgeInsets.fromLTRB(20, 12, 20, 120));
    });

    testWidgets('library card inner padding is token-exact ($mode)', (WidgetTester tester) async {
      const Key key = Key('library_card_padding');
      await tester.pumpWidget(
        _host(
          const Padding(
            key: key,
            padding: EdgeInsets.all(PrismSpacing.md),
            child: SizedBox.shrink(),
          ),
          brightness: brightness,
        ),
      );

      // ISO: pre-migration literal was all(16) (skeleton / _TipCard / _DomainCard).
      expect(_resolvedPadding(tester, key), const EdgeInsets.all(16));
    });

    testWidgets('shop scroll body padding is token-exact ($mode)', (WidgetTester tester) async {
      const Key key = Key('shop_scroll_body');
      await tester.pumpWidget(
        _host(
          Padding(
            key: key,
            padding: PrismSpacing.scrollBody(top: PrismSpacing.xxs),
            child: const SizedBox.shrink(),
          ),
          brightness: brightness,
        ),
      );

      // ISO: pre-migration literal was fromLTRB(20, 4, 20, 120).
      expect(_resolvedPadding(tester, key), const EdgeInsets.fromLTRB(20, 4, 20, 120));
    });
  }
}
