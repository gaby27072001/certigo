import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  setUpAll(disableGoogleFontsFetching);

  group('GradientText', () {
    testWidgets('renders the text through a ShaderMask', (WidgetTester tester) async {
      await pumpPrism(
        tester,
        const GradientText(
          'commencent ici',
          gradient: LinearGradient(colors: kOrbitBrandGradient),
        ),
      );

      expect(find.text('commencent ici'), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });
  });
}
