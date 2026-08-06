// ignore_for_file: implementation_imports
// ISO contract for the PR6 quests_screen + friends_screen tokenisation (Lot C).
//
// PR6 replaces nine hard-coded EdgeInsets literals with PrismSpacing tokens,
// strictly value-for-value:
//   quests_screen.dart
//     * fromLTRB(20, 4, 20, 120) -> scrollBody(top: xxs)   (x2: list / loading)
//   friends_screen.dart
//     * fromLTRB(20, 4, 20, 120) -> scrollBody(top: xxs)   (x2: roster / loading)
//     * fromLTRB(20, 14, 20, 0)  -> fromLTRB(gutter, debt14, gutter, 0)
//                                                           (inline error padding)
//     * fromLTRB(20, 4, 20, 0)   -> fromLTRB(gutter, xxs, gutter, 0)
//                                                           (_AddFriendCard padding)
//     * fromLTRB(4, 0, 4, 10)    -> fromLTRB(xxs, 0, xxs, debt10)
//                                                           (roster count padding)
//     * symmetric(h: 14, v: 12)  -> symmetric(h: debt14, v: sm)  (_FriendCard)
//     * all(10)                  -> all(debt10)            (loader padding)
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

    testWidgets('scroll body padding is token-exact ($mode)', (WidgetTester tester) async {
      const Key key = Key('lot_c_scroll_body');
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

      // ISO: pre-migration literal was fromLTRB(20, 4, 20, 120)
      // (quests list / loading, friends roster / loading).
      expect(
        _resolvedPadding(tester, key),
        const EdgeInsets.fromLTRB(20, 4, 20, 120),
      );
    });

    testWidgets('inline error padding is token-exact ($mode)', (WidgetTester tester) async {
      const Key key = Key('lot_c_inline_error');
      await tester.pumpWidget(
        _host(
          const Padding(
            key: key,
            padding: EdgeInsets.fromLTRB(
              PrismSpacing.gutter,
              PrismSpacing.debt14,
              PrismSpacing.gutter,
              0,
            ),
            child: SizedBox.shrink(),
          ),
          brightness: brightness,
        ),
      );

      // ISO: pre-migration literal was fromLTRB(20, 14, 20, 0).
      expect(
        _resolvedPadding(tester, key),
        const EdgeInsets.fromLTRB(20, 14, 20, 0),
      );
    });

    testWidgets('add-friend card padding is token-exact ($mode)', (WidgetTester tester) async {
      const Key key = Key('lot_c_add_friend');
      await tester.pumpWidget(
        _host(
          const Padding(
            key: key,
            padding: EdgeInsets.fromLTRB(
              PrismSpacing.gutter,
              PrismSpacing.xxs,
              PrismSpacing.gutter,
              0,
            ),
            child: SizedBox.shrink(),
          ),
          brightness: brightness,
        ),
      );

      // ISO: pre-migration literal was fromLTRB(20, 4, 20, 0).
      expect(
        _resolvedPadding(tester, key),
        const EdgeInsets.fromLTRB(20, 4, 20, 0),
      );
    });

    testWidgets('roster count padding is token-exact ($mode)', (WidgetTester tester) async {
      const Key key = Key('lot_c_roster_count');
      await tester.pumpWidget(
        _host(
          const Padding(
            key: key,
            padding: EdgeInsets.fromLTRB(
              PrismSpacing.xxs,
              0,
              PrismSpacing.xxs,
              PrismSpacing.debt10,
            ),
            child: SizedBox.shrink(),
          ),
          brightness: brightness,
        ),
      );

      // ISO: pre-migration literal was fromLTRB(4, 0, 4, 10).
      expect(
        _resolvedPadding(tester, key),
        const EdgeInsets.fromLTRB(4, 0, 4, 10),
      );
    });

    testWidgets('friend card padding is token-exact ($mode)', (WidgetTester tester) async {
      const Key key = Key('lot_c_friend_card');
      await tester.pumpWidget(
        _host(
          const Padding(
            key: key,
            padding: EdgeInsets.symmetric(
              horizontal: PrismSpacing.debt14,
              vertical: PrismSpacing.sm,
            ),
            child: SizedBox.shrink(),
          ),
          brightness: brightness,
        ),
      );

      // ISO: pre-migration literal was symmetric(horizontal: 14, vertical: 12).
      expect(
        _resolvedPadding(tester, key),
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
    });

    testWidgets('loader padding is token-exact ($mode)', (WidgetTester tester) async {
      const Key key = Key('lot_c_loader');
      await tester.pumpWidget(
        _host(
          const Padding(
            key: key,
            padding: EdgeInsets.all(PrismSpacing.debt10),
            child: SizedBox.shrink(),
          ),
          brightness: brightness,
        ),
      );

      // ISO: pre-migration literal was all(10).
      expect(
        _resolvedPadding(tester, key),
        const EdgeInsets.all(10),
      );
    });
  }
}
