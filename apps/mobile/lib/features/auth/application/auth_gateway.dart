import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'auth_diagnostics.dart';
import 'auth_state.dart';

/// Signature **technique** d'un échec de connexion sociale, sans donnée
/// personnelle : uniquement des identifiants fixes du SDK AppAuth et du
/// protocole OAuth. Jamais de description, d'URL, d'e-mail ni de jeton.
///
/// Elle rend diagnostiquable, depuis Sentry, un échec survenu sur l'appareil
/// d'un testeur : les builds de release n'affichent pas la carte de diagnostic
/// et `debugPrint` n'y laisse aucune trace exploitable.
@immutable
class AuthFailureSignature {
  const AuthFailureSignature({
    this.pluginCode,
    this.nativeType,
    this.nativeCode,
    this.oauthError,
    this.underlyingDomain,
    this.errorType,
  });

  /// Construit la signature d'une erreur `flutter_appauth`, ou à défaut son
  /// seul type Dart.
  factory AuthFailureSignature.fromError(Object error) {
    final FlutterAppAuthPlatformErrorDetails? details = switch (error) {
      FlutterAppAuthUserCancelledException(:final platformErrorDetails) => platformErrorDetails,
      FlutterAppAuthPlatformException(:final platformErrorDetails) => platformErrorDetails,
      _ => null,
    };
    return AuthFailureSignature(
      pluginCode: error is PlatformException ? error.code : null,
      nativeType: details?.type,
      nativeCode: details?.code,
      oauthError: details?.error,
      underlyingDomain: details?.domain,
      errorType: error.runtimeType.toString(),
    );
  }

  /// Code d'erreur du plugin (`authorize_failed`, `discovery_failed`…).
  final String? pluginCode;

  /// Domaine d'erreur AppAuth (`org.openid.appauth.general`…).
  final String? nativeType;

  /// Code d'erreur AppAuth dans ce domaine (`-3`…).
  final String? nativeCode;

  /// Code d'erreur OAuth renvoyé par le serveur (`invalid_request`…).
  final String? oauthError;

  /// Domaine de l'erreur sous-jacente, sur iOS
  /// (`com.apple.AuthenticationServices.WebAuthenticationSession`…).
  final String? underlyingDomain;

  /// Type Dart de l'erreur reçue.
  final String? errorType;
}

/// Erreur métier remontée au contrôleur pour afficher un message clair.
class AuthGatewayException implements Exception {
  const AuthGatewayException(
    this.message, {
    this.cause = AuthFailureCause.unknown,
    this.diagnostic,
    this.signature,
  });

  final String message;

  /// Cause normalisée (pour la télémétrie et le repli de message).
  final AuthFailureCause cause;

  /// Détail technique **brut** de l'erreur sous-jacente : `code=…/msg=…/details=…`
  /// d'une [PlatformException] `flutter_appauth`, ou `type : toString()` d'une
  /// erreur inattendue.
  ///
  /// **Destiné aux journaux, jamais à l'écran.** Le contrôleur le journalise et
  /// affiche une phrase qui dit quoi faire : un `PlatformException code=…`
  /// recopié devant l'apprenant lui donnait tout sauf une action possible.
  /// `null` pour les cas volontairement propres (ex. annulation).
  final String? diagnostic;

  /// Signature sans donnée personnelle, seule partie remontée à Sentry.
  final AuthFailureSignature? signature;

  @override
  String toString() =>
      'AuthGatewayException($cause, $message${diagnostic == null ? '' : ', diag=$diagnostic'})';
}

/// Abstraction du flux OIDC (Authorization Code + PKCE).
///
/// Isolée derrière une interface car l'implémentation réelle
/// ([AppAuthGateway]) repose sur des *platform channels* (flutter_appauth) qui
/// lèvent `MissingPluginException` sous `flutter test`. Les tests injectent un
/// faux.
abstract interface class AuthGateway {
  /// Ouvre le navigateur système, authentifie l'utilisateur via Entra
  /// (en pré-orientant vers [provider]) et échange le code contre des jetons.
  Future<AuthSession> signIn(AuthProvider provider);

  /// Rafraîchit silencieusement les jetons à partir du `refresh_token`.
  Future<AuthSession> refresh(String refreshToken);

  /// Déconnexion (locale par défaut ; le nettoyage du stockage est géré par le
  /// contrôleur).
  Future<void> signOut(AuthSession session);

  /// Ré-authentification interactive pour une opération sensible. Le fournisseur
  /// doit ignorer les cookies silencieux et produire une preuve `auth_time` fraîche.
  Future<AuthSession> reauthenticate(AuthProvider provider);
}

/// Implémentation réelle basée sur `flutter_appauth` + Microsoft Entra
/// External ID.
class AppAuthGateway implements AuthGateway {
  AppAuthGateway({FlutterAppAuth? appAuth, AuthDiagnostics? diagnostics})
      : _appAuth = appAuth ?? const FlutterAppAuth(),
        _diagnostics = diagnostics ?? const NoopAuthDiagnostics();

  final FlutterAppAuth _appAuth;

  /// Puits d'étapes tracées à l'écran (build de diagnostic). Inerte par défaut.
  final AuthDiagnostics _diagnostics;

  List<String> get _scopes => <String>[
        ...AppEnv.entraScopes,
        if (AppEnv.entraApiScope.isNotEmpty) AppEnv.entraApiScope,
      ];

  /// Agent externe préféré pour l'ouverture du navigateur système.
  ///
  /// Sur **iOS/macOS**, on force une session **éphémère**
  /// (`ASWebAuthenticationSession` sans partage de cookies avec le navigateur de
  /// l'utilisateur) : cela supprime le prompt système de session partagée
  /// (« … souhaite utiliser ciamlogin.com ») et isole les cookies. C'est un
  /// correctif connu des blocages de callback `ASWebAuthenticationSession` après
  /// la page de confirmation CIAM. En v8 de `flutter_appauth`, l'ancien
  /// `preferEphemeralSession: true` a été remplacé par cette valeur d'enum.
  ///
  /// Ailleurs (Android), on conserve l'agent par défaut : la fédération y
  /// fonctionne déjà et cet enum n'y est de toute façon pas appliqué.
  ExternalUserAgent get _preferredUserAgent =>
      (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)
          ? ExternalUserAgent.ephemeralAsWebAuthenticationSession
          : ExternalUserAgent.asWebAuthenticationSession;

  @override
  Future<AuthSession> signIn(AuthProvider provider) => _authenticate(provider, sensitive: false);

  @override
  Future<AuthSession> reauthenticate(AuthProvider provider) =>
      _authenticate(provider, sensitive: true);

  Future<AuthSession> _authenticate(
    AuthProvider provider, {
    required bool sensitive,
  }) async {
    try {
      // Étape 1 — ouverture de l'autorisation (navigateur système). On sépare
      // volontairement `authorize()` de `token()` (plutôt que le combiné
      // `authorizeAndExchangeCode`) afin d'ISOLER un blocage du callback
      // (authorize) d'un blocage de l'échange (token) : chaque étape est tracée
      // et remonte son erreur propre, sans hang silencieux.
      _diagnostics.mark(AuthDiagnosticStep.authorizeOpened);
      final AuthorizationResponse authorization = await _appAuth.authorize(
        AuthorizationRequest(
          AppEnv.entraClientId,
          AppEnv.entraRedirectUri,
          issuer: AppEnv.entraAuthority,
          scopes: _scopes,
          additionalParameters: <String, String>{
            ...?_hintFor(provider),
            if (sensitive) 'max_age': '0',
          },
          // `login` et jamais `select_account` : mesuré le 2026-09-27, avec
          // `select_account` CIAM ignore l'indice de fournisseur et réaffiche sa
          // propre page de choix, que l'utilisateur prenait pour l'écran de
          // connexion de l'app (« c'est une boucle »). `login` respecte aussi le
          // fournisseur choisi quand une session CIAM existe encore (Android).
          // Pour une opération sensible, `max_age=0` exige en plus une
          // authentification fraîche (`auth_time`).
          promptValues: const <String>['login'],
          externalUserAgent: _preferredUserAgent,
        ),
      );

      // Étape 2 — le callback natif est revenu ; on trace la présence (et la
      // longueur, jamais la valeur) du code d'autorisation.
      final String? code = authorization.authorizationCode;
      _diagnostics.mark(
        AuthDiagnosticStep.callbackReturned,
        detail: code == null || code.isEmpty ? 'code absent' : 'code len=${code.length}',
      );
      if (code == null || code.isEmpty) {
        _diagnostics.mark(
          AuthDiagnosticStep.failed,
          detail: 'callback revenu sans code d\'autorisation',
        );
        throw const AuthGatewayException(
          'La connexion n\'a pas renvoyé de code d\'autorisation.',
          cause: AuthFailureCause.providerError,
          diagnostic: 'authorize() est revenu sans authorizationCode '
              '(étape : callback / autorisation). Le navigateur est revenu à '
              'l\'app mais sans code exploitable.',
          signature: AuthFailureSignature(errorType: 'MissingAuthorizationCode'),
        );
      }

      // Étape 3 — échange du code contre des jetons (token endpoint). On réutilise
      // le `codeVerifier` (PKCE) et le `nonce` produits par `authorize()`, à
      // l'identique de ce que faisait le combiné en interne.
      _diagnostics.mark(AuthDiagnosticStep.tokenExchangeStarted);
      final TokenResponse result = await _appAuth.token(
        TokenRequest(
          AppEnv.entraClientId,
          AppEnv.entraRedirectUri,
          issuer: AppEnv.entraAuthority,
          scopes: _scopes,
          authorizationCode: code,
          codeVerifier: authorization.codeVerifier,
          nonce: authorization.nonce,
          grantType: GrantType.authorizationCode,
        ),
      );

      // Étape 4 — jetons reçus (longueurs seulement, jamais les jetons).
      _diagnostics.mark(
        AuthDiagnosticStep.tokenReceived,
        detail: 'access len=${result.accessToken?.length ?? 0}, '
            'id len=${result.idToken?.length ?? 0}',
      );

      return _toSession(
        result.accessToken,
        result.refreshToken,
        result.idToken,
        result.accessTokenExpirationDateTime,
        provider,
      );
    } on FlutterAppAuthUserCancelledException catch (e) {
      _diagnostics.mark(
        AuthDiagnosticStep.failed,
        detail: 'annulé par l\'utilisateur',
      );
      // AppAuth iOS signale aussi comme « annulation » une page web qui n'a pas
      // pu s'ouvrir : la signature permet de distinguer les deux dans Sentry.
      throw AuthGatewayException(
        'Connexion annulée.',
        cause: AuthFailureCause.cancelled,
        signature: AuthFailureSignature.fromError(e),
      );
    } on AuthGatewayException {
      // Déjà typée + tracée (ex. code d'autorisation absent) : relayer telle quelle.
      rethrow;
    } on PlatformException catch (e) {
      final ({String message, AuthFailureCause cause}) described = _describeError(e, provider);
      // Annulation : on garde le message propre, sans bruit technique.
      final String? diagnostic =
          described.cause == AuthFailureCause.cancelled ? null : _platformDiagnostic(e);
      _diagnostics.mark(
        AuthDiagnosticStep.failed,
        detail: diagnostic ?? described.message,
      );
      throw AuthGatewayException(
        described.message,
        cause: described.cause,
        diagnostic: diagnostic,
        signature: AuthFailureSignature.fromError(e),
      );
    } catch (e) {
      // Erreur inattendue (non PlatformException) : on ne l'avale pas, on
      // remonte son type + toString() pour diagnostic à l'écran.
      _diagnostics.mark(
        AuthDiagnosticStep.failed,
        detail: '${e.runtimeType} : $e',
      );
      throw AuthGatewayException(
        'La connexion via ${provider.id} a échoué. Vérifiez la configuration Entra puis réessayez.',
        cause: AuthFailureCause.providerError,
        diagnostic: '${e.runtimeType} : $e',
        signature: AuthFailureSignature.fromError(e),
      );
    }
  }

  /// Détail technique brut d'une [PlatformException] `flutter_appauth`
  /// (code + message + details) destiné à révéler la cause réelle à l'écran.
  String _platformDiagnostic(PlatformException e) {
    final String msg = e.message == null ? '' : ' msg=${e.message}';
    final String details = e.details == null ? '' : ' details=${e.details}';
    return 'PlatformException code=${e.code}$msg$details';
  }

  /// Traduit une [PlatformException] `flutter_appauth` en message utilisateur FR
  /// **et** en [AuthFailureCause] normalisée (source unique côté social).
  ({String message, AuthFailureCause cause}) _describeError(
    PlatformException e,
    AuthProvider provider,
  ) {
    final String lowerCode = e.code.toLowerCase();
    final String lowerMessage = (e.message ?? '').toLowerCase();
    final String details = '${e.details ?? ''}'.toLowerCase();
    final String haystack = '$lowerCode $lowerMessage $details';

    if (haystack.contains('user_cancel')) {
      return (message: 'Connexion annulée.', cause: AuthFailureCause.cancelled);
    }
    if (haystack.contains('network') ||
        haystack.contains('timeout') ||
        haystack.contains('timed out') ||
        haystack.contains('unreachable') ||
        haystack.contains('connection')) {
      return (
        message: 'Pas de connexion. Vérifiez votre réseau puis réessayez.',
        cause: AuthFailureCause.network,
      );
    }
    if (haystack.contains('redirect_uri') ||
        haystack.contains('redirect uri') ||
        haystack.contains('invalid_redirect')) {
      return (
        message:
            'Configuration de redirection invalide. Vérifiez ENTRA_REDIRECT_URI (${AppEnv.entraRedirectUri}) et sa déclaration native sur iOS/Android.',
        cause: AuthFailureCause.configError,
      );
    }
    if (haystack.contains('invalid_client') ||
        haystack.contains('unauthorized_client') ||
        haystack.contains('client_id')) {
      return (
        message:
            'Client Entra invalide. Vérifiez ENTRA_CLIENT_ID et l\'application Entra External ID.',
        cause: AuthFailureCause.configError,
      );
    }
    if (haystack.contains('domain_hint') ||
        haystack.contains('idp') ||
        haystack.contains('identity provider') ||
        haystack.contains('federat')) {
      return (
        message:
            'Fournisseur ${provider.id} indisponible dans Entra External ID. Vérifiez la fédération et le domain_hint.',
        cause: AuthFailureCause.providerError,
      );
    }
    return (
      message:
          'La connexion via ${provider.id} a échoué. Vérifiez la configuration Entra puis réessayez.',
      cause: AuthFailureCause.providerError,
    );
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    try {
      final TokenResponse result = await _appAuth.token(
        TokenRequest(
          AppEnv.entraClientId,
          AppEnv.entraRedirectUri,
          issuer: AppEnv.entraAuthority,
          scopes: _scopes,
          refreshToken: refreshToken,
          grantType: 'refresh_token',
        ),
      );
      return _toSession(
        result.accessToken,
        result.refreshToken ?? refreshToken,
        result.idToken,
        result.accessTokenExpirationDateTime,
        null,
      );
    } on PlatformException catch (e) {
      final ({String message, AuthFailureCause cause}) described =
          _describeError(e, AuthProvider.microsoft);
      throw AuthGatewayException(
        described.message,
        cause: described.cause,
        diagnostic: described.cause == AuthFailureCause.cancelled ? null : _platformDiagnostic(e),
      );
    } catch (e) {
      throw AuthGatewayException(
        'Impossible de rafraîchir la session.',
        cause: AuthFailureCause.providerError,
        diagnostic: '${e.runtimeType} : $e',
      );
    }
  }

  @override
  Future<void> signOut(AuthSession session) async {
    // Déconnexion locale : on n'ouvre pas le navigateur pour fermer la session
    // du fournisseur (expérience moins brutale). `prompt=login` redemande les
    // identifiants à la connexion suivante : changer de compte reste possible.
    return;
  }

  /// Retourne l'indice de fournisseur (`domain_hint`) qui envoie Entra External
  /// ID directement chez le fournisseur choisi (voir [AppEnv.appleDomainHint]
  /// pour les valeurs mesurées).
  Map<String, String>? _hintFor(AuthProvider provider) {
    final String hint = switch (provider) {
      AuthProvider.microsoft => AppEnv.microsoftDomainHint,
      AuthProvider.google => AppEnv.googleDomainHint,
      AuthProvider.apple => AppEnv.appleDomainHint,
      // L'e-mail/mot de passe ne passe pas par Entra : aucun indice de domaine.
      AuthProvider.email => '',
    };
    if (hint.isEmpty) return null;
    return <String, String>{'domain_hint': hint};
  }

  AuthSession _toSession(
    String? accessToken,
    String? refreshToken,
    String? idToken,
    DateTime? expiry,
    AuthProvider? provider,
  ) {
    final Map<String, dynamic> claims = _decodeJwtClaims(idToken);
    final String? userId = (claims['oid'] ?? claims['sub']) as String?;
    final String? name = (claims['name'] ?? claims['preferred_username']) as String?;
    final String? email = (claims['email'] ?? claims['preferred_username']) as String?;
    return AuthSession(
      // L'API valide un jeton porteur ; on privilégie l'access_token et on
      // retombe sur l'id_token si l'IdP n'a pas émis d'access_token séparé.
      accessToken: accessToken ?? idToken ?? '',
      refreshToken: refreshToken,
      idToken: idToken,
      accessTokenExpiry: expiry,
      userId: userId,
      displayName: name,
      email: email,
      provider: provider,
    );
  }

  /// Décodage léger des claims OIDC (payload base64url de l'`id_token`) sans
  /// dépendance externe. La validation de signature est faite côté backend.
  Map<String, dynamic> _decodeJwtClaims(String? token) {
    if (token == null) return const <String, dynamic>{};
    final List<String> parts = token.split('.');
    if (parts.length != 3) return const <String, dynamic>{};
    try {
      final String payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final Object? decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }
}
