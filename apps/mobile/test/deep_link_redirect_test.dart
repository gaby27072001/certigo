import 'package:certigo/app/auth_redirect.dart';
import 'package:certigo/app/deep_link_redirect.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/deep_links/application/deep_link_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const AuthSession session = AuthSession(accessToken: 'token');
  const String controlledTestHost = 'links.user-owned.example';

  DeepLinkRouterCoordinator enabledCoordinator() => DeepLinkRouterCoordinator(
        policy: const DeepLinkPolicy(enabled: true, primaryHost: controlledTestHost),
      );

  group('protected HTTPS navigation', () {
    test('retains only the validated internal route through auth and onboarding', () {
      final DeepLinkRouterCoordinator coordinator = enabledCoordinator();

      expect(
        coordinator.redirect(
          uri: Uri.parse('https://$controlledTestHost/learn/az-900/identity-basics'),
          location: '/learn/az-900/identity-basics',
          auth: const Unauthenticated(),
          onboardingCompleted: false,
        ),
        AuthShellRoutes.landing,
      );
      expect(coordinator.pendingLocation, '/lesson/az-900/identity-basics');

      expect(
        coordinator.redirect(
          uri: Uri.parse(AuthShellRoutes.landing),
          location: AuthShellRoutes.landing,
          auth: const Authenticated(session),
          onboardingCompleted: false,
        ),
        AuthShellRoutes.onboardingSplash,
      );
      expect(coordinator.pendingLocation, '/lesson/az-900/identity-basics');

      expect(
        coordinator.redirect(
          uri: Uri.parse(AuthShellRoutes.onboardingSplash),
          location: AuthShellRoutes.onboardingSplash,
          auth: const Authenticated(session),
          onboardingCompleted: true,
        ),
        '/lesson/az-900/identity-basics',
      );
      expect(coordinator.pendingLocation, isNull);
    });

    test('navigates immediately when auth and onboarding are ready', () {
      final DeepLinkRouterCoordinator coordinator = enabledCoordinator();

      expect(
        coordinator.redirect(
          uri: Uri.parse('https://$controlledTestHost/achievements/first-lesson'),
          location: '/achievements/first-lesson',
          auth: const Authenticated(session),
          onboardingCompleted: true,
        ),
        isNull,
      );
      expect(coordinator.pendingLocation, isNull);
    });

    test('does not turn an auth refresh on the current detail into a new link', () {
      final DeepLinkRouterCoordinator coordinator = enabledCoordinator();
      final Uri achievement = Uri.parse('/achievements/first-lesson');

      expect(
        coordinator.redirect(
          uri: achievement,
          location: achievement.path,
          auth: const Authenticated(session),
          onboardingCompleted: true,
        ),
        isNull,
      );
      expect(
        coordinator.redirect(
          uri: achievement,
          location: achievement.path,
          auth: const Unauthenticated(),
          onboardingCompleted: true,
        ),
        AuthShellRoutes.landing,
      );
      expect(coordinator.pendingLocation, isNull);
    });
  });

  group('public and rejected links', () {
    test('keeps account deletion public while signed out', () {
      final DeepLinkRouterCoordinator coordinator = enabledCoordinator();

      expect(
        coordinator.redirect(
          uri: Uri.parse('https://$controlledTestHost/account-deletion'),
          location: '/account-deletion',
          auth: const Unauthenticated(),
          onboardingCompleted: false,
        ),
        isNull,
      );
    });

    test('rejects foreign origins instead of replaying their path', () {
      final DeepLinkRouterCoordinator coordinator = enabledCoordinator();

      expect(
        coordinator.redirect(
          uri: Uri.parse('https://$controlledTestHost.evil.example/assignments/a'),
          location: '/assignments/a',
          auth: const Authenticated(session),
          onboardingCompleted: true,
        ),
        AuthShellRoutes.home,
      );
      expect(coordinator.pendingLocation, isNull);
    });

    test('feature flag off falls back without navigating to the link', () {
      final DeepLinkRouterCoordinator coordinator = DeepLinkRouterCoordinator();

      expect(
        coordinator.redirect(
          uri: Uri.parse('/assignments/a'),
          location: '/assignments/a',
          auth: const Unauthenticated(),
          onboardingCompleted: true,
        ),
        AuthShellRoutes.landing,
      );
      expect(coordinator.pendingLocation, isNull);
    });
  });

  test('certigo auth callback is not handled as an HTTPS link', () {
    final DeepLinkRouterCoordinator coordinator = enabledCoordinator();

    expect(
      coordinator.redirect(
        uri: Uri.parse('certigo://auth/'),
        location: AuthShellRoutes.auth,
        auth: const Unauthenticated(),
        onboardingCompleted: false,
      ),
      isNull,
    );
    expect(coordinator.pendingLocation, isNull);
  });
}
