/// Content-free telemetry for runtime content synchronization.
///
/// Events carry only normalized outcomes, stages, counters, durations and the
/// public manifest identity (a content hash, never personal data). They never
/// carry the owner, file identifiers, paths, URLs, payload bytes or exception
/// messages, so a sink cannot leak study content, answers or who studied what.
library;

import 'package:core/core.dart';

/// How one synchronization attempt ended.
enum RuntimeContentSyncOutcome {
  /// The active release already matched the server (304 or same manifest).
  unchanged,

  /// A new release was downloaded (at least one file) and atomically activated.
  activated,

  /// A new release was activated entirely from bytes already on the device.
  activatedFromCache,

  /// The attempt failed; the previous activation, if any, stays in use.
  failed,
}

/// Where a failed attempt stopped. Coarse on purpose: enough to route an
/// incident, not enough to describe the content involved.
enum RuntimeContentFailureStage { localCache, manifest, download, validation, storage, activation }

/// One finished synchronization attempt.
class RuntimeContentSyncEvent {
  const RuntimeContentSyncEvent({
    required this.outcome,
    required this.durationMs,
    this.failureStage,
    this.failureKind,
    this.downloadedFiles = 0,
    this.reusedFiles = 0,
    this.totalFiles = 0,
    this.activeManifestId,
    this.recoveredIncompleteActivation = false,
    this.canRollback = false,
  });

  final RuntimeContentSyncOutcome outcome;
  final int durationMs;
  final RuntimeContentFailureStage? failureStage;

  /// Type name of the normalized failure (for example `NetworkFailure`), never
  /// its message.
  final String? failureKind;
  final int downloadedFiles;
  final int reusedFiles;
  final int totalFiles;

  /// Public manifest identity active after the attempt (`sha256:…`).
  final String? activeManifestId;
  final bool recoveredIncompleteActivation;
  final bool canRollback;

  /// The exact, allow-listed shape a sink may forward.
  Map<String, Object?> toMap() => <String, Object?>{
        'outcome': outcome.name,
        'durationMs': durationMs,
        'failureStage': failureStage?.name,
        'failureKind': failureKind,
        'downloadedFiles': downloadedFiles,
        'reusedFiles': reusedFiles,
        'totalFiles': totalFiles,
        'activeManifestId': activeManifestId,
        'recoveredIncompleteActivation': recoveredIncompleteActivation,
        'canRollback': canRollback,
      };
}

/// One local rollback to the previous valid release.
class RuntimeContentRollbackEvent {
  const RuntimeContentRollbackEvent({
    required this.restored,
    required this.durationMs,
    this.activeManifestId,
    this.failureKind,
  });

  final bool restored;
  final int durationMs;
  final String? activeManifestId;
  final String? failureKind;

  Map<String, Object?> toMap() => <String, Object?>{
        'restored': restored,
        'durationMs': durationMs,
        'activeManifestId': activeManifestId,
        'failureKind': failureKind,
      };
}

/// Sink for runtime content telemetry. Implementations must forward only
/// [RuntimeContentSyncEvent.toMap] / [RuntimeContentRollbackEvent.toMap].
abstract interface class RuntimeContentTelemetry {
  void syncFinished(RuntimeContentSyncEvent event);

  void rollbackFinished(RuntimeContentRollbackEvent event);
}

/// Stable label of a normalized failure: its analytics [Failure.code], never
/// its message.
String runtimeContentFailureKind(Failure failure) => failure.code ?? 'unknown';

/// Default sink: records nothing, so no data leaves the device by default.
class NoopRuntimeContentTelemetry implements RuntimeContentTelemetry {
  const NoopRuntimeContentTelemetry();

  @override
  void syncFinished(RuntimeContentSyncEvent event) {}

  @override
  void rollbackFinished(RuntimeContentRollbackEvent event) {}
}
