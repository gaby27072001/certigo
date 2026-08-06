// Hermetic tests for the fallback widget (ADR-003).
//
// [PrismBlockFallback] is intentionally theme-free (it only depends on
// `material.dart`), so these tests pump it inside a plain [MaterialApp] rather
// than the Prism harness and keep this unit focused on fallback behavior.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/src/rendering/block_fallback.dart';

Future<void> pumpFallback(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('PrismBlockFallback', () {
    testWidgets('renders visibly for every reason without throwing',
        (WidgetTester tester) async {
      for (final BlockFallbackReason reason in BlockFallbackReason.values) {
        await pumpFallback(
          tester,
          PrismBlockFallback(reason: reason, blockType: 'demo'),
        );

        expect(
          find.byKey(PrismBlockFallback.rootKey),
          findsOneWidget,
          reason: 'fallback card should be present for $reason',
        );
        expect(find.byType(Icon), findsOneWidget);
        expect(find.byType(Text), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('names the offending block type for an unknown type',
        (WidgetTester tester) async {
      await pumpFallback(
        tester,
        const PrismBlockFallback(
          reason: BlockFallbackReason.unknownType,
          blockType: 'sparkle',
        ),
      );

      expect(find.textContaining('sparkle'), findsOneWidget);
    });

    testWidgets('mentions the schema version for an unsupported schema',
        (WidgetTester tester) async {
      await pumpFallback(
        tester,
        const PrismBlockFallback(
          reason: BlockFallbackReason.unsupportedSchema,
          schemaVersion: 9,
        ),
      );

      expect(find.textContaining('renderer/9'), findsOneWidget);
    });

    testWidgets('shows diagnostic detail when provided',
        (WidgetTester tester) async {
      await pumpFallback(
        tester,
        const PrismBlockFallback(
          reason: BlockFallbackReason.malformed,
          detail: 'FormatException: missing body',
        ),
      );

      expect(find.textContaining('missing body'), findsOneWidget);
    });

    testWidgets('carries an accessibility label', (WidgetTester tester) async {
      await pumpFallback(
        tester,
        const PrismBlockFallback(reason: BlockFallbackReason.malformed),
      );

      expect(
        find.bySemanticsLabel('Bloc de contenu de repli'),
        findsOneWidget,
      );
    });
  });
}
