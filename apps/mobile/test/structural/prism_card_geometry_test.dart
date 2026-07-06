// ignore_for_file: implementation_imports
// Geometry contract for PrismCard — the migration target's shape, frozen.
//
// PR4→PR8 replace ~14 hand-rolled `_XxxCard` widgets with `PrismCard`. These
// tests pin PrismCard's resolved geometry (inner padding, corner radius) and the
// structural signature of each variant (border / shadow / gradient presence), in
// both light and dark themes. Any change to the card's default shape — the shape
// every migrated screen inherits — is caught here.
//
// Structural only: no colours, no pixels. That makes the net identical under any
// Flutter engine (unlike golden PNGs, which diverge across engine versions), so
// it is a stable ISO guarantee for the migrations rather than a brittle golden.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Direct src imports (not the barrel) so this test never compiles
// prism_typography.dart, whose google_fonts dependency has a const-eval bug that
// breaks compilation on some local toolchains. PrismCard and PrismColorScheme both
// import only flutter + leaf token files, so the net stays green locally and in CI.
import 'package:prism_ui/src/components/prism_card.dart';
import 'package:prism_ui/src/theme/prism_color_scheme.dart';
import 'package:prism_ui/src/tokens/prism_radii.dart';

// Builds the theme via the PrismColorScheme extension directly instead of
// PrismTheme.light()/.dark(), which would pull in typography (google_fonts).
// PrismCard reads geometry-relevant state from `context.prism`, which resolves the
// extension below — so the card's shape is exercised without the typography layer.
Widget _host(Widget child, {required Brightness brightness}) {
  final PrismColorScheme scheme =
      brightness == Brightness.dark ? PrismColorScheme.dark : PrismColorScheme.light;
  return MaterialApp(
    theme: ThemeData(
      brightness: brightness,
      extensions: <ThemeExtension<dynamic>>[scheme],
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

BoxDecoration _cardDecoration(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(of: find.byType(PrismCard), matching: find.byType(DecoratedBox)).first,
  );
  return box.decoration as BoxDecoration;
}

EdgeInsets _cardPadding(WidgetTester tester) {
  final Padding pad = tester.widget<Padding>(
    find.descendant(of: find.byType(PrismCard), matching: find.byType(Padding)).first,
  );
  return pad.padding.resolve(TextDirection.ltr);
}

void main() {
  for (final Brightness brightness in Brightness.values) {
    final String mode = brightness == Brightness.dark ? 'dark' : 'light';

    testWidgets('PrismCard default geometry is token-exact ($mode)', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const PrismCard(child: SizedBox.shrink()), brightness: brightness),
      );

      expect(_cardPadding(tester), const EdgeInsets.all(18));
      expect(_cardDecoration(tester).borderRadius, PrismRadii.cardXl);
    });

    testWidgets('PrismCard surface variant — bordered, shadowed, no gradient ($mode)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const PrismCard(child: SizedBox.shrink()), brightness: brightness),
      );

      final BoxDecoration d = _cardDecoration(tester);
      expect(d.border, isNotNull);
      expect(d.gradient, isNull);
      expect(d.boxShadow, isNotEmpty);
    });

    testWidgets('PrismCard tonal variant — bordered, shadowed, no gradient ($mode)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const PrismCard(variant: PrismCardVariant.tonal, child: SizedBox.shrink()),
          brightness: brightness,
        ),
      );

      final BoxDecoration d = _cardDecoration(tester);
      expect(d.border, isNotNull);
      expect(d.gradient, isNull);
      expect(d.boxShadow, isNotEmpty);
    });

    testWidgets('PrismCard outlined variant — bordered (1.5), no shadow ($mode)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const PrismCard(variant: PrismCardVariant.outlined, child: SizedBox.shrink()),
          brightness: brightness,
        ),
      );

      final BoxDecoration d = _cardDecoration(tester);
      expect(d.border, isNotNull);
      expect((d.border! as Border).top.width, 1.5);
      expect(d.boxShadow, isEmpty);
    });

    testWidgets('PrismCard filled variant — gradient, no border ($mode)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const PrismCard(variant: PrismCardVariant.filled, child: SizedBox.shrink()),
          brightness: brightness,
        ),
      );

      final BoxDecoration d = _cardDecoration(tester);
      expect(d.gradient, isNotNull);
      expect(d.border, isNull);
    });
  }
}
