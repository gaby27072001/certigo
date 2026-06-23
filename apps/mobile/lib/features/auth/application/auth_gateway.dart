import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

import 'auth_state.dart';

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
  AppAuthGateway({FlutterAppAuth? appAuth}) : _appAuth = appAuth ?? const FlutterAppAuth();

  final FlutterAppAuth _appAuth;

  List<String> get _scopes => <String>[
        ...AppEnv.entraScopes,
        if (AppEnv.entraApiScope.isNotEmpty) AppEnv.entraApiScope,
      ];

  @override
  Future<AuthSession> signIn(AuthProvider provider) async {
    final AuthorizationTokenResponse result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        AppEnv.entraClientId,
        AppEnv.entraRedirectUri,
        issuer: AppEnv.entraAuthority,
        scopes: _scopes,
        additionalParameters: _hintFor(provider),
        // Laisse l'utilisateur choisir/ajouter un compte à chaque connexion
        // explicite (utile après une déconnexion).
        promptValues: const <String>['select_account'],
      ),
    );
    return _toSession(
      result.accessToken,
      result.refreshToken,
      result.idToken,
      result.accessTokenExpirationDateTime,
      provider,
    );
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
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
  }

  @override
  Future<void> signOut(AuthSession session) async {
    // Déconnexion locale : on n'ouvre pas le navigateur pour fermer la session
    // du fournisseur (expérience moins brutale). `select_account` à la
    // prochaine connexion permet de changer de compte.
    return;
  }

  Map<String, String>? _hintFor(AuthProvider provider) {
    final String hint = switch (provider) {
      AuthProvider.microsoft => AppEnv.microsoftDomainHint,
      AuthProvider.google => AppEnv.googleDomainHint,
      AuthProvider.apple => AppEnv.appleDomainHint,
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
    final String? name = (claims['name'] ?? claims['preferred_username']) as String?;
    final String? email = (claims['email'] ?? claims['preferred_username']) as String?;
    return AuthSession(
      // L'API valide un jeton porteur ; on privilégie l'access_token et on
      // retombe sur l'id_token si l'IdP n'a pas émis d'access_token séparé.
      accessToken: accessToken ?? idToken ?? '',
      refreshToken: refreshToken,
      idToken: idToken,
      accessTokenExpiry: expiry,
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
