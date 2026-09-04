import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';

import '../models/content_release.dart';

const String contentReleaseCacheSlotA = 'a';
const String contentReleaseCacheSlotB = 'b';
const String contentReleaseCachePointer = 'pointer';

typedef ContentReleaseCacheRead = Future<String?> Function(String key);
typedef ContentReleaseCacheWrite = Future<void> Function(String key, String value);
typedef ContentReleaseFileWrite = ({
  OfflineContentFileDescriptor descriptor,
  Uint8List bytes,
});

abstract interface class ContentReleaseCacheStore {
  Future<void> stageManifest(OfflineContentManifest manifest);

  Future<List<OfflineContentFileDescriptor>> missingFiles(OfflineContentManifest manifest);

  Future<void> stageFile({
    required OfflineContentManifest manifest,
    required OfflineContentFileDescriptor descriptor,
    required Uint8List bytes,
  });

  Future<void> stageFiles({
    required OfflineContentManifest manifest,
    required List<ContentReleaseFileWrite> files,
  });

  Future<void> activate(OfflineContentManifest manifest);

  Future<ContentReleaseCacheSelection> readBest();
}

class ContentReleaseCacheSelection {
  const ContentReleaseCacheSelection({this.release, this.failure});

  final CachedContentRelease? release;
  final CacheFailure? failure;
}

class CachedContentRelease {
  CachedContentRelease({
    required this.manifest,
    required Map<String, Uint8List> files,
    required this.restoredPrevious,
  }) : _files = Map<String, Uint8List>.unmodifiable(files);

  final OfflineContentManifest manifest;
  final bool restoredPrevious;
  final Map<String, Uint8List> _files;

  Uint8List fileBytes(OfflineContentFileDescriptor descriptor) {
    final Uint8List? value = _files[descriptor.path];
    if (value == null) {
      throw ContentReleaseCacheException('Cached file ${descriptor.path} is missing.');
    }
    return Uint8List.fromList(value);
  }
}

class ContentReleaseCacheException implements Exception {
  const ContentReleaseCacheException(this.message);

  final String message;

  @override
  String toString() => 'ContentReleaseCacheException: $message';
}

class ContentReleaseIntegrityException extends ContentReleaseCacheException {
  const ContentReleaseIntegrityException(super.message);
}

class JsonContentReleaseCacheStore implements ContentReleaseCacheStore {
  JsonContentReleaseCacheStore({
    required ContentReleaseCacheRead read,
    required ContentReleaseCacheWrite write,
  })  : _read = read,
        _write = write;

  static const String _schema = 'certigo.mobile-release-cache/v1';
  static const Set<String> _privateKeys = <String>{
    'answerkey',
    'correct',
    'correctoptionids',
    'explanation',
    'privatemanifestid',
    'rationale',
    'releaseid',
    'solution',
  };

  final ContentReleaseCacheRead _read;
  final ContentReleaseCacheWrite _write;

  @override
  Future<void> stageManifest(OfflineContentManifest manifest) async {
    final _LoadedCache loaded = await _load();
    final _CacheState state = loaded.state;
    final Map<String, dynamic> manifestJson = manifest.toJson();
    final _StoredGeneration? existing = state.generations[manifest.version];
    bool replace = false;
    if (existing != null && jsonEncode(existing.manifest) != jsonEncode(manifestJson)) {
      try {
        OfflineContentManifest.fromJson(existing.manifest);
      } on FormatException {
        replace = true;
      } on TypeError {
        replace = true;
      }
      if (!replace) {
        throw ContentReleaseIntegrityException(
          'Manifest version ${manifest.version} changed despite its immutable identity.',
        );
      }
    }
    final _StoredGeneration target = existing == null || replace
        ? _StoredGeneration(manifest: manifestJson, files: <String, _StoredFile>{})
        : existing;
    if (existing == null || replace) {
      state.generations[manifest.version] = target;
    }
    bool changed = existing == null || replace || loaded.failure != null;
    for (final OfflineContentFileDescriptor descriptor in manifest.files) {
      final _StoredFile? current = target.files[descriptor.path];
      if (current != null && _isValidStoredFile(descriptor, current)) continue;

      final _StoredFile? reusable = _findReusable(state, descriptor);
      if (reusable != null) {
        target.files[descriptor.path] = reusable;
        changed = true;
      } else if (current != null) {
        target.files.remove(descriptor.path);
        changed = true;
      }
    }

    final Set<String> expectedPaths =
        manifest.files.map((OfflineContentFileDescriptor file) => file.path).toSet();
    final int before = target.files.length;
    target.files.removeWhere((String path, _StoredFile _) => !expectedPaths.contains(path));
    changed = changed || target.files.length != before;

    final Set<String?> retained = <String?>{
      state.activeVersion,
      state.previousVersion,
      manifest.version,
    };
    final int generationCount = state.generations.length;
    state.generations.removeWhere((String id, _StoredGeneration _) => !retained.contains(id));
    changed = changed || state.generations.length != generationCount;

    if (changed) await _commit(loaded, state);
  }

  @override
  Future<List<OfflineContentFileDescriptor>> missingFiles(OfflineContentManifest manifest) async {
    final _LoadedCache loaded = await _load();
    final _StoredGeneration? generation = loaded.state.generations[manifest.version];
    if (generation == null) {
      throw ContentReleaseCacheException('Manifest version ${manifest.version} is not staged.');
    }
    _ensureSameManifest(manifest, generation);
    return manifest.files
        .where(
          (OfflineContentFileDescriptor descriptor) =>
              !_isValidStoredFile(descriptor, generation.files[descriptor.path]),
        )
        .toList(growable: false);
  }

  @override
  Future<void> stageFile({
    required OfflineContentManifest manifest,
    required OfflineContentFileDescriptor descriptor,
    required Uint8List bytes,
  }) =>
      stageFiles(
        manifest: manifest,
        files: <ContentReleaseFileWrite>[
          (descriptor: descriptor, bytes: bytes),
        ],
      );

  @override
  Future<void> stageFiles({
    required OfflineContentManifest manifest,
    required List<ContentReleaseFileWrite> files,
  }) async {
    if (files.isEmpty) return;
    final Map<String, OfflineContentFileDescriptor> declaredByPath =
        <String, OfflineContentFileDescriptor>{
      for (final OfflineContentFileDescriptor descriptor in manifest.files)
        descriptor.path: descriptor,
    };
    final List<ContentReleaseFileWrite> validFiles = <ContentReleaseFileWrite>[];
    ContentReleaseCacheException? firstFailure;
    for (final ContentReleaseFileWrite file in files) {
      try {
        final OfflineContentFileDescriptor? declared = declaredByPath[file.descriptor.path];
        if (declared == null) {
          throw ContentReleaseCacheException(
            'File ${file.descriptor.path} is not declared by ${manifest.manifestId}.',
          );
        }
        if (!_sameDescriptor(declared, file.descriptor)) {
          throw ContentReleaseIntegrityException(
            'File ${file.descriptor.path} metadata differs from the staged manifest.',
          );
        }
        _validateContent(file.descriptor, file.bytes);
        validFiles.add(file);
      } on ContentReleaseCacheException catch (error) {
        firstFailure ??= error;
      }
    }

    if (validFiles.isNotEmpty) {
      final _LoadedCache loaded = await _load();
      final _StoredGeneration? generation = loaded.state.generations[manifest.version];
      if (generation == null) {
        throw ContentReleaseCacheException('Manifest version ${manifest.version} is not staged.');
      }
      _ensureSameManifest(manifest, generation);
      for (final ContentReleaseFileWrite file in validFiles) {
        final OfflineContentFileDescriptor descriptor = file.descriptor;
        generation.files[descriptor.path] = _StoredFile(
          id: descriptor.id,
          resourceType: descriptor.resourceType,
          hash: descriptor.hash,
          size: descriptor.size,
          trackId: descriptor.trackId,
          bytes: base64Encode(file.bytes),
        );
      }
      await _commit(loaded, loaded.state);
    }
    if (firstFailure != null) throw firstFailure;
  }

  @override
  Future<void> activate(OfflineContentManifest manifest) async {
    final _LoadedCache loaded = await _load();
    final _CacheState state = loaded.state;
    final _StoredGeneration? generation = state.generations[manifest.version];
    if (generation == null) {
      throw ContentReleaseCacheException('Manifest version ${manifest.version} is not staged.');
    }
    _ensureSameManifest(manifest, generation);
    _validatedFiles(manifest, generation);

    if (state.activeVersion == manifest.version) return;
    state.previousVersion = _validatedRollbackVersion(
      state,
      excluding: manifest.version,
    );
    state.activeVersion = manifest.version;
    final Set<String?> retained = <String?>{state.activeVersion, state.previousVersion};
    state.generations.removeWhere((String id, _StoredGeneration _) => !retained.contains(id));
    await _commit(loaded, state);
  }

  String? _validatedRollbackVersion(_CacheState state, {required String excluding}) {
    for (final String? id in <String?>{
      state.activeVersion,
      state.previousVersion,
    }) {
      if (id == null || id == excluding) continue;
      final _StoredGeneration? generation = state.generations[id];
      if (generation == null) continue;
      try {
        final OfflineContentManifest manifest = OfflineContentManifest.fromJson(
          generation.manifest,
        );
        if (manifest.version != id) continue;
        _validatedFiles(manifest, generation);
        return id;
      } on ContentReleaseCacheException {
        continue;
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return null;
  }

  @override
  Future<ContentReleaseCacheSelection> readBest() async {
    final _LoadedCache loaded = await _load();
    CacheFailure? failure = loaded.failure;
    void markInvalid() {
      failure ??= const CacheFailure(
        'Le cache offline actif est incomplet, corrompu ou incompatible.',
      );
    }

    final List<({String? id, bool previous})> candidates = <({String? id, bool previous})>[
      (id: loaded.state.activeVersion, previous: false),
      (id: loaded.state.previousVersion, previous: true),
    ];

    for (final ({String? id, bool previous}) candidate in candidates) {
      final String? id = candidate.id;
      if (id == null) continue;
      final _StoredGeneration? generation = loaded.state.generations[id];
      if (generation == null) {
        failure ??= const CacheFailure('Le cache offline actif est incomplet.');
        continue;
      }
      try {
        final OfflineContentManifest manifest = OfflineContentManifest.fromJson(
          generation.manifest,
        );
        if (manifest.version != id) {
          throw const ContentReleaseIntegrityException(
            'Cached manifest pointer does not match its immutable version.',
          );
        }
        return ContentReleaseCacheSelection(
          release: CachedContentRelease(
            manifest: manifest,
            files: _validatedFiles(manifest, generation),
            restoredPrevious: candidate.previous,
          ),
          failure: failure,
        );
      } on ContentReleaseCacheException {
        markInvalid();
      } on FormatException {
        markInvalid();
      } on TypeError {
        markInvalid();
      }
    }

    return ContentReleaseCacheSelection(release: null, failure: failure);
  }

  Future<_LoadedCache> _load() async {
    final List<String?> values = await Future.wait(<Future<String?>>[
      _read(contentReleaseCachePointer),
      _read(contentReleaseCacheSlotA),
      _read(contentReleaseCacheSlotB),
    ]);
    final String? pointer = values[0];
    final String? rawA = values[1];
    final String? rawB = values[2];
    final Map<String, _CacheState> valid = <String, _CacheState>{};
    bool foundCorruption = false;

    void decodeSlot(String slot, String? raw) {
      if (raw == null || raw.isEmpty) return;
      try {
        valid[slot] = _CacheState.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map<dynamic, dynamic>),
          expectedSchema: _schema,
        );
      } on FormatException {
        foundCorruption = true;
        // The alternate journal slot remains eligible below.
      } on TypeError {
        foundCorruption = true;
        // The alternate journal slot remains eligible below.
      }
    }

    decodeSlot(contentReleaseCacheSlotA, rawA);
    decodeSlot(contentReleaseCacheSlotB, rawB);
    if (pointer != null && valid.containsKey(pointer)) {
      return _LoadedCache(
        slot: pointer,
        state: valid[pointer]!,
        failure:
            foundCorruption ? const CacheFailure('Un slot du journal offline est corrompu.') : null,
      );
    }
    if (valid.isNotEmpty) {
      final MapEntry<String, _CacheState> latest = valid.entries.reduce(
        (MapEntry<String, _CacheState> left, MapEntry<String, _CacheState> right) =>
            left.value.revision >= right.value.revision ? left : right,
      );
      return _LoadedCache(
        slot: latest.key,
        state: latest.value,
        failure: pointer != null || foundCorruption
            ? const CacheFailure('Le pointeur du journal offline a été restauré.')
            : null,
      );
    }
    if ((rawA != null && rawA.isNotEmpty) || (rawB != null && rawB.isNotEmpty)) {
      return _LoadedCache(
        slot: null,
        state: _CacheState(
          revision: 0,
          activeVersion: null,
          previousVersion: null,
          generations: <String, _StoredGeneration>{},
        ),
        failure: const CacheFailure('Les deux slots du journal offline sont corrompus.'),
      );
    }
    return _LoadedCache(
      slot: null,
      state: _CacheState(
        revision: 0,
        activeVersion: null,
        previousVersion: null,
        generations: <String, _StoredGeneration>{},
      ),
      failure: null,
    );
  }

  Future<void> _commit(_LoadedCache loaded, _CacheState state) async {
    state.revision++;
    final String target = loaded.slot == contentReleaseCacheSlotA
        ? contentReleaseCacheSlotB
        : contentReleaseCacheSlotA;
    await _write(target, jsonEncode(state.toJson(_schema)));
    await _write(contentReleaseCachePointer, target);
  }

  _StoredFile? _findReusable(_CacheState state, OfflineContentFileDescriptor descriptor) {
    for (final _StoredGeneration generation in state.generations.values) {
      for (final _StoredFile candidate in generation.files.values) {
        if (_isValidStoredFile(descriptor, candidate)) return candidate;
      }
    }
    return null;
  }

  bool _isValidStoredFile(OfflineContentFileDescriptor descriptor, _StoredFile? stored) {
    if (stored == null ||
        stored.id != descriptor.id ||
        stored.resourceType != descriptor.resourceType ||
        stored.hash != descriptor.hash ||
        stored.size != descriptor.size ||
        stored.trackId != descriptor.trackId) {
      return false;
    }
    try {
      _validateContent(descriptor, base64Decode(stored.bytes));
      return true;
    } on ContentReleaseCacheException {
      return false;
    } on FormatException {
      return false;
    } on TypeError {
      return false;
    }
  }

  Map<String, Uint8List> _validatedFiles(
    OfflineContentManifest manifest,
    _StoredGeneration generation,
  ) {
    final Set<String> expectedPaths =
        manifest.files.map((OfflineContentFileDescriptor file) => file.path).toSet();
    if (generation.files.keys.toSet().difference(expectedPaths).isNotEmpty) {
      throw const ContentReleaseIntegrityException('Cached generation contains undeclared files.');
    }

    final Map<String, Uint8List> files = <String, Uint8List>{};
    for (final OfflineContentFileDescriptor descriptor in manifest.files) {
      final _StoredFile? stored = generation.files[descriptor.path];
      if (!_isValidStoredFile(descriptor, stored)) {
        throw ContentReleaseIntegrityException(
          'Cached file ${descriptor.path} failed integrity validation.',
        );
      }
      files[descriptor.path] = base64Decode(stored!.bytes);
    }
    return files;
  }

  void _validateContent(OfflineContentFileDescriptor descriptor, Uint8List bytes) {
    if (bytes.length != descriptor.size) {
      throw ContentReleaseIntegrityException(
        'File ${descriptor.path} has ${bytes.length} bytes; expected ${descriptor.size}.',
      );
    }
    final String actualHash = sha256.convert(bytes).toString();
    if (actualHash != descriptor.hash) {
      throw ContentReleaseIntegrityException('File ${descriptor.path} failed SHA-256 validation.');
    }

    final Object? payload;
    try {
      payload = jsonDecode(utf8.decode(bytes));
    } on FormatException catch (error) {
      throw ContentReleaseIntegrityException(
        'File ${descriptor.path} is not valid UTF-8 JSON: $error',
      );
    }
    if (payload is! Map<String, dynamic>) {
      throw ContentReleaseIntegrityException('File ${descriptor.path} must contain a JSON object.');
    }
    _ensurePublic(payload, descriptor.path);
  }

  void _ensurePublic(Object? value, String location) {
    if (value is Map) {
      for (final MapEntry<dynamic, dynamic> entry in value.entries) {
        final String key = entry.key as String;
        if (_privateKeys.contains(key.toLowerCase())) {
          throw ContentReleaseIntegrityException(
            'Private field $key is forbidden in offline content at $location.',
          );
        }
        _ensurePublic(entry.value, '$location.$key');
      }
    } else if (value is List) {
      for (int index = 0; index < value.length; index++) {
        _ensurePublic(value[index], '$location[$index]');
      }
    }
  }

  void _ensureSameManifest(OfflineContentManifest manifest, _StoredGeneration generation) {
    if (jsonEncode(manifest.toJson()) != jsonEncode(generation.manifest)) {
      throw ContentReleaseIntegrityException(
        'Staged manifest version ${manifest.version} changed unexpectedly.',
      );
    }
  }

  bool _sameDescriptor(OfflineContentFileDescriptor left, OfflineContentFileDescriptor right) =>
      left.id == right.id &&
      left.path == right.path &&
      left.resourceType == right.resourceType &&
      left.hash == right.hash &&
      left.size == right.size &&
      left.trackId == right.trackId;
}

class _LoadedCache {
  const _LoadedCache({required this.slot, required this.state, required this.failure});

  final String? slot;
  final _CacheState state;
  final CacheFailure? failure;
}

class _CacheState {
  _CacheState({
    required this.revision,
    required this.activeVersion,
    required this.previousVersion,
    required this.generations,
  });

  factory _CacheState.fromJson(Map<String, dynamic> json, {required String expectedSchema}) {
    if (json['schema'] != expectedSchema) {
      throw const FormatException('Unsupported offline cache schema.');
    }
    final Object? revision = json['revision'];
    if (revision is! int || revision < 0) {
      throw const FormatException('Invalid offline cache revision.');
    }
    final Object? rawGenerations = json['generations'];
    if (rawGenerations is! Map) {
      throw const FormatException('Invalid offline cache generations.');
    }
    final Map<String, _StoredGeneration> generations = <String, _StoredGeneration>{};
    for (final MapEntry<dynamic, dynamic> entry in rawGenerations.entries) {
      generations[entry.key as String] = _StoredGeneration.fromJson(
        Map<String, dynamic>.from(entry.value as Map<dynamic, dynamic>),
      );
    }
    return _CacheState(
      revision: revision,
      activeVersion: json['activeVersion'] as String?,
      previousVersion: json['previousVersion'] as String?,
      generations: generations,
    );
  }

  int revision;
  String? activeVersion;
  String? previousVersion;
  final Map<String, _StoredGeneration> generations;

  Map<String, dynamic> toJson(String schema) => <String, dynamic>{
        'schema': schema,
        'revision': revision,
        if (activeVersion != null) 'activeVersion': activeVersion,
        if (previousVersion != null) 'previousVersion': previousVersion,
        'generations': generations.map(
          (String id, _StoredGeneration generation) =>
              MapEntry<String, dynamic>(id, generation.toJson()),
        ),
      };
}

class _StoredGeneration {
  _StoredGeneration({required this.manifest, required this.files});

  factory _StoredGeneration.fromJson(Map<String, dynamic> json) {
    final Object? rawManifest = json['manifest'];
    final Object? rawFiles = json['files'];
    if (rawManifest is! Map || rawFiles is! Map) {
      throw const FormatException('Invalid offline cache generation.');
    }
    return _StoredGeneration(
      manifest: Map<String, dynamic>.from(rawManifest),
      files: rawFiles.map<String, _StoredFile>(
        (dynamic path, dynamic value) => MapEntry<String, _StoredFile>(
          path as String,
          _StoredFile.fromJson(Map<String, dynamic>.from(value as Map<dynamic, dynamic>)),
        ),
      ),
    );
  }

  final Map<String, dynamic> manifest;
  final Map<String, _StoredFile> files;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'manifest': manifest,
        'files': files.map(
          (String path, _StoredFile file) => MapEntry<String, dynamic>(path, file.toJson()),
        ),
      };
}

class _StoredFile {
  const _StoredFile({
    required this.id,
    required this.resourceType,
    required this.hash,
    required this.size,
    required this.trackId,
    required this.bytes,
  });

  factory _StoredFile.fromJson(Map<String, dynamic> json) => _StoredFile(
        id: json['id'] as String,
        resourceType: json['resourceType'] as String,
        hash: json['hash'] as String,
        size: json['size'] as int,
        trackId: json['trackId'] as String?,
        bytes: json['bytes'] as String,
      );

  final String id;
  final String resourceType;
  final String hash;
  final int size;
  final String? trackId;
  final String bytes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'resourceType': resourceType,
        'hash': hash,
        'size': size,
        if (trackId != null) 'trackId': trackId,
        'bytes': bytes,
      };
}
