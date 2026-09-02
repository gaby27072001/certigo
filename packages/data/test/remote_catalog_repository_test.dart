import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.payload);

  final Map<String, dynamic> payload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode(payload),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

RemoteCatalogRepository _repository(Map<String, dynamic> payload) {
  final Dio dio = Dio()..httpClientAdapter = _JsonAdapter(payload);
  return RemoteCatalogRepository(
    ApiClient(dio: dio, baseUrl: 'https://example.test', tokenProvider: () async => null),
  );
}

Map<String, dynamic> _payload({
  String schema = 'urn:certigo:contract:certification-catalog:app:v2',
  String sourceSchema = 'certigo.certification-catalog/v1',
}) =>
    <String, dynamic>{
      'schema': schema,
      'sourceSchema': sourceSchema,
      'sourceAsOf': '2026-08-17',
      'providers': <dynamic>[],
      'tracks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'gcp:cloud-digital-leader',
          'code': '',
          'provider': 'gcp',
          'status': 'active',
          'contentStatus': 'planned',
          'learningAvailable': false,
          'blueprint': <String, dynamic>{
            'version': '2026-08-17',
            'objectives': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'section-1',
                'title': 'Digital Transformation with Google Cloud',
                'weightPercent': 18.5,
                'weightType': 'approximate',
              },
            ],
          },
        },
      ],
    };

void main() {
  test('decodes the explicit app v2 and canonical source v1 catalog contract', () async {
    final Result<List<TrackSummary>> result = await _repository(_payload()).getCatalog();

    expect(result, isA<Success<List<TrackSummary>>>());
    final TrackSummary track = (result as Success<List<TrackSummary>>).value.single;
    expect(track.id, 'gcp:cloud-digital-leader');
    expect(track.blueprint!.objectives.single.weightPercent, 18.5);
  });

  test('accepts the legacy app v2 identifier during the compatibility window', () async {
    final Result<List<TrackSummary>> result = await _repository(
      _payload(schema: 'certigo.app-certification-catalog/v2'),
    ).getCatalog();

    expect(result, isA<Success<List<TrackSummary>>>());
  });

  test('rejects unknown app and source schemas without a broad fallback', () async {
    final Result<List<TrackSummary>> appResult = await _repository(
      _payload(schema: 'urn:certigo:contract:certification-catalog:app:v1'),
    ).getCatalog();
    final Result<List<TrackSummary>> sourceResult = await _repository(
      _payload(sourceSchema: 'certigo.certification-catalog/v2'),
    ).getCatalog();

    expect((appResult as Err<List<TrackSummary>>).failure, isA<ParseFailure>());
    expect((sourceResult as Err<List<TrackSummary>>).failure, isA<ParseFailure>());
  });
}
