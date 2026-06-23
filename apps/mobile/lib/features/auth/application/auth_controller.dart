import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_gateway.dart';
import 'auth_state.dart';
import 'session_store.dart';

/// Passerelle OIDC réelle. Surchargée par un faux dans les tests.
final authGatewayProvider = Provider<AuthGateway>((Ref ref) => AppAuthGateway());

/// Stockage sécurisé de la session. Surchargé par un faux dans les tests.
final sessionStoreProvider = Provider<SessionStore>((Ref ref) => SecureSessionStore());

/// Vrai quand Entra External ID est réellement configuré (clientId + autorité).
///
/// Exposé comme provider — et non lu directement depuis [AppEnv] dans le
/// contrôleur — pour pouvoir le forcer à `true` dans les tests, où les
/// `--dart-define` ne sont pas appliqués.
final authConfiguredProvider = Provider<bool>((Ref ref) => AppEnv.entraConfigured);

/// Vrai quand l'écran de connexion doit être présenté (Entra configuré, ou
/// aperçu forcé via `FORCE_AUTH_UI`). Faux en dev → passage direct.
final authRequiredProvider =
    Provider<bool>((Ref ref) => AppEnv.entraConfigured || AppEnv.forceAuthUi);

/// Contrôleur d'authentification : source de vérité synchrone de l'état de
/// session, pilotant le garde de navigation et l'injection du jeton d'API.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Orchestration de l'authentification multi-fournisseurs + persistance.
///
/// `Notifier` (synchrone) — et non `AsyncNotifier` — afin que le `redirect` de
/// GoRouter puisse lire l'état immédiatement, sans `await`.
class AuthController extends Notifier<AuthState> {
  late final AuthGateway _gateway;
  late final SessionStore _store;
  late final bool _required;
  late final bool _configured;

  @override
  AuthState build() {
    _gateway = ref.read(authGatewayProvider);
    _store = ref.read(sessionStoreProvider);
    _required = ref.read(authRequiredProvider);
    _configured = ref.read(authConfiguredProvider);
    // Différé en micro-tâche : `build` doit retourner sans muter l'état.
    Future<void>.microtask(_restore);
    return const AuthLoading();
  }

  /// Restauration au démarrage : c'est ce qui réalise l'**auto-connexion**.
  Future<void> _restore() async {
    // Passage direct en dev : tant qu'Entra n'est pas configuré (et qu'on ne
    // force pas l'aperçu), on n'impose pas d'écran de connexion pour préserver
    // le flux de développement existant (jeton dev).
    if (!_required) {
      state = Authenticated(_devSession());
      return;
    }

    final AuthSession? session = await _store.read();
    if (session == null) {
      state = const Unauthenticated();
      return;
    }
    if (!session.isExpired) {
      state = Authenticated(session);
      return;
    }
    // Session expirée → tentative de rafraîchissement silencieux.
    final AuthSession? refreshed = await _tryRefresh(session);
    state = refreshed != null ? Authenticated(refreshed) : const Unauthenticated();
  }

  /// Connexion explicite via l'un des trois fournisseurs.
  Future<void> signIn(AuthProvider provider) async {
    if (!_configured) {
      state = const Unauthenticated(
        'Configuration Entra requise : renseignez ENTRA_CLIENT_ID et ENTRA_AUTHORITY.',
      );
      return;
    }
    state = const AuthLoading();
    try {
      final AuthSession session = await _gateway.signIn(provider);
      if (session.accessToken.isEmpty) {
        state = const Unauthenticated('La connexion a échoué. Réessayez.');
        return;
      }
      await _store.write(session);
      state = Authenticated(session);
    } catch (_) {
      state = const Unauthenticated('La connexion a échoué. Réessayez.');
    }
  }

  /// Déconnexion : efface la session persistée et revient à l'écran de connexion.
  Future<void> signOut() async {
    final AuthState current = state;
    if (current is Authenticated) {
      try {
        await _gateway.signOut(current.session);
      } catch (_) {
        // Déconnexion best-effort : on nettoie le stockage quoi qu'il arrive.
      }
    }
    await _store.clear();
    state = const Unauthenticated();
  }

  /// Jeton d'accès courant pour l'API, rafraîchi de façon proactive.
  ///
  /// Branché sur le `tokenProvider` : injecté en en-tête `Authorization` à
  /// chaque requête.
  Future<String?> currentAccessToken() async {
    // En dev (non requis), on renvoie le jeton dev quel que soit l'état.
    if (!_required) return AppEnv.devAuthToken;

    final AuthState current = state;
    if (current is! Authenticated) return null;

    AuthSession session = current.session;
    if (session.willExpireSoon) {
      final AuthSession? refreshed = await _tryRefresh(session);
      if (refreshed != null) {
        session = refreshed;
        state = Authenticated(refreshed);
      }
    }
    return session.accessToken;
  }

  /// Appelé par l'`ApiClient` sur une réponse 401 : tente un rafraîchissement,
  /// sinon force une reconnexion.
  Future<void> handleUnauthorized() async {
    if (!_required) return;
    final AuthState current = state;
    if (current is Authenticated && current.session.refreshToken != null) {
      final AuthSession? refreshed = await _tryRefresh(current.session);
      if (refreshed != null) {
        state = Authenticated(refreshed);
        return;
      }
    }
    await _store.clear();
    state = const Unauthenticated('Votre session a expiré. Reconnectez-vous.');
  }

  Future<AuthSession?> _tryRefresh(AuthSession session) async {
    final String? refreshToken = session.refreshToken;
    if (refreshToken == null) return null;
    try {
      final AuthSession refreshed = await _gateway.refresh(refreshToken);
      if (refreshed.accessToken.isEmpty) return null;
      await _store.write(refreshed);
      return refreshed;
    } catch (_) {
      return null;
    }
  }

  AuthSession _devSession() => const AuthSession(
        accessToken: AppEnv.devAuthToken,
        displayName: 'Développeur',
      );
}
