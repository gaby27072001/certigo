import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const String offlineContentManifestV1 = 'certigo.mobile-offline-manifest/v1';
const String packageManifestV3 = 'certigo.content.package-manifest/v3';

const String catalogContentResourceType = 'catalog';
const String lessonContentResourceType = 'lesson';

final RegExp _digestIdPattern = RegExp(r'^sha256:[0-9a-f]{64}$');
final RegExp _hexDigestPattern = RegExp(r'^[0-9a-f]{64}$');

bool isContentDigestId(String value) => _digestIdPattern.hasMatch(value);

class OfflineContentFileDescriptor {
  OfflineContentFileDescriptor({
    required this.id,
    required this.path,
    required this.resourceType,
    required this.hash,
    required this.size,
    this.trackId,
  }) {
    _validate();
  }

  factory OfflineContentFileDescriptor.fromJson(Map<String, dynamic> json) {
    _requireOnlyKeys(json, <String>{'id', 'path', 'resourceType', 'hash', 'size', 'trackId'});
    return OfflineContentFileDescriptor(
      id: _requiredString(json, 'id'),
      path: _requiredString(json, 'path'),
      resourceType: _requiredString(json, 'resourceType'),
      hash: _requiredString(json, 'hash'),
      size: _requiredInt(json, 'size'),
      trackId: _optionalString(json, 'trackId'),
    );
  }

  final String id;
  final String path;
  final String resourceType;
  final String hash;
  final int size;
  final String? trackId;

  bool get isCatalog => resourceType == catalogContentResourceType;
  bool get isLesson => resourceType == lessonContentResourceType;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'path': path,
        'resourceType': resourceType,
        'hash': hash,
        'size': size,
        if (trackId != null) 'trackId': trackId,
      };

  void _validate() {
    if (id.trim() != id || id.isEmpty) {
      throw const FormatException('Offline content file id is invalid.');
    }
    if (path.trim() != path || path.isEmpty || path.startsWith('/') || path.contains(r'\')) {
      throw const FormatException('Offline content file path is invalid.');
    }
    if (!_hexDigestPattern.hasMatch(hash)) {
      throw const FormatException('Offline content file hash is invalid.');
    }
    if (size <= 0) {
      throw const FormatException('Offline content file size is invalid.');
    }
    switch (resourceType) {
      case catalogContentResourceType:
        if (id != catalogContentResourceType || path != 'catalog/tracks.json' || trackId != null) {
          throw const FormatException('Offline catalog descriptor is invalid.');
        }
      case lessonContentResourceType:
        if (trackId == null || trackId!.trim() != trackId || trackId!.isEmpty) {
          throw const FormatException('Offline lesson descriptor is missing trackId.');
        }
        final String expectedPath =
            'tracks/${Uri.encodeComponent(trackId!)}/lessons/${Uri.encodeComponent(id)}.json';
        if (path != expectedPath) {
          throw const FormatException('Offline lesson descriptor path is invalid.');
        }
      default:
        throw FormatException('Unsupported offline content resource type: $resourceType');
    }
  }
}

class OfflineContentManifest {
  OfflineContentManifest({
    required this.schema,
    required this.manifestId,
    required this.version,
    required this.sourceSchema,
    required this.files,
  }) {
    _validate();
  }

  factory OfflineContentManifest.create({
    required String schema,
    required String manifestId,
    required String sourceSchema,
    required List<OfflineContentFileDescriptor> files,
  }) =>
      OfflineContentManifest(
        schema: schema,
        manifestId: manifestId,
        version: _computeVersion(schema, manifestId, sourceSchema, files),
        sourceSchema: sourceSchema,
        files: files,
      );

  factory OfflineContentManifest.fromJson(Map<String, dynamic> json) {
    _requireOnlyKeys(
      json,
      <String>{'schema', 'manifestId', 'version', 'sourceSchema', 'fileCount', 'files'},
    );
    final List<dynamic> rawFiles = json['files'] as List<dynamic>? ??
        (throw const FormatException('Offline content manifest files are required.'));
    final int fileCount = _requiredInt(json, 'fileCount');
    if (fileCount != rawFiles.length) {
      throw const FormatException('Offline content manifest fileCount does not match files.');
    }
    return OfflineContentManifest(
      schema: _requiredString(json, 'schema'),
      manifestId: _requiredString(json, 'manifestId'),
      version: _requiredString(json, 'version'),
      sourceSchema: _requiredString(json, 'sourceSchema'),
      files: rawFiles
          .map(
            (dynamic value) => OfflineContentFileDescriptor.fromJson(
              Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
            ),
          )
          .toList(growable: false),
    );
  }

  final String schema;
  final String manifestId;
  final String version;
  final String sourceSchema;
  final List<OfflineContentFileDescriptor> files;

  OfflineContentFileDescriptor get catalog =>
      files.singleWhere((OfflineContentFileDescriptor file) => file.isCatalog);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schema': schema,
        'manifestId': manifestId,
        'version': version,
        'sourceSchema': sourceSchema,
        'fileCount': files.length,
        'files': files.map((OfflineContentFileDescriptor file) => file.toJson()).toList(),
      };

  void _validate() {
    if (schema != offlineContentManifestV1) {
      throw FormatException('Unsupported offline content manifest schema: $schema');
    }
    if (!isContentDigestId(manifestId)) {
      throw const FormatException('Offline content manifestId is invalid.');
    }
    if (!isContentDigestId(version)) {
      throw const FormatException('Offline content manifest version is invalid.');
    }
    if (sourceSchema != packageManifestV3) {
      throw FormatException('Unsupported source package manifest schema: $sourceSchema');
    }
    if (files.where((OfflineContentFileDescriptor file) => file.isCatalog).length != 1) {
      throw const FormatException('Offline content manifest must contain one catalog.');
    }

    final Set<String> paths = <String>{};
    final Set<String> identities = <String>{};
    for (final OfflineContentFileDescriptor file in files) {
      if (!paths.add(file.path)) {
        throw FormatException('Duplicate offline content path: ${file.path}');
      }
      final String identity = '${file.resourceType}\u0000${file.trackId ?? ''}\u0000${file.id}';
      if (!identities.add(identity)) {
        throw FormatException('Duplicate offline content identity: ${file.id}');
      }
    }
    if (version != _computeVersion(schema, manifestId, sourceSchema, files)) {
      throw const FormatException(
        'Offline content manifest version does not match its immutable descriptors.',
      );
    }
  }

  static String _computeVersion(
    String schema,
    String manifestId,
    String sourceSchema,
    List<OfflineContentFileDescriptor> files,
  ) {
    final List<OfflineContentFileDescriptor> sorted = List<OfflineContentFileDescriptor>.from(files)
      ..sort(
        (OfflineContentFileDescriptor left, OfflineContentFileDescriptor right) =>
            left.path.compareTo(right.path),
      );
    final String canonical = <String>[
      schema,
      manifestId,
      sourceSchema,
      ...sorted.map(
        (OfflineContentFileDescriptor file) => <Object>[
          file.id,
          file.path,
          file.resourceType,
          file.hash,
          file.size,
          file.trackId ?? '',
        ].join('\u0000'),
      ),
    ].join('\n');
    return 'sha256:${sha256.convert(utf8.encode(canonical))}';
  }
}

class ContentFileResponse {
  const ContentFileResponse({
    required this.bytes,
    required this.manifestId,
    required this.hash,
    required this.size,
  });

  final Uint8List bytes;
  final String? manifestId;
  final String? hash;
  final int? size;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string when present.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! num || value.toInt() != value) {
    throw FormatException('$key must be an integer.');
  }
  return value.toInt();
}

void _requireOnlyKeys(Map<String, dynamic> json, Set<String> allowed) {
  final String? unexpected = json.keys.cast<String?>().firstWhere(
        (String? key) => key == null || !allowed.contains(key),
        orElse: () => null,
      );
  if (unexpected != null) {
    throw FormatException('Unexpected offline content field: $unexpected');
  }
}
