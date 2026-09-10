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

void main() {
  testWidgets('real account creation goes directly to confirmation without fake social steps', (
    WidgetTester tester,
  ) async {
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: PrismTheme.light(),
          routerConfig: router,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.enterText(find.byKey(const Key('register-password')), 'password123');
    await tester.enterText(find.byKey(const Key('register-password-confirm')), 'password123');
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(container.read(authControllerProvider), isA<Authenticated>());
    expect(router.routerDelegate.currentConfiguration.uri.path, '/register/profile-created');
    expect(find.textContaining('Bienvenue Alex'), findsWidgets);
    expect(find.textContaining('contact'), findsNothing);
    expect(find.textContaining('ami fictif'), findsNothing);
    expect(find.textContaining('AJOUTER'), findsNothing);
    expect(credentials.registerCalls, <String>['alex@certigo.test']);
  });
}
