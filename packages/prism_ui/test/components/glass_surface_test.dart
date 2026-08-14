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

    testWidgets('invokes onTap when pressed', (WidgetTester tester) async {
      int taps = 0;
      await pumpPrism(tester, GlassSurface(onTap: () => taps++, child: const Text('Tap me')));

      await tester.tap(find.text('Tap me'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });
}
