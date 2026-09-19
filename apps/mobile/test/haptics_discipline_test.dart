import 'dart:io';

import 'package:certigo/features/lesson/application/lesson_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Garde de **discipline haptique**.
///
/// ## Pourquoi ce fichier vit dans `apps/mobile/test/`
///
/// Le code gardé est presque entièrement dans `packages/prism_ui`. Une garde
/// posée à côté de lui serait pourtant **verte et incapable de bloquer une
/// fusion** :
///
/// Mesuré sur `ci-mobile.yml` — `packages/prism_ui` n'y apparaît qu'une fois,
/// et ce pas ne lance que `test/rendering/renderer_golden_test.dart`. Les **40
/// autres** fichiers de test du paquet ne tournent nulle part. Le job requis
/// « Flutter app + UI packages » exécute `flutter test --coverage` avec
/// `working-directory: apps/mobile`, et c'est le seul `flutter test` d'une PR.
///
/// C'est le raisonnement déjà écrit dans `prism_tokens_contract_test.dart`,
/// appliqué au même problème. Voir DESIGN.md §10 : *« une garde qui ne peut pas
/// échouer est une décoration »*.
///
/// ## Les deux défauts que cette garde ferme
///
/// 1. `prism_button.dart` appelait `HapticFeedback.lightImpact()` **sans
///    condition** à chaque appui. `PrismButton` étant le bouton de toute
///    l'application, ses 38 sites d'appel vibraient — « Précédent », « Suivant »,
///    « Refaire un examen » compris.
/// 2. Aucun moyen de couper quoi que ce soit : `hapticsEnabled`,
///    `hapticService`, `enableHaptics` — **zéro occurrence** dans le dépôt.
///
/// ## Comment on lit une vibration en test
///
/// Aucun simulateur ne vibre. Mais la vibration *demandée* part sur
/// `SystemChannels.platform`, et ce canal s'écoute. Ce n'est pas un double posé
/// à côté du code : c'est le message que l'iPhone recevrait.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> emitted;

  setUp(() {
    emitted = <String>[];
    PrismHaptics.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        emitted.add('${call.arguments}');
      }
      return null;
    });
  });

  tearDown(() {
    // La porte est un état statique : la laisser fermée contaminerait les
    // fichiers de test suivants.
    PrismHaptics.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget host(Widget child) => MaterialApp(
        theme: PrismTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  // ---------------------------------------------------------------------
  // Sans ces témoins, chaque `isEmpty` ci-dessous serait indiscernable d'un
  // canal muet qui n'enregistre rien. docs/GOVERNANCE.md §7 : un instrument
  // muet doit échouer, pas rendre zéro.
  // ---------------------------------------------------------------------
  group('l\'instrument sait varier', () {
    test('rien n\'est émis quand rien n\'est demandé', () {
      expect(emitted, isEmpty);
    });

    test('porte ouverte, chaque intensité est captée avec son type', () async {
      PrismHaptics.selection();
      PrismHaptics.light();
      PrismHaptics.medium();
      PrismHaptics.heavy();
      await pumpEventQueue();

      expect(emitted, <String>[
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });
  });

  group('un tap ordinaire ne vibre pas', () {
    testWidgets('PrismButton par défaut n\'émet aucune vibration', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        host(PrismButton(label: 'Suivant', onPressed: () => tapped = true)),
      );

      await tester.tap(find.byType(PrismButton));
      await tester.pump();

      // Le tap doit avoir atteint le bouton. Sans cette assertion, un bouton
      // devenu insensible rendrait « aucune vibration » — vrai, et sans rapport.
      expect(tapped, isTrue,
          reason: 'Le tap n\'a pas atteint le bouton : la '
              'mesure de vibration ci-dessous ne porterait sur rien.');
      expect(
        emitted,
        isEmpty,
        reason: 'C\'est le défaut que cette garde ferme : `PrismButton` '
            'appelait `HapticFeedback.lightImpact()` sans condition, donc '
            'chaque bouton de l\'application vibrait à chaque appui.',
      );
    });

    testWidgets('PrismPressable par défaut n\'émet aucune vibration', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        host(
          PrismPressable(
            onPressed: () => tapped = true,
            child: const Padding(padding: EdgeInsets.all(16), child: Text('Carte')),
          ),
        ),
      );

      await tester.tap(find.byType(PrismPressable));
      await tester.pump();

      expect(tapped, isTrue);
      expect(emitted, isEmpty);
    });

    testWidgets('contrôle positif — le même bouton vibre quand on le demande',
        (WidgetTester tester) async {
      // Sans ce témoin, « aucune vibration » ci-dessus pourrait venir d'un
      // `PrismHaptic` cassé plutôt que d'un défaut correctement retiré.
      await tester.pumpWidget(
        host(PrismButton(label: 'Soumettre', haptic: PrismHaptic.light, onPressed: () {})),
      );

      await tester.tap(find.byType(PrismButton));
      await tester.pump();

      expect(
        emitted,
        <String>['HapticFeedbackType.lightImpact'],
        reason: 'L\'exception nommée doit rester possible : le défaut est sûr, '
            'l\'exception se déclare au site d\'appel (DESIGN.md §10, règle 8).',
      );
    });
  });

  group('la porte est le seul point de passage', () {
    // `flutter test` s'exécute avec le répertoire courant à `apps/mobile`.
    const String gatePath = '../../packages/prism_ui/lib/src/feedback/prism_haptics.dart';
    const List<String> roots = <String>['lib', '../../packages/prism_ui/lib'];

    List<File> dartFiles() => <File>[
          for (final String root in roots)
            ...Directory(root)
                .listSync(recursive: true)
                .whereType<File>()
                .where((File f) => f.path.endsWith('.dart')),
        ];

    /// Les appels réels, commentaires exclus — les commentaires de ce dépôt
    /// citent volontairement `HapticFeedback.lightImpact()` pour documenter le
    /// défaut retiré.
    List<String> realCalls(File file) {
      final RegExp call = RegExp(r'HapticFeedback\.\w+');
      return <String>[
        for (final String line in file.readAsLinesSync())
          if (call.hasMatch(line) && !_isComment(line)) line.trim(),
      ];
    }

    test('les arbres scannés existent et contiennent du Dart', () {
      for (final String root in roots) {
        expect(
          Directory(root).existsSync(),
          isTrue,
          reason: '$root est introuvable : le chemin relatif a changé et ce '
              'scan ne mesure plus rien.',
        );
      }
      expect(
        dartFiles().length,
        greaterThan(100),
        reason: 'Trop peu de fichiers lus : le scan est devenu aveugle.',
      );
    });

    test('le détecteur voit la porte elle-même', () {
      // Témoin : si ce motif cessait de trouver quoi que ce soit, l'absence
      // d'infraction ci-dessous serait vraie par construction.
      final File gate = File(gatePath);
      expect(gate.existsSync(), isTrue, reason: '$gatePath est introuvable.');
      expect(
        realCalls(gate),
        isNotEmpty,
        reason: 'La porte n\'appelle plus `HapticFeedback` : le détecteur ne '
            'peut plus rien attraper.',
      );
    });

    test('aucun HapticFeedback n\'est appelé hors de la porte', () {
      final Map<String, List<String>> offenders = <String, List<String>>{};
      for (final File file in dartFiles()) {
        if (file.path.replaceAll(r'\', '/').endsWith('src/feedback/prism_haptics.dart')) {
          continue;
        }
        final List<String> hits = realCalls(file);
        if (hits.isNotEmpty) offenders[file.path] = hits;
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Un `HapticFeedback` appelé hors de `PrismHaptics` échappe au '
            'réglage utilisateur : le réglage « Vibrations » deviendrait un '
            'mensonge pour ces sites.',
      );
    });
  });

  group('le réglage « Vibrations » coupe réellement tout', () {
    /// Déclenche **toutes** les sources de vibration du dépôt.
    Future<void> fireEverySource(WidgetTester tester) async {
      PrismHaptics.selection();
      PrismHaptics.light();
      PrismHaptics.medium();
      PrismHaptics.heavy();
      PrismHaptics.play(PrismHaptic.selection);
      PrismHaptics.play(PrismHaptic.light);

      const HapticLessonFeedback feedback = HapticLessonFeedback();
      feedback.graded(correct: true);
      feedback.graded(correct: false);
      feedback.completed();

      await tester.pumpWidget(
        host(PrismButton(label: 'Soumettre', haptic: PrismHaptic.light, onPressed: () {})),
      );
      await tester.tap(find.byType(PrismButton));
      await tester.pump();

      await tester.pumpWidget(
        host(
          PrismPressable(
            haptic: PrismHaptic.selection,
            onPressed: () {},
            child: const Padding(padding: EdgeInsets.all(16), child: Text('Option')),
          ),
        ),
      );
      await tester.tap(find.byType(PrismPressable));
      await tester.pump();

      // La seconde frappe de fin de leçon est différée.
      await tester.pump(HapticLessonFeedback.successBeatGap * 3);
    }

    testWidgets('porte fermée : plus une seule vibration, de toutes les sources',
        (WidgetTester tester) async {
      PrismHaptics.enabled = false;

      await fireEverySource(tester);

      expect(
        emitted,
        isEmpty,
        reason: 'Le réglage « Vibrations » doit fermer **toutes** les sources, '
            'y compris `HapticLessonFeedback` et les exceptions nommées. Une '
            'seule source qui contourne la porte suffit à rendre le réglage '
            'faux.',
      );
    });

    testWidgets('contrôle positif — porte ouverte, les mêmes gestes vibrent',
        (WidgetTester tester) async {
      PrismHaptics.enabled = true;

      await fireEverySource(tester);

      // 6 appels directs + 4 de la couche leçon (juste, faux, puis la double
      // frappe de fin) + le bouton + la tuile.
      expect(
        emitted,
        hasLength(12),
        reason: 'Si ce compte tombe, le test « porte fermée » ci-dessus '
            'mesurerait un silence qu\'il n\'a pas provoqué.',
      );
    });

    test('la porte rouvre ce qu\'elle a fermé', () async {
      PrismHaptics.enabled = false;
      PrismHaptics.light();
      await pumpEventQueue();
      expect(emitted, isEmpty);

      PrismHaptics.enabled = true;
      PrismHaptics.light();
      await pumpEventQueue();
      expect(emitted, <String>['HapticFeedbackType.lightImpact']);
    });
  });
}

bool _isComment(String line) {
  final String trimmed = line.trimLeft();
  return trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('/*');
}
