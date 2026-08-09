import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  group('PrismProgressBar', () {
    testWidgets('exposes its percentage through semantics', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrism(tester, const PrismProgressBar(value: 0.5, semanticLabel: 'Progression'));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byType(PrismProgressBar)),
        containsSemantics(label: 'Progression', value: '50%'),
      );

      handle.dispose();
    });

    testWidgets('rejects values outside the 0..1 range', (WidgetTester tester) async {
      const double tooHigh = 1.5;

      expect(() => PrismProgressBar(value: tooHigh), throwsAssertionError);
    });
  });
}
