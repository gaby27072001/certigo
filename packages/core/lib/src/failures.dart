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

/// No connectivity / request timed out. UI offers a retry and offline content.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Connexion indisponible']) : super(code: 'network');
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
