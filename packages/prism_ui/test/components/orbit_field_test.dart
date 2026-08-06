import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  Widget buildField({bool reduceMotion = true}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const OrbitField(
        center: Text('C'),
        ringRadii: <double>[80, 140],
        items: <OrbitItem>[
          OrbitItem(ring: 0, angle: 0, child: Text('A')),
          OrbitItem(ring: 1, angle: 1.2, child: Text('B')),
          OrbitItem(radius: 100, angle: 2, child: Text('D')),
        ],
      ),
    );
  }

  group('OrbitField', () {
    testWidgets('renders the center and every orbiting item', (WidgetTester tester) async {
      await pumpPrism(tester, buildField());

      expect(find.text('C'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('paints the concentric rings behind the items', (WidgetTester tester) async {
      await pumpPrism(tester, buildField());

      // Rings are drawn via a CustomPaint layer inside the field.
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('with reduced motion, an item at angle 0 rests to the right of the center', (
      WidgetTester tester,
    ) async {
      await pumpPrism(tester, buildField());
      // No float loop under reduced motion → layout is static and settles.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final Offset center = tester.getCenter(find.text('C'));
      final Offset itemA = tester.getCenter(find.text('A'));

      // angle 0 → purely horizontal to the right, no vertical float drift.
      expect(itemA.dx, greaterThan(center.dx));
      expect((itemA.dy - center.dy).abs(), lessThan(1.0));
    });

    testWidgets('runs the gentle float when motion is allowed (no exception)', (
      WidgetTester tester,
    ) async {
      await pumpPrism(tester, buildField(reduceMotion: false));
      await tester.pump(const Duration(milliseconds: 100));
      // The float controller repeats forever; never pumpAndSettle here.
      expect(find.text('A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
