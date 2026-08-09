import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:certigo/features/lesson/application/check_outcome.dart';
import 'package:certigo/features/lesson/presentation/widgets/check_step_widget.dart';
import 'package:certigo/features/lesson/presentation/widgets/cloze_step_widget.dart';
import 'package:certigo/features/lesson/presentation/widgets/match_pairs_step_widget.dart';
import 'package:certigo/features/lesson/presentation/widgets/ordering_step_widget.dart';
import 'package:prism_ui/prism_ui.dart';

/// Widget tests for the Duolingo-style exercise shells (§3.3). Each widget is
/// *controlled* (selection + outcome owned by the controller), so we pump it
/// under a bare Prism host — no backend, router or network — and assert the
/// French type framing, the rendered options, and that taps fire the right
/// callback with the right option id.
void main() {
  // Full-width, scrollable host: the shells are tall Columns, so vertical
  // scroll prevents height overflow. The width is the full 800px test surface
  // (the test font renders each glyph ~1em wide, so headers need the room).
  Widget host(Widget child) => MaterialApp(
        theme: PrismTheme.light(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  group('OrderingStepWidget', () {
    testWidgets('shows the ordering framing and returns a bank chip via onToggle', (tester) async {
      String? toggled;
      await tester.pumpWidget(
        host(
          OrderingStepWidget(
            item: const QuizItem(
              id: 'o1',
              conceptId: 'c-test',
              type: ItemType.ordering,
              stem: 'Ordonne les étapes.',
              options: <QuizOption>[
                QuizOption(id: 's1', label: 'Réseau'),
                QuizOption(id: 's2', label: 'NSG'),
              ],
            ),
            selection: const <String>[],
            outcome: null,
            onToggle: (String id) => toggled = id,
          ),
        ),
      );

      expect(find.text('Mets dans le bon ordre'), findsOneWidget);
      expect(find.text('Ordonne les étapes.'), findsOneWidget);
      expect(find.text('Réseau'), findsOneWidget);

      await tester.tap(find.text('Réseau'));
      await tester.pump();
      expect(toggled, 's1');
    });
  });

  group('ClozeStepWidget', () {
    testWidgets('shows the cloze framing and word bank, and fires onToggle', (tester) async {
      String? toggled;
      await tester.pumpWidget(
        host(
          ClozeStepWidget(
            item: const QuizItem(
              id: 'c1',
              conceptId: 'c-test',
              type: ItemType.cloze,
              stem: 'En ____ tu gères.',
              options: <QuizOption>[
                QuizOption(id: 'w-iaas', label: 'IaaS'),
                QuizOption(id: 'w-paas', label: 'PaaS'),
              ],
            ),
            selection: const <String>[],
            outcome: null,
            onToggle: (String id) => toggled = id,
          ),
        ),
      );

      expect(find.text('Complète la phrase'), findsOneWidget);
      expect(find.text('BANQUE DE MOTS'), findsOneWidget);
      expect(find.text('IaaS'), findsOneWidget);

      await tester.tap(find.text('IaaS'));
      await tester.pump();
      expect(toggled, 'w-iaas');
    });
  });

  group('MatchPairsStepWidget', () {
    testWidgets('shows the pairing framing and commits a completed pair', (tester) async {
      final List<String> pairs = <String>[];
      await tester.pumpWidget(
        host(
          MatchPairsStepWidget(
            item: const QuizItem(
              id: 'm1',
              conceptId: 'c-test',
              type: ItemType.matchPairs,
              stem: 'Associe.',
              options: <QuizOption>[QuizOption(id: 'l1', label: 'VM')],
              matches: <QuizOption>[QuizOption(id: 'r1', label: 'IaaS')],
            ),
            selection: const <String>[],
            outcome: null,
            onToggleMatch: (String l, String r) => pairs.add('$l:$r'),
          ),
        ),
      );

      expect(find.text('Associe les paires'), findsOneWidget);
      expect(find.text('Touche un concept puis sa correspondance.'), findsOneWidget);

      // A left tap alone is transient (no commit); the right tap completes it.
      await tester.tap(find.text('VM'));
      await tester.pump();
      expect(pairs, isEmpty);

      await tester.tap(find.text('IaaS'));
      await tester.pump();
      expect(pairs, <String>['l1:r1']);
    });
  });

  group('CheckStepWidget', () {
    testWidgets('scenario type reads "Scénario" and fires onToggle on a pick', (tester) async {
      String? toggled;
      await tester.pumpWidget(
        host(
          CheckStepWidget(
            item: const QuizItem(
              id: 'sc1',
              conceptId: 'c-test',
              type: ItemType.scenario,
              stem: 'Quel modèle ?',
              options: <QuizOption>[
                QuizOption(id: 'a', label: 'PaaS'),
                QuizOption(id: 'b', label: 'IaaS'),
              ],
            ),
            selection: const <String>[],
            outcome: null,
            onToggle: (String id) => toggled = id,
          ),
        ),
      );

      expect(find.text('Scénario'), findsOneWidget);
      expect(find.byIcon(Icons.alt_route_rounded), findsOneWidget);

      await tester.tap(find.text('PaaS'));
      await tester.pump();
      expect(toggled, 'a');
    });

    testWidgets('spotTheIssue type reads "Repère l\'erreur"', (tester) async {
      await tester.pumpWidget(
        host(
          const CheckStepWidget(
            item: QuizItem(
              id: 'si1',
              conceptId: 'c-test',
              type: ItemType.spotTheIssue,
              stem: 'Quelle action affaiblit la sécurité ?',
              options: <QuizOption>[
                QuizOption(id: 'a', label: 'Ouvrir RDP au monde'),
                QuizOption(id: 'b', label: 'Activer MFA'),
              ],
            ),
            selection: <String>[],
            outcome: null,
            onToggle: _noop,
          ),
        ),
      );

      expect(find.text('Repère l\'erreur'), findsOneWidget);
      expect(find.byIcon(Icons.bug_report_rounded), findsOneWidget);
    });

    testWidgets('a graded check reveals the explanation and stops accepting taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          CheckStepWidget(
            item: const QuizItem(
              id: 'q1',
              conceptId: 'c-test',
              type: ItemType.mcq,
              stem: 'Qui patche l\'OS invité ?',
              options: <QuizOption>[
                QuizOption(id: 'a', label: 'Le client'),
                QuizOption(id: 'b', label: 'Microsoft'),
              ],
            ),
            selection: const <String>['a'],
            outcome: const CheckOutcome(
              correct: true,
              correctAnswer: <String>['a'],
              explanation: 'En IaaS, l\'OS invité est à vous.',
            ),
            onToggle: (String _) => taps++,
          ),
        ),
      );

      expect(find.textContaining('En IaaS'), findsOneWidget);

      await tester.tap(find.text('Le client'));
      await tester.pump();
      expect(taps, 0, reason: 'options are inert once graded');
    });
  });
}

void _noop(String _) {}
