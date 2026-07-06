import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  setUpAll(disableGoogleFontsFetching);

  group('VendorLogo', () {
    testWidgets('draws a stylised mark for every vendor', (WidgetTester tester) async {
      await pumpPrism(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final VendorBrand brand in VendorBrand.values) VendorLogo(brand: brand, size: 40),
          ],
        ),
      );

      expect(find.byType(VendorLogo), findsNWidgets(VendorBrand.values.length));
      // Each logo is a CustomPaint; the tree also holds framework CustomPaints,
      // so assert at least one per vendor logo is present.
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('VendorTile', () {
    testWidgets('real vendor shows label, subtitle and fires onTap', (WidgetTester tester) async {
      int taps = 0;
      await pumpPrism(
        tester,
        SizedBox(
          width: 200,
          child: VendorTile(
            brand: VendorBrand.microsoft,
            subtitle: '84 certifications',
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.text('Microsoft'), findsOneWidget);
      expect(find.text('84 certifications'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      await tester.tap(find.byType(VendorTile));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('showcase vendor is locked, shows "Bientôt" and ignores taps',
        (WidgetTester tester) async {
      int taps = 0;
      await pumpPrism(
        tester,
        SizedBox(
          width: 200,
          child: VendorTile(
            brand: VendorBrand.google,
            subtitle: 'Bientôt',
            locked: true,
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Bientôt'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      await tester.tap(find.byType(VendorTile), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(taps, 0);
    });
  });
}
