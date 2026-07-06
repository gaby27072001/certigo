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
  static const String landing = '/landing'; // écran d'ouverture façon Luma (hero + sheet)
  static const String auth = '/auth'; // écran de connexion e-mail (ouvert depuis la sheet)
  static const String home = '/home'; // accueil (dans le shell)
  static const String onboardingSplash = '/onboarding/splash'; // ≠ [splash] (cf. #154)

  /// Ensemble des routes du flux de démarrage (hors shell), doit rester
  /// synchronisé avec `OnboardingRoutes.all` (asserté dans `router.dart`).
  static const Set<String> startupPaths = <String>{
    onboardingSplash,
    '/welcome',
    '/onboarding/intro',
    '/onboarding/birth-year',
    '/onboarding/certification',
    '/onboarding/domains',
    '/onboarding/building',
    '/onboarding/attribution',
    '/onboarding/level',
    '/onboarding/level-reaction',
    '/onboarding/reasons',
    '/onboarding/reasons-reaction',
    '/onboarding/routine-intro',
    '/onboarding/goal',
    '/onboarding/goal-reaction',
    '/onboarding/notifications',
    '/onboarding/widget',
    '/onboarding/widget-reaction',
    '/onboarding/promise',
    '/onboarding/paywall',
    '/onboarding/paywall-reaction',
    '/onboarding/start',
    '/onboarding/start-reaction',
    '/login',
  };

  static bool isStartup(String location) =>
      startupPaths.contains(location) || location.startsWith('/onboarding');
}

/// Décision de redirection d'authentification, **pure et testable**.
///
/// Retourne la route cible, ou `null` pour rester sur [location].
///
/// Invariants garantis :
/// - un utilisateur `Unauthenticated` atterrit par défaut sur l'écran
///   d'ouverture [AuthShellRoutes.landing] (façon Luma) ; l'écran de connexion
///   e-mail [AuthShellRoutes.auth] reste accessible (ouvert depuis la sheet) ;
/// - un utilisateur `Authenticated` ne reste JAMAIS sur une surface d'auth
///   ([AuthShellRoutes.splash], [AuthShellRoutes.landing] ou
///   [AuthShellRoutes.auth]) : il part vers l'onboarding ou l'accueil ;
/// - la cible d'onboarding est [AuthShellRoutes.onboardingSplash]
///   (≠ [AuthShellRoutes.splash]), ce qui évite le piège du spinner (#154) ;
/// - aucune redirection ne renvoie vers [location] elle-même (pas de boucle).
String? resolveAuthRedirect({
  required AuthState auth,
  required String location,
  required bool onboardingCompleted,
}) {
  final bool atAuthSplash = location == AuthShellRoutes.splash;
  final bool atLanding = location == AuthShellRoutes.landing;
  final bool atAuth = location == AuthShellRoutes.auth;
  final bool atOnboarding = AuthShellRoutes.isStartup(location);

  // Restauration de session : rester sur le splash d'auth.
  if (auth is AuthLoading) {
    return atAuthSplash ? null : AuthShellRoutes.splash;
  }
  // Non authentifié : présenter l'écran d'ouverture (landing) par défaut, tout
  // en autorisant l'écran de connexion e-mail atteint depuis la sheet.
  if (auth is Unauthenticated) {
    return (atLanding || atAuth) ? null : AuthShellRoutes.landing;
  }
  // Authentifié : ne jamais rester sur une surface d'auth (splash, landing, auth).
  if (atAuthSplash || atLanding || atAuth) {
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
