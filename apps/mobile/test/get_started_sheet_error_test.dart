import 'dart:async';

import 'package:certigo/app/auth_redirect.dart';
import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/auth_gateway.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/auth/presentation/landing_screen.dart';
import 'package:certigo/features/auth/presentation/widgets/auth_provider_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'auth_controller_test.dart' show FakeAuthGateway, FakeCredentialsGateway, FakeSessionStore;

/// Passerelle dont chaque tentative reste suspendue jusqu'à ce que le test la
/// conclue : on observe l'écran pendant `AuthLoading`, puis après l'échec.
class _SteppedAuthGateway extends FakeAuthGateway {
  final List<Completer<AuthSession>> _attempts = <Completer<AuthSession>>[];

  @override
  Future<AuthSession> signIn(AuthProvider provider) {
    signInCalls.add(provider);
    final Completer<AuthSession> attempt = Completer<AuthSession>();
    _attempts.add(attempt);
    return attempt.future;
  }

  void failLast(AuthGatewayException error) => _attempts.last.completeError(error);
}

/// Cas signalé le 2026-09-25 sur iPhone : « Continuer avec Apple » échouait,
/// la feuille « Commencer » restait ouverte et l'échec s'affichait sur
/// l'accueil, caché derrière elle (« ça affiche juste la page initiale de
/// connexion »). Un échec s'affiche sur la surface qui a lancé la tentative.
///
/// Harnais routé comme `router.dart` (navigateur racine, `refreshListenable`
/// nourri par l'état d'auth, `redirect` = `resolveAuthRedirect`) autour du
/// vrai [LandingScreen] : sans la vraie redirection, un tel test verrouillerait
/// un système qui n'existe pas en production.
void main() {
  const AuthGatewayException appleWindowClosed = AuthGatewayException(
    'Connexion annulée.',
    cause: AuthFailureCause.cancelled,
  );
  const String appleFailureMessage =
      'La connexion Apple n\'a pas abouti : la fenêtre a été fermée ou n\'a pas pu '
      's\'ouvrir. Réessaie, ou connecte-toi avec ton e-mail.';

  late ProviderContainer container;

  Future<void> pumpLanding(
    WidgetTester tester, {
    required AuthGateway gateway,
    bool configured = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: <Override>[
        authGatewayProvider.overrideWithValue(gateway),
        credentialsGatewayProvider.overrideWithValue(FakeCredentialsGateway()),
        sessionStoreProvider.overrideWithValue(FakeSessionStore()),
        authConfiguredProvider.overrideWithValue(configured),
        authRequiredProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _RouterHarness()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('landing-existing-account')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('get-started-close')), findsOneWidget);
  }

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('get-started-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('get-started-close')), findsNothing);
  }

  Future<void> tapApple(WidgetTester tester) async {
    await tester.tap(find.text('Continuer avec Apple'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
      'l’échec d’une tentative Apple s’affiche dans la feuille, et pas derrière elle '
      'sur l’accueil', (WidgetTester tester) async {
    final _SteppedAuthGateway gateway = _SteppedAuthGateway();
    await pumpLanding(tester, gateway: gateway);
    await openSheet(tester);

    await tapApple(tester);
    expect(gateway.signInCalls, <AuthProvider>[AuthProvider.apple]);
    expect(find.byKey(const Key('get-started-error')), findsNothing);

    gateway.failLast(appleWindowClosed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final Finder sheetError = find.byKey(const Key('get-started-error'));
    expect(sheetError, findsOneWidget, reason: 'L’échec doit être lu dans la feuille.');
    expect(
        find.descendant(of: sheetError, matching: find.text(appleFailureMessage)), findsOneWidget);
    expect(
      find.byKey(const Key('landing-auth-error')),
      findsNothing,
      reason: 'L’accueil, caché derrière la feuille, ne doit pas porter cet échec.',
    );
    final AuthProviderButton apple = tester.widget<AuthProviderButton>(
      find.widgetWithText(AuthProviderButton, 'Continuer avec Apple'),
    );
    expect(apple.loading, isFalse);
    expect(apple.enabled, isTrue);

    await closeSheet(tester);

    expect(
      find.byKey(const Key('landing-auth-error')),
      findsNothing,
      reason: 'Fermer la feuille ne fait pas réapparaître l’échec sur l’accueil.',
    );
    expect(find.text(appleFailureMessage), findsNothing);
  });

  testWidgets('une nouvelle tentative efface l’échec affiché, puis montre le sien', (
    WidgetTester tester,
  ) async {
    final _SteppedAuthGateway gateway = _SteppedAuthGateway();
    await pumpLanding(tester, gateway: gateway);
    await openSheet(tester);

    await tapApple(tester);
    gateway.failLast(appleWindowClosed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('get-started-error')), findsOneWidget);

    await tapApple(tester);
    expect(find.byKey(const Key('get-started-error')), findsNothing);

    gateway.failLast(
      const AuthGatewayException(
        'refus',
        cause: AuthFailureCause.providerError,
        diagnostic: 'PlatformException code=authorize_failed',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final Finder sheetError = find.byKey(const Key('get-started-error'));
    expect(sheetError, findsOneWidget);
    expect(
      find.descendant(
        of: sheetError,
        matching:
            find.text('La connexion Apple a échoué. Réessaie, ou connecte-toi avec ton e-mail.'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('PlatformException'), findsNothing);
    expect(gateway.signInCalls, <AuthProvider>[AuthProvider.apple, AuthProvider.apple]);
  });

  testWidgets(
      'un échec immédiat, sans état de chargement (build sans Entra), reste aussi '
      'dans la feuille', (WidgetTester tester) async {
    final _SteppedAuthGateway gateway = _SteppedAuthGateway();
    await pumpLanding(tester, gateway: gateway, configured: false);
    await openSheet(tester);

    await tapApple(tester);

    expect(gateway.signInCalls, isEmpty);
    expect(find.byKey(const Key('get-started-error')), findsOneWidget);
    expect(find.byKey(const Key('landing-auth-error')), findsNothing);

    await closeSheet(tester);

    expect(find.byKey(const Key('landing-auth-error')), findsNothing);
  });

  testWidgets('ouvrir puis fermer la feuille sans tentative garde le message propre à l’accueil',
      (WidgetTester tester) async {
    final _SteppedAuthGateway gateway = _SteppedAuthGateway();
    await pumpLanding(tester, gateway: gateway);
    container.read(authControllerProvider.notifier).finishAccountDeletion();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    const String deleted = 'Votre compte et vos données Certigo ont été supprimés.';
    expect(find.byKey(const Key('landing-auth-error')), findsOneWidget);
    expect(find.text(deleted), findsOneWidget);

    await openSheet(tester);
    await closeSheet(tester);

    expect(find.byKey(const Key('landing-auth-error')), findsOneWidget);
    expect(find.text(deleted), findsOneWidget);
    expect(gateway.signInCalls, isEmpty);
  });

  testWidgets('sans Entra, deux tentatives Apple réarment chaque fois la feuille', (
    WidgetTester tester,
  ) async {
    final _SteppedAuthGateway gateway = _SteppedAuthGateway();
    await pumpLanding(tester, gateway: gateway, configured: false);
    await openSheet(tester);

    for (int attempt = 0; attempt < 2; attempt++) {
      await tapApple(tester);
      expect(find.byKey(const Key('get-started-error')), findsOneWidget);
      expect(
        find.text('La connexion Apple n\'est pas disponible dans cette version. '
            'Connecte-toi avec ton e-mail.'),
        findsOneWidget,
      );
      final AuthProviderButton apple = tester.widget<AuthProviderButton>(
        find.widgetWithText(AuthProviderButton, 'Continuer avec Apple'),
      );
      expect(apple.loading, isFalse);
      expect(apple.enabled, isTrue);
      expect(find.byKey(const Key('landing-auth-error')), findsNothing);
    }
    expect(gateway.signInCalls, isEmpty);
  });
}

/// Reproduit le câblage de `router.dart` autour du vrai [LandingScreen].
class _RouterHarness extends ConsumerStatefulWidget {
  const _RouterHarness();

  @override
  ConsumerState<_RouterHarness> createState() => _RouterHarnessState();
}

class _RouterHarnessState extends ConsumerState<_RouterHarness> {
  late final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();
  late final ValueNotifier<int> _authRefresh = ValueNotifier<int>(0);
  late final GoRouter _router;
  ProviderSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.listenManual<AuthState>(authControllerProvider, (_, __) {
      _authRefresh.value = _authRefresh.value + 1;
    });
    _router = GoRouter(
      navigatorKey: _rootKey,
      initialLocation: AuthShellRoutes.landing,
      refreshListenable: _authRefresh,
      redirect: (BuildContext _, GoRouterState state) => resolveAuthRedirect(
        auth: ref.read(authControllerProvider),
        location: state.matchedLocation,
        onboardingCompleted: false,
      ),
      routes: <RouteBase>[
        GoRoute(
          path: AuthShellRoutes.splash,
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const Scaffold(key: Key('splash-probe')),
        ),
        GoRoute(
          path: AuthShellRoutes.landing,
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const LandingScreen(),
        ),
        GoRoute(
          path: AuthShellRoutes.auth,
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const Scaffold(key: Key('auth-probe')),
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
  Widget build(BuildContext context) =>
      MaterialApp.router(routerConfig: _router, theme: PrismTheme.light());
}
