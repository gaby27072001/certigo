import 'dart:convert';
import 'dart:typed_data';

import 'package:data/data.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

class _ProfileAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'id': 'user-1',
        'displayName': 'Learner',
        'handle': 'learner',
        'activeTrackId': (options.data as Map<String, dynamic>)['trackId'],
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('setActiveTrack posts the selected id and returns the updated profile', () async {
    final _ProfileAdapter adapter = _ProfileAdapter();
    final Dio dio = Dio()..httpClientAdapter = adapter;
    final RemoteUserRepository repository = RemoteUserRepository(
      ApiClient(dio: dio, baseUrl: 'https://example.test', tokenProvider: () async => 'token'),
    );

    final result = await repository.setActiveTrack(
      trackId: 'dp-900',
      expectedTrackId: 'az-900',
    );

    expect(result.valueOrNull?.activeTrackId, 'dp-900');
    expect(adapter.request?.method, 'POST');
    expect(adapter.request?.path, '/me/active-track');
    expect(adapter.request?.data, <String, dynamic>{
      'trackId': 'dp-900',
      'expectedTrackId': 'az-900',
    });
  });
}
