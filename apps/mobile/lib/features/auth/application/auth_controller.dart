import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_gateway.dart';
import 'auth_state.dart';
import 'credentials_gateway.dart';
import 'session_store.dart';

/// Passerelle OIDC réelle. Surchargée par un faux dans les tests.
final authGatewayProvider = Provider<AuthGateway>(
  (Ref ref) => AppAuthGateway(),
);

/// Passerelle e-mail/mot de passe réelle (API HTTP). Surchargée dans les tests.
final credentialsGatewayProvider = Provider<CredentialsGateway>(
  (Ref ref) => HttpCredentialsGateway(),
);

/// Stockage sécurisé de la session. Surchargé par un faux dans les tests.
final sessionStoreProvider = Provider<SessionStore>(
  (Ref ref) => SecureSessionStore(),
);

/// Vrai quand Entra External ID est réellement configuré (clientId + autorité).
///
/// Exposé comme provider — et non lu directement depuis [AppEnv] dans le
/// contrôleur — pour pouvoir le forcer à `true` dans les tests, où les
/// `--dart-define` ne sont pas appliqués.
final authConfiguredProvider = Provider<bool>(
  (Ref ref) => AppEnv.entraConfigured,
);

/// Vrai quand l'écran de connexion doit être présenté. Désormais **toujours
/// vrai** : la connexion par e-mail/mot de passe est disponible en permanence,
/// indépendamment d'Entra. (Surchargeable à `false` dans les tests pour vérifier
/// l'ancien passage direct en dev.)
final authRequiredProvider = Provider<bool>(
  (Ref ref) => true,
);

/// Contrôleur d'authentification : source de vérité synchrone de l'état de
/// session, pilotant le garde de navigation et l'injection du jeton d'API.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Orchestration de l'authentification multi-fournisseurs + persistance.
///
/// `Notifier` (synchrone) — et non `AsyncNotifier` — afin que le `redirect` de
/// GoRouter puisse lire l'état immédiatement, sans `await`.
class AuthController extends Notifier<AuthState> {
  late final AuthGateway _gateway;
  late final CredentialsGateway _credentials;
  late final SessionStore _store;
  late final bool _required;
  late final bool _configured;

  @override
  AuthState build() {
    _gateway = ref.read(authGatewayProvider);
    _credentials = ref.read(credentialsGatewayProvider);
    _store = ref.read(sessionStoreProvider);
    _required = ref.read(authRequiredProvider);
    _configured = ref.read(authConfiguredProvider);
    // Différé en micro-tâche : `build` doit retourner sans muter l'état.
    Future<void>.microtask(_restore);
    return const AuthLoading();
  }

  /// Restauration au démarrage : c'est ce qui réalise l'**auto-connexion**.
  Future<void> _restore() async {
    debugPrint('[LOGIN-DBG] restore:start required=$_required');
    // Passage direct en dev : tant qu'Entra n'est pas configuré (et qu'on ne
    // force pas l'aperçu), on n'impose pas d'écran de connexion pour préserver
    // le flux de développement existant (jeton dev).
    if (!_required) {
      state = Authenticated(_devSession());
      debugPrint('[LOGIN-DBG] restore:dev-passthrough state=Authenticated');
      return;
    }

    // Garde-fou : toute erreur — ou tout blocage du coffre sécurisé (le store
    // applique déjà un timeout) — doit dégrader proprement vers « non
    // authentifié » pour que l'app quitte TOUJOURS le splash et atteigne /auth.
    try {
      final AuthSession? session = await _store.read().timeout(const Duration(seconds: 6));
      final String readResult = session == null ? 'null' : 'session-found';
      debugPrint('[LOGIN-DBG] restore:read $readResult');
      if (session == null) {
        state = const Unauthenticated();
        debugPrint('[LOGIN-DBG] restore:end state=Unauthenticated');
        return;
      }
      if (!session.isExpired) {
        state = Authenticated(session);
        debugPrint('[LOGIN-DBG] restore:end state=Authenticated');
        return;
      }
      // Session expirée → tentative de rafraîchissement silencieux.
      final AuthSession? refreshed = await _tryRefresh(session);
      final String refreshState = refreshed != null ? 'Authenticated' : 'Unauthenticated';
      state = refreshed != null ? Authenticated(refreshed) : const Unauthenticated();
      debugPrint('[LOGIN-DBG] restore:end state=$refreshState (post-refresh)');
    } catch (e, st) {
      _logAuthError('_restore', e, st);
      debugPrint('[LOGIN-DBG] restore:error $e');
      state = const Unauthenticated();
    }
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
    } on AuthGatewayException catch (e) {
      state = Unauthenticated(e.message);
    } catch (e, st) {
      _logAuthError('signIn(${provider.id})', e, st);
      state = const Unauthenticated('La connexion a échoué. Réessayez.');
    }
  }

  /// Connexion par e-mail + mot de passe (compte géré par notre backend).
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    debugPrint('[LOGIN-DBG] signIn:start');
    state = const AuthLoading();
    final Stopwatch sw = Stopwatch()..start();
    try {
      debugPrint('[LOGIN-DBG] signIn:before login()');
      final AuthSession session = await _credentials
          .login(email: email, password: password)
          .timeout(const Duration(seconds: 25));
      final String tokenState = session.accessToken.isEmpty ? 'empty-token' : 'token-present';
      debugPrint('[LOGIN-DBG] signIn:after login() $tokenState (${sw.elapsedMilliseconds}ms)');
      if (session.accessToken.isEmpty) {
        state = const Unauthenticated('La connexion a échoué. Réessayez.');
        return;
      }
      debugPrint('[LOGIN-DBG] signIn:before write()');
      await _store.write(session);
      debugPrint('[LOGIN-DBG] signIn:after write()');
      state = Authenticated(session);
      debugPrint('[LOGIN-DBG] signIn:end state=Authenticated (${sw.elapsedMilliseconds}ms)');
    } on TimeoutException catch (e, st) {
      _logAuthError('signInWithEmail(timeout)', e, st);
      debugPrint('[LOGIN-DBG] signIn:timeout after ${sw.elapsedMilliseconds}ms');
      state = const Unauthenticated('La connexion a expiré. Réessayez.');
    } on AuthGatewayException catch (e) {
      debugPrint('[LOGIN-DBG] signIn:gateway-error (${sw.elapsedMilliseconds}ms) ${e.message}');
      state = Unauthenticated(e.message);
    } catch (e, st) {
      _logAuthError('signInWithEmail', e, st);
      debugPrint('[LOGIN-DBG] signIn:error (${sw.elapsedMilliseconds}ms) $e');
      state = const Unauthenticated('La connexion a échoué. Réessayez.');
    }
  }

  /// Création d'un compte e-mail + mot de passe, puis connexion immédiate.
  Future<void> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AuthLoading();
    try {
      final AuthSession session = await _credentials.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (session.accessToken.isEmpty) {
        state = const Unauthenticated('La création du compte a échoué. Réessayez.');
        return;
      }
      await _store.write(session);
      state = Authenticated(session);
    } on AuthGatewayException catch (e) {
      state = Unauthenticated(e.message);
    } catch (e, st) {
      _logAuthError('registerWithEmail', e, st);
      state = const Unauthenticated('La création du compte a échoué. Réessayez.');
    }
  }

  /// Déconnexion : efface la session persistée et revient à l'écran de connexion.
  Future<void> signOut() async {
    final AuthState current = state;
    if (current is Authenticated) {
      try {
        await _gateway.signOut(current.session);
      } catch (e, st) {
        _logAuthError('signOut', e, st);
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
      // Les sessions e-mail/mot de passe se rafraîchissent via notre API ; les
      // sessions Entra via le flux OIDC.
      final AuthSession refreshed = session.provider == AuthProvider.email
          ? await _credentials.refresh(refreshToken)
          : await _gateway.refresh(refreshToken);
      if (refreshed.accessToken.isEmpty) return null;
      await _store.write(refreshed);
      return refreshed;
    } catch (e, st) {
      _logAuthError('_tryRefresh', e, st);
      return null;
    }
  }

  void _logAuthError(String operation, Object error, StackTrace stackTrace) {
    debugPrint('[AuthController] $operation failed: $error');
    debugPrint('$stackTrace');
  }

  AuthSession _devSession() => const AuthSession(
        accessToken: AppEnv.devAuthToken,
        displayName: 'Développeur',
      );
}
