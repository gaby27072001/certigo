import 'package:certigo/app/auth_redirect.dart';
import 'package:certigo/app/deep_link_redirect.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/deep_links/application/deep_link_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const AuthSession session = AuthSession(accessToken: 'token');
  const String controlledTestHost = 'links.user-owned.example';

  late ValueNotifier<AuthState> auth;
  late ValueNotifier<bool> onboardingCompleted;
  late DeepLinkRouterCoordinator coordinator;
  late GoRouter router;

  void createRouter({
    AuthState initialAuth = const Unauthenticated(),
    bool initialOnboardingCompleted = false,
  }) {
    auth = ValueNotifier<AuthState>(initialAuth);
    onboardingCompleted = ValueNotifier<bool>(initialOnboardingCompleted);
    coordinator = DeepLinkRouterCoordinator(
      policy: const DeepLinkPolicy(enabled: true, primaryHost: controlledTestHost),
    );
    router = GoRouter(
      initialLocation: AuthShellRoutes.landing,
      refreshListenable: Listenable.merge(<Listenable>[auth, onboardingCompleted]),
      redirect: (BuildContext context, GoRouterState state) => coordinator.redirect(
        uri: state.uri,
        location: state.matchedLocation,
        auth: auth.value,
        onboardingCompleted: onboardingCompleted.value,
      ),
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, __) => const Text('root')),
        GoRoute(path: AuthShellRoutes.landing, builder: (_, __) => const Text('landing')),
        GoRoute(path: AuthShellRoutes.home, builder: (_, __) => const Text('home')),
        GoRoute(
          path: AuthShellRoutes.onboardingSplash,
          builder: (_, __) => const Text('onboarding'),
        ),
        GoRoute(path: '/learn/:trackId/:lessonId', builder: (_, __) => const Text('ingress')),
        GoRoute(
          path: '/lesson/:trackId/:lessonId',
          builder: (_, GoRouterState state) =>
              Text('lesson:${state.pathParameters['trackId']}/${state.pathParameters['lessonId']}'),
        ),
        GoRoute(
          path: '/assignments/:assignmentId',
          builder: (_, GoRouterState state) =>
              Text('assignment:${state.pathParameters['assignmentId']}'),
        ),
        GoRoute(
          path: '/achievements/:achievementId',
          builder: (_, GoRouterState state) =>
              Text('achievement:${state.pathParameters['achievementId']}'),
        ),
        GoRoute(
          path: AuthShellRoutes.accountDeletion,
          builder: (_, __) => const Text('account-deletion'),
        ),
      ],
    );
  }

  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  tearDown(() {
    router.dispose();
    auth.dispose();
    onboardingCompleted.dispose();
  });

  testWidgets('replays a protected warm link after auth and onboarding', (tester) async {
    createRouter();
    await pumpRouter(tester);

    router.go('https://$controlledTestHost/learn/az-900/identity-basics');
    await tester.pumpAndSettle();

    expect(find.text('landing'), findsOneWidget);
    expect(coordinator.pendingLocation, '/lesson/az-900/identity-basics');

    auth.value = const Authenticated(session);
    onboardingCompleted.value = true;
    await tester.pumpAndSettle();

    expect(find.text('lesson:az-900/identity-basics'), findsOneWidget);
    expect(coordinator.pendingLocation, isNull);
  });

  testWidgets('opens assignment, achievement, and public deletion routes', (tester) async {
    createRouter(initialAuth: const Authenticated(session), initialOnboardingCompleted: true);
    await pumpRouter(tester);

    router.go('https://$controlledTestHost/assignments/assignment-42');
    await tester.pumpAndSettle();
    expect(find.text('assignment:assignment-42'), findsOneWidget);

    router.go('https://$controlledTestHost/achievements/first-lesson');
    await tester.pumpAndSettle();
    expect(find.text('achievement:first-lesson'), findsOneWidget);

    auth.value = const Unauthenticated();
    router.go('https://$controlledTestHost/account-deletion');
    await tester.pumpAndSettle();
    expect(find.text('account-deletion'), findsOneWidget);
  });

  testWidgets('foreign HTTPS origin falls back instead of opening its matching path', (
    tester,
  ) async {
    createRouter(initialAuth: const Authenticated(session), initialOnboardingCompleted: true);
    await pumpRouter(tester);

    router.go('https://$controlledTestHost.evil.example/assignments/assignment-42');
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('assignment:assignment-42'), findsNothing);
  });

  testWidgets('certigo auth callback stays outside HTTPS link handling', (tester) async {
    createRouter();
    await pumpRouter(tester);

    router.go('certigo://auth/');
    await tester.pumpAndSettle();

    expect(find.text('landing'), findsOneWidget);
    expect(coordinator.pendingLocation, isNull);
  });
}
