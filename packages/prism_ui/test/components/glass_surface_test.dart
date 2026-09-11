import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  group('GlassSurface', () {
    testWidgets('renders its child and blurs by default', (WidgetTester tester) async {
      await pumpPrism(tester, const GlassSurface(child: Text('Frosted')));

      expect(find.text('Frosted'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('drops the blur when disabled but keeps the child', (WidgetTester tester) async {
      await pumpPrism(tester, const GlassSurface(blurEnabled: false, child: Text('Solid')));

      expect(find.text('Solid'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('keeps glass blur when only motion is reduced', (WidgetTester tester) async {
      await pumpPrism(
        tester,
        const GlassSurface(child: Text('Calm glass')),
        disableAnimations: true,
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('drops the blur entirely under Reduce Transparency', (WidgetTester tester) async {
      // Le réglage ne demande pas moins de flou, il demande qu'il n'y en ait
      // plus. Un `BackdropFilter` de sigma nul resterait une couche de
      // composition coûteuse, et resterait surtout un aveu que la demande n'a
      // pas été entendue.
      await pumpPrism(
        tester,
        const GlassSurface(child: Text('Opaque')),
        reduceTransparency: true,
      );

      expect(find.text('Opaque'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    for (final Brightness brightness in Brightness.values) {
      final String name = brightness == Brightness.dark ? 'sombre' : 'clair';

      testWidgets('la surface peinte est vraiment opaque sous Reduce Transparency ($name)',
          (WidgetTester tester) async {
        // Supprimer le `BackdropFilter` ne suffirait pas si le fond restait
        // translucide : le contenu transparaîtrait toujours, simplement net au
        // lieu d'être flou.
        await pumpPrism(
          tester,
          const GlassSurface(child: Text('Opaque')),
          brightness: brightness,
          reduceTransparency: true,
        );

        final DecoratedBox painted = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .firstWhere((DecoratedBox d) => (d.decoration as BoxDecoration).color != null);
        final Color fill = (painted.decoration as BoxDecoration).color!;
        expect(fill.a, 1.0, reason: 'le fond du verre doit être opaque en $name');
      });

      testWidgets('une teinte reste opaque sous Reduce Transparency ($name)',
          (WidgetTester tester) async {
        await pumpPrism(
          tester,
          const GlassSurface(tint: Color(0xFF3B35F2), child: Text('Teinté')),
          brightness: brightness,
          reduceTransparency: true,
        );

        final DecoratedBox painted = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .firstWhere((DecoratedBox d) => (d.decoration as BoxDecoration).color != null);
        expect((painted.decoration as BoxDecoration).color!.a, 1.0);
      });
    }

    testWidgets('invokes onTap when pressed', (WidgetTester tester) async {
      int taps = 0;
      await pumpPrism(tester, GlassSurface(onTap: () => taps++, child: const Text('Tap me')));

      await tester.tap(find.text('Tap me'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });
}
