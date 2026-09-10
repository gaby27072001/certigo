/// Typed failures that flow through `Result<T>`.
///
/// Each failure carries a stable [code] (useful for analytics + localized
/// messages) and a human [message]. UI maps codes to friendly copy; we never
/// surface raw exception strings to learners.
sealed class Failure {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'Failure(${code ?? runtimeType}, $message)';
}

/// Pourquoi une requête a échoué au niveau du transport.
///
/// Ces trois cas étaient auparavant confondus en un seul [NetworkFailure], ce
/// qui faisait afficher « vérifiez votre réseau » à un utilisateur dont la
/// connexion venait précisément d'aboutir. La distinction existe côté client
/// HTTP ; elle est conservée jusqu'à l'interface.
enum NetworkFailureKind {
  /// Aucune connexion n'a pu être établie : hors ligne, DNS, pas de route.
  /// C'est le seul cas où demander à l'utilisateur de vérifier son réseau est
  /// justifié.
  unreachable,

  /// La connexion n'a pas pu être établie dans le délai imparti. La cause est
  /// **ambiguë** — réseau lent ou serveur injoignable — et ne doit être
  /// imputée à aucun des deux.
  connectTimeout,

  /// Connexion établie, puis silence du serveur au-delà du délai imparti.
  /// **Le réseau a prouvé qu'il fonctionne** : ne jamais demander de le
  /// vérifier ici.
  responseTimeout,
}

/// No connectivity / request timed out. UI offers a retry and offline content.
///
/// [kind] précise laquelle des trois causes s'est produite, sans changer le
/// type : tout code qui teste `is NetworkFailure` ou qui filtre sur le code
/// `network` continue de se comporter à l'identique.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Connexion indisponible'])
      : kind = NetworkFailureKind.unreachable,
        super(code: 'network');

  /// Délai dépassé avant d'avoir pu établir la connexion.
  const NetworkFailure.connectTimeout([super.message = 'Connexion indisponible'])
      : kind = NetworkFailureKind.connectTimeout,
        super(code: 'network');

  /// Connexion établie, mais le serveur n'a pas répondu à temps.
  const NetworkFailure.responseTimeout([super.message = 'Connexion indisponible'])
      : kind = NetworkFailureKind.responseTimeout,
        super(code: 'network');

  final NetworkFailureKind kind;
}

/// Server responded with an error status (5xx, or unexpected 4xx).
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode}) : super(code: 'server');
  final int? statusCode;
}

/// Authentication/authorization problem — token expired or missing.
final class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Session expirée']) : super(code: 'auth');
}

/// Requested resource not found.
final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Introuvable']) : super(code: 'not_found');
}

/// Local cache miss (used to fall back to remote).
final class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Données locales indisponibles']) : super(code: 'cache');
}

/// Data could not be parsed / mapped — a contract mismatch bug.
final class ParseFailure extends Failure {
  const ParseFailure([super.message = 'Réponse inattendue']) : super(code: 'parse');
}

/// Anything we did not anticipate.
final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Une erreur est survenue']) : super(code: 'unknown');
}

/// Catalog was reachable but returned no tracks — backend likely not seeded yet.
/// UI should surface an actionable message instead of silently showing an empty list.
final class CatalogEmptyFailure extends Failure {
  const CatalogEmptyFailure([super.message = 'Aucune certification disponible'])
      : super(code: 'catalog_empty');
}
