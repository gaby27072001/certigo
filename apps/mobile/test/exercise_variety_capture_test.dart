@Tags(<String>['capture'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:certigo/features/lesson/application/lesson_session_state.dart';
import 'package:certigo/features/lesson/application/lesson_step.dart';
import 'package:certigo/features/lesson/presentation/widgets/step_renderer.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Génère une capture PNG **lisible** de chaque type d'exercice.
///
/// ## Pourquoi un outil séparé plutôt qu'un golden
///
/// Les goldens du dépôt sont rendus avec la police de test par défaut, qui
/// dessine chaque glyphe comme un rectangle plein : `manager_dashboard.png` est
/// une preuve de **mise en page**, illisible pour un humain. Ce fichier charge
/// la police Roboto **livrée avec le SDK Flutter** (donc présente sur tout poste
/// et sur les runners) et produit des images où le texte se lit.
///
/// Ce n'est **pas une gate** : aucune comparaison de pixels, aucun échec
/// possible en CI. Sans `CERTIGO_EXERCISE_CAPTURE=1`, rien ne s'exécute. C'est
/// un outil de preuve, invoqué à la main :
///
/// ```powershell
/// $env:CERTIGO_EXERCISE_CAPTURE = '1'
/// cd apps/mobile
/// flutter test test/exercise_variety_capture_test.dart --tags capture
/// # -> apps/mobile/build/exercise-captures/*.png
/// ```
///
/// La garantie de non-régression est ailleurs, dans deux gates réellement
/// exécutées : `exercise_variety_render_test.dart` (ci-mobile) et
/// `tools/validate_content.mjs` (ci-content).
void main() {
  // Génération à la demande : `--update-goldens` écrit les PNG, et rien
  // d'autre ne s'exécute. Sans ce drapeau la suite est entièrement ignorée,
  // donc **aucune comparaison de pixels en CI** — des images produites sur
  // Windows ne peuvent pas être rejouées à l'identique sur un runner Linux, et
  // une gate qui échoue pour cette raison ne surveillerait rien.
  final bool capture = autoUpdateGoldenFiles;
  // `FontLoader.load()` requires a live binding; without this the future never
  // completes and the run hangs instead of failing.
  TestWidgetsFlutterBinding.ensureInitialized();

  QuizItem item(
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

  // Les items de content/az-900/lessons/resource-locks.lesson.yaml, réduits à
  // leur charge utile publique (sans clé de réponse), plus matchPairs dans ses
  // deux états : publié (colonne droite vide) et embarqué (mode démo).
  final Map<String, QuizItem> scenes = <String, QuizItem>{
    'cloze': item(
      ItemType.cloze,
      stem: 'Un verrou ____ laisse encore modifier la ressource mais interdit de la '
          "supprimer, tandis qu'un verrou ____ la fige totalement.",
      labels: <String>['CanNotDelete', 'ReadOnly', 'Deny', 'Reader'],
    ),
    'ordering': item(
      ItemType.ordering,
      stem: "Range les quatre portées d'Azure, de la plus large à la plus étroite.",
      labels: <String>['Groupe de ressources', 'Ressource', 'Groupe de gestion', 'Abonnement'],
    ),
    'mcq': item(
      ItemType.mcq,
      stem: 'Sur laquelle de ces portées est-il impossible de poser un verrou de ressource ?',
      labels: <String>[
        'Le groupe de gestion',
        "L'abonnement",
        'Le groupe de ressources',
        'Une ressource individuelle',
      ],
    ),
    'scenario': item(
      ItemType.scenario,
      stem: 'Vous posez un verrou ReadOnly sur un conteneur Azure Cosmos DB. Une '
          'application y écrit des documents en continu. Que se passe-t-il ?',
      labels: <String>[
        'Elles continuent : le verrou ne couvre que le plan de gestion',
        'Elles échouent : ReadOnly rend le conteneur non inscriptible',
      ],
    ),
    'multi': item(
      ItemType.multi,
      stem: 'Quels rôles intégrés peuvent créer ou retirer un verrou ? Plusieurs réponses.',
      labels: <String>[
        'Propriétaire (Owner)',
        "Administrateur de l'accès utilisateur",
        'Contributeur (Contributor)',
        'Lecteur (Reader)',
      ],
    ),
    'spotTheIssue': item(
      ItemType.spotTheIssue,
      stem: "Une équipe veut empêcher toute suppression accidentelle en production. "
          'Quelle décision manque son objectif ?',
      labels: <String>[
        "Poser un verrou sur le groupe de gestion qui contient l'abonnement",
        'Poser un verrou CanNotDelete sur le groupe de ressources',
        'Limiter le rôle Propriétaire à deux personnes',
      ],
    ),
    'applied': item(
      ItemType.applied,
      stem: 'Vous devez supprimer un groupe de ressources protégé par un verrou hérité. '
          "Classe les étapes dans l'ordre.",
      labels: <String>[
        'Retirer le verrou à la portée où il est défini',
        'Supprimer le groupe de ressources',
        "Localiser le verrou et la portée d'où il est hérité",
        'Vérifier vos droits sur cette portée',
      ],
    ),
    'matchPairs-publie-colonne-vide': item(
      ItemType.matchPairs,
      stem: 'Associe chaque service Azure à son modèle de service.',
      labels: <String>['Azure Virtual Machines', 'Azure App Service', 'Microsoft 365'],
    ),
    'matchPairs-embarque-mode-demo': item(
      ItemType.matchPairs,
      stem: 'Associe chaque service Azure à son modèle de service.',
      labels: <String>['Azure Virtual Machines', 'Azure App Service', 'Microsoft 365'],
      matchLabels: <String>['IaaS', 'PaaS', 'SaaS'],
    ),
  };

  setUpAll(() async {
    if (!capture) return;
    // Charge les **vraies** polices Prism, déjà présentes dans le dépôt. Sans
    // cela le harnais dessine chaque glyphe comme un rectangle plein : les
    // goldens existants du dépôt (`manager_dashboard.png`) prouvent une mise en
    // page, pas un texte lisible.
    //
    // Le nom de famille doit être celui que Flutter **résout**, pas celui
    // déclaré : un `TextStyle(fontFamily: 'Archivo', package: 'prism_ui')`
    // demande au moteur la famille `packages/prism_ui/Archivo`.
    const String prismAssets = '../../packages/prism_ui/assets/fonts';
    for (final MapEntry<String, String> font in <String, String>{
      'packages/prism_ui/Archivo': 'Archivo-Variable.ttf',
      'packages/prism_ui/Inter': 'Inter-Variable.ttf',
      'packages/prism_ui/JetBrainsMono': 'JetBrainsMono-Variable.ttf',
      'packages/prism_ui/PlusJakartaSans': 'PlusJakartaSans-Variable.ttf',
    }.entries) {
      final File file = File('$prismAssets/${font.value}');
      if (!file.existsSync()) continue;
      await ui.loadFontFromList(file.readAsBytesSync(), fontFamily: font.key);
    }
    // Les icônes Material viennent du SDK, pas du dépôt : sans elles, chaque
    // pictogramme se dessine en carré vide et la capture ment sur l'écran réel.
    final String? sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk == null) return;
    final File icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await ui.loadFontFromList(icons.readAsBytesSync(), fontFamily: 'MaterialIcons');
    }
  });

  for (final MapEntry<String, QuizItem> scene in scenes.entries) {
    testWidgets('capture ${scene.key}', (WidgetTester tester) async {
      if (!capture) {
        markTestSkipped('lancer avec --update-goldens pour régénérer les captures');
        return;
      }
      tester.view.physicalSize = const Size(430, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final QuizItem quizItem = scene.value;
      final Lesson lesson = Lesson(
        id: 'az900-l-resource-locks',
        trackId: 'az-900',
        unitId: 'az900-u-identity-governance',
        domainId: 'management-governance',
        title: 'Verrous de ressources',
        estMinutes: 9,
        blocks: <LessonBlock>[
          LessonBlock(type: BlockType.check, conceptId: quizItem.conceptId, check: quizItem),
        ],
      );
      final List<LessonStep> steps = buildLessonSteps(lesson);
      final GlobalKey key = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: PrismTheme.light(),
            home: Scaffold(
              backgroundColor: PrismTheme.light().scaffoldBackgroundColor,
              body: SafeArea(
                child: StepRenderer(
                  state: LessonSessionState(
                    status: LessonStatus.ready,
                    lesson: lesson,
                    steps: steps,
                    index: steps.indexWhere((LessonStep s) => s.isCheck),
                  ),
                  onToggleOption: (_) {},
                  onToggleMatch: (_, __) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // `matchesGoldenFile` est le seul chemin qui pilote correctement la
      // rastérisation sous le harnais automatisé : un appel direct à
      // `RenderRepaintBoundary.toImage()` attend une trame que rien ne planifie
      // et bloque indéfiniment (mesuré).
      await expectLater(find.byKey(key), matchesGoldenFile('exercise-captures/${scene.key}.png'));
    });
  }
}
