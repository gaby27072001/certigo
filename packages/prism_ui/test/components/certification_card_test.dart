import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  group('CertificationCard', () {
    testWidgets('renders code, title, level chip and lesson/chapter counts', (
      WidgetTester tester,
    ) async {
      await pumpPrism(
        tester,
        const SizedBox(
          width: 340,
          child: CertificationCard(
            code: 'AZ-900',
            title: 'Azure Fundamentals',
            summary: 'Les bases du cloud Azure.',
            levelLabel: 'Fondamentaux',
            lessonCount: 24,
            unitCount: 6,
            accent: Color(0xFF0078D4),
          ),
        ),
      );

      expect(find.text('AZ-900'), findsOneWidget);
      expect(find.text('Azure Fundamentals'), findsOneWidget);
      expect(find.text('Fondamentaux'), findsOneWidget);
      expect(find.text('24 leçons · 6 chapitres'), findsOneWidget);
    });

    testWidgets('hides the counts row when counts are not provided', (WidgetTester tester) async {
      await pumpPrism(
        tester,
        const SizedBox(
          width: 340,
          child: CertificationCard(
            code: 'AI-900',
            title: 'AI Fundamentals',
            accent: Color(0xFF8C5CF6),
          ),
        ),
      );

      expect(find.text('AI-900'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
    });

    testWidgets('announces planned content as disabled and shows a schedule icon', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpPrism(
        tester,
        const SizedBox(
          width: 340,
          child: CertificationCard(
            code: 'GCP',
            title: 'Cloud Digital Leader',
            levelLabel: 'Fondamentaux',
            statusLabel: 'Parcours à venir',
            accent: Color(0xFF4285F4),
          ),
        ),
      );

      expect(find.text('Parcours à venir'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(
        find.bySemanticsLabel('GCP, Cloud Digital Leader, Fondamentaux, Parcours à venir'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('fires onTap and shows the selected check mark', (WidgetTester tester) async {
      int taps = 0;
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpPrism(
        tester,
        SizedBox(
          width: 340,
          child: CertificationCard(
            code: 'DP-900',
            title: 'Data Fundamentals',
            accent: const Color(0xFF22B8CF),
            selected: true,
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      final SemanticsNode node = tester.getSemantics(find.byType(CertificationCard));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await tester.tap(find.text('DP-900'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      semantics.dispose();
    });
  });
}
