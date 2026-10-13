import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_diagnostics.dart';
import 'auth_gateway.dart';
import 'auth_state.dart';
import 'auth_telemetry.dart';
import 'credentials_gateway.dart';
import 'session_store.dart';

/// Passerelle OIDC réelle. Surchargée par un faux dans les tests.
final authGatewayProvider = Provider<AuthGateway>(
  (Ref ref) => AppAuthGateway(diagnostics: ref.read(authDiagnosticsProvider.notifier)),
);

/// Passerelle e-mail/mot de passe réelle (API HTTP). Surchargée dans les tests.
final credentialsGatewayProvider = Provider<CredentialsGateway>(
  (Ref ref) => HttpCredentialsGateway(),
);

/// Stockage sécurisé de la session. Surchargé par un faux dans les tests.
final sessionStoreProvider = Provider<SessionStore>((Ref ref) => SecureSessionStore());

/// Vrai quand Entra External ID est réellement configuré (clientId + autorité).
///
/// Exposé comme provider — et non lu directement depuis [AppEnv] dans le
/// contrôleur — pour pouvoir le forcer à `true` dans les tests, où les
/// `--dart-define` ne sont pas appliqués.
final authConfiguredProvider = Provider<bool>((Ref ref) => AppEnv.entraConfigured);

/// Vrai quand l'écran de connexion doit être présenté. Désormais **toujours
/// vrai** : la connexion par e-mail/mot de passe est disponible en permanence,
/// indépendamment d'Entra. (Surchargeable à `false` dans les tests pour vérifier
/// l'ancien passage direct en dev.)
final authRequiredProvider = Provider<bool>((Ref ref) => true);

typedef AuthLocalAccountCleanup = Future<void> Function();

final authLocalAccountCleanupProvider = Provider<AuthLocalAccountCleanup>(
  (Ref ref) => () async {},
);

/// Contrôleur d'authentification : source de vérité synchrone de l'état de
/// session, pilotant le garde de navigation et l'injection du jeton d'API.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

class SensitiveReauthenticationResult {
  const SensitiveReauthenticationResult._(this.succeeded, this.message, this.reauthenticationToken);

  const SensitiveReauthenticationResult.success([String? token]) : this._(true, null, token);

  const SensitiveReauthenticationResult.failure(String message) : this._(false, message, null);

  final bool succeeded;
  final String? message;
  final String? reauthenticationToken;
}

/// Orchestration de l'authentification multi-fournisseurs + persistance.
///
/// `Notifier` (synchrone) — et non `AsyncNotifier` — afin que le `redirect` de
/// GoRouter puisse lire l'état immédiatement, sans `await`.
class AuthController extends Notifier<AuthState> {
  late final AuthGateway _gateway;
  late final CredentialsGateway _credentials;
  late final SessionStore _store;
  late final AuthTelemetry _telemetry;
  late final AuthDiagnosticsNotifier _diagnostics;
  late final AuthLocalAccountCleanup _localAccountCleanup;
  late final bool _required;
  late final bool _configured;
  int _sessionRevision = 0;
  Future<void> _sessionStoreTail = Future<void>.value();

  /// Filet de sécurité pour la connexion e-mail (appel API direct).
  static const Duration _emailTimeout = Duration(seconds: 25);

  /// Filet de sécurité pour la connexion sociale : borne le flux pour éviter un
  /// spinner infini si le callback OIDC ne revient jamais (build de diagnostic).
  /// Assez long pour une vraie saisie d'identifiants dans le navigateur système,
  /// assez court pour ne pas laisser l'utilisateur bloqué sans retour.
  static const Duration _socialTimeout = Duration(seconds: 45);

  /// Délai de lecture du coffre au démarrage (déjà borné dans le store aussi).
  static const Duration _restoreReadTimeout = Duration(seconds: 6);

  AuthState get currentState => state;

  @override
  AuthState build() {
    _gateway = ref.read(authGatewayProvider);
    _credentials = ref.read(credentialsGatewayProvider);
    _store = ref.read(sessionStoreProvider);
    _telemetry = ref.read(authTelemetryProvider);
    _diagnostics = ref.read(authDiagnosticsProvider.notifier);
    _localAccountCleanup = ref.read(authLocalAccountCleanupProvider);
    _required = ref.read(authRequiredProvider);
    _configured = ref.read(authConfiguredProvider);
    // Différé en micro-tâche : `build` doit retourner sans muter l'état.
    Future<void>.microtask(_restore);
    return const AuthLoading();
  }

  /// Restauration au démarrage : c'est ce qui réalise l'**auto-connexion**.
  Future<void> _restore() async {
    final int revision = _sessionRevision;
    // Passage direct en dev : tant qu'Entra n'est pas configuré (et qu'on ne
    // force pas l'aperçu), on n'impose pas d'écran de connexion pour préserver
    // le flux de développement existant (jeton dev).
    if (!_required) {
      if (_isCurrent(revision)) state = Authenticated(_devSession());
      return;
    }

    // Garde-fou : toute erreur — ou tout blocage du coffre sécurisé (le store
    // applique déjà un timeout) — doit dégrader proprement vers « non
    // authentifié » pour que l'app quitte TOUJOURS le splash et atteigne /auth.
    try {
      final AuthSession? session = await _store.read().timeout(_restoreReadTimeout);
      if (!_isCurrent(revision)) return;
      if (session == null) {
        // Aucune session mémorisée (premier lancement / déconnecté) : ce n'est
        // pas un échec — aucune tentative d'auto-connexion à mesurer.
        state = const Unauthenticated();
        return;
      }
      // Une session existe : c'est une vraie tentative d'auto-connexion.
      _telemetry.authStart(AuthMethod.restore);
      if (!session.isExpired) {
        _telemetry.authSuccess(AuthMethod.restore);
        state = Authenticated(session);
        return;
      }
      // Session expirée → tentative de rafraîchissement silencieux.
      final AuthSession? refreshed = await _tryRefresh(session);
      if (!_isCurrent(revision)) return;
      if (refreshed != null) {
        _telemetry.authSuccess(AuthMethod.restore);
        state = Authenticated(refreshed);
      } else {
        _telemetry.authFailure(AuthMethod.restore, AuthFailureCause.providerError);
        state = const Unauthenticated();
      }
    } catch (e, st) {
      if (!_isCurrent(revision)) return;
      _logAuthError('_restore', e, st);
      _telemetry.authFailure(AuthMethod.restore, AuthFailureCause.unknown);
      state = const Unauthenticated();
    }
  }

  /// Connexion explicite via l'un des trois fournisseurs.
  Future<void> signIn(AuthProvider provider) async {
    final int revision = ++_sessionRevision;
    final AuthMethod method = AuthMethodX.fromProvider(provider);
    if (!_configured) {
      _telemetry.authFailure(method, AuthFailureCause.configError);
      // La feuille d'accueil propose les fournisseurs même sans Entra (dev, ou
      // build `ENTRA_OPTIONAL=true`) : ce message arrive devant un apprenant,
      // qui ne peut pas renseigner une variable de build. Elle part au journal.
      _logAuthDetail(
        'signIn(${provider.id})',
        'Entra non configuré : ENTRA_CLIENT_ID et ENTRA_AUTHORITY absents du build',
      );
      state = Unauthenticated(
        'La connexion ${_providerLabel(provider)} n\'est pas disponible dans cette version. '
        'Connecte-toi avec ton e-mail.',
      );
      return;
    }
    _telemetry.authStart(method);
    // Nouvelle tentative sociale : on repart d'une trace de diagnostic vierge.
    // Les étapes 1→4 sont poussées par la passerelle (authorize/token), l'étape
    // 5 (session écrite) ci-dessous, et « échec » par la passerelle ou ici.
    _diagnostics.reset();
    state = const AuthLoading();
    final Stopwatch sw = Stopwatch()..start();
    try {
      final AuthSession session = await _gateway.signIn(provider).timeout(_socialTimeout);
      if (!_isCurrent(revision)) return;
      if (session.accessToken.isEmpty) {
        _telemetry.authFailure(
          method,
          AuthFailureCause.providerError,
          durationMs: sw.elapsedMilliseconds,
          detail: _socialFailureDetail(
            const AuthFailureSignature(errorType: 'EmptyAccessToken'),
          ),
        );
        _diagnostics.mark(
          AuthDiagnosticStep.failed,
          detail: 'jeton d\'accès vide après échange du code',
        );
        _logAuthDetail(
          'signIn(${provider.id})',
          'la réponse OIDC ne contenait ni access_token ni id_token',
        );
        state = Unauthenticated(
          'La connexion ${_providerLabel(provider)} n\'a pas abouti. '
          'Réessaie, ou connecte-toi avec ton e-mail.',
        );
        return;
      }
      if (!await _persistSession(session, revision)) return;
      _diagnostics.mark(AuthDiagnosticStep.sessionWritten);
      _telemetry.authSuccess(method, durationMs: sw.elapsedMilliseconds);
      state = Authenticated(session);
    } on TimeoutException catch (e, st) {
      if (!_isCurrent(revision)) return;
      _logAuthError('signIn(${provider.id}, timeout)', e, st);
      _telemetry.authFailure(
        method,
        AuthFailureCause.timeout,
        durationMs: sw.elapsedMilliseconds,
        detail: _socialFailureDetail(AuthFailureSignature.fromError(e)),
      );
      final int seconds = _socialTimeout.inSeconds;
      _diagnostics.mark(
        AuthDiagnosticStep.failed,
        detail: 'timeout ${seconds}s — voir la dernière étape atteinte ci-dessus',
      );
      state = Unauthenticated(
        'La fenêtre ${_providerLabel(provider)} n\'a pas répondu. '
        'Réessaie, ou connecte-toi avec ton e-mail.',
      );
    } on AuthGatewayException catch (e) {
      if (!_isCurrent(revision)) return;
      _telemetry.authFailure(
        method,
        e.cause,
        durationMs: sw.elapsedMilliseconds,
        detail: _socialFailureDetail(e.signature),
      );
      state = Unauthenticated(_displayError(e, provider));
    } catch (e, st) {
      if (!_isCurrent(revision)) return;
      _logAuthError('signIn(${provider.id})', e, st);
      _telemetry.authFailure(
        method,
        AuthFailureCause.unknown,
        durationMs: sw.elapsedMilliseconds,
        detail: _socialFailureDetail(AuthFailureSignature.fromError(e)),
      );
      _diagnostics.mark(AuthDiagnosticStep.failed, detail: '${e.runtimeType} : $e');
      state = Unauthenticated(
        'La connexion ${_providerLabel(provider)} a échoué. '
        'Réessaie, ou connecte-toi avec ton e-mail.',
      );
    }
  }

  AuthFailureDetail _socialFailureDetail(
    AuthFailureSignature? signature, {
    AuthFlow flow = AuthFlow.signIn,
  }) =>
      AuthFailureDetail(
        flow: flow,
        lastStep: _diagnostics.lastReachedStep,
        signature: signature,
      );

  /// Message affiché pour une erreur métier passerelle.
  ///
  /// Le détail technique porté par [AuthGatewayException.diagnostic] **ne
  /// traverse pas** : il part dans les journaux. Un `PlatformException
  /// code=… msg=… details=…` recopié à l'écran donnait à l'apprenant tout sauf
  /// ce qu'il pouvait en faire.
  ///
  /// Le message métier, lui, est conservé quand la passerelle a su qualifier la
  /// cause (réseau, délai, identifiants). Une annulation reçoit un message qui
  /// ne présume pas que l'apprenant a fermé la fenêtre, et les causes que seul
  /// un développeur peut corriger (configuration, refus du fournisseur) sont
  /// remplacées par la seule action que l'apprenant peut réellement tenter.
  String _displayError(AuthGatewayException e, AuthProvider provider) {
    _logAuthDetail('signIn(${provider.id})', e.diagnostic ?? e.message);
    return switch (e.cause) {
      // AppAuth iOS signale aussi en « annulation » une page qui n'a pas pu
      // s'ouvrir : le message ne présume pas que l'apprenant l'a fermée.
      AuthFailureCause.cancelled => 'La connexion ${_providerLabel(provider)} n\'a pas abouti : '
          'la fenêtre a été fermée ou n\'a pas pu s\'ouvrir. '
          'Réessaie, ou connecte-toi avec ton e-mail.',
      AuthFailureCause.network ||
      AuthFailureCause.timeout ||
      AuthFailureCause.invalidCredentials =>
        e.message,
      AuthFailureCause.providerError ||
      AuthFailureCause.configError ||
      AuthFailureCause.unknown =>
        'La connexion ${_providerLabel(provider)} a échoué. '
            'Réessaie, ou connecte-toi avec ton e-mail.',
    };
  }

  /// Libellé lisible du fournisseur, inséré dans les messages d'erreur.
  String _providerLabel(AuthProvider provider) => switch (provider) {
        AuthProvider.microsoft => 'Microsoft',
        AuthProvider.google => 'Google',
        AuthProvider.apple => 'Apple',
        AuthProvider.email => 'e-mail',
      };

  /// Connexion par e-mail + mot de passe (compte géré par notre backend).
  Future<void> signInWithEmail({required String email, required String password}) async {
    final int revision = ++_sessionRevision;
    _telemetry.authStart(AuthMethod.email);
    state = const AuthLoading();
    final Stopwatch sw = Stopwatch()..start();
    try {
      AuthSession session;
      try {
        session = await _credentials.login(email: email, password: password).timeout(_emailTimeout);
      } on AuthGatewayException catch (e) {
        // Un serveur qui met trop de temps à répondre est la signature d'un
        // backend qui démarre à froid. UNE seule reprise, et le compte de 1 est
        // contraint, pas préféré :
        //  * borne respectée — la première tentative échoue au délai de
        //    connexion du client HTTP (`connectTimeout`, packages/data
        //    api_client.dart), et cette attente dépasse à elle seule le
        //    démarrage à froid observé : 5 161 ms mesurés le 2026-09-10 sur
        //    `POST /auth/login` du backend dev après 15 h d'inactivité, contre
        //    224 à 427 ms à chaud sur les trois appels suivants ;
        //  * marge — l'échec de la première tentative réchauffe donc l'hôte
        //    lui-même : la reprise part sur un backend déjà démarré ;
        //  * ce qu'une seconde reprise ajouterait — une attente supplémentaire
        //    d'un `connectTimeout` entier pour un utilisateur qui regarde son
        //    écran, sans bénéfice mesuré, l'hôte étant déjà chaud.
        // Relire cette mesure avant de porter le compte au-delà de 1.
        //
        // Bornée à la connexion : `auth/register` n'a pas de clé d'idempotence,
        // et reprendre une inscription réussie mais expirée afficherait « adresse
        // déjà utilisée » à quelqu'un qui vient de créer son compte.
        if (e.cause != AuthFailureCause.timeout) rethrow;
        if (!_isCurrent(revision)) return;
        state = const AuthLoading(retrying: true);
        session = await _credentials.login(email: email, password: password).timeout(_emailTimeout);
      }
      if (!_isCurrent(revision)) return;
      if (session.accessToken.isEmpty) {
        _telemetry.authFailure(
          AuthMethod.email,
          AuthFailureCause.providerError,
          durationMs: sw.elapsedMilliseconds,
        );
        state = const Unauthenticated('La connexion a échoué. Réessayez.');
        return;
      }
      if (!await _persistSession(session, revision)) return;
      _telemetry.authSuccess(AuthMethod.email, durationMs: sw.elapsedMilliseconds);
      state = Authenticated(session);
    } on TimeoutException catch (e, st) {
      if (!_isCurrent(revision)) return;
      _logAuthError('signInWithEmail(timeout)', e, st);
      _telemetry.authFailure(
        AuthMethod.email,
        AuthFailureCause.timeout,
        durationMs: sw.elapsedMilliseconds,
      );
      state = Unauthenticated(authMessageForCause(AuthFailureCause.timeout));
    } on AuthGatewayException catch (e) {
      if (!_isCurrent(revision)) return;
      _telemetry.authFailure(AuthMethod.email, e.cause, durationMs: sw.elapsedMilliseconds);
      state = Unauthenticated(e.message);
    } catch (e, st) {
      if (!_isCurrent(revision)) return;
      _logAuthError('signInWithEmail', e, st);
      _telemetry.authFailure(
        AuthMethod.email,
        AuthFailureCause.unknown,
        durationMs: sw.elapsedMilliseconds,
      );
      state = const Unauthenticated('La connexion a échoué. Réessayez.');
    }
  }

  /// Création d'un compte e-mail + mot de passe, puis connexion immédiate.
  Future<void> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final int revision = ++_sessionRevision;
    _telemetry.authStart(AuthMethod.register);
    state = const AuthLoading();
    final Stopwatch sw = Stopwatch()..start();
    try {
      final AuthSession session = await _credentials
          .register(email: email, password: password, displayName: displayName)
          .timeout(_emailTimeout);
      if (!_isCurrent(revision)) return;
      if (session.accessToken.isEmpty) {
        _telemetry.authFailure(
          AuthMethod.register,
          AuthFailureCause.providerError,
          durationMs: sw.elapsedMilliseconds,
        );
        state = const Unauthenticated('La création du compte a échoué. Réessayez.');
        return;
      }
      if (!await _persistSession(session, revision)) return;
      _telemetry.authSuccess(AuthMethod.register, durationMs: sw.elapsedMilliseconds);
      state = Authenticated(session);
    } on TimeoutException catch (e, st) {
      if (!_isCurrent(revision)) return;
      _logAuthError('registerWithEmail(timeout)', e, st);
      _telemetry.authFailure(
        AuthMethod.register,
        AuthFailureCause.timeout,
        durationMs: sw.elapsedMilliseconds,
      );
      state = Unauthenticated(authMessageForCause(AuthFailureCause.timeout));
    } on AuthGatewayException catch (e) {
      if (!_isCurrent(revision)) return;
      _telemetry.authFailure(AuthMethod.register, e.cause, durationMs: sw.elapsedMilliseconds);
      state = Unauthenticated(e.message);
    } catch (e, st) {
      if (!_isCurrent(revision)) return;
      _logAuthError('registerWithEmail', e, st);
      _telemetry.authFailure(
        AuthMethod.register,
        AuthFailureCause.unknown,
        durationMs: sw.elapsedMilliseconds,
      );
      state = const Unauthenticated('La création du compte a échoué. Réessayez.');
    }
  }

  /// Déconnexion : efface la session persistée et revient à l'écran de connexion.
  Future<void> signOut() async {
    final AuthState current = state;
    final int revision = ++_sessionRevision;
    state = const AuthSigningOut();
    if (current is Authenticated) {
      try {
        await _gateway.signOut(current.session);
      } catch (e, st) {
        _logAuthError('signOut', e, st);
        // Déconnexion best-effort : on nettoie le stockage quoi qu'il arrive.
      }
    }
    String? cleanupMessage;
    try {
      await _localAccountCleanup();
    } catch (e, st) {
      _logAuthError('signOut(local cleanup)', e, st);
      cleanupMessage =
          'Déconnexion terminée. Certaines données locales seront nettoyées au prochain démarrage.';
    }
    var sessionCleared = true;
    try {
      if (!await _clearPersistedSession(revision)) {
        sessionCleared = false;
      }
    } catch (e, st) {
      _logAuthError('signOut(session clear)', e, st);
      sessionCleared = false;
    }
    if (!_isCurrent(revision)) return;
    if (!sessionCleared) {
      state = current;
      return;
    }
    state = Unauthenticated.signedOut(cleanupMessage);
  }

  Future<SensitiveReauthenticationResult> reauthenticateForAccountDeletion({
    required String expectedUserId,
    String? password,
  }) async {
    final AuthState current = state;
    if (current is! Authenticated) {
      return const SensitiveReauthenticationResult.failure(
        'Votre session a expiré. Reconnectez-vous avant de supprimer le compte.',
      );
    }

    final AuthProvider? provider = current.session.provider;
    if (provider == null) {
      return const SensitiveReauthenticationResult.failure(
        'Impossible de vérifier votre identité. Reconnectez-vous puis réessayez.',
      );
    }

    try {
      final AuthSession fresh;
      if (provider == AuthProvider.email) {
        final String? email = current.session.email;
        if (email == null || email.isEmpty || password == null || password.isEmpty) {
          return const SensitiveReauthenticationResult.failure(
            'Saisissez votre mot de passe pour confirmer la suppression.',
          );
        }
        fresh = await _credentials.login(email: email, password: password).timeout(_emailTimeout);
      } else {
        _diagnostics.reset();
        fresh = await _gateway.reauthenticate(provider).timeout(_socialTimeout);
      }

      if (fresh.accessToken.isEmpty || fresh.userId == null || fresh.userId != expectedUserId) {
        return const SensitiveReauthenticationResult.failure(
          'Le compte vérifié ne correspond pas au compte à supprimer.',
        );
      }

      await _store.write(fresh);
      state = Authenticated(fresh);
      return SensitiveReauthenticationResult.success(
        provider == AuthProvider.email ? null : fresh.idToken,
      );
    } on TimeoutException catch (error, stackTrace) {
      _logAuthError('reauthenticateForAccountDeletion(timeout)', error, stackTrace);
      _reportReauthenticationFailure(
        provider,
        AuthFailureCause.timeout,
        AuthFailureSignature.fromError(error),
      );
      return const SensitiveReauthenticationResult.failure('La vérification a expiré. Réessayez.');
    } on AuthGatewayException catch (error) {
      _reportReauthenticationFailure(provider, error.cause, error.signature);
      return SensitiveReauthenticationResult.failure(_reauthenticationError(error, provider));
    } catch (error, stackTrace) {
      _logAuthError('reauthenticateForAccountDeletion', error, stackTrace);
      _reportReauthenticationFailure(
        provider,
        AuthFailureCause.unknown,
        AuthFailureSignature.fromError(error),
      );
      return const SensitiveReauthenticationResult.failure('La vérification a échoué. Réessayez.');
    }
  }

  void _reportReauthenticationFailure(
    AuthProvider provider,
    AuthFailureCause cause,
    AuthFailureSignature? signature,
  ) {
    if (provider == AuthProvider.email) return;
    _telemetry.authFailure(
      AuthMethodX.fromProvider(provider),
      cause,
      detail: _socialFailureDetail(signature, flow: AuthFlow.reauthentication),
    );
  }

  /// Message d'une vérification sociale échouée avant suppression : la cause,
  /// le fait que rien n'a été supprimé, et quoi faire. Comme à la connexion, le
  /// détail technique part au journal et non à l'écran.
  String _reauthenticationError(AuthGatewayException e, AuthProvider provider) {
    if (provider == AuthProvider.email) return e.message;
    _logAuthDetail('reauthenticate(${provider.id})', e.diagnostic ?? e.message);
    final String label = _providerLabel(provider);
    return switch (e.cause) {
      AuthFailureCause.network => e.message,
      AuthFailureCause.cancelled => 'La vérification $label n\'a pas abouti : la fenêtre a été '
          'fermée ou n\'a pas pu s\'ouvrir. Votre compte n\'a pas été supprimé. '
          'Réessayez pour confirmer la suppression.',
      _ => 'La vérification $label a échoué. Votre compte n\'a pas été supprimé. '
          'Réessayez dans un instant.',
    };
  }

  Future<void> completeAccountDeletion({required String expectedUserId}) async {
    final AuthState current = state;
    if (current is! Authenticated || current.session.userId != expectedUserId) {
      throw StateError('Authenticated person does not match the completed deletion.');
    }
    final int revision = ++_sessionRevision;
    try {
      await _gateway.signOut(current.session);
    } catch (error, stackTrace) {
      _logAuthError('completeAccountDeletion', error, stackTrace);
    }
    final AuthState afterSignOut = state;
    if (!_isCurrent(revision) ||
        afterSignOut is! Authenticated ||
        afterSignOut.session.userId != expectedUserId) {
      throw StateError('Authenticated person changed during account deletion.');
    }
    if (!await _clearPersistedSession(revision)) {
      throw StateError('Authenticated session changed during account deletion.');
    }
    state = const AccountDeletionCompleted();
  }

  void finishAccountDeletion() {
    state = const Unauthenticated('Votre compte et vos données Certigo ont été supprimés.');
  }

  /// Renvoie l'e-mail de vérification pour le compte connecté (best-effort).
  /// Retourne `true` si l'appel a abouti, `false` sinon.
  Future<bool> resendVerificationEmail() async {
    final AuthState current = state;
    if (current is! Authenticated) return false;
    final String? email = current.session.email;
    if (email == null || email.isEmpty) return false;
    try {
      await _credentials.resendVerification(email);
      return true;
    } catch (e, st) {
      _logAuthError('resendVerificationEmail', e, st);
      return false;
    }
  }

  /// Rafraîchit la session pour re-lire l'état de vérification après confirmation
  /// (le lien étant cliqué hors de l'app). Sans effet si non authentifié ou sans
  /// jeton de rafraîchissement.
  Future<void> reloadVerificationStatus() async {
    final AuthState current = state;
    if (current is! Authenticated) return;
    final AuthSession? refreshed = await _tryRefresh(current.session);
    if (refreshed != null) {
      state = Authenticated(refreshed);
    }
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
    final int revision = _sessionRevision;

    AuthSession session = current.session;
    if (session.willExpireSoon) {
      final AuthSession? refreshed = await _tryRefresh(session);
      if (refreshed != null) {
        session = refreshed;
        state = Authenticated(refreshed);
      }
    }
    return _isCurrent(revision) ? session.accessToken : null;
  }

  /// Appelé par l'`ApiClient` sur une réponse 401 : tente un rafraîchissement,
  /// sinon force une reconnexion.
  Future<void> handleUnauthorized() async {
    if (!_required) return;
    final AuthState current = state;
    if (current is AuthSigningOut) return;
    final int revision = _sessionRevision;
    if (current is Authenticated && current.session.refreshToken != null) {
      final AuthSession? refreshed = await _tryRefresh(current.session);
      if (refreshed != null) {
        if (!_isCurrent(revision)) return;
        state = Authenticated(refreshed);
        return;
      }
    }
    if (!await _clearPersistedSession(revision)) return;
    state = const Unauthenticated('Votre session a expiré. Reconnectez-vous.');
  }

  Future<AuthSession?> _tryRefresh(AuthSession session) async {
    final int revision = _sessionRevision;
    final String? refreshToken = session.refreshToken;
    if (refreshToken == null) return null;
    try {
      // Les sessions e-mail/mot de passe se rafraîchissent via notre API ; les
      // sessions Entra via le flux OIDC.
      final AuthSession refreshed = session.provider == AuthProvider.email
          ? await _credentials.refresh(refreshToken)
          : await _gateway.refresh(refreshToken);
      if (refreshed.accessToken.isEmpty) return null;
      if (!_isCurrent(revision)) return null;
      // La réponse `/auth/refresh` n'inclut pas l'e-mail : on reporte celui de la
      // session précédente pour que les fonctions qui s'appuient dessus (renvoi de
      // l'e-mail de vérification) continuent de marcher après un refresh silencieux.
      final AuthSession carried = refreshed.copyWith(
        email: refreshed.email ?? session.email,
        userId: refreshed.userId ?? session.userId,
      );
      if (!await _persistSession(carried, revision)) return null;
      return carried;
    } catch (e, st) {
      _logAuthError('_tryRefresh', e, st);
      return null;
    }
  }

  void _logAuthError(String operation, Object error, StackTrace stackTrace) {
    debugPrint('[AuthController] $operation failed: $error');
    debugPrint('$stackTrace');
  }

  /// Journalise un détail technique **au lieu** de l'afficher.
  ///
  /// C'est la contrepartie de [_displayError] : rien n'est perdu, mais le
  /// destinataire change. Sentry capte déjà les erreurs non rattrapées ; ceci
  /// couvre les échecs que l'on rattrape volontairement.
  void _logAuthDetail(String operation, String detail) {
    debugPrint('[AuthController] $operation: $detail');
  }

  bool _isCurrent(int revision) => revision == _sessionRevision;

  Future<bool> _persistSession(AuthSession session, int revision) async {
    var persisted = false;
    final Future<void> operation = _sessionStoreTail.then((_) async {
      if (!_isCurrent(revision)) return;
      await _store.write(session);
      persisted = _isCurrent(revision);
    });
    _sessionStoreTail = operation.catchError((Object _) {});
    await operation;
    return persisted;
  }

  Future<bool> _clearPersistedSession(int revision) async {
    var cleared = false;
    final Future<void> operation = _sessionStoreTail.then((_) async {
      if (!_isCurrent(revision)) return;
      await _store.clear();
      cleared = _isCurrent(revision);
    });
    _sessionStoreTail = operation.catchError((Object _) {});
    await operation;
    return cleared;
  }

  AuthSession _devSession() => AuthSession(
        accessToken: AppEnv.devAuthToken,
        userId: AppEnv.devAuthToken.trim().isEmpty ? 'dev-user' : AppEnv.devAuthToken.trim(),
        displayName: 'Développeur',
      );
}
