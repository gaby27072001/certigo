import 'dart:convert';

/// Fournisseur d'identité présenté à l'utilisateur sur l'écran de connexion.
///
/// Les trois premiers ([microsoft], [google], [apple]) sont fédérés derrière
/// **Microsoft Entra External ID** (modèle « courtier d'identité ») : quel que
/// soit le bouton choisi, Entra émet le même type de jeton OIDC pour notre API.
/// [email] est le mode **e-mail + mot de passe** géré directement par notre
/// backend (jetons signés localement), toujours disponible même sans Entra.
enum AuthProvider { microsoft, google, apple, email }

/// Indice de domaine (`domain_hint`) éventuel transmis à Entra pour pré-router
/// l'utilisateur vers le bon fournisseur fédéré.
extension AuthProviderX on AuthProvider {
  String get id => switch (this) {
        AuthProvider.microsoft => 'microsoft',
        AuthProvider.google => 'google',
        AuthProvider.apple => 'apple',
        AuthProvider.email => 'email',
      };

  static AuthProvider? fromId(String? value) => switch (value) {
        'microsoft' => AuthProvider.microsoft,
        'google' => AuthProvider.google,
        'apple' => AuthProvider.apple,
        'email' => AuthProvider.email,
        _ => null,
      };
}

/// Session authentifiée persistée localement (stockage sécurisé).
///
/// Contient les jetons OIDC et un minimum d'informations de profil décodées
/// depuis l'`id_token`, afin d'afficher le nom/email sans appel réseau.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.accessTokenExpiry,
    this.displayName,
    this.email,
    this.provider,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime? accessTokenExpiry;
  final String? displayName;
  final String? email;
  final AuthProvider? provider;

  /// Marge de sécurité : on rafraîchit le jeton un peu avant son expiration
  /// réelle pour éviter qu'une requête parte avec un jeton tout juste expiré.
  static const Duration _refreshSkew = Duration(minutes: 2);

  bool get isExpired {
    final DateTime? expiry = accessTokenExpiry;
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  bool get willExpireSoon {
    final DateTime? expiry = accessTokenExpiry;
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry.subtract(_refreshSkew));
  }

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? idToken,
    DateTime? accessTokenExpiry,
    String? displayName,
    String? email,
    AuthProvider? provider,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      idToken: idToken ?? this.idToken,
      accessTokenExpiry: accessTokenExpiry ?? this.accessTokenExpiry,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      provider: provider ?? this.provider,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'idToken': idToken,
        'accessTokenExpiry': accessTokenExpiry?.toIso8601String(),
        'displayName': displayName,
        'email': email,
        'provider': provider?.id,
      };

  static AuthSession? fromJson(Map<String, dynamic> json) {
    final Object? token = json['accessToken'];
    if (token is! String || token.isEmpty) return null;
    final Object? expiryRaw = json['accessTokenExpiry'];
    return AuthSession(
      accessToken: token,
      refreshToken: json['refreshToken'] as String?,
      idToken: json['idToken'] as String?,
      accessTokenExpiry: expiryRaw is String ? DateTime.tryParse(expiryRaw) : null,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      provider: AuthProviderX.fromId(json['provider'] as String?),
    );
  }

  String encode() => jsonEncode(toJson());

  static AuthSession? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return fromJson(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// État synchrone exposé à l'application (lu directement par le garde de
/// navigation `redirect` de GoRouter).
sealed class AuthState {
  const AuthState();
}

/// Restauration de session en cours (premier démarrage) → écran de chargement.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Utilisateur connecté → accès au parcours.
class Authenticated extends AuthState {
  const Authenticated(this.session);

  final AuthSession session;
}

/// Aucune session valide → écran de connexion (avec message éventuel).
class Unauthenticated extends AuthState {
  const Unauthenticated([this.message]);

  final String? message;
}
