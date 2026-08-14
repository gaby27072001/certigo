import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../support/prism_harness.dart';

void main() {
  const Color accent = Color(0xFF0078D4);

  group('ChapterSectionCard', () {
    testWidgets('available chapter shows counter, progress and "Commencer ici"', (
      WidgetTester tester,
    ) async {
      int starts = 0;
      await pumpPrism(
        tester,
        SizedBox(
          width: 360,
          child: ChapterSectionCard(
            index: 1,
            title: 'Concepts du cloud',
            accent: accent,
            lessonsTotal: 5,
            lessonsCompleted: 2,
            onStart: () => starts++,
          ),
        ),
      );

      expect(find.text('CHAPITRE 1'), findsOneWidget);
      expect(find.text('Concepts du cloud'), findsOneWidget);
      expect(find.text('2/5 leçons'), findsOneWidget);
      expect(find.text('Commencer ici'), findsOneWidget);

      await tester.tap(find.text('Commencer ici'));
      await tester.pumpAndSettle();
      expect(starts, 1);
    });

    testWidgets('locked chapter shows the padlock hint and ignores taps', (
      WidgetTester tester,
    ) async {
      int starts = 0;
      await pumpPrism(
        tester,
        SizedBox(
          width: 360,
          child: ChapterSectionCard(
            index: 2,
            title: 'Gouvernance',
            accent: accent,
            lessonsTotal: 4,
            lessonsCompleted: 0,
            locked: true,
            lockedHint: 'Termine le chapitre précédent pour débloquer',
            onStart: () => starts++,
          ),
        ),
      );

      expect(find.text('Commencer ici'), findsNothing);
      expect(find.text('Termine le chapitre précédent pour débloquer'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      await tester.tap(find.byType(ChapterSectionCard), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(starts, 0);
    });

    testWidgets('completed chapter shows the check emblem and no start link', (
      WidgetTester tester,
    ) async {
      await pumpPrism(
        tester,
        const SizedBox(
          width: 360,
          child: ChapterSectionCard(
            index: 1,
            title: 'Concepts du cloud',
            accent: accent,
            lessonsTotal: 5,
            lessonsCompleted: 5,
            completed: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('Commencer ici'), findsNothing);
      expect(find.text('5/5 leçons'), findsOneWidget);
    });

    testWidgets('renders the intercalated mascot bubble when provided', (
      WidgetTester tester,
    ) async {
      await pumpPrism(
        tester,
        const SizedBox(
          width: 360,
          child: ChapterSectionCard(
            index: 3,
            title: 'Sécurité',
            accent: accent,
            lessonsTotal: 3,
            lessonsCompleted: 1,
            mascot: AuroraMascot.nimbus,
            mascotMessage: 'Courage, on continue !',
          ),
        ),
      );

      expect(find.byType(SpeechBubble), findsOneWidget);
      expect(find.byType(MascotAvatar), findsOneWidget);
      expect(find.text('Courage, on continue !'), findsOneWidget);
    });
  });
}
