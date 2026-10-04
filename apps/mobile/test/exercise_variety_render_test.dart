import 'package:certigo/features/lesson/application/answer_grading.dart';
import 'package:certigo/features/lesson/application/lesson_session_state.dart';
import 'package:certigo/features/lesson/application/lesson_step.dart';
import 'package:certigo/features/lesson/presentation/widgets/check_step_widget.dart';
import 'package:certigo/features/lesson/presentation/widgets/cloze_step_widget.dart';
import 'package:certigo/features/lesson/presentation/widgets/match_pairs_step_widget.dart';
import 'package:certigo/features/lesson/presentation/widgets/ordering_step_widget.dart';
import 'package:certigo/features/lesson/presentation/widgets/step_renderer.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// **Ce que le contenu peut déclarer contre ce que le lecteur sait afficher.**
///
/// Le corpus n'exerçait que deux des huit types d'exercice déclarés. Avant
/// d'écrire du contenu qui en utilise davantage, il fallait une mesure : chaque
/// type déclaré atteint-il réellement un widget, ou tombe-t-il dans un repli
/// invisible ? Ce fichier répond en faisant passer, pour chaque [ItemType], une
/// charge utile **publique** — exactement ce que le serveur envoie, clé de
/// réponse retirée — dans le vrai [StepRenderer].
///
/// Il tient lieu de cliquet côté application, là où
/// `tools/validate_content.mjs` tient celui du corpus : retirer un widget,
/// changer un aiguillage ou publier un type sans rendu fait rougir `ci-mobile`.
void main() {
  /// Charge utile publique d'un item, telle que `LessonCheck` la transporte :
  /// `id`, `conceptId`, `type`, `stem`, `options`. Ni `correct`, ni
  /// `explanation` — la correction est serveur-autoritaire.
  QuizItem published(
    ItemType type, {
    required String stem,
    required List<String> labels,
    List<String> matchLabels = const <String>[],
  }) {
    return QuizItem(
      id: 'item-${itemTypeToWire(type)}',
      conceptId: 'c-resource-locks',
      type: type,
      stem: stem,
      options: <QuizOption>[
        for (int i = 0; i < labels.length; i++) QuizOption(id: 'o$i', label: labels[i]),
      ],
      matches: <QuizOption>[
        for (int i = 0; i < matchLabels.length; i++) QuizOption(id: 'm$i', label: matchLabels[i]),
      ],
    );
  }

  /// Les items réellement présents dans `content/az-900/lessons/resource-locks.lesson.yaml`,
  /// réduits à leur charge utile publique. Les intitulés sont raccourcis ; ce
  /// qui est fidèle, c'est le **type** et la **forme** de chaque item.
  final Map<ItemType, QuizItem> authored = <ItemType, QuizItem>{
    ItemType.cloze: published(
      ItemType.cloze,
      stem: 'Un verrou ____ laisse encore modifier la ressource, tandis '
          "qu'un verrou ____ la fige totalement.",
      labels: <String>['CanNotDelete', 'ReadOnly', 'Deny', 'Reader'],
    ),
    ItemType.ordering: published(
      ItemType.ordering,
      stem: "Range les quatre portées d'Azure, de la plus large à la plus étroite.",
      labels: <String>[
        'Groupe de ressources',
        'Ressource',
        'Groupe de gestion',
        'Abonnement',
      ],
    ),
    ItemType.mcq: published(
      ItemType.mcq,
      stem: 'Sur laquelle de ces portées est-il impossible de poser un verrou ?',
      labels: <String>['Le groupe de gestion', "L'abonnement", 'Le groupe de ressources'],
    ),
    ItemType.scenario: published(
      ItemType.scenario,
      stem: 'Un verrou ReadOnly est posé sur un conteneur Cosmos DB. '
          'Que deviennent les écritures ?',
      labels: <String>['Elles continuent', 'Elles échouent'],
    ),
    ItemType.multi: published(
      ItemType.multi,
      stem: 'Quels rôles peuvent créer ou retirer un verrou ?',
      labels: <String>['Propriétaire', "Administrateur de l'accès utilisateur", 'Contributeur'],
    ),
    ItemType.spotTheIssue: published(
      ItemType.spotTheIssue,
      stem: 'Quelle décision manque son objectif ?',
      labels: <String>['Verrouiller le groupe de gestion', 'Verrouiller le groupe de ressources'],
    ),
    ItemType.applied: published(
      ItemType.applied,
      stem: "Classe les étapes dans l'ordre où elles doivent être menées.",
      labels: <String>['Retirer le verrou', 'Supprimer le groupe', 'Localiser le verrou'],
    ),
  };

  Widget host(QuizItem item) {
    final Lesson lesson = Lesson(
      id: 'az900-l-resource-locks',
      trackId: 'az-900',
      unitId: 'az900-u-identity-governance',
      domainId: 'management-governance',
      title: 'Verrous de ressources',
      estMinutes: 9,
      blocks: <LessonBlock>[
        LessonBlock(type: BlockType.check, conceptId: item.conceptId, check: item),
      ],
    );
    final List<LessonStep> steps = buildLessonSteps(lesson);
    final int checkIndex = steps.indexWhere((LessonStep s) => s.isCheck);
    return MaterialApp(
      theme: PrismTheme.light(),
      home: Scaffold(
        body: StepRenderer(
          state: LessonSessionState(
            status: LessonStatus.ready,
            lesson: lesson,
            steps: steps,
            index: checkIndex,
          ),
          onToggleOption: (_) {},
          onMoveOption: ({required int fromIndex, required int toIndex}) {},
          onToggleMatch: (_, __) {},
        ),
      ),
    );
  }

  group('chaque type déclaré atteint un widget', () {
    // L'aiguillage attendu, type par type. Une entrée manquante ou un widget
    // changé fait rougir : c'est le cliquet.
    final Map<ItemType, Type> expectedWidget = <ItemType, Type>{
      ItemType.mcq: CheckStepWidget,
      ItemType.multi: CheckStepWidget,
      ItemType.scenario: CheckStepWidget,
      ItemType.spotTheIssue: CheckStepWidget,
      ItemType.cloze: ClozeStepWidget,
      ItemType.ordering: OrderingStepWidget,
      ItemType.applied: OrderingStepWidget,
      ItemType.matchPairs: MatchPairsStepWidget,
    };

    test("l'instrument n'est pas muet", () {
      // Sans ce contrôle, un catalogue vide ferait passer toute la suite.
      expect(ItemType.values, isNotEmpty);
      expect(
        expectedWidget.keys.toSet(),
        ItemType.values.toSet()..remove(ItemType.unknown),
        reason: 'Un ItemType a été ajouté ou retiré sans décider de son widget.',
      );
    });

    group('type inconnu — repli explicite', () {
      testWidgets('affiche un message de compatibilité sans QCM', (WidgetTester tester) async {
        final QuizItem unknown = published(
          ItemType.unknown,
          stem: 'Question future.',
          labels: <String>['Réponse A', 'Réponse B'],
        );

        await tester.pumpWidget(host(unknown));
        await tester.pumpAndSettle();

        expect(find.byType(CheckStepWidget), findsNothing);
        expect(find.text('Exercice non pris en charge'), findsOneWidget);
        expect(
          find.text('Cet exercice n\'est pas encore pris en charge par cette version de l\'app.'),
          findsOneWidget,
        );
        expect(isAnswerableCheck(unknown), isFalse);
      });
    });

    for (final MapEntry<ItemType, QuizItem> entry in authored.entries) {
      final String wire = itemTypeToWire(entry.key);

      testWidgets('$wire est rendu par ${expectedWidget[entry.key]}', (WidgetTester tester) async {
        // Fenêtre volontairement large : la police de test (Ahem) dessine chaque
        // glyphe dans un carré plein, donc un libellé comme « Vérifie ta
        // compréhension » y occupe environ le double de sa largeur réelle et
        // déborde d'un gabarit téléphone. Ce test mesure l'**aiguillage**
        // type → widget, pas la mise en page ; la mise en page est couverte par
        // les goldens de `packages/prism_ui`.
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(host(entry.value));
        await tester.pumpAndSettle();

        expect(
          find.byType(expectedWidget[entry.key]!),
          findsOneWidget,
          reason: '"$wire" n\'atteint pas son widget : il tombe dans un repli.',
        );
        // Aucun type authorable ne doit atterrir sur le repli générique.
        if (expectedWidget[entry.key] != CheckStepWidget) {
          expect(find.byType(CheckStepWidget), findsNothing);
        }
      });

      test('$wire est répondable tel que publié', () {
        expect(
          isAnswerableCheck(entry.value),
          isTrue,
          reason: '"$wire" est publiable mais la CTA de validation resterait grisée.',
        );
      });
    }
  });

  group('matchPairs — impasse épinglée', () {
    // Le widget existe et fonctionne, mais seulement si l'item porte une
    // colonne droite `matches`. Or `lesson.schema.json` l'interdit
    // (`additionalProperties: false`), `LessonCheck` n'a pas ce champ et
    // `seed_content.py` ne l'émet pas : un item publié ne peut pas en avoir.
    final QuizItem asPublished = published(
      ItemType.matchPairs,
      stem: 'Associe chaque service à son modèle.',
      labels: <String>['Azure VM', 'App Service'],
    );
    final QuizItem asBundled = published(
      ItemType.matchPairs,
      stem: 'Associe chaque service à son modèle.',
      labels: <String>['Azure VM', 'App Service'],
      matchLabels: <String>['IaaS', 'PaaS'],
    );

    test('publié via la chaîne de contenu, il est irrépondable', () {
      expect(asPublished.matches, isEmpty);
      expect(
        isAnswerableCheck(asPublished),
        isFalse,
        reason: 'Si ceci devient vrai, `matches` traverse enfin la chaîne de '
            'contenu : retirer matchPairs de UNUSED_ITEM_TYPES_PIN.',
      );
    });

    test('embarqué en dur (mode démo), il est répondable', () {
      // `sample_lesson.dart` contourne la chaîne : c'est la seule façon
      // d'observer ce widget aujourd'hui.
      expect(isAnswerableCheck(asBundled), isTrue);
    });

    testWidgets('publié, sa colonne droite est vide à l\'écran', (WidgetTester tester) async {
      await tester.pumpWidget(host(asPublished));
      await tester.pumpAndSettle();

      expect(find.byType(MatchPairsStepWidget), findsOneWidget);
      // Les deux concepts s'affichent ; rien à quoi les associer.
      expect(find.text('Azure VM'), findsOneWidget);
      expect(find.text('IaaS'), findsNothing);
    });
  });

  group('familles de correction — parité client/serveur', () {
    // Le serveur (`QuizService.IsCorrect`) trie les deux listes avant de les
    // comparer : il corrige **sans tenir compte de l'ordre**, pour tous les
    // types. Le client, lui, compare position par position pour trois d'entre
    // eux. Cet écart est épinglé ici pour qu'il cesse d'être invisible.
    const List<String> abc = <String>['a', 'b', 'c'];
    const List<String> cba = <String>['c', 'b', 'a'];

    test('trois types sont sensibles à l\'ordre côté client', () {
      final Set<ItemType> ordered = <ItemType>{
        for (final ItemType type in ItemType.values)
          if (!gradeSelection(type, cba, abc)) type,
      };

      expect(
        ordered,
        <ItemType>{ItemType.ordering, ItemType.cloze, ItemType.applied},
        reason: 'La liste des types corrigés dans l\'ordre a changé.\n'
            'Rappel : le serveur trie avant de comparer, donc il accepte '
            'l\'ordre inverse pour ces trois types. Toute évolution ici doit '
            'être reflétée dans Certigo.Application/Services/QuizService.cs.',
      );
    });

    test('les autres types comparent des ensembles', () {
      for (final ItemType type in <ItemType>[
        ItemType.mcq,
        ItemType.multi,
        ItemType.scenario,
        ItemType.spotTheIssue,
        ItemType.matchPairs,
      ]) {
        expect(gradeSelection(type, cba, abc), isTrue, reason: itemTypeToWire(type));
      }
    });
  });
}
