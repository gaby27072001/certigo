import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';

const String kPackageManifestV1 = 'certigo.content.package-manifest/v1';
const String kPackageManifestV2 = 'certigo.content.package-manifest/v2';
const String kPackageManifestV3 = 'certigo.content.package-manifest/v3';

const Set<String> _publicResourceTypes = <String>{
  'certificationCatalog',
  'concept',
  'coverageMatrix',
  'domain',
  'lesson',
  'question',
  'track',
  'unit',
};

const Set<String> _forbiddenPublicKeys = <String>{
  'answerkey',
  'correct',
  'correctoptionids',
  'explanation',
  'privatemanifestid',
  'rationale',
  'releaseid',
  'solution',
};

final RegExp _digestId = RegExp(r'^sha256:[0-9a-f]{64}$');
final RegExp _hexDigest = RegExp(r'^[0-9a-f]{64}$');
final RegExp _resourceId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]*$');

class RuntimeContentLimits {
  const RuntimeContentLimits({
    this.maxManifestBytes = 2 * 1024 * 1024,
    this.maxFiles = 10000,
    this.maxFileBytes = 2 * 1024 * 1024,
    this.maxReleaseBytes = 128 * 1024 * 1024,
    this.maxCacheBytes = 384 * 1024 * 1024,
    this.maxAttempts = 3,
    this.maxCleanupEntries = 32,
    this.stagingRetention = const Duration(hours: 24),
  });

  final int maxManifestBytes;
  final int maxFiles;
  final int maxFileBytes;
  final int maxReleaseBytes;
  final int maxCacheBytes;
  final int maxAttempts;
  final int maxCleanupEntries;
  final Duration stagingRetention;
}

class PublicContentFile {
  const PublicContentFile({
    required this.id,
    required this.path,
    required this.resourceType,
    required this.hash,
    required this.size,
  });

  final String id;
  final String path;
  final String resourceType;
  final String hash;
  final int size;

  factory PublicContentFile.fromJson(
    Map<String, dynamic> json, {
    required String manifestSchema,
    required RuntimeContentLimits limits,
  }) {
    _expectKeys(
      json,
      required: manifestSchema == kPackageManifestV1
          ? const <String>{'id', 'path', 'hash', 'size'}
          : const <String>{'id', 'path', 'resourceType', 'hash', 'size'},
      optional: manifestSchema == kPackageManifestV1
          ? const <String>{}
          : const <String>{'provider', 'certification', 'blueprintVersion', 'objective'},
      name: 'manifest file',
    );
    final String id = _requiredString(json, 'id');
    final String path = _requiredString(json, 'path');
    final String hash = _requiredString(json, 'hash');
    final int size = _requiredInt(json, 'size');
    if (!_resourceId.hasMatch(id) || id.length > 256 || id == '.' || id == '..') {
      throw FormatException('Unsafe public content file id: $id');
    }
    _ensureSafePath(path);
    if (manifestSchema == kPackageManifestV1 &&
        !RegExp(r'^questions/[^/]+\.json$').hasMatch(path)) {
      throw FormatException('Legacy public package path is invalid: $path');
    }
    if (!_hexDigest.hasMatch(hash)) {
      throw FormatException('Invalid SHA-256 for public content file $id');
    }
    if (size <= 0 || size > limits.maxFileBytes) {
      throw FormatException('Invalid size for public content file $id: $size');
    }

    final String resourceType = manifestSchema == kPackageManifestV1
        ? _resourceTypeFromPath(path)
        : _requiredString(json, 'resourceType');
    if (!_publicResourceTypes.contains(resourceType)) {
      throw FormatException('Private or unsupported resourceType: $resourceType');
    }
    if (manifestSchema != kPackageManifestV3 &&
        const <String>{'track', 'domain', 'unit', 'lesson', 'concept'}.contains(resourceType)) {
      throw FormatException('$resourceType requires package-manifest/v3');
    }
    _ensureResourcePath(resourceType, path);
    return PublicContentFile(
      id: id,
      path: path,
      resourceType: resourceType,
      hash: hash,
      size: size,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'path': path,
    'resourceType': resourceType,
    'hash': hash,
    'size': size,
  };
}

class PublicContentManifest {
  const PublicContentManifest({
    required this.schema,
    required this.files,
    required this.manifestId,
    required this.rootHash,
    required this.rawJson,
  });

  final String schema;
  final List<PublicContentFile> files;
  final String manifestId;
  final String rootHash;
  final Map<String, dynamic> rawJson;

  int get totalBytes => files.fold<int>(0, (int total, PublicContentFile file) {
    return total + file.size;
  });

  factory PublicContentManifest.fromJson(
    Map<String, dynamic> json, {
    RuntimeContentLimits limits = const RuntimeContentLimits(),
  }) {
    _expectKeys(
      json,
      required: const <String>{
        'schema',
        'channel',
        'artifact',
        'algorithm',
        'serialization',
        'fileCount',
        'files',
        'manifestId',
        'rootHash',
      },
      optional: const <String>{},
      name: 'package manifest',
    );
    final String schema = _requiredString(json, 'schema');
    if (schema != kPackageManifestV1 &&
        schema != kPackageManifestV2 &&
        schema != kPackageManifestV3) {
      throw FormatException('Unsupported public package manifest schema: $schema');
    }
    if (json['channel'] != 'public' ||
        json['artifact'] != 'public' ||
        json['algorithm'] != 'sha256' ||
        json['serialization'] != 'json-sorted-keys-compact-utf8-lf') {
      throw const FormatException('Package manifest is not the supported public artifact');
    }

    final dynamic rawFiles = json['files'];
    if (rawFiles is! List<dynamic>) {
      throw const FormatException('Package manifest files must be an array');
    }
    final int fileCount = _requiredInt(json, 'fileCount');
    if (fileCount != rawFiles.length || fileCount > limits.maxFiles) {
      throw FormatException('Package manifest fileCount is invalid: $fileCount');
    }
    final List<PublicContentFile> files = rawFiles
        .map(
          (dynamic value) => PublicContentFile.fromJson(
            _asStringMap(value, 'manifest file'),
            manifestSchema: schema,
            limits: limits,
          ),
        )
        .toList(growable: false);
    final Set<String> ids = <String>{};
    final Set<String> paths = <String>{};
    for (final PublicContentFile file in files) {
      if (!ids.add(file.id)) {
        throw FormatException('Duplicate public content file id: ${file.id}');
      }
      if (!paths.add(file.path)) {
        throw FormatException('Duplicate public content file path: ${file.path}');
      }
    }
    final int totalBytes = files.fold<int>(
      0,
      (int total, PublicContentFile file) => total + file.size,
    );
    if (totalBytes > limits.maxReleaseBytes) {
      throw FormatException('Public content release exceeds ${limits.maxReleaseBytes} bytes');
    }

    final String manifestId = _requiredString(json, 'manifestId');
    final String rootHash = _requiredString(json, 'rootHash');
    if (!_digestId.hasMatch(manifestId) || !_hexDigest.hasMatch(rootHash)) {
      throw const FormatException('Package manifest identities are invalid');
    }
    final Map<String, dynamic> digestBody = Map<String, dynamic>.from(json)
      ..remove('manifestId')
      ..remove('rootHash');
    final String digest = sha256.convert(utf8.encode(_canonicalJson(digestBody))).toString();
    if (manifestId != 'sha256:$digest' || rootHash != digest) {
      throw const FormatException('Package manifest canonical digest is invalid');
    }

    return PublicContentManifest(
      schema: schema,
      files: files,
      manifestId: manifestId,
      rootHash: rootHash,
      rawJson: Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(json)),
    );
  }

  PublicContentFile? fileById(String id) {
    for (final PublicContentFile file in files) {
      if (file.id == id) return file;
    }
    return null;
  }
}

class PublicManifestFetch {
  const PublicManifestFetch._({required this.notModified, this.manifest, this.etag});

  const PublicManifestFetch.notModified(String etag) : this._(notModified: true, etag: etag);

  const PublicManifestFetch.fetched(PublicContentManifest manifest, String etag)
    : this._(notModified: false, manifest: manifest, etag: etag);

  final bool notModified;
  final PublicContentManifest? manifest;
  final String? etag;
}

class PublicContentFileFetch {
  const PublicContentFileFetch({
    required this.bytes,
    required this.etag,
    required this.publicManifestId,
    required this.resourceType,
  });

  final Uint8List bytes;
  final String etag;
  final String publicManifestId;
  final String resourceType;
}

abstract interface class PublicContentSource {
  Future<Result<PublicManifestFetch>> fetchActiveManifest({
    String? ifNoneMatch,
    RuntimeContentLimits limits = const RuntimeContentLimits(),
  });

  Future<Result<PublicContentFileFetch>> fetchFile({
    required String publicManifestId,
    required PublicContentFile file,
  });
}

Map<String, dynamic> validatePublicContentPayload(PublicContentFile file, Uint8List bytes) {
  if (bytes.length != file.size) {
    throw FormatException(
      'Public content file ${file.id} has ${bytes.length} bytes; expected ${file.size}',
    );
  }
  final String actualHash = sha256.convert(bytes).toString();
  if (actualHash != file.hash) {
    throw FormatException(
      'Public content file ${file.id} hash is $actualHash; expected ${file.hash}',
    );
  }
  final dynamic decoded = jsonDecode(utf8.decode(bytes));
  final Map<String, dynamic> json = _asStringMap(decoded, file.id);
  _rejectForbiddenPublicKeys(json, r'$');

  final String actualId = switch (file.resourceType) {
    'certificationCatalog' => 'certification-catalog',
    'coverageMatrix' => _requiredString(json, 'certification'),
    _ => _requiredString(json, 'id'),
  };
  if (actualId != file.id) {
    throw FormatException(
      'Manifest id ${file.id} does not match public payload identity $actualId',
    );
  }
  switch (file.resourceType) {
    case 'certificationCatalog':
      if (json['schema'] != 'certigo.certification-catalog/v1') {
        throw const FormatException('Unsupported certification catalog schema');
      }
    case 'coverageMatrix':
      if (json['schema'] != 'certigo.coverage-matrix/v1') {
        throw const FormatException('Unsupported coverage matrix schema');
      }
    case 'question':
      if (json['kind'] != 'public' ||
          !const <String>{'v2', 'v3', 'v4'}.contains(json['schemaVersion'])) {
        throw const FormatException('Unsupported public question schema');
      }
    case 'track':
    case 'domain':
    case 'unit':
    case 'lesson':
    case 'concept':
      if (json['resourceType'] != file.resourceType) {
        throw FormatException('Runtime resourceType mismatch for ${file.id}');
      }
      if (json['schema'] != 'certigo.runtime.${file.resourceType}/v1') {
        throw FormatException('Unsupported runtime resource schema for ${file.id}');
      }
    default:
      throw FormatException('Unsupported public resourceType: ${file.resourceType}');
  }
  return json;
}

String runtimeContentScopeKey(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    throw const FormatException('Runtime content scope cannot be empty');
  }
  return sha256.convert(utf8.encode(normalized)).toString().substring(0, 32);
}

String _canonicalJson(dynamic value) => jsonEncode(_sortJson(value));

dynamic _sortJson(dynamic value) {
  if (value is Map) {
    final SplayTreeMap<String, dynamic> sorted = SplayTreeMap<String, dynamic>();
    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException('JSON object key must be a string');
      }
      sorted[entry.key as String] = _sortJson(entry.value);
    }
    return sorted;
  }
  if (value is List) {
    return value.map<dynamic>(_sortJson).toList(growable: false);
  }
  return value;
}

void _rejectForbiddenPublicKeys(dynamic value, String path) {
  if (value is Map) {
    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      final String key = entry.key as String;
      if (_forbiddenPublicKeys.contains(key.toLowerCase())) {
        throw FormatException('Public content contains forbidden key $path.$key');
      }
      _rejectForbiddenPublicKeys(entry.value, '$path.$key');
    }
  } else if (value is List) {
    for (var index = 0; index < value.length; index++) {
      _rejectForbiddenPublicKeys(value[index], '$path[$index]');
    }
  }
}

void _ensureSafePath(String path) {
  final List<String> segments = path.split('/');
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.contains(r'\') ||
      segments.any((String segment) => segment.isEmpty || segment == '.' || segment == '..')) {
    throw FormatException('Unsafe public content path: $path');
  }
}

void _ensureResourcePath(String resourceType, String path) {
  final bool valid = switch (resourceType) {
    'question' => path.startsWith('questions/'),
    'certificationCatalog' => path == 'catalog/certifications.json',
    'coverageMatrix' => path.startsWith('coverage/'),
    'track' => path.startsWith('runtime/tracks/'),
    'domain' => path.startsWith('runtime/domains/'),
    'unit' => path.startsWith('runtime/units/'),
    'lesson' => path.startsWith('runtime/lessons/'),
    'concept' => path.startsWith('runtime/concepts/'),
    _ => false,
  };
  if (!valid || !path.endsWith('.json')) {
    throw FormatException('Public content path does not match $resourceType: $path');
  }
}

String _resourceTypeFromPath(String path) {
  if (path.startsWith('questions/')) return 'question';
  if (path == 'catalog/certifications.json') return 'certificationCatalog';
  if (path.startsWith('coverage/')) return 'coverageMatrix';
  if (path.startsWith('runtime/tracks/')) return 'track';
  if (path.startsWith('runtime/domains/')) return 'domain';
  if (path.startsWith('runtime/units/')) return 'unit';
  if (path.startsWith('runtime/lessons/')) return 'lesson';
  if (path.startsWith('runtime/concepts/')) return 'concept';
  throw FormatException('Cannot infer public resourceType from path: $path');
}

void _expectKeys(
  Map<String, dynamic> json, {
  required Set<String> required,
  required Set<String> optional,
  required String name,
}) {
  final Set<String> keys = json.keys.toSet();
  final Set<String> missing = required.difference(keys);
  final Set<String> unknown = keys.difference(required.union(optional));
  if (missing.isNotEmpty || unknown.isNotEmpty) {
    throw FormatException(
      '$name keys are invalid; missing=${missing.join(',')}, unknown=${unknown.join(',')}',
    );
  }
}

Map<String, dynamic> _asStringMap(dynamic value, String name) {
  if (value is! Map) {
    throw FormatException('$name must be a JSON object');
  }
  return Map<String, dynamic>.from(value);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  if (value is! num || value.toInt() != value) {
    throw FormatException('$key must be an integer');
  }
  return value.toInt();
}
