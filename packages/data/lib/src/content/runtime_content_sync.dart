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
  })  : _source = source,
        _store = store,
        _pins = pins,
        _delay = delay ?? Future<void>.delayed;

  final PublicContentSource _source;
  final RuntimeContentStore _store;
  final RuntimeContentPinRegistry? _pins;
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
    RuntimeContentActivation? activation;
    try {
      activation = await _store.readActivation(ownerScope);
    } on FormatException catch (error) {
      _failed(
        'Le cache local du contenu est invalide.',
        null,
        canRollback: false,
      );
      throw RuntimeContentSyncException(error.message);
    } on FileSystemException catch (error) {
      _failed(
        'Le cache local du contenu est indisponible.',
        null,
        canRollback: false,
      );
      throw RuntimeContentSyncException(error.message);
    } on StateError catch (error) {
      _failed(
        'Le cache local du contenu est indisponible.',
        null,
        canRollback: false,
      );
      throw RuntimeContentSyncException(error.message);
    }
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

  Set<String> _protectedManifestIds(Set<String> requested) => <String>{
        ...requested,
        ...?_pins?.manifestIds,
      };

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
