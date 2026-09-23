import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:data/data.dart';

class ContentFixture {
  ContentFixture({
    required this.id,
    required this.path,
    required this.resourceType,
    required String json,
  }) : bytes = Uint8List.fromList(utf8.encode('$json\n'));

  final String id;
  final String path;
  final String resourceType;
  final Uint8List bytes;

  String get hash => sha256.convert(bytes).toString();
}

ContentFixture jsonFixture({
  required String id,
  required String path,
  required String resourceType,
  required Map<String, dynamic> json,
}) =>
    ContentFixture(
      id: id,
      path: path,
      resourceType: resourceType,
      json: jsonEncode(json),
    );

ContentFixture questionFixture(
  String id, {
  String prompt = 'Question publique ?',
  String certificationId = 'microsoft:az-900',
  String domainId = 'microsoft.az-900.domain.cloud-concepts',
  String conceptId = 'microsoft.az-900.concept.cloud-service-models',
  String? legacyId,
}) {
  return ContentFixture(
    id: id,
    path: 'questions/$id.json',
    resourceType: 'question',
    json: jsonEncode(<String, dynamic>{
      'id': id,
      if (legacyId != null) 'legacyId': legacyId,
      'schemaVersion': 'v4',
      'kind': 'public',
      'metadata': <String, dynamic>{
        'provider': 'microsoft',
        'certification': certificationId,
        'blueprintVersion': '2026-08-17',
        'objective': 'section-1',
        'domainId': domainId,
        'conceptId': conceptId,
      },
      'itemType': 'mcq',
      'difficulty': 1,
      'prompt': prompt,
      'options': <Map<String, String>>[
        <String, String>{'id': 'a', 'label': 'A'},
        <String, String>{'id': 'b', 'label': 'B'},
      ],
    }),
  );
}

Map<String, dynamic> manifestJson(List<ContentFixture> fixtures) {
  final Map<String, dynamic> body = <String, dynamic>{
    'schema': kPackageManifestV3,
    'channel': 'public',
    'artifact': 'public',
    'algorithm': 'sha256',
    'serialization': 'json-sorted-keys-compact-utf8-lf',
    'fileCount': fixtures.length,
    'files': fixtures
        .map(
          (ContentFixture fixture) => <String, dynamic>{
            'id': fixture.id,
            'path': fixture.path,
            'resourceType': fixture.resourceType,
            'hash': fixture.hash,
            'size': fixture.bytes.length,
          },
        )
        .toList(growable: false),
  };
  final String digest = sha256.convert(utf8.encode(jsonEncode(_sort(body)))).toString();
  final String releaseDigest = sha256.convert(utf8.encode('release:$digest')).toString();
  return <String, dynamic>{
    ...body,
    'manifestId': 'sha256:$digest',
    'rootHash': digest,
    'releaseId': 'sha256:$releaseDigest',
  };
}

PublicContentManifest manifest(List<ContentFixture> fixtures) =>
    PublicContentManifest.fromJson(manifestJson(fixtures));

class FakePublicContentSource implements PublicContentSource {
  FakePublicContentSource(PublicContentManifest manifest, List<ContentFixture> fixtures)
      : _manifest = manifest,
        _files = <String, Uint8List>{
          for (final ContentFixture fixture in fixtures) fixture.id: fixture.bytes,
        };

  PublicContentManifest _manifest;
  final Map<String, Uint8List> _files;
  bool corruptNextFile = false;
  Failure? manifestFailure;

  /// When set, every file request after this many successful downloads fails
  /// with [fileFailure], simulating a connection lost in the middle of a sync.
  int? failFilesAfter;
  Failure fileFailure = const NetworkFailure();
  int manifestRequests = 0;
  int fileRequests = 0;
  int servedFiles = 0;

  void promote(PublicContentManifest manifest, List<ContentFixture> fixtures) {
    _manifest = manifest;
    for (final ContentFixture fixture in fixtures) {
      _files[fixture.id] = fixture.bytes;
    }
  }

  @override
  Future<Result<PublicManifestFetch>> fetchActiveManifest({
    String? ifNoneMatch,
    RuntimeContentLimits limits = const RuntimeContentLimits(),
  }) async {
    manifestRequests++;
    final Failure? failure = manifestFailure;
    if (failure != null) return Err<PublicManifestFetch>(failure);
    final String etag = '"${_manifest.manifestId}"';
    return Success<PublicManifestFetch>(
      ifNoneMatch == etag
          ? PublicManifestFetch.notModified(
              etag: etag,
              releaseId: _manifest.releaseId!,
              publicManifestId: _manifest.manifestId,
            )
          : PublicManifestFetch.fetched(_manifest, etag),
    );
  }

  @override
  Future<Result<PublicContentFileFetch>> fetchFile({
    required String releaseId,
    required String publicManifestId,
    required PublicContentFile file,
    String? ifNoneMatch,
  }) async {
    fileRequests++;
    final int? limit = failFilesAfter;
    if (limit != null && servedFiles >= limit) {
      return Err<PublicContentFileFetch>(fileFailure);
    }
    servedFiles++;
    final Uint8List bytes = Uint8List.fromList(_files[file.id]!);
    if (corruptNextFile) {
      corruptNextFile = false;
      bytes[0] = bytes[0] ^ 0xff;
    }
    return Success<PublicContentFileFetch>(
      PublicContentFileFetch.fetched(
        bytes: bytes,
        etag: '"sha256:${file.hash}"',
        releaseId: releaseId,
        publicManifestId: publicManifestId,
        resourceType: file.resourceType,
      ),
    );
  }
}

dynamic _sort(dynamic value) {
  if (value is Map) {
    final SplayTreeMap<String, dynamic> sorted = SplayTreeMap<String, dynamic>();
    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      sorted[entry.key as String] = _sort(entry.value);
    }
    return sorted;
  }
  if (value is List) return value.map<dynamic>(_sort).toList(growable: false);
  return value;
}
