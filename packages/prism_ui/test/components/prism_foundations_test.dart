import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  group('Prism foundations', () {
    testWidgets('content frame fills compact width', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpPrism(tester, const PrismContentFrame(child: ColoredBox(color: Colors.red)));

      expect(tester.getSize(find.byType(PrismContentFrame)).width, 390);
    });

    testWidgets('content frame caps wide layouts', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpPrism(
        tester,
        const PrismContentFrame(
          maxWidth: 760,
          child: ColoredBox(key: ValueKey<String>('framed-content'), color: Colors.red),
        ),
      );

      expect(tester.getSize(find.byKey(const ValueKey<String>('framed-content'))).width, 760);
    });

    testWidgets('content frame shrink-wraps when used as chrome', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpPrism(
        tester,
        const Align(
          alignment: Alignment.bottomCenter,
          child: PrismContentFrame(
            maxWidth: 640,
            expandHeight: false,
            child: SizedBox(key: ValueKey<String>('chrome'), height: 72),
          ),
        ),
      );

      expect(tester.getSize(find.byType(PrismContentFrame)).height, 72);
      expect(tester.getSize(find.byKey(const ValueKey<String>('chrome'))).width, 640);
    });

    testWidgets('pressable feedback becomes immediate with reduced motion', (
      WidgetTester tester,
    ) async {
      await pumpPrism(
        tester,
        PrismPressable(onPressed: () {}, child: const SizedBox(width: 120, height: 48)),
        disableAnimations: true,
      );

      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration, Duration.zero);
    });

    testWidgets('progress motion becomes immediate with reduced motion', (
      WidgetTester tester,
    ) async {
      await pumpPrism(tester, const PrismProgressBar(value: 0.7), disableAnimations: true);

      expect(
        tester
            .widget<TweenAnimationBuilder<double>>(find.byType(TweenAnimationBuilder<double>))
            .duration,
        Duration.zero,
      );
    });
  });
}
