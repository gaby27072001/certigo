import 'dart:convert';

/// Fournisseur d'identité présenté à l'utilisateur sur l'écran de connexion.
///
/// Les trois premiers ([microsoft], [google], [apple]) sont fédérés derrière
/// **Microsoft Entra External ID** (modèle « courtier d'identité ») : quel que
/// soit le bouton choisi, Entra émet le même type de jeton OIDC pour notre API.
/// [email] est le mode **e-mail + mot de passe** géré directement par notre
/// backend (jetons signés localement), toujours disponible même sans Entra.
enum AuthProvider { microsoft, google, apple, email }

/// Cause **normalisée** d'un échec d'authentification.
///
/// Source unique de vérité partagée par les deux passerelles (e-mail via
/// [credentials_gateway] et social via [auth_gateway]) : chaque couche traduit
/// son erreur technique vers l'une de ces causes, ce qui permet (1) un message
/// utilisateur cohérent via [authMessageForCause] et (2) une télémétrie sans
/// donnée sensible. Aucune donnée personnelle n'est portée ici.
enum AuthFailureCause {
  /// L'utilisateur a annulé (fermeture du navigateur, bouton retour).
  cancelled,

  /// Délai dépassé (réseau lent, navigateur laissé ouvert…).
  timeout,

  /// Pas de connectivité / requête réseau échouée.
  network,

  /// Le fournisseur (Entra/IdP fédéré) a refusé ou n'est pas disponible.
  providerError,

  /// Identifiants e-mail/mot de passe invalides.
  invalidCredentials,

  /// Configuration d'authentification absente ou incohérente.
  configError,

  /// Cause non catégorisée.
  unknown,
}

/// Message utilisateur FR par défaut pour une [AuthFailureCause].
///
/// Les passerelles peuvent fournir un message plus spécifique (ex. redirection
/// invalide) tout en taguant la même cause ; ceci est le repli normalisé.
String authMessageForCause(AuthFailureCause cause) => switch (cause) {
      AuthFailureCause.cancelled => 'Connexion annulée.',
      AuthFailureCause.timeout => 'La connexion a expiré. Réessayez.',
      AuthFailureCause.network => 'Pas de connexion. Vérifiez votre réseau puis réessayez.',
      AuthFailureCause.providerError => 'La connexion a échoué. Réessayez.',
      AuthFailureCause.invalidCredentials => 'E-mail ou mot de passe incorrect.',
      AuthFailureCause.configError =>
        'Configuration d\'authentification invalide. Contactez le support.',
      AuthFailureCause.unknown => 'Une erreur est survenue. Réessayez.',
    };

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
    this.userId,
    this.displayName,
    this.email,
    this.provider,
    this.emailVerified = true,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime? accessTokenExpiry;
  final String? userId;
  final String? displayName;
  final String? email;
  final AuthProvider? provider;

  /// Whether the backend considers this account's e-mail confirmed. Defaults to
  /// `true` so social/Entra sessions and pre-feature accounts are never nagged;
  /// only a freshly-registered, unconfirmed email/password account is `false`.
  final bool emailVerified;

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
    String? userId,
    String? displayName,
    String? email,
    AuthProvider? provider,
    bool? emailVerified,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      idToken: idToken ?? this.idToken,
      accessTokenExpiry: accessTokenExpiry ?? this.accessTokenExpiry,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      provider: provider ?? this.provider,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'idToken': idToken,
        'accessTokenExpiry': accessTokenExpiry?.toIso8601String(),
        'userId': userId,
        'displayName': displayName,
        'email': email,
        'provider': provider?.id,
        'emailVerified': emailVerified,
      };

  static AuthSession? fromJson(Map<String, dynamic> json) {
    final Object? token = json['accessToken'];
    if (token is! String || token.isEmpty) return null;
    final Object? expiryRaw = json['accessTokenExpiry'];
    final String? idToken = json['idToken'] as String?;
    return AuthSession(
      accessToken: token,
      refreshToken: json['refreshToken'] as String?,
      idToken: idToken,
      accessTokenExpiry: expiryRaw is String ? DateTime.tryParse(expiryRaw) : null,
      userId: json['userId'] as String? ?? _decodeUserId(idToken) ?? _decodeUserId(token),
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      provider: AuthProviderX.fromId(json['provider'] as String?),
      emailVerified: json['emailVerified'] as bool? ?? true,
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

  static String? _decodeUserId(String? token) {
    if (token == null) return null;
    final List<String> parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final String normalized = base64Url.normalize(parts[1]);
      final Object? payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is! Map<String, dynamic>) return null;
      final Object? userId = payload['oid'] ?? payload['sub'];
      return userId is String && userId.isNotEmpty ? userId : null;
    } on FormatException {
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

class AuthSigningOut extends AuthState {
  const AuthSigningOut();
}

/// Utilisateur connecté → accès au parcours.
class Authenticated extends AuthState {
  const Authenticated(this.session);

  final AuthSession session;
}

/// Aucune session valide → écran de connexion (avec message éventuel).
class Unauthenticated extends AuthState {
  const Unauthenticated([this.message]) : clearLocalAccountData = false;

  const Unauthenticated.signedOut([this.message]) : clearLocalAccountData = true;

  final String? message;
  final bool clearLocalAccountData;
}
