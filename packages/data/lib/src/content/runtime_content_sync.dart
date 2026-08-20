import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';

import '../sync/sync_dispatcher.dart';
import 'runtime_content.dart';
import 'runtime_content_store.dart';

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
  final Map<String, int> _pins = <String, int>{};

  Set<String> get manifestIds => Set<String>.unmodifiable(_pins.keys);

  RuntimeContentPin pin(String? publicManifestId) {
    if (publicManifestId == null || publicManifestId.isEmpty) {
      return RuntimeContentPin._();
    }
    _pins.update(publicManifestId, (int count) => count + 1, ifAbsent: () => 1);
    return RuntimeContentPin._(() {
      final int count = _pins[publicManifestId] ?? 0;
      if (count <= 1) {
        _pins.remove(publicManifestId);
      } else {
        _pins[publicManifestId] = count - 1;
      }
    });
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
    this.limits = const RuntimeContentLimits(),
    Future<void> Function(Duration duration)? delay,
  })  : _source = source,
        _store = store,
        _delay = delay ?? Future<void>.delayed;

  final PublicContentSource _source;
  final RuntimeContentStore _store;
  final RuntimeContentLimits limits;
  final Future<void> Function(Duration duration) _delay;
  final StreamController<RuntimeContentStatus> _statuses =
      StreamController<RuntimeContentStatus>.broadcast();

  RuntimeContentStatus _current = const RuntimeContentStatus.idle();
  Future<RuntimeContentSyncReport>? _inFlight;
  String? _inFlightOwnerId;
  Set<String> _inFlightPins = <String>{};

  RuntimeContentStatus get currentStatus => _current;
  Stream<RuntimeContentStatus> get statuses => _statuses.stream;

  Future<RuntimeContentSyncReport> sync({
    required String ownerId,
    Set<String> pinnedManifestIds = const <String>{},
  }) {
    final Future<RuntimeContentSyncReport>? running = _inFlight;
    if (running != null) {
      if (_inFlightOwnerId == ownerId && pinnedManifestIds.difference(_inFlightPins).isEmpty) {
        return running;
      }
      return running.then(
        (_) => sync(ownerId: ownerId, pinnedManifestIds: pinnedManifestIds),
        onError: (Object _, StackTrace __) =>
            sync(ownerId: ownerId, pinnedManifestIds: pinnedManifestIds),
      );
    }
    _inFlightOwnerId = ownerId;
    _inFlightPins = Set<String>.of(pinnedManifestIds);
    final Future<RuntimeContentSyncReport> operation = _sync(
      ownerScope: runtimeContentScopeKey(ownerId),
      pinnedManifestIds: pinnedManifestIds,
    ).whenComplete(() {
      _inFlight = null;
      _inFlightOwnerId = null;
      _inFlightPins = <String>{};
    });
    _inFlight = operation;
    return operation;
  }

  Future<RuntimeContentActivation?> rollback({required String ownerId}) async {
    final Future<RuntimeContentSyncReport>? running = _inFlight;
    if (running != null) {
      try {
        await running;
      } on RuntimeContentSyncException {
        // A failed sync preserves the last valid activation before rollback.
      }
    }
    try {
      final RuntimeContentActivation? activation = await _store.rollback(
        runtimeContentScopeKey(ownerId),
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
      _failed(
        'La version précédente du contenu n\'a pas pu être restaurée.',
        _current.activeManifestId,
        canRollback: true,
      );
      throw RuntimeContentSyncException(error.message);
    } on FormatException catch (error) {
      _failed(
        'La version précédente du contenu est invalide.',
        _current.activeManifestId,
        canRollback: false,
      );
      throw RuntimeContentSyncException(error.message);
    } on StateError catch (error) {
      _failed(
        'La version précédente du contenu n\'a pas pu être restaurée.',
        _current.activeManifestId,
        canRollback: true,
      );
      throw RuntimeContentSyncException(error.message);
    }
  }

  Future<RuntimeContentSyncReport> _sync({
    required String ownerScope,
    required Set<String> pinnedManifestIds,
  }) async {
    RuntimeContentActivation? activation = await _store.readActivation(ownerScope);
    if (activation?.recovered ?? false) {
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

    try {
      final PublicManifestFetch fetched = await _retry<PublicManifestFetch>(
        () => _source.fetchActiveManifest(ifNoneMatch: activation?.etag, limits: limits),
      );
      if (fetched.notModified) {
        if (activation == null) {
          throw const RuntimeContentSyncException('Le serveur a répondu 304 sans cache actif.');
        }
        await _store.cleanup(ownerScope: ownerScope, protectedManifestIds: pinnedManifestIds);
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

      final PublicContentManifest manifest = fetched.manifest!;
      final String etag = fetched.etag!;
      if (activation?.activeManifestId == manifest.manifestId) {
        _emit(
          RuntimeContentStatus(
            phase: RuntimeContentPhase.ready,
            activeManifestId: activation!.activeManifestId,
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
        activation = await _store.activate(
          ownerScope: ownerScope,
          manifest: manifest,
          etag: etag,
        );
        await _store.cleanup(
          ownerScope: ownerScope,
          protectedManifestIds: <String>{
            ...pinnedManifestIds,
            activation.activeManifestId,
            if (activation.previousManifestId != null) activation.previousManifestId!,
          },
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

      await _store.ensureCapacity(
        ownerScope: ownerScope,
        target: manifest,
        protectedManifestIds: pinnedManifestIds,
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
              () => _source.fetchFile(publicManifestId: manifest.manifestId, file: file),
            );
            validatePublicContentPayload(file, response.bytes);
            await _store.writeStagedFile(manifest, file, response.bytes);
            downloaded++;
          }
        } else {
          reused++;
        }
        completed++;
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
      activation = await _store.activate(ownerScope: ownerScope, manifest: manifest, etag: etag);
      await _store.cleanup(
        ownerScope: ownerScope,
        protectedManifestIds: <String>{
          ...pinnedManifestIds,
          activation.activeManifestId,
          if (activation.previousManifestId != null) activation.previousManifestId!,
        },
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
      _failed(
        'Le contenu téléchargé est invalide.',
        activation?.activeManifestId,
        canRollback: activation?.previousManifestId != null,
      );
      throw RuntimeContentSyncException(error.message);
    } on FileSystemException catch (error) {
      _failed(
        'Espace de stockage insuffisant ou indisponible.',
        activation?.activeManifestId,
        canRollback: activation?.previousManifestId != null,
      );
      throw RuntimeContentSyncException(error.message);
    } on StateError catch (error) {
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
    final Future<RuntimeContentSyncReport>? running = _inFlight;
    if (running != null) {
      try {
        await running;
      } on RuntimeContentSyncException {
        // The status already carries the failure; disposal only waits for completion.
      }
    }
    await _statuses.close();
  }
}
