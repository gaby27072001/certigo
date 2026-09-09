import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/auth_state.dart' show AuthState, Unauthenticated;
import 'package:certigo/features/auth/presentation/landing_screen.dart';
import 'package:certigo/features/auth/presentation/widgets/auth_provider_button.dart';
import 'package:prism_ui/prism_ui.dart';

import 'auth_controller_test.dart' show FakeAuthGateway, FakeCredentialsGateway, FakeSessionStore;

/// Tests d'interface de [LandingScreen] : le hero d'ouverture façon Luma rend
/// sans exception, et le CTA « Commencer » ouvre la bottom sheet d'auth
/// contenant Microsoft / Google / Apple + « e-mail ».
///
/// On ne `pumpAndSettle` jamais : `OrbitField` anime un flottement en boucle et
/// ne se stabiliserait pas.
void main() {
  Future<void> pumpLanding(WidgetTester tester, {bool configured = true}) async {
    // Le hero façon Luma est plus haut que la fenêtre de test par défaut
    // (800x600) : on élargit la surface pour que le CTA, le lien « J'ai déjà un
    // compte » et la sheet soient à l'écran et donc tappables.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authGatewayProvider.overrideWithValue(FakeAuthGateway()),
          credentialsGatewayProvider.overrideWithValue(FakeCredentialsGateway()),
          sessionStoreProvider.overrideWithValue(FakeSessionStore()),
          authConfiguredProvider.overrideWithValue(configured),
          authRequiredProvider.overrideWithValue(true),
        ],
        child: MaterialApp(theme: PrismTheme.light(), home: const LandingScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('rend le hero (wordmark, titre en deux lignes, CTA)', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpLanding(tester);

    expect(find.text('Certigo'), findsOneWidget);
    expect(find.text('Tes certifs cloud & IT'), findsOneWidget);
    expect(find.text('commencent ici'), findsOneWidget); // 2ᵉ ligne en dégradé
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.bySemanticsLabel('Commencer'), findsOneWidget);
    expect(find.byKey(const Key('landing-existing-account')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('taper « Commencer » ouvre la sheet avec Microsoft/Google/Apple + e-mail', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpLanding(tester);

    await tester.tap(find.text('Commencer'));
    await tester.pump(); // démarre l'ouverture de la sheet
    await tester.pump(const Duration(milliseconds: 400)); // laisse la sheet apparaître

    // La sheet est ouverte : son titre « Commencer » s'ajoute au CTA.
    expect(find.text('Commencer'), findsNWidgets(2));
    expect(find.byType(AuthProviderButton), findsNWidgets(4));
    expect(find.text('Continuer avec Microsoft'), findsOneWidget);
    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.text('Continuer avec Apple'), findsOneWidget);
    expect(find.text('Continuer avec un e-mail'), findsOneWidget);
    expect(find.bySemanticsLabel('Continuer avec Microsoft'), findsOneWidget);
    expect(find.bySemanticsLabel('Continuer avec Google'), findsOneWidget);
    expect(find.bySemanticsLabel('Continuer avec Apple'), findsOneWidget);
    expect(find.bySemanticsLabel('Continuer avec un e-mail'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('même sans Entra configuré, la sheet montre les 4 boutons', (
    WidgetTester tester,
  ) async {
    await pumpLanding(tester, configured: false);

    await tester.tap(find.text('Commencer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Les fournisseurs sociaux sont toujours proposés depuis l'écran
    // d'ouverture (la config Entra est vérifiée au moment du tap, pas ici).
    expect(find.byType(AuthProviderButton), findsNWidgets(4));
    expect(find.text('Continuer avec Microsoft'), findsOneWidget);
    expect(find.text('Continuer avec un e-mail'), findsOneWidget);
  });

  // Réécrit : ce test assertait auparavant le comportement fautif — il se
  // contentait de vérifier que « J'ai déjà un compte » ouvrait « aussi » la
  // même feuille, ce qui verrouillait justement le défaut signalé (un compte
  // existant était envoyé sur le premier écran d'inscription). Il vérifie
  // désormais que l'intention est distincte, et surtout où mène le bouton
  // e-mail. Harnais routé local : `pumpLanding` reste inchangé pour les autres.
  testWidgets(
      'le lien « J’ai déjà un compte » ouvre la feuille en intention connexion, '
      'et son bouton e-mail mène au formulaire de connexion — pas à l’inscription',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: '/landing',
      routes: <RouteBase>[
        GoRoute(path: '/landing', builder: (_, __) => const LandingScreen()),
        GoRoute(
          path: '/register/name',
          builder: (_, __) => const Scaffold(body: Center(child: Text('CIBLE inscription'))),
        ),
        GoRoute(
          path: '/auth',
          builder: (_, __) => const Scaffold(body: Center(child: Text('CIBLE connexion'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authGatewayProvider.overrideWithValue(FakeAuthGateway()),
          credentialsGatewayProvider.overrideWithValue(FakeCredentialsGateway()),
          sessionStoreProvider.overrideWithValue(FakeSessionStore()),
          authConfiguredProvider.overrideWithValue(true),
          authRequiredProvider.overrideWithValue(true),
        ],
        child: MaterialApp.router(theme: PrismTheme.light(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('landing-existing-account')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Cadrage « connexion » : la feuille ne dit plus « Commencer » à quelqu'un
    // qui possède déjà un compte, et ne lui recommande plus un fournisseur.
    expect(find.text('Content de te revoir'), findsOneWidget);
    expect(find.text('Recommandé'), findsNothing);

    // Mais les quatre fournisseurs restent proposés : un compte existant a pu
    // être créé avec n'importe lequel d'entre eux.
    expect(find.byType(AuthProviderButton), findsNWidgets(4));

    await tester.tap(find.text('Continuer avec un e-mail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('CIBLE connexion'), findsOneWidget);
    expect(find.text('CIBLE inscription'), findsNothing);
  });

  testWidgets(
      "affiche le message quand l'écran est monté APRÈS l'échec "
      "(cas réel iOS : /landing → /splash → /landing renaissante)", (WidgetTester tester) async {
    // Sur iOS en production, la séquence mesurée est :
    //   1. tap Microsoft/Google/Apple → `state = AuthLoading` (synchrone).
    //   2. `authControllerProvider` change → `authRefresh.value++`
    //      (router.dart:150-151) → `refreshListenable` de `GoRouter` notifie.
    //   3. `resolveAuthRedirect` (auth_redirect.dart:82-89) éjecte
    //      `AuthLoading` sur `/landing` vers `/splash`, sur le navigateur
    //      RACINE — celui qui porte la bottom sheet (`useRootNavigator: true`
    //      dans get_started_sheet.dart:20).
    //   4. La sheet ET l'instance courante de `LandingScreen` sont
    //      démontées ; leur `ref.listen` disparaît avec elles.
    //   5. Le gateway échoue → `state = Unauthenticated(message)`.
    //   6. Le routeur remonte une NOUVELLE instance de `LandingScreen`, qui
    //      n'a rien observé — son `ref.listen` a été enregistré APRÈS
    //      l'émission.
    //
    // Le seul mécanisme fiable pour porter le message dans ce cas est le
    // REPLI sur `state.message` calculé dans `build`. Ce test simule le
    // point 6 : landing est instanciée alors que l'état est DÉJÀ
    // `Unauthenticated(message)`, sans passer par une transition observable.
    // C'est le chemin réel — pas une hypothèse. Cf. session d'enquête
    // « investigate-ios-login-loopback » et le message n°436.
    //
    // Sciemment SANS test compagnon qui monte la sheet et lance signIn : un
    // tel test devrait rejouer la vraie logique de redirection (GoRouter +
    // `resolveAuthRedirect` + navigation racine) pour que le mécanisme
    // observé soit celui qui panne en production. Sinon il verrouille un
    // système qui n'existe pas, exactement le motif « test-mémorial » qui a
    // mordu ce dépôt aujourd'hui.
    const String errorMessage = 'Message pré-existant — mesure du remontage après échec';

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          // Force l'état initial du contrôleur à Unauthenticated(message)
          // SANS passer par la transition AuthLoading → Unauthenticated —
          // cela simule exactement le cas où LandingScreen est montée APRÈS
          // que l'état soit déjà à Unauthenticated(message).
          authControllerProvider.overrideWith(
            () => _StaticUnauthController(const Unauthenticated(errorMessage)),
          ),
          authGatewayProvider.overrideWithValue(FakeAuthGateway()),
          credentialsGatewayProvider.overrideWithValue(FakeCredentialsGateway()),
          sessionStoreProvider.overrideWithValue(FakeSessionStore()),
          authConfiguredProvider.overrideWithValue(true),
          authRequiredProvider.overrideWithValue(true),
        ],
        child: MaterialApp(theme: PrismTheme.light(), home: const LandingScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Le message DOIT être visible dès le premier frame utile — sans
    // qu'aucune transition d'état n'ait été observée par le `ref.listen`.
    expect(find.byKey(const Key('landing-auth-error')), findsOneWidget);
    expect(find.textContaining(errorMessage), findsOneWidget);
  });
}

/// Contrôleur d'auth factice qui retourne un état **fixé** au montage, sans
/// exécuter la restauration réelle. Sert exclusivement à simuler le cas où
/// `LandingScreen` est instanciée APRÈS que l'état soit déjà `Unauthenticated`
/// — c'est-à-dire APRÈS que la transition observée par un `ref.listen` ait eu
/// lieu. Il n'appelle jamais `super.build`, donc les gateways ne sont pas
/// initialisées : les tests ne doivent PAS déclencher `signIn`.
class _StaticUnauthController extends AuthController {
  _StaticUnauthController(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}
