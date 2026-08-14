import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/foundation.dart';

import 'auth_gateway.dart';
import 'auth_state.dart';

/// Flux d'authentification **e-mail + mot de passe** géré par notre backend.
///
/// Contrairement à [AuthGateway] (OIDC via Entra), aucune dépendance plateforme
/// n'est requise : tout passe par l'API HTTP. Isolé derrière une interface pour
/// que les tests injectent un faux (le contrôleur ne connaît que ce contrat).
abstract interface class CredentialsGateway {
  /// Crée un compte puis renvoie la session (jetons + profil).
  Future<AuthSession> register({
    required String email,
    required String password,
    String? displayName,
  });

  /// Connecte un compte existant et renvoie la session.
  Future<AuthSession> login({required String email, required String password});

  /// Réémet une session à partir du `refresh_token` local.
  Future<AuthSession> refresh(String refreshToken);

  /// Renvoie l'e-mail de vérification pour un compte non confirmé. Best-effort :
  /// le backend répond toujours de façon générique (aucune énumération de comptes).
  Future<void> resendVerification(String email);
}

/// Implémentation réelle : poste sur les points de terminaison anonymes
/// `auth/register`, `auth/login`, `auth/refresh` de l'API Certigo.
///
/// Utilise un [ApiClient] **sans jeton** (`tokenProvider` nul) : ces appels sont
/// anonymes — c'est précisément eux qui produisent le premier jeton.
class HttpCredentialsGateway implements CredentialsGateway {
  HttpCredentialsGateway({ApiClient? client})
      : _client = client ?? ApiClient(tokenProvider: _noToken, debugLog: debugPrint);

  final ApiClient _client;

  static Future<String?> _noToken() async => null;

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final Result<AuthSession> result = await _client.postJson<AuthSession>(
        '/auth/register',
        <String, dynamic>{
          'email': email,
          'password': password,
          if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
        },
        (Map<String, dynamic> json) => _sessionFrom(json, email: email));
    return _unwrap(result);
  }

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    final Result<AuthSession> result = await _client.postJson<AuthSession>(
      '/auth/login',
      <String, dynamic>{'email': email, 'password': password},
      (Map<String, dynamic> json) => _sessionFrom(json, email: email),
    );
    return _unwrap(result);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    final Result<AuthSession> result = await _client.postJson<AuthSession>(
      '/auth/refresh',
      <String, dynamic>{'refreshToken': refreshToken},
      (Map<String, dynamic> json) => _sessionFrom(json),
    );
    return _unwrap(result);
  }

  @override
  Future<void> resendVerification(String email) async {
    // Le backend répond toujours de façon générique ({message}) ; on ignore le
    // corps et on ne propage pas d'échec bloquant (best-effort).
    await _client.postJson<bool>(
        '/auth/resend-verification',
        <String, dynamic>{
          'email': email,
        },
        (Map<String, dynamic> json) => true);
  }

  /// Convertit l'`AuthResultDto` JSON du backend en [AuthSession] locale.
  /// L'e-mail n'est pas renvoyé par l'API : on conserve celui saisi (best-effort).
  AuthSession _sessionFrom(Map<String, dynamic> json, {String? email}) {
    final Object? profile = json['profile'];
    final String? displayName =
        profile is Map<String, dynamic> ? profile['displayName'] as String? : null;
    final Object? expiryRaw = json['accessTokenExpiresAt'];
    return AuthSession(
      accessToken: (json['accessToken'] as String?) ?? '',
      refreshToken: json['refreshToken'] as String?,
      accessTokenExpiry: expiryRaw is String ? DateTime.tryParse(expiryRaw) : null,
      displayName: displayName,
      email: email,
      provider: AuthProvider.email,
      emailVerified: json['emailVerified'] as bool? ?? true,
    );
  }

  AuthSession _unwrap(Result<AuthSession> result) => result.when(
        success: (AuthSession session) => session,
        failure: (Failure f) {
          final ({String message, AuthFailureCause cause}) described = _describeFor(f);
          throw AuthGatewayException(described.message, cause: described.cause);
        },
      );

  /// Traduit une [Failure] (mappée par [ApiClient] depuis le code HTTP) en
  /// message clair FR **et** en [AuthFailureCause] normalisée. Le backend renvoie
  /// déjà des messages en français ; on reste robuste en se basant sur le code.
  ({String message, AuthFailureCause cause}) _describeFor(Failure failure) {
    if (failure is NetworkFailure) {
      return (
        message: 'Pas de connexion. Vérifiez votre réseau puis réessayez.',
        cause: AuthFailureCause.network,
      );
    }
    if (failure is AuthFailure) {
      return (
        message: 'E-mail ou mot de passe incorrect.',
        cause: AuthFailureCause.invalidCredentials,
      );
    }
    if (failure is ServerFailure) {
      return switch (failure.statusCode) {
        429 => (
            message: 'Trop de tentatives de connexion. Réessayez dans quelques minutes.',
            cause: AuthFailureCause.providerError,
          ),
        409 => (
            message: 'Cette adresse e-mail est déjà utilisée.',
            cause: AuthFailureCause.invalidCredentials,
          ),
        400 => (
            message: 'Vérifiez votre e-mail et un mot de passe d’au moins 8 caractères.',
            cause: AuthFailureCause.invalidCredentials,
          ),
        _ => (
            message: 'Le service est momentanément indisponible. Réessayez.',
            cause: AuthFailureCause.providerError,
          ),
      };
    }
    return (message: 'Une erreur est survenue. Réessayez.', cause: AuthFailureCause.unknown);
  }
}
