import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'runtime_content.dart';

final RegExp _activationDigestId = RegExp(r'^sha256:[0-9a-f]{64}$');

class RuntimeContentActivation {
  const RuntimeContentActivation({
    required this.activeManifestId,
    required this.etag,
    required this.generation,
    required this.activatedAt,
    this.activeReleaseId,
    this.previousManifestId,
    this.previousReleaseId,
    this.recovered = false,
  });

  final String? activeReleaseId;
  final String activeManifestId;
  final String? previousReleaseId;
  final String? previousManifestId;
  final String etag;
  final int generation;
  final DateTime activatedAt;
  final bool recovered;

  RuntimeContentActivation copyWith({bool? recovered}) => RuntimeContentActivation(
        activeManifestId: activeManifestId,
        activeReleaseId: activeReleaseId,
        previousManifestId: previousManifestId,
        previousReleaseId: previousReleaseId,
        etag: etag,
        generation: generation,
        activatedAt: activatedAt,
        recovered: recovered ?? this.recovered,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schema': 'certigo.mobile.content-activation/v1',
        if (activeReleaseId != null) 'activeReleaseId': activeReleaseId,
        'activeManifestId': activeManifestId,
        if (previousReleaseId != null) 'previousReleaseId': previousReleaseId,
        if (previousManifestId != null) 'previousManifestId': previousManifestId,
        'etag': etag,
        'generation': generation,
        'activatedAt': activatedAt.toUtc().toIso8601String(),
      };

  factory RuntimeContentActivation.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != 'certigo.mobile.content-activation/v1') {
      throw const FormatException('Unsupported mobile content activation schema');
    }
    final String activeManifestId = _requiredActivationDigest(json, 'activeManifestId');
    final String? activeReleaseId = _optionalActivationDigest(json, 'activeReleaseId');
    final String? previousManifestId = _optionalActivationDigest(json, 'previousManifestId');
    final String? previousReleaseId = _optionalActivationDigest(json, 'previousReleaseId');
    final dynamic rawGeneration = json['generation'];
    final dynamic rawEtag = json['etag'];
    if (rawGeneration is! num ||
        rawGeneration.toInt() != rawGeneration ||
        rawGeneration.toInt() < 1 ||
        rawEtag is! String ||
        rawEtag.isEmpty) {
      throw const FormatException('Invalid mobile content activation metadata');
    }
    return RuntimeContentActivation(
      activeManifestId: activeManifestId,
      activeReleaseId: activeReleaseId,
      previousManifestId: previousManifestId,
      previousReleaseId: previousReleaseId,
      etag: rawEtag,
      generation: rawGeneration.toInt(),
      activatedAt: DateTime.parse(json['activatedAt'] as String),
    );
  }
}

String _requiredActivationDigest(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  if (value is! String || !_activationDigestId.hasMatch(value)) {
    throw FormatException('Invalid mobile content activation $key');
  }
  return value;
}

String? _optionalActivationDigest(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  if (value == null) return null;
  if (value is! String || !_activationDigestId.hasMatch(value)) {
    throw FormatException('Invalid mobile content activation $key');
  }
  return value;
}

class CachedPublicContentFile {
  const CachedPublicContentFile({
    required this.releaseId,
    required this.publicManifestId,
    required this.file,
    required this.bytes,
  });

  final String? releaseId;
  final String publicManifestId;
  final PublicContentFile file;
  final Uint8List bytes;
}

abstract interface class RuntimeContentStore {
  Future<RuntimeContentActivation?> readActivation(String ownerScope);

  Future<PublicContentManifest?> readActiveManifest(String ownerScope);

  Future<bool> hasCompleteRelease(PublicContentManifest manifest);

  Future<void> prepare(PublicContentManifest manifest);

  Future<Uint8List?> readStagedFile(PublicContentManifest manifest, PublicContentFile file);

  Future<Uint8List?> readReleaseFile(String publicManifestId, PublicContentFile file);

  Future<void> writeStagedFile(
    PublicContentManifest manifest,
    PublicContentFile file,
    Uint8List bytes,
  );

  Future<void> ensureCapacity({
    required String ownerScope,
    required PublicContentManifest target,
    required Set<String> protectedManifestIds,
  });

  Future<RuntimeContentActivation> activate({
    required String ownerScope,
    required PublicContentManifest manifest,
    required String etag,
  });

  Future<RuntimeContentActivation?> rollback(String ownerScope);

  Future<void> cleanup({required String ownerScope, required Set<String> protectedManifestIds});

  Future<CachedPublicContentFile?> readActiveFile(String ownerScope, String fileId);

  Future<void> purgePerson(String ownerScope);
}

class InMemoryRuntimeContentStore implements RuntimeContentStore {
  final Map<String, RuntimeContentActivation> _activations = <String, RuntimeContentActivation>{};
  final Map<String, PublicContentManifest> _manifests = <String, PublicContentManifest>{};
  final Map<String, Map<String, Uint8List>> _staging = <String, Map<String, Uint8List>>{};
  final Map<String, Map<String, Uint8List>> _releases = <String, Map<String, Uint8List>>{};
  final Set<String> _deletedOwners = <String>{};

  @override
  Future<RuntimeContentActivation?> readActivation(String ownerScope) async =>
      _deletedOwners.contains(ownerScope) ? null : _activations[ownerScope];

  @override
  Future<PublicContentManifest?> readActiveManifest(String ownerScope) async {
    final RuntimeContentActivation? activation = _activations[ownerScope];
    final PublicContentManifest? manifest =
        activation == null ? null : _manifests[activation.activeManifestId];
    final String? releaseId = activation?.activeReleaseId;
    return manifest == null || releaseId == null ? manifest : manifest.withReleaseId(releaseId);
  }

  @override
  Future<bool> hasCompleteRelease(PublicContentManifest manifest) async {
    final Map<String, Uint8List>? release = _releases[manifest.manifestId];
    if (release == null) return false;
    for (final PublicContentFile file in manifest.files) {
      final Uint8List? bytes = release[file.hash];
      if (bytes == null) return false;
      try {
        validatePublicContentPayload(file, bytes);
      } on FormatException {
        return false;
      }
    }
    return true;
  }

  @override
  Future<void> prepare(PublicContentManifest manifest) async {
    _manifests[manifest.manifestId] = manifest;
    _staging.putIfAbsent(manifest.manifestId, () => <String, Uint8List>{});
  }

  @override
  Future<Uint8List?> readStagedFile(PublicContentManifest manifest, PublicContentFile file) async =>
      _copy(_staging[manifest.manifestId]?[file.hash]);

  @override
  Future<Uint8List?> readReleaseFile(String publicManifestId, PublicContentFile file) async =>
      _copy(_releases[publicManifestId]?[file.hash]);

  @override
  Future<void> writeStagedFile(
    PublicContentManifest manifest,
    PublicContentFile file,
    Uint8List bytes,
  ) async {
    _staging.putIfAbsent(manifest.manifestId, () => <String, Uint8List>{})[file.hash] = _copy(
      bytes,
    )!;
  }

  @override
  Future<void> ensureCapacity({
    required String ownerScope,
    required PublicContentManifest target,
    required Set<String> protectedManifestIds,
  }) async {}

  @override
  Future<RuntimeContentActivation> activate({
    required String ownerScope,
    required PublicContentManifest manifest,
    required String etag,
  }) async {
    if (_deletedOwners.contains(ownerScope)) {
      throw StateError('Runtime content owner was deleted.');
    }
    if (!await hasCompleteRelease(manifest)) {
      final Map<String, Uint8List> staged = _staging[manifest.manifestId] ?? <String, Uint8List>{};
      if (manifest.files.any((PublicContentFile file) => !staged.containsKey(file.hash))) {
        throw StateError('Cannot activate an incomplete public content release.');
      }
      _releases[manifest.manifestId] = <String, Uint8List>{
        for (final MapEntry<String, Uint8List> entry in staged.entries)
          entry.key: _copy(entry.value)!,
      };
    }
    _staging.remove(manifest.manifestId);
    final RuntimeContentActivation? current = _activations[ownerScope];
    final RuntimeContentActivation next = RuntimeContentActivation(
      activeReleaseId: manifest.releaseId,
      activeManifestId: manifest.manifestId,
      previousReleaseId: current?.activeManifestId == manifest.manifestId
          ? current?.previousReleaseId
          : current?.activeReleaseId,
      previousManifestId: current?.activeManifestId == manifest.manifestId
          ? current?.previousManifestId
          : current?.activeManifestId,
      etag: etag,
      generation: (current?.generation ?? 0) + 1,
      activatedAt: DateTime.now().toUtc(),
    );
    _activations[ownerScope] = next;
    return next;
  }

  @override
  Future<RuntimeContentActivation?> rollback(String ownerScope) async {
    final RuntimeContentActivation? current = _activations[ownerScope];
    final String? previous = current?.previousManifestId;
    if (current == null || previous == null || !_releases.containsKey(previous)) {
      return null;
    }
    final RuntimeContentActivation next = RuntimeContentActivation(
      activeReleaseId: current.previousReleaseId,
      activeManifestId: previous,
      previousReleaseId: current.activeReleaseId,
      previousManifestId: current.activeManifestId,
      etag: '"$previous"',
      generation: current.generation + 1,
      activatedAt: DateTime.now().toUtc(),
      recovered: true,
    );
    _activations[ownerScope] = next;
    return next;
  }

  @override
  Future<void> cleanup({
    required String ownerScope,
    required Set<String> protectedManifestIds,
  }) async {
    final Set<String> keep = <String>{
      ...protectedManifestIds,
      for (final RuntimeContentActivation activation in _activations.values)
        activation.activeManifestId,
      for (final RuntimeContentActivation activation in _activations.values)
        if (activation.previousManifestId != null) activation.previousManifestId!,
    };
    _releases.removeWhere((String manifestId, _) => !keep.contains(manifestId));
  }

  @override
  Future<CachedPublicContentFile?> readActiveFile(String ownerScope, String fileId) async {
    final RuntimeContentActivation? activation = _activations[ownerScope];
    if (activation == null) return null;
    final PublicContentManifest? manifest = _manifests[activation.activeManifestId];
    final PublicContentFile? file = manifest?.fileById(fileId);
    final Uint8List? bytes =
        file == null ? null : _releases[activation.activeManifestId]?[file.hash];
    if (file == null || bytes == null) return null;
    return CachedPublicContentFile(
      releaseId: activation.activeReleaseId,
      publicManifestId: activation.activeManifestId,
      file: file,
      bytes: _copy(bytes)!,
    );
  }

  @override
  Future<void> purgePerson(String ownerScope) async {
    _activations.remove(ownerScope);
    _deletedOwners.add(ownerScope);
  }

  static Uint8List? _copy(Uint8List? value) => value == null ? null : Uint8List.fromList(value);
}

class FileRuntimeContentStore implements RuntimeContentStore {
  FileRuntimeContentStore({
    required Directory root,
    required String spaceScope,
    this.limits = const RuntimeContentLimits(),
    DateTime Function()? clock,
  })  : _root = root,
        _spaceScope = spaceScope,
        _clock = clock ?? DateTime.now;

  final Directory _root;
  final String _spaceScope;
  final RuntimeContentLimits limits;
  final DateTime Function() _clock;
  int _temporarySequence = 0;
  final Set<String> _purgingOwners = <String>{};
  final Set<String> _deletedOwners = <String>{};
  final Map<String, Future<void>> _ownerMutationTails = <String, Future<void>>{};

  Directory get _spaceRoot => Directory(
        '${_root.path}${Platform.pathSeparator}public${Platform.pathSeparator}'
        'spaces${Platform.pathSeparator}$_spaceScope',
      );

  Directory get _releaseRoot => Directory('${_spaceRoot.path}${Platform.pathSeparator}releases');

  Directory get _stagingRoot => Directory('${_spaceRoot.path}${Platform.pathSeparator}staging');

  Directory _personRoot(String ownerScope) => Directory(
        '${_root.path}${Platform.pathSeparator}person${Platform.pathSeparator}$ownerScope',
      );

  File _personDeletionMarker(String ownerScope) => File(
        '${_root.path}${Platform.pathSeparator}person-deletions'
        '${Platform.pathSeparator}$ownerScope.confirmed',
      );

  Directory _ownerRoot(String ownerScope) => Directory(
        '${_personRoot(ownerScope).path}${Platform.pathSeparator}'
        'spaces${Platform.pathSeparator}$_spaceScope',
      );

  Directory _activationRoot(String ownerScope) =>
      Directory('${_ownerRoot(ownerScope).path}${Platform.pathSeparator}activations');

  Directory _releaseDirectory(String manifestId) => Directory(
        '${_releaseRoot.path}${Platform.pathSeparator}${_manifestDirectoryName(manifestId)}',
      );

  Directory _stagingDirectory(String manifestId) => Directory(
        '${_stagingRoot.path}${Platform.pathSeparator}${_manifestDirectoryName(manifestId)}',
      );

  @override
  Future<RuntimeContentActivation?> readActivation(String ownerScope) async {
    _ensureOwnerScope(ownerScope);
    if (_purgingOwners.contains(ownerScope) || await _isOwnerDeleted(ownerScope)) return null;
    final Directory root = _activationRoot(ownerScope);
    if (!await root.exists()) return null;
    final List<File> files = await root
        .list()
        .where((FileSystemEntity entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((File a, File b) => b.path.compareTo(a.path));
    var skippedInvalid = false;
    for (final File file in files) {
      try {
        final RuntimeContentActivation activation = RuntimeContentActivation.fromJson(
          Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map),
        );
        if (await _isCompleteRelease(activation.activeManifestId)) {
          return skippedInvalid ? activation.copyWith(recovered: true) : activation;
        }
        skippedInvalid = true;
      } on FormatException {
        skippedInvalid = true;
      } on FileSystemException {
        skippedInvalid = true;
      } on TypeError {
        skippedInvalid = true;
      }
    }
    return null;
  }

  @override
  Future<PublicContentManifest?> readActiveManifest(String ownerScope) async {
    final RuntimeContentActivation? activation = await readActivation(ownerScope);
    if (activation == null) return null;
    final PublicContentManifest manifest = await _readManifest(
      _releaseDirectory(activation.activeManifestId),
    );
    final String? releaseId = activation.activeReleaseId;
    return releaseId == null ? manifest : manifest.withReleaseId(releaseId);
  }

  @override
  Future<bool> hasCompleteRelease(PublicContentManifest manifest) =>
      _isCompleteRelease(manifest.manifestId);

  @override
  Future<void> prepare(PublicContentManifest manifest) async {
    final Directory stage = _stagingDirectory(manifest.manifestId);
    await Directory('${stage.path}${Platform.pathSeparator}files').create(recursive: true);
    final File manifestFile = File('${stage.path}${Platform.pathSeparator}manifest.json');
    if (await manifestFile.exists()) {
      try {
        final PublicContentManifest staged = PublicContentManifest.fromJson(
          Map<String, dynamic>.from(jsonDecode(await manifestFile.readAsString()) as Map),
          limits: limits,
        );
        if (staged.manifestId == manifest.manifestId) return;
      } on FormatException {
        // A partial or corrupt transaction is discarded before it can be resumed.
      } on TypeError {
        // A non-object JSON document is also an invalid resumable transaction.
      }
      await stage.delete(recursive: true);
      await Directory('${stage.path}${Platform.pathSeparator}files').create(recursive: true);
    }
    await _writeNewFile(manifestFile, utf8.encode(jsonEncode(manifest.canonicalJson)));
  }

  @override
  Future<Uint8List?> readStagedFile(PublicContentManifest manifest, PublicContentFile file) =>
      _readIfPresent(_contentFile(_stagingDirectory(manifest.manifestId), file));

  @override
  Future<Uint8List?> readReleaseFile(String publicManifestId, PublicContentFile file) =>
      _readIfPresent(_contentFile(_releaseDirectory(publicManifestId), file));

  @override
  Future<void> writeStagedFile(
    PublicContentManifest manifest,
    PublicContentFile file,
    Uint8List bytes,
  ) async {
    if (bytes.length != file.size || bytes.length > limits.maxFileBytes) {
      throw const FileSystemException('Staged public content file has an invalid size.');
    }
    final File destination = _contentFile(_stagingDirectory(manifest.manifestId), file);
    if (await destination.exists()) {
      await destination.delete();
    }
    await _writeNewFile(destination, bytes);
  }

  @override
  Future<void> ensureCapacity({
    required String ownerScope,
    required PublicContentManifest target,
    required Set<String> protectedManifestIds,
  }) async {
    if (target.totalBytes > limits.maxReleaseBytes) {
      throw const FileSystemException('Public content release exceeds the configured limit.');
    }
    await cleanup(ownerScope: ownerScope, protectedManifestIds: protectedManifestIds);
    final int used = await _directorySize(_releaseRoot) + await _directorySize(_stagingRoot);
    final bool releasePresent = await _releaseDirectory(target.manifestId).exists();
    final Directory stagedFiles = Directory(
      '${_stagingDirectory(target.manifestId).path}${Platform.pathSeparator}files',
    );
    final int stagedBytes = await _directorySize(stagedFiles);
    final int remainingTargetBytes =
        releasePresent ? 0 : (target.totalBytes - stagedBytes).clamp(0, target.totalBytes);
    final int projected = used + remainingTargetBytes;
    if (projected > limits.maxCacheBytes) {
      throw const FileSystemException('Insufficient runtime content cache budget.');
    }
  }

  @override
  Future<RuntimeContentActivation> activate({
    required String ownerScope,
    required PublicContentManifest manifest,
    required String etag,
  }) =>
      _serializeOwnerMutation(
        ownerScope,
        () => _activate(ownerScope: ownerScope, manifest: manifest, etag: etag),
      );

  Future<RuntimeContentActivation> _activate({
    required String ownerScope,
    required PublicContentManifest manifest,
    required String etag,
  }) async {
    await _ensureOwnerAvailable(ownerScope);
    final Directory stage = _stagingDirectory(manifest.manifestId);
    final Directory release = _releaseDirectory(manifest.manifestId);
    if (!await hasCompleteRelease(manifest)) {
      if (!await stage.exists()) {
        throw StateError('Runtime content staging directory is missing.');
      }
      for (final PublicContentFile file in manifest.files) {
        final File staged = _contentFile(stage, file);
        if (!await staged.exists() || await staged.length() != file.size) {
          throw StateError('Runtime content staging is incomplete for ${file.id}.');
        }
      }
      final File marker = File('${stage.path}${Platform.pathSeparator}complete');
      if (await marker.exists()) await marker.delete();
      await _writeNewFile(marker, utf8.encode(manifest.manifestId));

      await _releaseRoot.create(recursive: true);
      if (await release.exists()) {
        await release.delete(recursive: true);
      }
      await stage.rename(release.path);
    } else if (await stage.exists()) {
      await stage.delete(recursive: true);
    }

    final RuntimeContentActivation? current = await readActivation(ownerScope);
    await _ensureOwnerAvailable(ownerScope);
    final RuntimeContentActivation next = RuntimeContentActivation(
      activeReleaseId: manifest.releaseId,
      activeManifestId: manifest.manifestId,
      previousReleaseId: current?.activeManifestId == manifest.manifestId
          ? current?.previousReleaseId
          : current?.activeReleaseId,
      previousManifestId: current?.activeManifestId == manifest.manifestId
          ? current?.previousManifestId
          : current?.activeManifestId,
      etag: etag,
      generation: (current?.generation ?? 0) + 1,
      activatedAt: _clock().toUtc(),
    );
    await _writeActivation(ownerScope, next);
    return next;
  }

  @override
  Future<RuntimeContentActivation?> rollback(String ownerScope) =>
      _serializeOwnerMutation(ownerScope, () => _rollback(ownerScope));

  Future<RuntimeContentActivation?> _rollback(String ownerScope) async {
    await _ensureOwnerAvailable(ownerScope);
    final RuntimeContentActivation? current = await readActivation(ownerScope);
    final String? previous = current?.previousManifestId;
    if (current == null || previous == null || !await _isCompleteRelease(previous)) {
      return null;
    }
    final RuntimeContentActivation next = RuntimeContentActivation(
      activeReleaseId: current.previousReleaseId,
      activeManifestId: previous,
      previousReleaseId: current.activeReleaseId,
      previousManifestId: current.activeManifestId,
      etag: '"$previous"',
      generation: current.generation + 1,
      activatedAt: _clock().toUtc(),
      recovered: true,
    );
    await _writeActivation(ownerScope, next);
    return next;
  }

  @override
  Future<void> cleanup({
    required String ownerScope,
    required Set<String> protectedManifestIds,
  }) async {
    final Set<String> keep = <String>{
      ...protectedManifestIds,
      ...await _spaceActivationManifestIds(),
    };
    var removed = 0;
    if (await _releaseRoot.exists()) {
      final List<Directory> releases = await _releaseRoot
          .list()
          .where((FileSystemEntity entity) => entity is Directory)
          .cast<Directory>()
          .toList();
      for (final Directory release in releases) {
        if (removed >= limits.maxCleanupEntries) break;
        final String? manifestId = _manifestIdFromDirectory(release.path);
        if (manifestId != null && !keep.contains(manifestId)) {
          await release.delete(recursive: true);
          removed++;
        }
      }
    }
    if (removed >= limits.maxCleanupEntries || !await _stagingRoot.exists()) return;
    final DateTime cutoff = _clock().subtract(limits.stagingRetention);
    await for (final FileSystemEntity entity in _stagingRoot.list()) {
      if (removed >= limits.maxCleanupEntries) break;
      if (entity is! Directory) continue;
      final FileStat stat = await entity.stat();
      if (stat.modified.isBefore(cutoff)) {
        await entity.delete(recursive: true);
        removed++;
      }
    }
  }

  @override
  Future<CachedPublicContentFile?> readActiveFile(String ownerScope, String fileId) async {
    final RuntimeContentActivation? activation = await readActivation(ownerScope);
    if (activation == null) return null;
    final Directory release = _releaseDirectory(activation.activeManifestId);
    final PublicContentManifest manifest = await _readManifest(release);
    final PublicContentFile? file = manifest.fileById(fileId);
    if (file == null) return null;
    final Uint8List? bytes = await _readIfPresent(_contentFile(release, file));
    if (bytes == null) return null;
    validatePublicContentPayload(file, bytes);
    return CachedPublicContentFile(
      releaseId: activation.activeReleaseId,
      publicManifestId: activation.activeManifestId,
      file: file,
      bytes: bytes,
    );
  }

  @override
  Future<void> purgePerson(String ownerScope) =>
      _serializeOwnerMutation(ownerScope, () => _purgePerson(ownerScope));

  Future<void> _purgePerson(String ownerScope) async {
    _ensureOwnerScope(ownerScope);
    if (!_purgingOwners.add(ownerScope)) {
      throw StateError('Runtime content person purge is already in progress.');
    }
    final Directory person = _personRoot(ownerScope);
    final Directory tombstone = Directory('${person.path}.deleting');
    try {
      final File marker = _personDeletionMarker(ownerScope);
      if (!await marker.exists()) {
        await _writeNewFile(marker, utf8.encode('confirmed'));
      }
      _deletedOwners.add(ownerScope);
      if (await tombstone.exists()) {
        await tombstone.delete(recursive: true);
      }
      if (await person.exists()) {
        await person.rename(tombstone.path);
      }
      if (await tombstone.exists()) {
        await tombstone.delete(recursive: true);
      }
    } finally {
      _purgingOwners.remove(ownerScope);
    }
  }

  Future<void> _writeActivation(String ownerScope, RuntimeContentActivation activation) async {
    await _ensureOwnerAvailable(ownerScope);
    final Directory root = _activationRoot(ownerScope);
    await root.create(recursive: true);
    final String generation = activation.generation.toString().padLeft(20, '0');
    await _writeNewFile(
      File('${root.path}${Platform.pathSeparator}$generation.json'),
      utf8.encode(jsonEncode(activation.toJson())),
    );
    final List<File> files = await root
        .list()
        .where((FileSystemEntity entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((File a, File b) => b.path.compareTo(a.path));
    for (final File stale in files.skip(4)) {
      await stale.delete();
    }
  }

  Future<bool> _isCompleteRelease(String manifestId) async {
    final Directory release = _releaseDirectory(manifestId);
    if (!await File('${release.path}${Platform.pathSeparator}complete').exists()) {
      return false;
    }
    try {
      final PublicContentManifest manifest = await _readManifest(release);
      for (final PublicContentFile file in manifest.files) {
        final File cached = _contentFile(release, file);
        if (!await cached.exists()) {
          return false;
        }
        validatePublicContentPayload(file, await cached.readAsBytes());
      }
      return true;
    } on FormatException {
      return false;
    } on FileSystemException {
      return false;
    } on TypeError {
      return false;
    }
  }

  Future<Set<String>> _spaceActivationManifestIds() async {
    final Directory people = Directory('${_root.path}${Platform.pathSeparator}person');
    if (!await people.exists()) return <String>{};
    final Set<String> manifestIds = <String>{};
    await for (final FileSystemEntity entity in people.list()) {
      if (entity is! Directory) continue;
      final String ownerScope = entity.path.split(Platform.pathSeparator).last;
      if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(ownerScope)) continue;
      final RuntimeContentActivation? activation = await readActivation(ownerScope);
      if (activation == null) continue;
      manifestIds.add(activation.activeManifestId);
      if (activation.previousManifestId != null) {
        manifestIds.add(activation.previousManifestId!);
      }
    }
    return manifestIds;
  }

  Future<PublicContentManifest> _readManifest(Directory directory) async {
    final File file = File('${directory.path}${Platform.pathSeparator}manifest.json');
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.length > limits.maxManifestBytes) {
      throw const FormatException('Cached public manifest exceeds the configured limit');
    }
    return PublicContentManifest.fromJson(
      Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map),
      limits: limits,
    );
  }

  File _contentFile(Directory root, PublicContentFile file) =>
      File('${root.path}${Platform.pathSeparator}files${Platform.pathSeparator}${file.hash}.json');

  Future<void> _writeNewFile(File destination, List<int> bytes) async {
    await destination.parent.create(recursive: true);
    final File temporary = File(
      '${destination.path}.tmp.${_clock().toUtc().microsecondsSinceEpoch}.${_temporarySequence++}',
    );
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(destination.path);
  }

  static Future<Uint8List?> _readIfPresent(File file) async {
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static Future<int> _directorySize(Directory directory) async {
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final FileSystemEntity entity in directory.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  static String _manifestDirectoryName(String manifestId) {
    if (!manifestId.startsWith('sha256:') || manifestId.length != 71) {
      throw FormatException('Invalid public manifest id: $manifestId');
    }
    return manifestId.substring(7);
  }

  static String? _manifestIdFromDirectory(String path) {
    final String name = path.split(Platform.pathSeparator).last;
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(name) ? 'sha256:$name' : null;
  }

  static void _ensureOwnerScope(String ownerScope) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(ownerScope)) {
      throw FormatException('Invalid runtime content owner scope: $ownerScope');
    }
  }

  Future<bool> _isOwnerDeleted(String ownerScope) async {
    if (_deletedOwners.contains(ownerScope)) return true;
    final bool deleted = await _personDeletionMarker(ownerScope).exists() ||
        await Directory('${_personRoot(ownerScope).path}.deleting').exists();
    if (deleted) _deletedOwners.add(ownerScope);
    return deleted;
  }

  Future<void> _ensureOwnerAvailable(String ownerScope) async {
    _ensureOwnerScope(ownerScope);
    if (_purgingOwners.contains(ownerScope)) {
      throw StateError('Runtime content person purge is in progress.');
    }
    if (await _isOwnerDeleted(ownerScope)) {
      throw StateError('Runtime content owner was deleted.');
    }
  }

  Future<T> _serializeOwnerMutation<T>(
    String ownerScope,
    Future<T> Function() operation,
  ) {
    _ensureOwnerScope(ownerScope);
    final Future<void> previous = _ownerMutationTails[ownerScope] ?? Future<void>.value();
    final Future<T> current = previous.then<T>((_) => operation());
    final Future<void> tail = current.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _ownerMutationTails[ownerScope] = tail;
    return current.whenComplete(() {
      if (identical(_ownerMutationTails[ownerScope], tail)) {
        _ownerMutationTails.remove(ownerScope);
      }
    });
  }
}
