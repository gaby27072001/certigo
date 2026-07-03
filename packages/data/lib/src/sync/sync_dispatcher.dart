import 'package:core/core.dart';

import 'sync_action.dart';

/// Outcome of attempting to dispatch one [SyncAction].
enum SyncDispatch {
  /// The server accepted (or idempotently de-duplicated) the action.
  success,

  /// Transient problem — keep the action and retry later with backoff.
  retryable,

  /// Permanent problem — the action can never succeed; dead-letter it.
  permanent,
}

/// Sends one action to its destination. Injected into the engine so the pure
/// queue logic never imports HTTP.
typedef SyncSender = Future<SyncDispatch> Function(SyncAction action);

/// Maps a typed [Failure] to a dispatch outcome.
///
/// Pure and exhaustively tested:
/// * Network blips, 5xx and 429 (rate-limit) → transient, retried.
/// * Expired auth → retryable (a later token refresh may unblock it; the
///   engine's max-attempts cap prevents infinite spinning).
/// * Genuine client errors (404, other 4xx, parse/cache contract issues) →
///   permanent, dead-lettered (replaying could never succeed).
/// * Unknown → retryable by default (assume transient, bounded by max-attempts).
SyncDispatch classifyFailure(Failure failure) {
  return switch (failure) {
    NetworkFailure() => SyncDispatch.retryable,
    AuthFailure() => SyncDispatch.retryable,
    ServerFailure(:final int? statusCode) =>
      (statusCode == null || statusCode >= 500 || statusCode == 429)
          ? SyncDispatch.retryable
          : SyncDispatch.permanent,
    NotFoundFailure() => SyncDispatch.permanent,
    ParseFailure() => SyncDispatch.permanent,
    CacheFailure() => SyncDispatch.permanent,
    CatalogEmptyFailure() => SyncDispatch.retryable,
    UnknownFailure() => SyncDispatch.retryable,
  };
}
