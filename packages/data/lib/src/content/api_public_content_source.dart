import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';

import '../api/api_client.dart';
import 'runtime_content.dart';

const String kActivePublicManifestRoute = 'content/releases/active/manifest';
const bool kPublicContentFileDeliveryAvailable = false;
const String kPublicContentFileDeliveryBlocker =
    'Le contrat backend #304 n\'expose aucun endpoint API pour les fichiers du manifeste public.';

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
  }) async =>
      const Err<PublicContentFileFetch>(
        NotFoundFailure(kPublicContentFileDeliveryBlocker),
      );
}
