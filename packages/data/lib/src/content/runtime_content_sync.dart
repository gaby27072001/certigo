import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';

import '../sync/sync_dispatcher.dart';
import 'runtime_content.dart';
import 'runtime_content_store.dart';
import 'runtime_content_telemetry.dart';

enum RuntimeContentPhase { idle, checking, downloading, activating, ready, rolledBack, failed }

class RuntimeContentStatus {
  const RuntimeContentStatus({
    required this.phase,
    this.completedFiles = 0,
    this.totalFiles = 0,
    this.activeManifestId,
    this.message,
    this.canRollback = false,
  });

  const RuntimeContentStatus.idle() : this(phase: RuntimeContentPhase.idle);

  final RuntimeContentPhase phase;
  final int completedFiles;
  final int totalFiles;
  final String? activeManifestId;
  final String? message;
  final bool canRollback;

  double? get progress => totalFiles == 0 ? null : completedFiles / totalFiles;
}

class RuntimeContentSyncReport {
  const RuntimeContentSyncReport({
    required this.changed,
    required this.downloadedFiles,
    required this.reusedFiles,
    required this.activation,
  });

  final bool changed;
  final int downloadedFiles;
  final int reusedFiles;
  final RuntimeContentActivation activation;
}

class RuntimeContentSyncException implements Exception {
  const RuntimeContentSyncException(this.message, {this.failure});

  final String message;
  final Failure? failure;

  @override
  String toString() => 'RuntimeContentSyncException($message)';
}

class RuntimeContentPinRegistry {
  final Map<String, Map<String?, int>> _pins = <String, Map<String?, int>>{};

  Set<String> get manifestIds => Set<String>.unmodifiable(_pins.keys);

  RuntimeContentPin pin(String? publicManifestId, {String? ownerId}) {
    if (publicManifestId == null || publicManifestId.isEmpty) {
      return RuntimeContentPin._();
    }
    final String? ownerScope = ownerId == null ? null : runtimeContentScopeKey(ownerId);
    final Map<String?, int> owners = _pins.putIfAbsent(
      publicManifestId,
      () => <String?, int>{},
    );
    owners.update(ownerScope, (int count) => count + 1, ifAbsent: () => 1);
    return RuntimeContentPin._(() {
      final Map<String?, int>? currentOwners = _pins[publicManifestId];
      final int count = currentOwners?[ownerScope] ?? 0;
      if (count <= 1) {
        currentOwners?.remove(ownerScope);
      } else {
        currentOwners![ownerScope] = count - 1;
      }
      if (currentOwners?.isEmpty ?? false) _pins.remove(publicManifestId);
    });
  }

  void releaseOwner(String ownerId) {
    final String ownerScope = runtimeContentScopeKey(ownerId);
    _pins.removeWhere((String _, Map<String?, int> owners) {
      owners.remove(ownerScope);
      return owners.isEmpty;
    });
  }
}

class RuntimeContentPersonPurger {
  const RuntimeContentPersonPurger({
    required RuntimeContentStore store,
    required RuntimeContentPinRegistry pins,
  })  : _store = store,
        _pins = pins;

  final RuntimeContentStore _store;
  final RuntimeContentPinRegistry _pins;

  Future<void> purge({
    required String personId,
    required bool serverConfirmed,
  }) async {
    if (!serverConfirmed) {
      throw StateError('Runtime content can only be purged after server confirmation.');
    }
    final String normalized = personId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(personId, 'personId', 'A person id is required.');
    }
    await _store.purgePerson(runtimeContentScopeKey(normalized));
    _pins.releaseOwner(normalized);
  }
}

class RuntimeContentPin {
  RuntimeContentPin._([this._release]);

  final void Function()? _release;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _release?.call();
  }
}

class RuntimeContentSynchronizer {
  RuntimeContentSynchronizer({
    required PublicContentSource source,
    required RuntimeContentStore store,
    RuntimeContentPinRegistry? pins,
    this.limits = const RuntimeContentLimits(),
    Future<void> Function(Duration duration)? delay,
    RuntimeContentTelemetry telemetry = const NoopRuntimeContentTelemetry(),
  })  : _source = source,
        _store = store,
        _pins = pins,
        _delay = delay ?? Future<void>.delayed,
        _telemetry = telemetry;

  final PublicContentSource _source;
  final RuntimeContentStore _store;
  final RuntimeContentPinRegistry? _pins;
  final RuntimeContentLimits limits;
  final Future<void> Function(Duration duration) _delay;
  final RuntimeContentTelemetry _telemetry;
  final StreamController<RuntimeContentStatus> _statuses =
      StreamController<RuntimeContentStatus>.broadcast();

  RuntimeContentStatus _current = const RuntimeContentStatus.idle();
  Future<RuntimeContentSyncReport>? _inFlight;
  Future<RuntimeContentActivation?>? _inFlightRollback;
  String? _inFlightRollbackOwnerId;
  Future<void> _operationTail = Future<void>.value();
  String? _inFlightOwnerId;
  Set<String> _inFlightPins = <String>{};
  final Map<String, int> _pendingPins = <String, int>{};
  bool _disposed = false;

  RuntimeContentStatus get currentStatus => _current;
  Stream<RuntimeContentStatus> get statuses => _statuses.stream;

  Future<RuntimeContentSyncReport> sync({
    required String ownerId,
    Set<String> pinnedManifestIds = const <String>{},
  }) {
    if (_disposed) throw StateError('Runtime content synchronizer has been disposed.');
    final Set<String> requestedPins = Set<String>.unmodifiable(pinnedManifestIds);
    final Future<RuntimeContentSyncReport>? running = _inFlight;
    if (running != null) {
      if (_inFlightOwnerId == ownerId && requestedPins.difference(_inFlightPins).isEmpty) {
        return running;
      }
    }
    _inFlightRollback = null;
    _inFlightRollbackOwnerId = null;
    _inFlightOwnerId = ownerId;
    _inFlightPins = requestedPins;
    _retainPendingPins(requestedPins);
    late final Future<RuntimeContentSyncReport> operation;
    operation = _enqueueOperation(
      () => _sync(
        ownerScope: runtimeContentScopeKey(ownerId),
        pinnedManifestIds: requestedPins,
      ),
    );
    _inFlight = operation;
    unawaited(
      operation.then<void>(
        (_) {
          _releasePendingPins(requestedPins);
          _clearInFlight(operation);
        },
        onError: (Object _, StackTrace __) {
          _releasePendingPins(requestedPins);
          _clearInFlight(operation);
        },
      ),
    );
    return operation;
  }

  Future<RuntimeContentActivation?> rollback({required String ownerId}) {
    if (_disposed) throw StateError('Runtime content synchronizer has been disposed.');
    final Future<RuntimeContentActivation?>? running = _inFlightRollback;
    if (running != null && _inFlightRollbackOwnerId == ownerId) return running;
    _inFlight = null;
    _inFlightOwnerId = null;
    _inFlightPins = <String>{};
    late final Future<RuntimeContentActivation?> operation;
    operation = _enqueueOperation(() => _rollback(ownerId));
    _inFlightRollback = operation;
    _inFlightRollbackOwnerId = ownerId;
    unawaited(
      operation.then<void>(
        (_) => _clearInFlightRollback(operation),
        onError: (Object _, StackTrace __) => _clearInFlightRollback(operation),
      ),
    );
    return operation;
  }

  Future<RuntimeContentActivation?> _rollback(String ownerId) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final RuntimeContentActivation? activation = await _store.rollback(
        runtimeContentScopeKey(ownerId),
      );
      _telemetry.rollbackFinished(
        RuntimeContentRollbackEvent(
          restored: activation != null,
          durationMs: stopwatch.elapsedMilliseconds,
          activeManifestId: activation?.activeManifestId,
        ),
      );
      if (activation != null) {
        _emit(
          RuntimeContentStatus(
            phase: RuntimeContentPhase.rolledBack,
            activeManifestId: activation.activeManifestId,
            message: 'La dernière version valide du contenu a été restaurée.',
          ),
        );
      }
      return activation;
    } on FileSystemException catch (error) {
      _reportRollbackFailure(stopwatch, 'storage');
      _failed(
        'La version précédente du contenu n\'a pas pu être restaurée.',
        _current.activeManifestId,
        canRollback: true,
      );
      throw RuntimeContentSyncException(error.message);
    } on FormatException catch (error) {
      _reportRollbackFailure(stopwatch, 'invalidContent');
      _failed(
        'La version précédente du contenu est invalide.',
        _current.activeManifestId,
        canRollback: false,
      );
      throw RuntimeContentSyncException(error.message);
    } on StateError catch (error) {
      _reportRollbackFailure(stopwatch, 'state');
      _failed(
        'La version précédente du contenu n\'a pas pu être restaurée.',
        _current.activeManifestId,
        canRollback: true,
      );
      throw RuntimeContentSyncException(error.message);
    }
  }

  void _reportRollbackFailure(Stopwatch stopwatch, String failureKind) {
    _telemetry.rollbackFinished(
      RuntimeContentRollbackEvent(
        restored: false,
        durationMs: stopwatch.elapsedMilliseconds,
        activeManifestId: _current.activeManifestId,
        failureKind: failureKind,
      ),
    );
  }

  Future<T> _enqueueOperation<T>(Future<T> Function() operation) {
    final Future<T> current = _operationTail.then<T>((_) => operation());
    _operationTail = current.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return current;
  }

  void _clearInFlight(Future<RuntimeContentSyncReport> operation) {
    if (!identical(_inFlight, operation)) return;
    _inFlight = null;
    _inFlightOwnerId = null;
    _inFlightPins = <String>{};
  }

  void _clearInFlightRollback(Future<RuntimeContentActivation?> operation) {
    if (identical(_inFlightRollback, operation)) {
      _inFlightRollback = null;
      _inFlightRollbackOwnerId = null;
    }
  }

  Future<RuntimeContentSyncReport> _sync({
    required String ownerScope,
    required Set<String> pinnedManifestIds,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final _SyncProgress progress = _SyncProgress();
    try {
      final RuntimeContentSyncReport report = await _syncOnce(
        ownerScope: ownerScope,
        pinnedManifestIds: pinnedManifestIds,
        progress: progress,
      );
      _telemetry.syncFinished(
        RuntimeContentSyncEvent(
          outcome: !report.changed
              ? RuntimeContentSyncOutcome.unchanged
              : report.downloadedFiles > 0
                  ? RuntimeContentSyncOutcome.activated
                  : RuntimeContentSyncOutcome.activatedFromCache,
          durationMs: stopwatch.elapsedMilliseconds,
          downloadedFiles: report.downloadedFiles,
          reusedFiles: report.reusedFiles,
          totalFiles: progress.totalFiles,
          activeManifestId: report.activation.activeManifestId,
          recoveredIncompleteActivation: progress.recovered,
          canRollback: report.activation.previousManifestId != null,
        ),
      );
      return report;
    } on RuntimeContentSyncException catch (error) {
      final Failure? failure = error.failure;
      _telemetry.syncFinished(
        RuntimeContentSyncEvent(
          outcome: RuntimeContentSyncOutcome.failed,
          durationMs: stopwatch.elapsedMilliseconds,
          failureStage: progress.failureStage ?? progress.stage,
          failureKind: failure == null ? progress.failureKind : runtimeContentFailureKind(failure),
          downloadedFiles: progress.downloaded,
          reusedFiles: progress.reused,
          totalFiles: progress.totalFiles,
          activeManifestId: _current.activeManifestId,
          recoveredIncompleteActivation: progress.recovered,
          canRollback: _current.canRollback,
        ),
      );
      rethrow;
    }
  }

  Future<RuntimeContentSyncReport> _syncOnce({
    required String ownerScope,
    required Set<String> pinnedManifestIds,
    required _SyncProgress progress,
  }) async {
    RuntimeContentActivation? activation;
    try {
      activation = await _store.readActivation(ownerScope);
    } on FormatException catch (error) {
      progress.failureKind = 'invalidContent';
      _failed(
        'Le cache local du contenu est invalide.',
        null,
        canRollback: false,
      );
      throw RuntimeContentSyncException(error.message);
    } on FileSystemException catch (error) {
      progress.failureKind = 'storage';
      _failed(
        'Le cache local du contenu est indisponible.',
        null,
        canRollback: false,
      );
      throw RuntimeContentSyncException(error.message);
    } on StateError catch (error) {
      progress.failureKind = 'state';
      _failed(
        'Le cache local du contenu est indisponible.',
        null,
        canRollback: false,
      );
      throw RuntimeContentSyncException(error.message);
    }
    if (activation?.recovered ?? false) {
      progress.recovered = true;
      _emit(
        RuntimeContentStatus(
          phase: RuntimeContentPhase.rolledBack,
          activeManifestId: activation!.activeManifestId,
          message: 'Une mise à jour incomplète a été annulée.',
        ),
      );
    }
    _emit(
      RuntimeContentStatus(
        phase: RuntimeContentPhase.checking,
        activeManifestId: activation?.activeManifestId,
      ),
    );

    progress.stage = RuntimeContentFailureStage.manifest;
    try {
      final PublicManifestFetch fetched = await _retry<PublicManifestFetch>(
        () => _source.fetchActiveManifest(ifNoneMatch: activation?.etag, limits: limits),
      );
      if (fetched.notModified) {
        if (activation == null) {
          throw const RuntimeContentSyncException('Le serveur a répondu 304 sans cache actif.');
        }
        if (fetched.etag != activation.etag ||
            fetched.publicManifestId != activation.activeManifestId ||
            fetched.releaseId == null) {
          throw const FormatException('La réponse 304 ne correspond pas au cache actif.');
        }
        if (activation.activeReleaseId == null) {
          final PublicContentManifest? cached = await _store.readActiveManifest(ownerScope);
          if (cached == null || cached.manifestId != fetched.publicManifestId) {
            throw const FormatException('Le cache actif ne correspond pas à la réponse 304.');
          }
          activation = await _store.activate(
            ownerScope: ownerScope,
            manifest: cached.withReleaseId(fetched.releaseId!),
            etag: fetched.etag,
          );
        } else if (fetched.releaseId != activation.activeReleaseId) {
          throw const FormatException('Le manifeste public est déjà lié à une autre version.');
        }
        await _store.cleanup(
          ownerScope: ownerScope,
          protectedManifestIds: _protectedManifestIds(pinnedManifestIds),
        );
        _emit(
          RuntimeContentStatus(
            phase: RuntimeContentPhase.ready,
            activeManifestId: activation.activeManifestId,
          ),
        );
        return RuntimeContentSyncReport(
          changed: false,
          downloadedFiles: 0,
          reusedFiles: 0,
          activation: activation,
        );
      }

      final PublicContentManifest? fetchedManifest = fetched.manifest;
      if (fetchedManifest == null ||
          fetchedManifest.releaseId == null ||
          fetched.releaseId != fetchedManifest.releaseId ||
          fetched.publicManifestId != fetchedManifest.manifestId) {
        throw const FormatException('Les identifiants de la version publique sont invalides.');
      }
      final PublicContentManifest manifest = fetchedManifest;
      final String etag = fetched.etag;
      progress.totalFiles = manifest.files.length;
      if (activation?.activeManifestId == manifest.manifestId) {
        if (activation!.activeReleaseId == null) {
          activation = await _store.activate(
            ownerScope: ownerScope,
            manifest: manifest,
            etag: etag,
          );
        } else if (activation.activeReleaseId != manifest.releaseId) {
          throw const FormatException('Le manifeste public actif est associé à une autre version.');
        }
        _emit(
          RuntimeContentStatus(
            phase: RuntimeContentPhase.ready,
            activeManifestId: activation.activeManifestId,
          ),
        );
        return RuntimeContentSyncReport(
          changed: false,
          downloadedFiles: 0,
          reusedFiles: manifest.files.length,
          activation: activation,
        );
      }
      if (await _store.hasCompleteRelease(manifest)) {
        progress.stage = RuntimeContentFailureStage.activation;
        activation = await _store.activate(
          ownerScope: ownerScope,
          manifest: manifest,
          etag: etag,
        );
        await _store.cleanup(
          ownerScope: ownerScope,
          protectedManifestIds: _protectedManifestIds(<String>{
            ...pinnedManifestIds,
            activation.activeManifestId,
            if (activation.previousManifestId != null) activation.previousManifestId!,
          }),
        );
        _emit(
          RuntimeContentStatus(
            phase: RuntimeContentPhase.ready,
            completedFiles: manifest.files.length,
            totalFiles: manifest.files.length,
            activeManifestId: activation.activeManifestId,
          ),
        );
        return RuntimeContentSyncReport(
          changed: true,
          downloadedFiles: 0,
          reusedFiles: manifest.files.length,
          activation: activation,
        );
      }

      progress.stage = RuntimeContentFailureStage.download;
      await _store.ensureCapacity(
        ownerScope: ownerScope,
        target: manifest,
        protectedManifestIds: _protectedManifestIds(pinnedManifestIds),
      );
      await _store.prepare(manifest);

      var downloaded = 0;
      var reused = 0;
      var completed = 0;
      for (final PublicContentFile file in manifest.files) {
        Uint8List? bytes = await _store.readStagedFile(manifest, file);
        if (!_isValid(file, bytes)) {
          bytes = await _reuseFile(activation, file);
          if (_isValid(file, bytes)) {
            await _store.writeStagedFile(manifest, file, bytes!);
            reused++;
          } else {
            final PublicContentFileFetch response = await _retry<PublicContentFileFetch>(
              () => _source.fetchFile(
                releaseId: manifest.releaseId!,
                publicManifestId: manifest.manifestId,
                file: file,
              ),
            );
            final Uint8List? downloadedBytes = response.bytes;
            if (response.notModified ||
                downloadedBytes == null ||
                response.releaseId != manifest.releaseId ||
                response.publicManifestId != manifest.manifestId ||
                response.resourceType != file.resourceType ||
                response.etag != '"sha256:${file.hash}"') {
              throw const FormatException('La réponse du fichier public est incohérente.');
            }
            validatePublicContentPayload(file, downloadedBytes);
            await _store.writeStagedFile(manifest, file, downloadedBytes);
            downloaded++;
          }
        } else {
          reused++;
        }
        completed++;
        progress
          ..downloaded = downloaded
          ..reused = reused;
        _emit(
          RuntimeContentStatus(
            phase: RuntimeContentPhase.downloading,
            completedFiles: completed,
            totalFiles: manifest.files.length,
            activeManifestId: activation?.activeManifestId,
          ),
        );
      }

      _emit(
        RuntimeContentStatus(
          phase: RuntimeContentPhase.activating,
          completedFiles: completed,
          totalFiles: manifest.files.length,
          activeManifestId: activation?.activeManifestId,
        ),
      );
      progress.stage = RuntimeContentFailureStage.activation;
      activation = await _store.activate(ownerScope: ownerScope, manifest: manifest, etag: etag);
      await _store.cleanup(
        ownerScope: ownerScope,
        protectedManifestIds: _protectedManifestIds(<String>{
          ...pinnedManifestIds,
          activation.activeManifestId,
          if (activation.previousManifestId != null) activation.previousManifestId!,
        }),
      );
      _emit(
        RuntimeContentStatus(
          phase: RuntimeContentPhase.ready,
          completedFiles: completed,
          totalFiles: manifest.files.length,
          activeManifestId: activation.activeManifestId,
        ),
      );
      return RuntimeContentSyncReport(
        changed: true,
        downloadedFiles: downloaded,
        reusedFiles: reused,
        activation: activation,
      );
    } on RuntimeContentSyncException catch (error) {
      _failed(
        error.message,
        activation?.activeManifestId,
        canRollback: activation?.previousManifestId != null,
      );
      rethrow;
    } on FormatException catch (error) {
      progress
        ..failureStage = RuntimeContentFailureStage.validation
        ..failureKind = 'invalidContent';
      _failed(
        'Le contenu téléchargé est invalide.',
        activation?.activeManifestId,
        canRollback: activation?.previousManifestId != null,
      );
      throw RuntimeContentSyncException(error.message);
    } on FileSystemException catch (error) {
      progress
        ..failureStage = RuntimeContentFailureStage.storage
        ..failureKind = 'storage';
      _failed(
        'Espace de stockage insuffisant ou indisponible.',
        activation?.activeManifestId,
        canRollback: activation?.previousManifestId != null,
      );
      throw RuntimeContentSyncException(error.message);
    } on StateError catch (error) {
      progress.failureKind = 'state';
      _failed(
        'La mise à jour locale n\'a pas pu être activée.',
        activation?.activeManifestId,
        canRollback: activation?.previousManifestId != null,
      );
      throw RuntimeContentSyncException(error.message);
    }
  }

  Future<Uint8List?> _reuseFile(
    RuntimeContentActivation? activation,
    PublicContentFile file,
  ) async {
    if (activation == null) return null;
    final Uint8List? active = await _store.readReleaseFile(activation.activeManifestId, file);
    if (_isValid(file, active)) return active;
    final String? previous = activation.previousManifestId;
    return previous == null ? null : _store.readReleaseFile(previous, file);
  }

  bool _isValid(PublicContentFile file, Uint8List? bytes) {
    if (bytes == null) return false;
    try {
      validatePublicContentPayload(file, bytes);
      return true;
    } on FormatException {
      return false;
    }
  }

  Set<String> _protectedManifestIds(Set<String> requested) => <String>{
        ...requested,
        ..._pendingPins.keys,
        ...?_pins?.manifestIds,
      };

  void _retainPendingPins(Set<String> manifestIds) {
    for (final String manifestId in manifestIds) {
      _pendingPins.update(manifestId, (int count) => count + 1, ifAbsent: () => 1);
    }
  }

  void _releasePendingPins(Set<String> manifestIds) {
    for (final String manifestId in manifestIds) {
      final int count = _pendingPins[manifestId] ?? 0;
      if (count <= 1) {
        _pendingPins.remove(manifestId);
      } else {
        _pendingPins[manifestId] = count - 1;
      }
    }
  }

  Future<T> _retry<T>(Future<Result<T>> Function() operation) async {
    Failure? lastFailure;
    for (var attempt = 1; attempt <= limits.maxAttempts; attempt++) {
      final Result<T> result = await operation();
      final T? value = result.valueOrNull;
      if (value != null) return value;
      final Failure failure = (result as Err<T>).failure;
      lastFailure = failure;
      if (classifyFailure(failure) != SyncDispatch.retryable || attempt == limits.maxAttempts) {
        break;
      }
      await _delay(Duration(seconds: 1 << (attempt - 1)));
    }
    throw RuntimeContentSyncException(
      lastFailure?.message ?? 'La synchronisation du contenu a échoué.',
      failure: lastFailure,
    );
  }

  void _failed(
    String message,
    String? activeManifestId, {
    required bool canRollback,
  }) {
    _emit(
      RuntimeContentStatus(
        phase: RuntimeContentPhase.failed,
        activeManifestId: activeManifestId,
        message: message,
        canRollback: canRollback,
      ),
    );
  }

  void _emit(RuntimeContentStatus status) {
    _current = status;
    if (!_statuses.isClosed) _statuses.add(status);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _operationTail;
    await _statuses.close();
  }
}

/// Mutable, content-free progress of one attempt, read only by telemetry.
class _SyncProgress {
  RuntimeContentFailureStage stage = RuntimeContentFailureStage.localCache;
  RuntimeContentFailureStage? failureStage;
  String? failureKind;
  int downloaded = 0;
  int reused = 0;
  int totalFiles = 0;
  bool recovered = false;
}
