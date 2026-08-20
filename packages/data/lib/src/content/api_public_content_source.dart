import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';

import '../api/api_client.dart';
import 'runtime_content.dart';

const String kActivePublicManifestRoute = 'content/releases/active/manifest';
const String kPublicContentFileRoute = 'content/releases/{publicManifestId}/files/{fileId}';

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
        if (value.statusCode == 304) {
          return Success<PublicManifestFetch>(PublicManifestFetch.notModified(etag));
        }
        final Uint8List? bytes = value.data;
        if (value.statusCode != 200 || bytes == null || bytes.length > limits.maxManifestBytes) {
          return const Err<PublicManifestFetch>(
            ParseFailure('Réponse inattendue pour le manifeste public.'),
          );
        }
        final String? contentType = value.header('content-type');
        final String? cacheControl = value.header('cache-control');
        if (contentType == null ||
            !contentType.startsWith('application/json') ||
            cacheControl == null ||
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
          return const Err<PublicManifestFetch>(
            ParseFailure('Le manifeste public est invalide.'),
          );
        } on TypeError {
          return const Err<PublicManifestFetch>(
            ParseFailure('Le manifeste public est invalide.'),
          );
        }
        if (etag != '"${manifest.manifestId}"') {
          return const Err<PublicManifestFetch>(
            ParseFailure('L\'ETag ne correspond pas au manifeste public.'),
          );
        }
        return Success<PublicManifestFetch>(PublicManifestFetch.fetched(manifest, etag));
      },
      failure: Err<PublicManifestFetch>.new,
    );
  }

  @override
  Future<Result<PublicContentFileFetch>> fetchFile({
    required String publicManifestId,
    required PublicContentFile file,
  }) async {
    final String manifest = Uri.encodeComponent(publicManifestId);
    final String fileId = Uri.encodeComponent(file.id);
    final Result<ApiResponse<Uint8List>> response = await _api.getBytesResponse(
      '/${kPublicContentFileRoute.replaceAll('{publicManifestId}', manifest).replaceAll('{fileId}', fileId)}',
    );
    return response.when(
      success: (ApiResponse<Uint8List> value) {
        final Uint8List? bytes = value.data;
        if (value.statusCode != 200 || bytes == null) {
          return const Err<PublicContentFileFetch>(
            ParseFailure('Réponse inattendue pour un fichier de contenu public.'),
          );
        }
        final String? etag = value.header('etag');
        final String? responseManifest = value.header('x-content-manifest-id');
        final String? resourceType = value.header('x-content-resource-type');
        final String? contentLength = value.header('content-length');
        final String? contentType = value.header('content-type');
        final String? cacheControl = value.header('cache-control');
        if (etag != '"${file.hash}"' ||
            responseManifest != publicManifestId ||
            resourceType != file.resourceType ||
            contentType == null ||
            !contentType.startsWith('application/json') ||
            cacheControl == null ||
            !cacheControl.contains('immutable') ||
            (contentLength != null && contentLength != file.size.toString())) {
          return const Err<PublicContentFileFetch>(
            ParseFailure('Les en-têtes du fichier public ne correspondent pas au manifeste.'),
          );
        }
        return Success<PublicContentFileFetch>(
          PublicContentFileFetch(
            bytes: bytes,
            etag: etag!,
            publicManifestId: responseManifest!,
            resourceType: resourceType!,
          ),
        );
      },
      failure: Err<PublicContentFileFetch>.new,
    );
  }
}
