import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'auth_diagnostics.dart';
import 'auth_state.dart';

/// Erreur métier remontée au contrôleur pour afficher un message clair.
class AuthGatewayException implements Exception {
  const AuthGatewayException(
    this.message, {
    this.cause = AuthFailureCause.unknown,
    this.diagnostic,
  });

  final String message;

  /// Cause normalisée (pour la télémétrie et le repli de message).
  final AuthFailureCause cause;

  /// Détail technique **brut** de l'erreur sous-jacente (build de diagnostic) :
  /// `code=…/msg=…/details=…` d'une [PlatformException] `flutter_appauth`, ou
  /// `type : toString()` d'une erreur inattendue. Concaténé au message affiché
  /// par le contrôleur afin de révéler la cause réelle à l'écran, sans rien
  /// perdre. `null` pour les cas volontairement propres (ex. annulation).
  final String? diagnostic;

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
  Future<AuthSession> signIn(AuthProvider provider) async {
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
          additionalParameters: _hintFor(provider),
          // Laisse l'utilisateur choisir/ajouter un compte à chaque connexion
          // explicite (utile après une déconnexion).
          promptValues: const <String>['select_account'],
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
    } on FlutterAppAuthUserCancelledException {
      _diagnostics.mark(AuthDiagnosticStep.failed, detail: 'annulé par l\'utilisateur');
      throw const AuthGatewayException('Connexion annulée.', cause: AuthFailureCause.cancelled);
    } on AuthGatewayException {
      // Déjà typée + tracée (ex. code d'autorisation absent) : relayer telle quelle.
      rethrow;
    } on PlatformException catch (e) {
      final ({String message, AuthFailureCause cause}) described = _describeError(e, provider);
      // Annulation : on garde le message propre, sans bruit technique.
      final String? diagnostic =
          described.cause == AuthFailureCause.cancelled ? null : _platformDiagnostic(e);
      _diagnostics.mark(AuthDiagnosticStep.failed, detail: diagnostic ?? described.message);
      throw AuthGatewayException(described.message, cause: described.cause, diagnostic: diagnostic);
    } catch (e) {
      // Erreur inattendue (non PlatformException) : on ne l'avale pas, on
      // remonte son type + toString() pour diagnostic à l'écran.
      _diagnostics.mark(AuthDiagnosticStep.failed, detail: '${e.runtimeType} : $e');
      throw AuthGatewayException(
        'La connexion via ${provider.id} a échoué. Vérifiez la configuration Entra puis réessayez.',
        cause: AuthFailureCause.providerError,
        diagnostic: '${e.runtimeType} : $e',
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
      final ({String message, AuthFailureCause cause}) described = _describeError(
        e,
        AuthProvider.microsoft,
      );
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
    // du fournisseur (expérience moins brutale). `select_account` à la
    // prochaine connexion permet de changer de compte.
    return;
  }

  /// Retourne les paramètres additionnels OIDC pour pré-sélectionner
  /// le fournisseur d'identité dans Entra External ID.
  ///
  /// `domain_hint=microsoft.com` achemine vers le fournisseur Microsoft
  /// Account du locataire CIAM, qui supporte à la fois les comptes
  /// personnels MSA et les comptes Azure AD professionnels.
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
      final String payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final Object? decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }
}
