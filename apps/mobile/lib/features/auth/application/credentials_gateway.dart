import 'package:core/core.dart';
import 'package:data/data.dart';

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
  Future<AuthSession> login({
    required String email,
    required String password,
  });

  /// Réémet une session à partir du `refresh_token` local.
  Future<AuthSession> refresh(String refreshToken);
}

/// Implémentation réelle : poste sur les points de terminaison anonymes
/// `auth/register`, `auth/login`, `auth/refresh` de l'API Microlingo.
///
/// Utilise un [ApiClient] **sans jeton** (`tokenProvider` nul) : ces appels sont
/// anonymes — c'est précisément eux qui produisent le premier jeton.
class HttpCredentialsGateway implements CredentialsGateway {
  HttpCredentialsGateway({ApiClient? client})
      : _client = client ?? ApiClient(tokenProvider: _noToken);

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
      (Map<String, dynamic> json) => _sessionFrom(json, email: email),
    );
    return _unwrap(result);
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
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
    );
  }

  AuthSession _unwrap(Result<AuthSession> result) => result.when(
        success: (AuthSession session) => session,
        failure: (Failure f) => throw AuthGatewayException(_messageFor(f)),
      );

  /// Traduit une [Failure] (mappée par [ApiClient] depuis le code HTTP) en
  /// message clair et localisé. Le backend renvoie déjà des messages en
  /// français, mais on reste robuste en se basant aussi sur le code.
  String _messageFor(Failure failure) {
    if (failure is NetworkFailure) {
      return 'Pas de connexion. Vérifiez votre réseau puis réessayez.';
    }
    if (failure is AuthFailure) {
      return 'E-mail ou mot de passe incorrect.';
    }
    if (failure is ServerFailure) {
      return switch (failure.statusCode) {
        409 => 'Cette adresse e-mail est déjà utilisée.',
        400 => 'Vérifiez votre e-mail et un mot de passe d’au moins 8 caractères.',
        _ => 'Le service est momentanément indisponible. Réessayez.',
      };
    }
    return 'Une erreur est survenue. Réessayez.';
  }
}
