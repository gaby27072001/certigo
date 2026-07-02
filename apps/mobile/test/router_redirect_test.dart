import 'package:certigo/app/auth_redirect.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests de **non-régression** du garde de redirection d'authentification.
///
/// Couvre en particulier la collision de route `/splash` (#154) : un utilisateur
/// fraîchement authentifié ne doit JAMAIS rester piégé sur le splash d'auth, et
/// la cible d'onboarding (`/onboarding/splash`) doit être distincte de `/splash`.
///
/// Importe le fichier feuille `auth_redirect.dart` (Dart pur) plutôt que
/// `router.dart` pour rester compilable sans l'arbre d'écrans.
void main() {
  const AuthSession validSession = AuthSession(accessToken: 'token');

  group('resolveAuthRedirect — restauration (AuthLoading)', () {
    test('reste sur le splash d\'auth', () {
      expect(
        resolveAuthRedirect(
          auth: const AuthLoading(),
          location: AuthShellRoutes.splash,
          onboardingCompleted: false,
        ),
        isNull,
      );
    });

    test('depuis une autre route → renvoyé sur le splash d\'auth', () {
      expect(
        resolveAuthRedirect(
          auth: const AuthLoading(),
          location: AuthShellRoutes.home,
          onboardingCompleted: true,
        ),
        AuthShellRoutes.splash,
      );
    });
  });

  group('resolveAuthRedirect — non authentifié', () {
    test('sur /auth → reste', () {
      expect(
        resolveAuthRedirect(
          auth: const Unauthenticated(),
          location: AuthShellRoutes.auth,
          onboardingCompleted: false,
        ),
        isNull,
      );
    });

    test('ailleurs → forcé sur /auth', () {
      expect(
        resolveAuthRedirect(
          auth: const Unauthenticated('msg'),
          location: AuthShellRoutes.home,
          onboardingCompleted: true,
        ),
        AuthShellRoutes.auth,
      );
    });
  });

  group('resolveAuthRedirect — authentifié (#154 non-régression)', () {
    test('sur /splash + onboarding non terminé → /onboarding/splash (PAS /splash)', () {
      final String? target = resolveAuthRedirect(
        auth: const Authenticated(validSession),
        location: AuthShellRoutes.splash,
        onboardingCompleted: false,
      );
      expect(target, AuthShellRoutes.onboardingSplash);
      // Cœur du bug #154 : la cible ne doit pas être la route d'auth splash.
      expect(target, isNot(AuthShellRoutes.splash));
    });

    test('sur /splash + onboarding terminé → /home', () {
      expect(
        resolveAuthRedirect(
          auth: const Authenticated(validSession),
          location: AuthShellRoutes.splash,
          onboardingCompleted: true,
        ),
        AuthShellRoutes.home,
      );
    });

    test('sur /auth → quitte toujours la surface d\'auth', () {
      final String? target = resolveAuthRedirect(
        auth: const Authenticated(validSession),
        location: AuthShellRoutes.auth,
        onboardingCompleted: true,
      );
      expect(target, AuthShellRoutes.home);
      expect(target, isNot(AuthShellRoutes.auth));
    });

    test('sur /home + onboarding non terminé → /onboarding/splash', () {
      expect(
        resolveAuthRedirect(
          auth: const Authenticated(validSession),
          location: AuthShellRoutes.home,
          onboardingCompleted: false,
        ),
        AuthShellRoutes.onboardingSplash,
      );
    });

    test('sur /home + onboarding terminé → reste (null)', () {
      expect(
        resolveAuthRedirect(
          auth: const Authenticated(validSession),
          location: AuthShellRoutes.home,
          onboardingCompleted: true,
        ),
        isNull,
      );
    });

    test('sur un écran d\'onboarding + terminé → renvoyé sur /home', () {
      expect(
        resolveAuthRedirect(
          auth: const Authenticated(validSession),
          location: '/welcome',
          onboardingCompleted: true,
        ),
        AuthShellRoutes.home,
      );
    });

    test('sur /onboarding/splash + non terminé → reste (pas de boucle)', () {
      expect(
        resolveAuthRedirect(
          auth: const Authenticated(validSession),
          location: AuthShellRoutes.onboardingSplash,
          onboardingCompleted: false,
        ),
        isNull,
      );
    });
  });

  group('invariants globaux', () {
    test('les deux splash sont des routes distinctes', () {
      expect(AuthShellRoutes.splash, isNot(AuthShellRoutes.onboardingSplash));
      expect(AuthShellRoutes.isStartup(AuthShellRoutes.splash), isFalse);
    });

    test('un utilisateur authentifié ne cible jamais une surface d\'auth', () {
      const List<String> locations = <String>[
        AuthShellRoutes.splash,
        AuthShellRoutes.auth,
        AuthShellRoutes.home,
        AuthShellRoutes.onboardingSplash,
        '/welcome',
        '/login',
      ];
      for (final bool completed in <bool>[true, false]) {
        for (final String loc in locations) {
          final String? target = resolveAuthRedirect(
            auth: const Authenticated(validSession),
            location: loc,
            onboardingCompleted: completed,
          );
          expect(
            target == AuthShellRoutes.splash || target == AuthShellRoutes.auth,
            isFalse,
            reason: 'loc=$loc completed=$completed a ciblé une surface d\'auth ($target)',
          );
        }
      }
    });
  });
}
