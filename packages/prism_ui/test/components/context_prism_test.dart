import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  group('context.prism', () {
    testWidgets('resolves the registered scheme under a Prism dark theme', (
      WidgetTester tester,
    ) async {
      late PrismColorScheme captured;
      await pumpPrism(
        tester,
        Builder(
          builder: (BuildContext context) {
            captured = context.prism;
            return const SizedBox.shrink();
          },
        ),
        brightness: Brightness.dark,
      );

      expect(identical(captured, PrismColorScheme.dark), isTrue);
      expect(captured.brightness, Brightness.dark);
    });

    testWidgets('falls back to the light scheme without a registered extension', (
      WidgetTester tester,
    ) async {
      late PrismColorScheme captured;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (BuildContext context) {
              captured = context.prism;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(identical(captured, PrismColorScheme.light), isTrue);
    });
  });
}
