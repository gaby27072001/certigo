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
  final List<Map<String, dynamic>> requestHeaders = <Map<String, dynamic>>[];
  bool returnNotModified = false;
  bool returnFileNotModified = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    requestHeaders.add(Map<String, dynamic>.from(options.headers));
    if (options.path == '/$kActivePublicManifestRoute') {
      if (returnNotModified) {
        return ResponseBody.fromBytes(
          const <int>[],
          304,
          headers: <String, List<String>>{
            'etag': <String>['"${manifest.manifestId}"'],
            'cache-control': <String>['private, no-cache'],
            'x-content-release-id': <String>[manifest.releaseId!],
            'x-content-manifest-id': <String>[manifest.manifestId],
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
          'x-content-release-id': <String>[manifest.releaseId!],
          'x-content-manifest-id': <String>[manifest.manifestId],
        },
      );
    }
    final String filePath = '/content/releases/${manifest.releaseId}/manifests/'
        '${manifest.manifestId}/files/${fixture.hash}/${fixture.path}';
    if (options.path == filePath) {
      final Map<String, List<String>> headers = <String, List<String>>{
        'etag': <String>['"sha256:${fixture.hash}"'],
        'cache-control': <String>['private, max-age=31536000, immutable'],
        'accept-ranges': <String>['none'],
        Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
        'x-content-sha256': <String>[fixture.hash],
        'x-content-release-id': <String>[manifest.releaseId!],
        'x-content-manifest-id': <String>[manifest.manifestId],
      };
      if (returnFileNotModified) {
        return ResponseBody.fromBytes(const <int>[], 304, headers: headers);
      }
      headers['content-length'] = <String>[fixture.bytes.length.toString()];
      return ResponseBody.fromBytes(fixture.bytes, 200, headers: headers);
    }
    return ResponseBody.fromString('Not found', 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('Dart routes and supported schemas match the #333 contract fixture', () async {
    final Map<String, dynamic> contract = Map<String, dynamic>.from(
      jsonDecode(
        await File('test/fixtures/runtime_content_backend_contract.json').readAsString(),
      ) as Map,
    );

    expect(contract['backendPullRequest'], 333);
    expect(contract['activeManifestRoute'], kActivePublicManifestRoute);
    expect(
      contract['publicFileRouteTemplate'],
      'content/releases/{releaseId}/manifests/{publicManifestId}/files/{hash}/{*path}',
    );
    expect(contract['releaseIdExposed'], isTrue);
    expect(contract['lessonSnapshotHeader'], 'X-Content-Manifest-Id');
    expect(contract['quizRevisionField'], 'publicManifestId');
    expect(
      contract['manifestSchemas'],
      <String>[kPackageManifestV1, kPackageManifestV2, kPackageManifestV3],
    );
    expect(
      contract['activeManifestHeaders'],
      containsAll(<String>[
        'ETag',
        'Cache-Control',
        'X-Content-Release-Id',
        'X-Content-Manifest-Id',
      ]),
    );
    expect(kPublicContentFileDeliveryAvailable, isTrue);
  });

  test('source consumes the exact active-manifest headers and honors 304', () async {
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
    adapter.returnNotModified = true;
    final Result<PublicManifestFetch> unchanged = await source.fetchActiveManifest(
      ifNoneMatch: '"${release.manifestId}"',
    );

    expect(fetched.valueOrNull!.manifest!.manifestId, release.manifestId);
    expect(fetched.valueOrNull!.releaseId, release.releaseId);
    expect(unchanged.valueOrNull!.notModified, isTrue);
    expect(unchanged.valueOrNull!.publicManifestId, release.manifestId);
    expect(adapter.paths, <String>[
      '/$kActivePublicManifestRoute',
      '/$kActivePublicManifestRoute',
    ]);
  });

  test('file delivery is release-pinned and honors immutable ETag revalidation', () async {
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

    final Result<PublicContentFileFetch> result = await source.fetchFile(
      releaseId: release.releaseId!,
      publicManifestId: release.manifestId,
      file: release.files.single,
    );
    adapter.returnFileNotModified = true;
    final Result<PublicContentFileFetch> unchanged = await source.fetchFile(
      releaseId: release.releaseId!,
      publicManifestId: release.manifestId,
      file: release.files.single,
      ifNoneMatch: '"sha256:${fixture.hash}"',
    );

    expect(result.valueOrNull!.bytes, fixture.bytes);
    expect(result.valueOrNull!.releaseId, release.releaseId);
    expect(unchanged.valueOrNull!.notModified, isTrue);
    expect(
      adapter.requestHeaders.last['If-None-Match'],
      '"sha256:${fixture.hash}"',
    );
  });

  test('unsafe file bindings fail before any network request', () async {
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
    final PublicContentFile unsafe = PublicContentFile(
      id: fixture.id,
      path: '../solutions/key.json',
      resourceType: fixture.resourceType,
      hash: fixture.hash,
      size: fixture.bytes.length,
    );

    final Result<PublicContentFileFetch> result = await source.fetchFile(
      releaseId: release.releaseId!,
      publicManifestId: release.manifestId,
      file: unsafe,
    );

    expect(result, isA<Err<PublicContentFileFetch>>());
    expect(adapter.paths, isEmpty);
  });
}
