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

    test('AuthSigningOut reste sur le splash pendant le nettoyage durable', () {
      expect(
        resolveAuthRedirect(
          auth: const AuthSigningOut(),
          location: AuthShellRoutes.home,
          onboardingCompleted: true,
        ),
        AuthShellRoutes.splash,
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

    // #WIL — Sans exception, `AuthLoading` sur `/landing` renverrait vers
    // `/splash` sur le navigateur racine. La bottom sheet « Commencer »
    // (get_started_sheet, `useRootNavigator: true`) serait démontée avant
    // que l'utilisateur voie sa propre action. `/landing` satisfait le même
    // critère que `/register` : chargement inline par bouton (`_pending`).
    test('sur /landing → reste (la bottom sheet affiche son propre spinner)', () {
      expect(
        resolveAuthRedirect(
          auth: const AuthLoading(),
          location: AuthShellRoutes.landing,
          onboardingCompleted: false,
        ),
        isNull,
      );
    });

    test('AuthSigningOut sur /landing → reste (même critère)', () {
      expect(
        resolveAuthRedirect(
          auth: const AuthSigningOut(),
          location: AuthShellRoutes.landing,
          onboardingCompleted: false,
        ),
        isNull,
      );
    });

    // #WIL — Sans exception, `AuthLoading` sur `/auth` renverrait vers
    // `/splash` sur le navigateur racine, démontant le formulaire e-mail ET
    // sa saisie (`TextEditingController` disposé) au moment précis où
    // l'utilisateur vient de se tromper. `/auth` satisfait le même critère
    // que `/register` et `/landing` : chargement inline par bouton
    // (`_emailSubmitting` pour le bouton principal, `_pending` pour les
    // boutons sociaux — même mécanisme que la sheet).
    test('sur /auth → reste (le formulaire affiche son propre spinner)', () {
      expect(
        resolveAuthRedirect(
          auth: const AuthLoading(),
          location: AuthShellRoutes.auth,
          onboardingCompleted: false,
        ),
        isNull,
      );
    });

    test('AuthSigningOut sur /auth → reste (même critère)', () {
      expect(
        resolveAuthRedirect(
          auth: const AuthSigningOut(),
          location: AuthShellRoutes.auth,
          onboardingCompleted: false,
        ),
        isNull,
      );
    });
  });

  group('resolveAuthRedirect — non authentifié', () {
    test('sur /landing → reste (écran d\'ouverture par défaut)', () {
      expect(
        resolveAuthRedirect(
          auth: const Unauthenticated(),
          location: AuthShellRoutes.landing,
          onboardingCompleted: false,
        ),
        isNull,
      );
    });

    group('resolveAuthRedirect — suppression confirmée', () {
      test('force la confirmation finale depuis toute autre route', () {
        expect(
          resolveAuthRedirect(
            auth: const AccountDeletionCompleted(),
            location: AuthShellRoutes.home,
            onboardingCompleted: true,
          ),
          AuthShellRoutes.accountDeleted,
        );
      });

      test('reste sur la confirmation finale sans boucle', () {
        expect(
          resolveAuthRedirect(
            auth: const AccountDeletionCompleted(),
            location: AuthShellRoutes.accountDeleted,
            onboardingCompleted: true,
          ),
          isNull,
        );
      });
    });

    test('sur /auth → reste (connexion e-mail ouverte depuis la sheet)', () {
      expect(
        resolveAuthRedirect(
          auth: const Unauthenticated(),
          location: AuthShellRoutes.auth,
          onboardingCompleted: false,
        ),
        isNull,
      );
    });

    test('ailleurs → forcé sur /landing (Option B)', () {
      expect(
        resolveAuthRedirect(
          auth: const Unauthenticated('msg'),
          location: AuthShellRoutes.home,
          onboardingCompleted: true,
        ),
        AuthShellRoutes.landing,
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

    test('sur /landing → quitte toujours l\'écran d\'ouverture', () {
      final String? target = resolveAuthRedirect(
        auth: const Authenticated(validSession),
        location: AuthShellRoutes.landing,
        onboardingCompleted: true,
      );
      expect(target, AuthShellRoutes.home);
      expect(target, isNot(AuthShellRoutes.landing));
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

  group('resolveAuthRedirect — flux d\'inscription progressif (Partie 3)', () {
    const List<String> registerPaths = <String>[
      AuthShellRoutes.registerName,
      AuthShellRoutes.registerEmail,
      AuthShellRoutes.registerPassword,
      AuthShellRoutes.registerProfileCreated,
    ];

    test('isRegisterFlow reconnaît les routes /register et rien d\'autre', () {
      for (final String p in registerPaths) {
        expect(AuthShellRoutes.isRegisterFlow(p), isTrue, reason: p);
      }
      expect(AuthShellRoutes.isRegisterFlow(AuthShellRoutes.onboardingSplash), isFalse);
      expect(AuthShellRoutes.isRegisterFlow(AuthShellRoutes.home), isFalse);
    });

    test('les routes register ne polluent pas l\'ensemble onboarding', () {
      for (final String p in registerPaths) {
        expect(AuthShellRoutes.startupPaths.contains(p), isFalse, reason: p);
        expect(AuthShellRoutes.isStartup(p), isFalse, reason: p);
      }
    });

    test('AuthLoading sur un écran register → reste (chargement inline, PAS /splash)', () {
      // Cœur du piège : l\'appel registerWithEmail passe par AuthLoading ; on ne
      // doit pas éjecter l\'écran de mot de passe vers le splash.
      expect(
        resolveAuthRedirect(
          auth: const AuthLoading(),
          location: AuthShellRoutes.registerPassword,
          onboardingCompleted: false,
        ),
        isNull,
      );
    });

    test('Unauthenticated sur un écran register pré-création → reste', () {
      expect(
        resolveAuthRedirect(
          auth: const Unauthenticated(),
          location: AuthShellRoutes.registerName,
          onboardingCompleted: false,
        ),
        isNull,
      );
    });

    test('Authenticated + onboarding non terminé → reste (le flux pilote sa nav)', () {
      for (final String p in registerPaths) {
        expect(
          resolveAuthRedirect(
            auth: const Authenticated(validSession),
            location: p,
            onboardingCompleted: false,
          ),
          isNull,
          reason: p,
        );
      }
    });

    test('Authenticated + onboarding terminé → /home (le flux ne piège pas)', () {
      expect(
        resolveAuthRedirect(
          auth: const Authenticated(validSession),
          location: AuthShellRoutes.registerProfileCreated,
          onboardingCompleted: true,
        ),
        AuthShellRoutes.home,
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
        AuthShellRoutes.landing,
        AuthShellRoutes.auth,
        AuthShellRoutes.home,
        AuthShellRoutes.onboardingSplash,
        '/welcome',
      ];
      for (final bool completed in <bool>[true, false]) {
        for (final String loc in locations) {
          final String? target = resolveAuthRedirect(
            auth: const Authenticated(validSession),
            location: loc,
            onboardingCompleted: completed,
          );
          expect(
            target == AuthShellRoutes.splash ||
                target == AuthShellRoutes.landing ||
                target == AuthShellRoutes.auth,
            isFalse,
            reason: 'loc=$loc completed=$completed a ciblé une surface d\'auth ($target)',
          );
        }
      }
    });
  });
}
