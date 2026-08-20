import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'runtime_content_test_support.dart';

class _ContractAdapter implements HttpClientAdapter {
  _ContractAdapter(this.manifest, this.fixture);

  final PublicContentManifest manifest;
  final ContentFixture fixture;
  final List<String> paths = <String>[];
  bool returnNotModified = false;
  bool omitContentLength = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    if (options.path == '/$kActivePublicManifestRoute') {
      if (returnNotModified) {
        return ResponseBody.fromBytes(
          const <int>[],
          304,
          headers: <String, List<String>>{
            'etag': <String>['"${manifest.manifestId}"'],
          },
        );
      }
      return ResponseBody.fromString(
        jsonEncode(manifest.rawJson),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          'etag': <String>['"${manifest.manifestId}"'],
          'cache-control': <String>['private, no-cache'],
        },
      );
    }
    final PublicContentFile file = manifest.files.single;
    final Map<String, List<String>> headers = <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      'etag': <String>['"${file.hash}"'],
      'cache-control': <String>['private, max-age=31536000, immutable'],
      'x-content-manifest-id': <String>[manifest.manifestId],
      'x-content-resource-type': <String>[file.resourceType],
    };
    if (!omitContentLength) {
      headers[Headers.contentLengthHeader] = <String>[fixture.bytes.length.toString()];
    }
    return ResponseBody.fromBytes(
      fixture.bytes,
      200,
      headers: headers,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('Dart routes and supported schemas match the #304 contract fixture', () async {
    final Map<String, dynamic> contract = Map<String, dynamic>.from(
      jsonDecode(
        await File('test/fixtures/runtime_content_backend_contract.json').readAsString(),
      ) as Map,
    );

    expect(contract['backendPullRequest'], 304);
    expect(contract['activeManifestRoute'], kActivePublicManifestRoute);
    expect(contract['publicFileRoute'], kPublicContentFileRoute);
    expect(
      contract['manifestSchemas'],
      <String>[kPackageManifestV1, kPackageManifestV2, kPackageManifestV3],
    );
    expect(
      contract['activeManifestHeaders'],
      containsAll(<String>['ETag', 'Cache-Control']),
    );
    expect(
      contract['publicFileHeaders'],
      containsAll(<String>[
        'ETag',
        'Cache-Control',
        'Content-Length',
        'Content-Type',
        'X-Content-Manifest-Id',
        'X-Content-Resource-Type',
      ]),
    );
  });

  test('source consumes the exact manifest/file headers and honors 304', () async {
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest release = manifest(<ContentFixture>[fixture]);
    final _ContractAdapter adapter = _ContractAdapter(release, fixture);
    final Dio dio = Dio()..httpClientAdapter = adapter;
    final ApiPublicContentSource source = ApiPublicContentSource(
      ApiClient(
        dio: dio,
        baseUrl: 'https://api.example.test',
        tokenProvider: () async => 'token',
      ),
    );

    final Result<PublicManifestFetch> fetched = await source.fetchActiveManifest();
    final Result<PublicContentFileFetch> file = await source.fetchFile(
      publicManifestId: release.manifestId,
      file: release.files.single,
    );
    adapter.returnNotModified = true;
    final Result<PublicManifestFetch> unchanged = await source.fetchActiveManifest(
      ifNoneMatch: '"${release.manifestId}"',
    );

    expect(fetched.valueOrNull!.manifest!.manifestId, release.manifestId);
    expect(file.valueOrNull!.bytes, fixture.bytes);
    expect(unchanged.valueOrNull!.notModified, isTrue);
    expect(adapter.paths.first, '/$kActivePublicManifestRoute');
    expect(
      adapter.paths[1],
      '/content/releases/${Uri.encodeComponent(release.manifestId)}/files/'
      '${Uri.encodeComponent(fixture.id)}',
    );
  });

  test('source accepts chunked delivery without Content-Length', () async {
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest release = manifest(<ContentFixture>[fixture]);
    final _ContractAdapter adapter = _ContractAdapter(release, fixture)..omitContentLength = true;
    final Dio dio = Dio()..httpClientAdapter = adapter;
    final ApiPublicContentSource source = ApiPublicContentSource(
      ApiClient(
        dio: dio,
        baseUrl: 'https://api.example.test',
        tokenProvider: () async => 'token',
      ),
    );

    final Result<PublicContentFileFetch> result = await source.fetchFile(
      publicManifestId: release.manifestId,
      file: release.files.single,
    );

    expect(result.isSuccess, isTrue);
  });
}
