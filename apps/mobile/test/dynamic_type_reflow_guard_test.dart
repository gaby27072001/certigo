import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:certigo/app/providers.dart';
import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/presentation/landing_screen.dart';
import 'package:certigo/features/home/presentation/coach_section.dart';
import 'package:certigo/features/path/presentation/path_screen.dart';
import 'package:prism_ui/prism_ui.dart';

import 'auth_controller_test.dart' show FakeAuthGateway, FakeCredentialsGateway, FakeSessionStore;
import 'support/prism_fonts.dart';

/// **Garde de reflow Dynamic Type.**
///
/// Règle P0 des HIG reprise par `DESIGN.md` : *à Dynamic Type maximal, aucune
/// action n'est masquée et aucun texte porteur d'information n'est amputé.*
///
/// Cette garde rend les écrans du parcours critique à 390×844 — le gabarit
/// iPhone 14/15/16 — puis mesure trois choses que l'œil ne peut pas vérifier
/// à l'échelle du dépôt :
///
/// 1. **aucun débordement de mise en page** (`RenderFlex overflowed`) ;
/// 2. **aucun texte porteur tronqué** (`RenderParagraph.didExceedMaxLines`) ;
/// 3. **l'action primaire reste dans le viewport** sans défilement à 2×.
///
/// Elle vit dans `apps/mobile/test/` **délibérément** : le job CI requis
/// « Flutter app + UI packages » n'exécute `flutter test` que dans `apps/mobile`.
/// Posée dans `packages/prism_ui/test/`, elle serait verte et incapable de
/// bloquer une fusion.
///
/// Les quatre défauts qu'elle mordait à l'écriture, mesurés sur `e21d0a8b` :
///
/// | Écran   | Échelle | Mesure                                                    |
/// |---------|---------|-----------------------------------------------------------|
/// | path    | 1.0     | nom de certif (65 c) peint sur 221×24 px — tronqué         |
/// | path    | 1.0     | chapitre (57 c) peint sur 177.8×19 px — tronqué            |
/// | path    | 2.0     | `A RenderFlex overflowed by 23 pixels on the bottom`       |
/// | path    | 2.0     | chapitre (57 c) peint sur **34.8 px de large** — affamé    |
/// | landing | 2.0     | CTA « Commencer » à y=1443 pour un viewport de 844         |
/// | coach   | 1.0/2.0 | titre de recommandation (39 c) tronqué                     |
void main() {
  // Les vraies polices Prism, sinon chaque glyphe est un carré plein et la
  // garde mesure une typographie qui n'existe pas. `FontLoader` exige un
  // binding vivant : sans cette ligne la future ne se résout jamais.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPrismFonts);

  /// Gabarit de référence : iPhone 14/15/16 en points logiques.
  const Size kPhone = Size(390, 844);

  /// Le nom le plus long du catalogue `content/` (65 caractères) — relevé sur
  /// `content/*/track.yaml`. Prendre le pire cas réel, pas un cas d'école :
  /// une garde calibrée sur un nom court ne mord jamais en production.
  const String kLongestRealTrackName =
      'Microsoft Certified: Azure AI Apps and Agents Developer Associate';

  /// Le titre d'unité le plus long du catalogue (44 caractères).
  const String kLongestRealUnitTitle = 'Concepts de sécurité, conformité et identité';

  void sizePhone(WidgetTester tester) {
    tester.view.physicalSize = kPhone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Le paragraphe rendu dont le texte plat vaut [text], ou `null`.
  RenderParagraph? paragraphOf(WidgetTester tester, String text) {
    for (final RenderObject node in tester.allRenderObjects) {
      if (node is RenderParagraph && node.text.toPlainText() == text) {
        return node;
      }
    }
    return null;
  }

  /// Échoue si [text] est amputé — avec la mesure réelle dans le message, car
  /// un échec qui ne dit pas *de combien* oblige à refaire l'enquête.
  void expectNotTruncated(WidgetTester tester, String text, {required String where}) {
    final RenderParagraph? p = paragraphOf(tester, text);
    expect(p, isNotNull, reason: '$where : le texte « $text » est absent du rendu.');
    expect(
      p!.didExceedMaxLines,
      isFalse,
      reason: '$where : « $text » (${text.length} c) est TRONQUÉ — '
          'peint sur ${p.size.width.toStringAsFixed(1)}×${p.size.height.toStringAsFixed(1)} px. '
          'Un texte porteur d’information doit refluer, pas être amputé.',
    );
  }

  /// Échoue si [text] est peint dans un ruban plus étroit que [minFraction] de
  /// la largeur d'écran. Capture l'affamement horizontal : une `Row` qui laisse
  /// 34.8 px à un libellé de 57 caractères « tient » sans déborder, mais
  /// n'affiche rien de lisible.
  void expectNotStarved(
    WidgetTester tester,
    String text, {
    required String where,
    double minFraction = 0.4,
  }) {
    final RenderParagraph? p = paragraphOf(tester, text);
    expect(p, isNotNull, reason: '$where : le texte « $text » est absent du rendu.');
    final double min = kPhone.width * minFraction;
    expect(
      p!.size.width,
      greaterThanOrEqualTo(min),
      reason: '$where : « $text » n’a que ${p.size.width.toStringAsFixed(1)} px de large '
          '(plancher ${min.toStringAsFixed(0)} px). La ligne horizontale doit devenir '
          'une pile verticale au lieu d’affamer le libellé.',
    );
  }

  void expectNoOverflow(WidgetTester tester, {required String where}) {
    final Object? error = tester.takeException();
    expect(
      error,
      isNull,
      reason: '$where : la mise en page déborde à grand texte — $error',
    );
  }

  // ---------------------------------------------------------------------------
  // Harnais
  // ---------------------------------------------------------------------------

  Future<void> pumpLanding(WidgetTester tester, double scale) async {
    sizePhone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authGatewayProvider.overrideWithValue(FakeAuthGateway()),
          credentialsGatewayProvider.overrideWithValue(FakeCredentialsGateway()),
          sessionStoreProvider.overrideWithValue(FakeSessionStore()),
          authConfiguredProvider.overrideWithValue(true),
          authRequiredProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          theme: PrismTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const LandingScreen(),
          ),
        ),
      ),
    );
    // Jamais `pumpAndSettle` : `OrbitField` anime un flottement en boucle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  LearningPath worstCasePath() => const LearningPath(
        trackId: 'ai-102',
        trackName: kLongestRealTrackName,
        exam: 'Examen AI-102',
        readinessScore: 72,
        readinessTrend7d: 5,
        units: <PathUnit>[
          PathUnit(
            id: 'u1',
            title: kLongestRealUnitTitle,
            domainId: 'd1',
            status: NodeStatus.inProgress,
            lessons: <PathLesson>[
              PathLesson(
                id: 'l1',
                title: 'Modèles de service',
                status: NodeStatus.inProgress,
                estMinutes: 5,
                masteryPct: 40,
              ),
            ],
          ),
        ],
        domains: <DomainProgress>[
          DomainProgress(id: 'd1', name: 'Concepts cloud', weight: 0.3, score: 70),
        ],
      );

  Future<void> pumpPath(WidgetTester tester, double scale) async {
    sizePhone(tester);
    final GoRouter router = GoRouter(
      initialLocation: '/path',
      routes: <RouteBase>[
        GoRoute(
          path: '/path',
          builder: (BuildContext context, GoRouterState state) =>
              const PathScreen(trackId: 'ai-102'),
        ),
        GoRoute(
          path: '/lesson/:trackId/:lessonId',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('LEÇON'))),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          pathProvider('ai-102').overrideWith((Ref ref) async => worstCasePath()),
          sessionStoreProvider.overrideWithValue(FakeSessionStore()),
        ],
        child: MaterialApp.router(
          theme: PrismTheme.light(),
          routerConfig: router,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  const Recommendation worstCaseRecommendation = Recommendation(
    kind: RecommendationKind.review,
    lessonId: 'l1',
    unitId: 'u1',
    conceptId: 'c1',
    title: 'Révise le stockage Azure et ses niveaux',
    domainId: 'd1',
    domainName: 'Stockage',
    reason: 'Ce concept est dû à la révision.',
    estMinutes: 5,
    priority: 80,
    masteryPct: 40,
    forgettingRiskPct: 75,
  );

  Future<void> pumpCoachRow(WidgetTester tester, double scale) async {
    sizePhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: PrismTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Center(child: CoachCard(item: worstCaseRecommendation, onTap: () {})),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // ---------------------------------------------------------------------------
  // Parcours — bandeau de certification
  // ---------------------------------------------------------------------------

  for (final double scale in <double>[1.0, 1.5, 2.0]) {
    testWidgets(
      'parcours @$scale× : le nom de certification et le chapitre refluent sans être amputés',
      (WidgetTester tester) async {
        await pumpPath(tester, scale);
        final String where = 'parcours @$scale×';

        expectNoOverflow(tester, where: where);
        expectNotTruncated(tester, kLongestRealTrackName, where: where);
        expectNotStarved(tester, 'Chapitre 1 · $kLongestRealUnitTitle', where: where);
        expectNotTruncated(tester, 'Chapitre 1 · $kLongestRealUnitTitle', where: where);
      },
    );
  }

  testWidgets('parcours @3.0× : la mise en page tient encore (Dynamic Type AX5)', (
    WidgetTester tester,
  ) async {
    await pumpPath(tester, 3.0);
    expectNoOverflow(tester, where: 'parcours @3.0×');
  });

  testWidgets('parcours @2.0× : les en-têtes ne confisquent pas le viewport', (
    WidgetTester tester,
  ) async {
    await pumpPath(tester, 2.0);
    // Le contenu réel du parcours — la première bulle de leçon — doit rester
    // visible au premier frame. Des en-têtes qui grossissent avec le texte
    // jusqu'à pousser le contenu hors de l'écran « sacrifient le contenu
    // principal pour préserver une maquette figée ».
    final Finder firstNode = find.byType(PathNode).first;
    expect(firstNode, findsOneWidget);
    final Rect node = tester.getRect(firstNode);
    expect(
      node.top,
      lessThan(kPhone.height),
      reason: 'parcours @2.0× : la première leçon est peinte à y=${node.top.toStringAsFixed(1)} '
          'pour un viewport de ${kPhone.height.toInt()} px — les en-têtes ont confisqué l’écran.',
    );
  });

  // ---------------------------------------------------------------------------
  // Accueil — carte du coach
  // ---------------------------------------------------------------------------

  for (final double scale in <double>[1.0, 2.0]) {
    testWidgets('coach @$scale× : le titre de la recommandation reflue sans être amputé', (
      WidgetTester tester,
    ) async {
      await pumpCoachRow(tester, scale);
      final String where = 'coach @$scale×';
      expectNoOverflow(tester, where: where);
      expectNotTruncated(tester, worstCaseRecommendation.title, where: where);
    });
  }

  // ---------------------------------------------------------------------------
  // Ouverture — le CTA ne descend pas sous le pli
  // ---------------------------------------------------------------------------

  testWidgets('ouverture @1.0× : le CTA « Commencer » est visible sans défiler (non-régression)', (
    WidgetTester tester,
  ) async {
    await pumpLanding(tester, 1.0);
    expectNoOverflow(tester, where: 'ouverture @1.0×');
    final Rect cta = tester.getRect(find.text('Commencer'));
    expect(
      cta.bottom,
      lessThanOrEqualTo(kPhone.height),
      reason: 'ouverture @1.0× : le CTA est déjà sous le pli — régression.',
    );
  });

  testWidgets(
    'ouverture @2.0× : le CTA « Commencer » reste dans le viewport — '
    'le hero décoratif rend sa place au contenu',
    (WidgetTester tester) async {
      await pumpLanding(tester, 2.0);
      expectNoOverflow(tester, where: 'ouverture @2.0×');
      final Rect cta = tester.getRect(find.text('Commencer'));
      expect(
        cta.bottom,
        lessThanOrEqualTo(kPhone.height),
        reason:
            'ouverture @2.0× : le CTA « Commencer » est peint à y=${cta.bottom.toStringAsFixed(1)} '
            'pour un viewport de ${kPhone.height.toInt()} px — l’action primaire est sous le pli. '
            'À Dynamic Type maximal, le hero décoratif doit céder sa place au contenu.',
      );
    },
  );

  testWidgets('ouverture @3.0× : le CTA reste atteignable en défilant (Dynamic Type AX5)', (
    WidgetTester tester,
  ) async {
    await pumpLanding(tester, 3.0);
    expectNoOverflow(tester, where: 'ouverture @3.0×');
    await tester.scrollUntilVisible(find.text('Commencer'), 200, maxScrolls: 30);
    await tester.pump();
    final Rect cta = tester.getRect(find.text('Commencer'));
    expect(
      cta.top,
      lessThan(kPhone.height),
      reason: 'ouverture @3.0× : le CTA reste hors d’atteinte même en défilant.',
    );
  });
}
