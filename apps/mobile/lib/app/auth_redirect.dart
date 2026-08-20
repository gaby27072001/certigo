import '../features/auth/application/auth_state.dart';

/// Chemins de routes impliqués dans le **garde de redirection d'authentification**,
/// isolés dans un fichier feuille sans dépendance widget.
///
/// Pourquoi ce fichier séparé : [resolveAuthRedirect] doit être testable
/// unitairement (non-régression #154). Importer `router.dart` tirerait tout
/// l'arbre d'écrans et transformerait ce test de garde en test widget. Ici on ne
/// dépend que de [AuthState] (Dart pur).
///
/// Les valeurs sont la **source de vérité** consommée par `router.dart`, qui
/// vérifie par ailleurs (assert) que `OnboardingRoutes` reste synchronisé.
abstract class AuthShellRoutes {
  static const String splash = '/splash'; // splash d'auth (restauration de session)
  static const String landing = '/landing'; // écran d'ouverture façon Luma (hero + sheet)
  static const String auth = '/auth'; // écran de connexion e-mail (ouvert depuis la sheet)
  static const String home = '/home'; // accueil (dans le shell)
  static const String accountDeletionInfo = '/account-deletion';
  static const String accountDeleted = '/account/deleted';
  static const String onboardingSplash = '/onboarding/splash'; // ≠ [splash] (cf. #154)

  /// Ensemble des routes du flux de démarrage (hors shell), doit rester
  /// synchronisé avec `OnboardingRoutes.all` (asserté dans `router.dart`).
  static const Set<String> startupPaths = <String>{
    onboardingSplash,
    '/welcome',
    '/onboarding/certification',
  };

  static bool isStartup(String location) => startupPaths.contains(location);

  // --- Flux d'inscription progressif (Partie 3, façon Duo) ---------------
  //
  // Ces écrans vivent hors du shell, sur le navigateur racine, et NE font PAS
  // partie de l'onboarding (l'assert `startupPaths == OnboardingRoutes.all`
  // reste donc valable). Ils sont atteignables :
  //  - pré-création (nom/e-mail/mot de passe) tant que l'utilisateur est
  //    `Unauthenticated` ;
  //  - confirmation post-création une fois `Authenticated`, avant l'onboarding.
  static const String registerName = '/register/name';
  static const String registerEmail = '/register/email';
  static const String registerPassword = '/register/password';
  static const String registerProfileCreated = '/register/profile-created';

  /// Vrai pour toute route du flux d'inscription progressif (préfixe
  /// `/register`). Distinct du préfixe `/onboarding`.
  static bool isRegisterFlow(String location) => location.startsWith('/register');

  static bool isPublic(String location) => location == accountDeletionInfo;
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
///   [AuthShellRoutes.auth]) : il part vers l'onboarding ou l'accueil ; les
///   écrans du **flux d'inscription progressif** ([AuthShellRoutes.isRegisterFlow])
///   font exception le temps de la confirmation post-création, où
///   le flux pilote lui-même sa navigation avant de rejoindre l'onboarding ;
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
  final bool atPublic = AuthShellRoutes.isPublic(location);
  final bool atOnboarding = AuthShellRoutes.isStartup(location);
  final bool atRegister = AuthShellRoutes.isRegisterFlow(location);

  if (auth is AccountDeletionCompleted) {
    return location == AuthShellRoutes.accountDeleted ? null : AuthShellRoutes.accountDeleted;
  }
  if (atPublic) return null;

  // Restauration de session : rester sur le splash d'auth. Exception : les
  // écrans d'inscription affichent leur propre chargement inline (CTA en
  // loading pendant l'appel `registerWithEmail`) — on ne les éjecte PAS vers le
  // splash, sinon l'écran de mot de passe serait démonté puis la réussite
  // court-circuiterait les écrans post-création (piège du garde de la P1).
  if (auth is AuthLoading || auth is AuthSigningOut) {
    return (atAuthSplash || atRegister) ? null : AuthShellRoutes.splash;
  }
  // Non authentifié : présenter l'écran d'ouverture (landing) par défaut, tout
  // en autorisant l'écran de connexion e-mail atteint depuis la sheet et les
  // écrans pré-création du flux d'inscription progressif.
  if (auth is Unauthenticated) {
    return (atLanding || atAuth || atRegister) ? null : AuthShellRoutes.landing;
  }
  // Authentifié + flux d'inscription : laisser la confirmation post-création
  // s'afficher avant de rejoindre l'onboarding.
  // Le dernier « CONTINUER » navigue explicitement vers l'accueil, ce qui
  // relance le garde ci-dessous (onboarding non terminé → onboardingSplash).
  if (atRegister) {
    return onboardingCompleted ? AuthShellRoutes.home : null;
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
