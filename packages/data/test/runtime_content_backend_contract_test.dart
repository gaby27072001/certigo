import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'runtime_content_test_support.dart';

class _ContractAdapter implements HttpClientAdapter {
  _ContractAdapter(this.manifest);

  final PublicContentManifest manifest;
  final List<String> paths = <String>[];
  bool returnNotModified = false;

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
    return ResponseBody.fromString('Not found', 404);
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
    expect(contract['publicFileRoute'], isNull);
    expect(contract['releaseIdExposed'], isFalse);
    expect(contract['lessonSnapshotHeader'], 'X-Content-Manifest-Id');
    expect(contract['quizRevisionField'], 'publicManifestId');
    expect(
      contract['manifestSchemas'],
      <String>[kPackageManifestV1, kPackageManifestV2, kPackageManifestV3],
    );
    expect(
      contract['activeManifestHeaders'],
      containsAll(<String>['ETag', 'Cache-Control']),
    );
    expect(kPublicContentFileDeliveryAvailable, isFalse);
  });

  test('source consumes the exact active-manifest headers and honors 304', () async {
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest release = manifest(<ContentFixture>[fixture]);
    final _ContractAdapter adapter = _ContractAdapter(release);
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
    expect(unchanged.valueOrNull!.notModified, isTrue);
    expect(adapter.paths, <String>[
      '/$kActivePublicManifestRoute',
      '/$kActivePublicManifestRoute',
    ]);
  });

  test('file delivery fails closed because #304 exposes no file endpoint', () async {
    final ContentFixture fixture = questionFixture('microsoft.az-900.section-1.cloud.001');
    final PublicContentManifest release = manifest(<ContentFixture>[fixture]);
    final _ContractAdapter adapter = _ContractAdapter(release);
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

    expect(result.isFailure, isTrue);
    final Failure failure = (result as Err<PublicContentFileFetch>).failure;
    expect(failure, isA<NotFoundFailure>());
    expect(failure.message, kPublicContentFileDeliveryBlocker);
    expect(adapter.paths, isEmpty);
  });
}
