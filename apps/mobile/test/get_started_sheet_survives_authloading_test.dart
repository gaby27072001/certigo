import 'dart:async';

import 'package:certigo/app/auth_redirect.dart';
import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/auth_gateway.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/auth/presentation/sign_in_screen.dart';
import 'package:certigo/features/auth/presentation/widgets/auth_provider_button.dart';
import 'package:certigo/features/auth/presentation/widgets/get_started_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'auth_controller_test.dart' show FakeAuthGateway, FakeCredentialsGateway, FakeSessionStore;

/// Passerelle OIDC **contrôlable** : expose un `Completer<AuthSession>` pour
/// que le test puisse maintenir `signIn` en attente pendant les assertions —
/// et l'aborter proprement à la fin pour éteindre le `Timer` créé par
/// `.timeout(_socialTimeout)` dans `auth_controller.dart`. Hérite de la fake
/// existante pour ne pas dupliquer `refresh`, `signOut`, etc.
class _ControllableAuthGateway extends FakeAuthGateway {
  _ControllableAuthGateway();

  final Completer<AuthSession> _pending = Completer<AuthSession>();

  @override
  Future<AuthSession> signIn(AuthProvider provider) {
    signInCalls.add(provider);
    return _pending.future;
  }

  /// Termine la future suspendue avec une erreur pour laisser le `.timeout()`
  /// s'éteindre et le contrôleur publier `Unauthenticated`.
  void abortPending() {
    if (!_pending.isCompleted) _pending.completeError(Exception('test teardown'));
  }
}

/// Passerelle e-mail/mot de passe **contrôlable** : le test suspend
/// `credentials.login(...)` sur un `Completer` jusqu'à ce qu'il ait vérifié
/// que l'écran est resté monté et que sa saisie est intacte pendant
/// `AuthLoading`. Il peut alors :
///  - soit `completeFailure(message)` pour observer que le contrôleur publie
///    `Unauthenticated(message)` et que le `_ErrorCard` de `SignInScreen`
///    affiche ce message via `Key('auth-error')` ;
///  - soit `abortPending()` pour un teardown neutre.
class _ControllableCredentialsGateway extends FakeCredentialsGateway {
  _ControllableCredentialsGateway();

  final Completer<AuthSession> _pending = Completer<AuthSession>();

  @override
  Future<AuthSession> login({required String email, required String password}) {
    loginCalls.add(email);
    return _pending.future;
  }

  void completeFailure(String message) {
    if (!_pending.isCompleted) _pending.completeError(AuthGatewayException(message));
  }

  void abortPending() {
    if (!_pending.isCompleted) _pending.completeError(Exception('test teardown'));
  }
}

/// Test de non-régression du **démontage sous les doigts** : les surfaces
/// d'entrée post-`Unauthenticated` (`/landing` + bottom sheet « Commencer »,
/// `/auth` = formulaire e-mail, `/register/*` = inscription progressive)
/// affichent un chargement inline par bouton pendant l'appel `signIn` /
/// `signInWithEmail`. Sans exception dans `resolveAuthRedirect` pour ces
/// routes, la première émission `AuthLoading` (publiée SYNCHRONE avant tout
/// `await`, cf. `auth_controller.dart:171/248`) éjecte la route racine vers
/// `/splash` et démonte la surface — avec, sur `/auth`, la saisie de
/// l'utilisateur (`TextEditingController` disposé) ET le canal d'affichage
/// du message d'erreur (`ref.listen` local qui ne peut plus s'exécuter).
///
/// Ce test **rejoue la vraie chaîne de production** — sans quoi il n'attrape
/// rien (cf. commit `f3fe90c7 test(mobile): retirer le test-mémorial` du même
/// jour, qui documente le piège d'un test sans `GoRouter`).
///
/// Le harnais reproduit à l'identique les 4 pièces de `router.dart:148-172` :
///   1. un `GlobalKey<NavigatorState>` racine (miroir de `_rootKey`) ;
///   2. un `ValueNotifier<int>` incrémenté par `ref.listen<AuthState>` sur
///      `authControllerProvider` (miroir strict de `authRefresh`) ;
///   3. `refreshListenable: authRefresh` sur le `GoRouter` ;
///   4. `redirect` = `resolveAuthRedirect(auth, matchedLocation, ...)`.
///
/// Contrôles négatifs (joués séparément sur chaque route, sortie brute
/// collée dans la description de la PR) :
///  - retirer `atLanding` de `auth_redirect.dart` → cas `/landing` ROUGE ;
///  - retirer `atAuth`    de `auth_redirect.dart` → cas `/auth`    ROUGE.
void main() {
  Future<void> pumpRouter(
    WidgetTester tester, {
    required String initialLocation,
    required _ControllableAuthGateway authGateway,
    _ControllableCredentialsGateway? credentialsGateway,
  }) async {
    // Fenêtre assez grande pour que la sheet et le formulaire tiennent en
    // hauteur (sinon les boutons du bas restent hors du viewport).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authGatewayProvider.overrideWithValue(authGateway),
          credentialsGatewayProvider
              .overrideWithValue(credentialsGateway ?? FakeCredentialsGateway()),
          sessionStoreProvider.overrideWithValue(FakeSessionStore()),
          authConfiguredProvider.overrideWithValue(true),
          authRequiredProvider.overrideWithValue(true),
        ],
        child: _RouterHarness(initialLocation: initialLocation),
      ),
    );
    // Laisse `_restore()` publier `Unauthenticated` (microtâche) et le routeur
    // atteindre `initialLocation`.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets(
    'sur /landing, taper Microsoft laisse la sheet montée et son bouton en spinner '
    '(sans le fix, la sheet est démontée par la redirection racine vers /splash)',
    (WidgetTester tester) async {
      final _ControllableAuthGateway gateway = _ControllableAuthGateway();
      await pumpRouter(
        tester,
        initialLocation: AuthShellRoutes.landing,
        authGateway: gateway,
      );

      final BuildContext ctx = tester.element(find.byKey(_kLandingProbeKey));
      unawaited(showGetStartedSheet(ctx));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('get-started-close')), findsOneWidget);
      expect(find.byType(AuthProviderButton), findsNWidgets(4));

      await tester.tap(find.text('Continuer avec Microsoft'));
      await tester.pump();
      // Pump long : couvre l'animation de démontage d'une modal bottom sheet
      // (~250ms sur Flutter par défaut) et laisse la redirection racine se
      // matérialiser complètement, sinon le `IgnorePointer` transitoire de la
      // sheet en train de disparaître trompe `findsOneWidget` sans vraiment
      // discriminer (constaté sur le contrôle négatif initial).
      await tester.pump(const Duration(milliseconds: 500));

      expect(gateway.signInCalls, <AuthProvider>[AuthProvider.microsoft]);

      // ⚡ ASSERTIONS QUI DISCRIMINENT ⚡
      expect(
        find.byKey(const Key('splash-probe')),
        findsNothing,
        reason: 'Le routeur racine a été redirigé vers `/splash` pendant '
            'AuthLoading — c\'est précisément le bug qui démonte la sheet. '
            'Vérifier que `resolveAuthRedirect` autorise `/landing` sous '
            '`AuthLoading` (miroir de l\'exception `atRegister`).',
      );
      expect(
        find.byKey(_kLandingProbeKey),
        findsOneWidget,
        reason: 'Le landing-probe a disparu — la route racine n\'est plus '
            '`/landing`.',
      );
      expect(
        find.byKey(const Key('get-started-close')),
        findsOneWidget,
        reason: 'La bottom sheet a été démontée pendant que l\'action était '
            'en cours — la redirection racine vers /splash a gagné.',
      );
      expect(find.byType(AuthProviderButton), findsNWidgets(4));

      final AuthProviderButton msBtn = tester.widget<AuthProviderButton>(
        find.widgetWithText(AuthProviderButton, 'Continuer avec Microsoft'),
      );
      expect(msBtn.loading, isTrue);

      gateway.abortPending();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      if (find.byKey(const Key('get-started-close')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('get-started-close')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
    },
  );

  testWidgets(
    'sur /auth, soumettre le formulaire laisse la saisie E-MAIL ET MOT DE PASSE intactes '
    'et affiche le message d\'erreur après retour à Unauthenticated '
    '(sans le fix, le formulaire est démonté et la saisie perdue avant même l\'affichage du message)',
    (WidgetTester tester) async {
      final _ControllableAuthGateway authGw = _ControllableAuthGateway();
      final _ControllableCredentialsGateway credGw = _ControllableCredentialsGateway();
      await pumpRouter(
        tester,
        initialLocation: AuthShellRoutes.auth,
        authGateway: authGw,
        credentialsGateway: credGw,
      );

      expect(find.byKey(const Key('email-field')), findsOneWidget);
      expect(find.byKey(const Key('password-field')), findsOneWidget);
      expect(find.byKey(const Key('email-submit')), findsOneWidget);
      expect(find.byKey(const Key('auth-error')), findsNothing);

      // Saisie utilisateur — c'est CE QUE la victime perdait sans le fix.
      const String kEmail = 'utilisateur@example.com';
      const String kPassword = 'MotDePasseSecret42';
      await tester.enterText(find.byKey(const Key('email-field')), kEmail);
      await tester.enterText(find.byKey(const Key('password-field')), kPassword);
      await tester.pump();

      // Action utilisateur : soumission. `signInWithEmail` publie
      // `AuthLoading` synchrone (auth_controller.dart:248) AVANT tout `await`.
      await tester.tap(find.byKey(const Key('email-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(credGw.loginCalls, <String>[kEmail]);

      // ⚡ ASSERTIONS QUI DISCRIMINENT — étape 1 : formulaire monté ⚡
      expect(
        find.byKey(const Key('splash-probe')),
        findsNothing,
        reason: 'Le routeur racine a été redirigé vers `/splash` pendant '
            'AuthLoading — c\'est précisément le bug qui démonte le '
            'formulaire e-mail et EFFACE LA SAISIE de l\'utilisateur. '
            'Vérifier que `resolveAuthRedirect` autorise `/auth` sous '
            '`AuthLoading` (miroir de l\'exception `atRegister` et de '
            'la nouvelle exception `atLanding`).',
      );
      expect(find.byKey(const Key('email-field')), findsOneWidget);
      expect(find.byKey(const Key('password-field')), findsOneWidget);

      // ⚡ L'ASSERTION QUI PORTE LE PRÉJUDICE RÉEL ⚡
      // La saisie sur les DEUX champs doit être préservée. Un correctif qui
      // préserverait la route et viderait le mot de passe serait faux
      // (l'utilisateur devrait quand même tout retaper) — ce test le refuse.
      final TextFormField emailField =
              tester.widget<TextFormField>(find.byKey(const Key('email-field'))),
          passwordField = tester.widget<TextFormField>(find.byKey(const Key('password-field')));
      expect(
        emailField.controller?.text,
        kEmail,
        reason: 'La saisie e-mail a été perdue — le formulaire a été démonté '
            'et son `TextEditingController` disposé.',
      );
      expect(
        passwordField.controller?.text,
        kPassword,
        reason: 'La saisie MOT DE PASSE a été perdue — le formulaire a été '
            'démonté et son `TextEditingController` disposé. C\'est '
            'exactement au moment où l\'utilisateur venait de se tromper '
            'qu\'il aurait dû pouvoir corriger sans tout retaper.',
      );

      // Le bouton principal rapporte son propre chargement (`_emailSubmitting`).
      expect(
        find.descendant(
          of: find.byKey(const Key('email-submit')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'Le formulaire est là mais le bouton principal n\'affiche '
            'pas son spinner — le contrat inline n\'est pas honoré.',
      );

      // ⚡ ÉTAPE 2 : le canal d'erreur rebranché ⚡
      // Sans le fix, l'écran était démonté avant que `Unauthenticated(message)`
      // ne soit émis, donc le `ref.listen` local ne s'exécutait jamais et le
      // message n'était pas posé sur `_authError`. Avec le fix, l'écran reste
      // monté : on doit VOIR le message.
      const String kServerMessage = 'E-mail ou mot de passe incorrect.';
      credGw.completeFailure(kServerMessage);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const Key('auth-error')),
        findsOneWidget,
        reason: 'Le message d\'erreur n\'apparaît pas alors que l\'écran est '
            'resté monté et que `Unauthenticated(message)` a été émis. '
            'Le `ref.listen` local devait poser `_authError`, et '
            '`_ErrorCard` devait le rendre.',
      );
      expect(
        find.text(kServerMessage),
        findsOneWidget,
        reason: 'La carte d\'erreur est là mais son texte ne correspond pas '
            'au message renvoyé par la passerelle.',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('email-submit')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
        reason: 'Le spinner du bouton principal aurait dû se retirer après '
            'le retour à `Unauthenticated`.',
      );
      final TextFormField emailFieldAfter =
              tester.widget<TextFormField>(find.byKey(const Key('email-field'))),
          passwordFieldAfter =
              tester.widget<TextFormField>(find.byKey(const Key('password-field')));
      expect(emailFieldAfter.controller?.text, kEmail);
      expect(passwordFieldAfter.controller?.text, kPassword);
    },
  );
}

const Key _kLandingProbeKey = Key('landing-probe');

/// Reproduit à l'identique le câblage de `router.dart:148-172` :
/// `ValueNotifier<int>` incrémenté par `ref.listen<AuthState>`, câblé en
/// `refreshListenable` du `GoRouter`, et `redirect` = `resolveAuthRedirect`.
class _RouterHarness extends ConsumerStatefulWidget {
  const _RouterHarness({required this.initialLocation});

  final String initialLocation;

  @override
  ConsumerState<_RouterHarness> createState() => _RouterHarnessState();
}

class _RouterHarnessState extends ConsumerState<_RouterHarness> {
  late final GlobalKey<NavigatorState> _rootKey;
  late final ValueNotifier<int> _authRefresh;
  late final GoRouter _router;
  ProviderSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _rootKey = GlobalKey<NavigatorState>();
    _authRefresh = ValueNotifier<int>(0);
    // Miroir strict de router.dart:149-152.
    _sub = ref.listenManual<AuthState>(authControllerProvider, (_, __) {
      _authRefresh.value = _authRefresh.value + 1;
    });
    _router = GoRouter(
      navigatorKey: _rootKey,
      initialLocation: widget.initialLocation,
      refreshListenable: _authRefresh,
      redirect: (BuildContext _, GoRouterState state) {
        final AuthState auth = ref.read(authControllerProvider);
        return resolveAuthRedirect(
          auth: auth,
          location: state.matchedLocation,
          onboardingCompleted: false,
        );
      },
      routes: <RouteBase>[
        GoRoute(
          path: AuthShellRoutes.splash,
          builder: (_, __) => const Scaffold(
            key: Key('splash-probe'),
            body: Center(child: Text('SPLASH')),
          ),
        ),
        GoRoute(
          path: AuthShellRoutes.landing,
          builder: (_, __) => const Scaffold(
            key: _kLandingProbeKey,
            body: Center(child: Text('LANDING')),
          ),
        ),
        GoRoute(
          // Vraie `SignInScreen` : le test doit observer son contrat inline
          // (spinner, `_authError`, `_ErrorCard`) et sa saisie réelle
          // (`TextEditingController`) — pas une probe.
          path: AuthShellRoutes.auth,
          builder: (_, __) => const SignInScreen(emailOnly: true),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _sub?.close();
    _router.dispose();
    _authRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      theme: PrismTheme.light(),
    );
  }
}
