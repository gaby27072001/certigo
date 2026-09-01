import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';

import '../api/api_client.dart';
import 'runtime_content.dart';

const String kActivePublicManifestRoute = 'content/releases/active/manifest';
const bool kPublicContentFileDeliveryAvailable = true;
final RegExp _digestId = RegExp(r'^sha256:[0-9a-f]{64}$');
final RegExp _hexDigest = RegExp(r'^[0-9a-f]{64}$');

class ApiPublicContentSource implements PublicContentSource {
  const ApiPublicContentSource(this._api);

  final ApiClient _api;

  @override
  Future<Result<PublicManifestFetch>> fetchActiveManifest({
    String? ifNoneMatch,
    RuntimeContentLimits limits = const RuntimeContentLimits(),
  }) async {
    final Result<ApiResponse<Uint8List>> response = await _api.getBytesResponse(
      '/$kActivePublicManifestRoute',
      headers: ifNoneMatch == null ? null : <String, dynamic>{'If-None-Match': ifNoneMatch},
    );
    return response.when(
      success: (ApiResponse<Uint8List> value) {
        final String? etag = value.header('etag');
        if (etag == null || etag.isEmpty) {
          return const Err<PublicManifestFetch>(
            ParseFailure('Le manifeste public ne contient pas d\'ETag.'),
          );
        }
        final String? releaseId = value.header('x-content-release-id');
        final String? publicManifestId = value.header('x-content-manifest-id');
        final String? cacheControl = value.header('cache-control');
        if (releaseId == null ||
            !_digestId.hasMatch(releaseId) ||
            publicManifestId == null ||
            !_digestId.hasMatch(publicManifestId) ||
            cacheControl == null ||
            !cacheControl.contains('private') ||
            !cacheControl.contains('no-cache')) {
          return const Err<PublicManifestFetch>(
            ParseFailure('Les identifiants du manifeste public sont absents.'),
          );
        }
        if (value.statusCode == 304) {
          return Success<PublicManifestFetch>(
            PublicManifestFetch.notModified(
              etag: etag,
              releaseId: releaseId,
              publicManifestId: publicManifestId,
            ),
          );
        }
        final Uint8List? bytes = value.data;
        if (value.statusCode != 200 || bytes == null || bytes.length > limits.maxManifestBytes) {
          return const Err<PublicManifestFetch>(
            ParseFailure('Réponse inattendue pour le manifeste public.'),
          );
        }
        final String? contentType = value.header('content-type');
        if (contentType == null ||
            !contentType.startsWith('application/json') ||
            !cacheControl.contains('no-cache')) {
          return const Err<PublicManifestFetch>(
            ParseFailure('Les en-têtes du manifeste public sont invalides.'),
          );
        }
        PublicContentManifest manifest;
        try {
          manifest = PublicContentManifest.fromJson(
            Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map),
            limits: limits,
          );
        } on FormatException {
          return const Err<PublicManifestFetch>(ParseFailure('Le manifeste public est invalide.'));
        } on TypeError {
          return const Err<PublicManifestFetch>(ParseFailure('Le manifeste public est invalide.'));
        }
        if (etag != '"${manifest.manifestId}"') {
          return const Err<PublicManifestFetch>(
            ParseFailure('L\'ETag ne correspond pas au manifeste public.'),
          );
        }
        if (manifest.releaseId != releaseId || manifest.manifestId != publicManifestId) {
          return const Err<PublicManifestFetch>(
            ParseFailure('Les identifiants du manifeste public sont incohérents.'),
          );
        }
        return Success<PublicManifestFetch>(PublicManifestFetch.fetched(manifest, etag));
      },
      failure: Err<PublicManifestFetch>.new,
    );
  }

  @override
  Future<Result<PublicContentFileFetch>> fetchFile({
    required String releaseId,
    required String publicManifestId,
    required PublicContentFile file,
    String? ifNoneMatch,
  }) async {
    if (!_digestId.hasMatch(releaseId) ||
        !_digestId.hasMatch(publicManifestId) ||
        !_hexDigest.hasMatch(file.hash) ||
        !_isSafePath(file.path)) {
      return const Err<PublicContentFileFetch>(
        ParseFailure('La liaison du fichier public est invalide.'),
      );
    }
    final String encodedPath = file.path.split('/').map(Uri.encodeComponent).join('/');
    final String route = '/content/releases/$releaseId/manifests/$publicManifestId/files/'
        '${file.hash}/$encodedPath';
    final Result<ApiResponse<Uint8List>> response = await _api.getBytesResponse(
      route,
      headers: ifNoneMatch == null ? null : <String, dynamic>{'If-None-Match': ifNoneMatch},
    );
    return response.when(
      success: (ApiResponse<Uint8List> value) {
        final String? etag = value.header('etag');
        final String? responseReleaseId = value.header('x-content-release-id');
        final String? responseManifestId = value.header('x-content-manifest-id');
        final String? responseHash = value.header('x-content-sha256');
        final String? contentType = value.header('content-type');
        final String? cacheControl = value.header('cache-control');
        final String? acceptRanges = value.header('accept-ranges');
        if (etag != '"sha256:${file.hash}"' ||
            responseReleaseId != releaseId ||
            responseManifestId != publicManifestId ||
            responseHash != file.hash ||
            contentType == null ||
            !contentType.startsWith('application/json') ||
            cacheControl == null ||
            !cacheControl.contains('private') ||
            !cacheControl.contains('immutable') ||
            acceptRanges != 'none') {
          return const Err<PublicContentFileFetch>(
            ParseFailure('Les en-têtes du fichier public sont invalides.'),
          );
        }
        if (value.statusCode == 304) {
          return Success<PublicContentFileFetch>(
            PublicContentFileFetch.notModified(
              etag: etag!,
              releaseId: releaseId,
              publicManifestId: publicManifestId,
              resourceType: file.resourceType,
            ),
          );
        }
        final Uint8List? bytes = value.data;
        final int? contentLength = int.tryParse(value.header('content-length') ?? '');
        if (value.statusCode != 200 ||
            bytes == null ||
            contentLength != file.size ||
            bytes.length != file.size) {
          return const Err<PublicContentFileFetch>(
            ParseFailure('Le fichier public ne correspond pas au manifeste.'),
          );
        }
        return Success<PublicContentFileFetch>(
          PublicContentFileFetch.fetched(
            bytes: bytes,
            etag: etag!,
            releaseId: releaseId,
            publicManifestId: publicManifestId,
            resourceType: file.resourceType,
          ),
        );
      },
      failure: Err<PublicContentFileFetch>.new,
    );
  }
}

bool _isSafePath(String path) {
  final List<String> segments = path.split('/');
  return path.isNotEmpty &&
      !path.startsWith('/') &&
      !path.contains(r'\') &&
      !path.contains('%') &&
      !path.runes.any((int rune) => rune < 0x20 || rune == 0x7f) &&
      segments.every((String segment) => segment.isNotEmpty && segment != '.' && segment != '..');
}
