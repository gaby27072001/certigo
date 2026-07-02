import '../features/auth/application/auth_state.dart';

/// Chemins de routes impliqués dans le **garde de redirection d'authentification**,
/// isolés dans un fichier feuille sans dépendance widget.
///
/// Pourquoi ce fichier séparé : [resolveAuthRedirect] doit être testable
/// unitairement (non-régression #154). Importer `router.dart` tirerait tout
/// l'arbre d'écrans (et donc `google_fonts` / `font_awesome_flutter`), ce qui
/// empêche la compilation des tests dans certains environnements SDK. Ici on ne
/// dépend que de [AuthState] (Dart pur).
///
/// Les valeurs sont la **source de vérité** consommée par `router.dart`, qui
/// vérifie par ailleurs (assert) que `OnboardingRoutes` reste synchronisé.
abstract class AuthShellRoutes {
  static const String splash = '/splash'; // splash d'auth (restauration de session)
  static const String auth = '/auth'; // écran de connexion
  static const String home = '/home'; // accueil (dans le shell)
  static const String onboardingSplash = '/onboarding/splash'; // ≠ [splash] (cf. #154)

  /// Ensemble des routes du flux de démarrage (hors shell), doit rester
  /// synchronisé avec `OnboardingRoutes.all` (asserté dans `router.dart`).
  static const Set<String> startupPaths = <String>{
    onboardingSplash,
    '/welcome',
    '/onboarding/start',
    '/onboarding/reasons',
    '/onboarding/domains',
    '/onboarding/level',
    '/onboarding/goal',
    '/onboarding/routine',
    '/onboarding/promise',
    '/login',
    '/onboarding/birth-year',
  };

  static bool isStartup(String location) =>
      startupPaths.contains(location) || location.startsWith('/onboarding');
}

/// Décision de redirection d'authentification, **pure et testable**.
///
/// Retourne la route cible, ou `null` pour rester sur [location].
///
/// Invariants garantis :
/// - un utilisateur `Authenticated` ne reste JAMAIS sur une surface d'auth
///   ([AuthShellRoutes.splash] ou [AuthShellRoutes.auth]) : il part vers
///   l'onboarding ou l'accueil ;
/// - la cible d'onboarding est [AuthShellRoutes.onboardingSplash]
///   (≠ [AuthShellRoutes.splash]), ce qui évite le piège du spinner (#154) ;
/// - aucune redirection ne renvoie vers [location] elle-même (pas de boucle).
String? resolveAuthRedirect({
  required AuthState auth,
  required String location,
  required bool onboardingCompleted,
}) {
  final bool atAuthSplash = location == AuthShellRoutes.splash;
  final bool atAuth = location == AuthShellRoutes.auth;
  final bool atOnboarding = AuthShellRoutes.isStartup(location);

  // Restauration de session : rester sur le splash d'auth.
  if (auth is AuthLoading) {
    return atAuthSplash ? null : AuthShellRoutes.splash;
  }
  // Non authentifié : forcer la connexion.
  if (auth is Unauthenticated) {
    return atAuth ? null : AuthShellRoutes.auth;
  }
  // Authentifié : ne jamais rester sur une surface d'auth.
  if (atAuthSplash || atAuth) {
    return onboardingCompleted ? AuthShellRoutes.home : AuthShellRoutes.onboardingSplash;
  }
  // Authentifié mais onboarding non terminé : forcer le flux de démarrage.
  if (!onboardingCompleted) {
    return atOnboarding ? null : AuthShellRoutes.onboardingSplash;
  }
  // Onboarding terminé : les écrans de démarrage ne sont plus atteignables.
  if (atOnboarding) return AuthShellRoutes.home;
  return null;
}
