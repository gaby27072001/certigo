import 'package:certigo/features/auth/application/auth_controller.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/auth/application/register_draft.dart';
import 'package:certigo/features/auth/presentation/register_password_screen.dart';
import 'package:certigo/features/auth/presentation/register_profile_created_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'auth_controller_test.dart' show FakeAuthGateway, FakeCredentialsGateway, FakeSessionStore;

/// Tests **discriminants** de la confirmation du mot de passe à l'inscription.
///
/// La composition qu'ils cassent : un seul champ de mot de passe à
/// l'inscription **+** aucun mécanisme de réinitialisation nulle part =
/// perte définitive du compte à la première faute de frappe (l'adresse est
/// prise côté backend, sans recours).
///
/// Chaque test doit **rougir** si l'on retire le correctif. Le contrôle
/// négatif exigé par le mandat est capturé dans la description de la PR
/// avec la sortie brute de `flutter test` sur ce fichier après retrait.
void main() {
  ({
    ProviderContainer container,
    FakeCredentialsGateway credentials,
    GoRouter router,
    Widget app,
  }) buildHarness(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final FakeCredentialsGateway credentials = FakeCredentialsGateway(
      onRegister: (String email, String password, String? name) => AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        provider: AuthProvider.email,
        email: email,
        displayName: name,
      ),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        authGatewayProvider.overrideWithValue(FakeAuthGateway()),
        credentialsGatewayProvider.overrideWithValue(credentials),
        sessionStoreProvider.overrideWithValue(FakeSessionStore()),
        authRequiredProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    container.read(registerDraftProvider.notifier)
      ..setName(firstName: 'Alex', lastName: 'Martin')
      ..setEmail('alex@certigo.test');

    final GoRouter router = GoRouter(
      initialLocation: '/register/password',
      routes: <RouteBase>[
        GoRoute(path: '/register/password', builder: (_, __) => const RegisterPasswordScreen()),
        GoRoute(
          path: '/register/profile-created',
          builder: (_, __) => const RegisterProfileCreatedScreen(),
        ),
        GoRoute(path: '/register/email', builder: (_, __) => const SizedBox()),
        GoRoute(path: '/home', builder: (_, __) => const SizedBox()),
      ],
    );

    final Widget app = UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: PrismTheme.light(),
        routerConfig: router,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );

    return (container: container, credentials: credentials, router: router, app: app);
  }

  testWidgets(
    'deux mots de passe DIFFERENTS -> soumission impossible et divergence signalee',
    (WidgetTester tester) async {
      final harness = buildHarness(tester);
      await tester.pumpWidget(harness.app);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      await tester.enterText(find.byKey(const Key('register-password')), 'password123');
      await tester.enterText(
        find.byKey(const Key('register-password-confirm')),
        'PASSWORD123',
      );
      await tester.pump();

      // Le tap sur CONTINUER ne fait rien : `onPrimary` est `null` tant que
      // la confirmation ne correspond pas. Aucun appel backend, aucun
      // basculement d'`AuthState`, on reste sur l'ecran.
      await tester.tap(find.text('CONTINUER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(harness.credentials.registerCalls, isEmpty);
      expect(harness.container.read(authControllerProvider), isNot(isA<Authenticated>()));
      expect(
        harness.router.routerDelegate.currentConfiguration.uri.path,
        '/register/password',
      );
      expect(find.text('Les mots de passe ne correspondent pas.'), findsOneWidget);
    },
  );

  testWidgets(
    'deux mots de passe IDENTIQUES -> soumission part normalement',
    (WidgetTester tester) async {
      final harness = buildHarness(tester);
      await tester.pumpWidget(harness.app);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      await tester.enterText(find.byKey(const Key('register-password')), 'password123');
      await tester.enterText(
        find.byKey(const Key('register-password-confirm')),
        'password123',
      );
      await tester.pump();

      expect(find.text('Les mots de passe correspondent.'), findsOneWidget);

      await tester.tap(find.text('CONTINUER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(harness.credentials.registerCalls, <String>['alex@certigo.test']);
      expect(harness.container.read(authControllerProvider), isA<Authenticated>());
      expect(
        harness.router.routerDelegate.currentConfiguration.uri.path,
        '/register/profile-created',
      );
    },
  );

  testWidgets(
    'champ de confirmation VIDE -> soumission impossible',
    (WidgetTester tester) async {
      final harness = buildHarness(tester);
      await tester.pumpWidget(harness.app);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      await tester.enterText(find.byKey(const Key('register-password')), 'password123');
      // La confirmation reste vide.
      await tester.pump();

      await tester.tap(find.text('CONTINUER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(harness.credentials.registerCalls, isEmpty);
      expect(harness.container.read(authControllerProvider), isNot(isA<Authenticated>()));
      expect(
        harness.router.routerDelegate.currentConfiguration.uri.path,
        '/register/password',
      );
      // Etat neutre : pas de « ne correspondent pas » pendant que l'utilisateur
      // n'a rien tape dans la confirmation.
      expect(find.text('Les mots de passe ne correspondent pas.'), findsNothing);
      expect(find.text('Confirme ton mot de passe.'), findsOneWidget);
    },
  );
}
