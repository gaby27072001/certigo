import 'dart:typed_data';

import 'package:data/data.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// Fake Dio adapter that records the last outbound [RequestOptions] and returns
/// an empty JSON body. Lets tests assert on request headers with no real network
/// and no Flutter dependency (hermetic — safe to run via `dart test`).
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('generateCorrelationId', () {
    test('is 32 lowercase hex characters', () {
      final id = generateCorrelationId();
      expect(id, hasLength(32));
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(id), isTrue);
    });

    test('produces distinct ids across calls', () {
      final ids = <String>{
        for (var i = 0; i < 200; i++) generateCorrelationId(),
      };
      expect(ids, hasLength(200));
    });
  });

  group('CorrelationIdInterceptor', () {
    test('mints x-correlation-id when the request has none', () {
      final interceptor = CorrelationIdInterceptor(generate: () => 'a' * 32);
      final options = RequestOptions(path: '/ping');
      interceptor.onRequest(options, RequestInterceptorHandler());
      expect(options.headers[kCorrelationIdHeader], 'a' * 32);
    });

    test('preserves a caller-supplied correlation id', () {
      final interceptor = CorrelationIdInterceptor(generate: () => 'a' * 32);
      final options = RequestOptions(
        path: '/ping',
        headers: {kCorrelationIdHeader: 'caller-supplied-id'},
      );
      interceptor.onRequest(options, RequestInterceptorHandler());
      expect(options.headers[kCorrelationIdHeader], 'caller-supplied-id');
    });
  });

  group('ApiClient wiring', () {
    ApiClient buildClient(
      _CapturingAdapter adapter, {
      CorrelationIdGenerator? generator,
    }) {
      final dio = Dio();
      dio.httpClientAdapter = adapter;
      return ApiClient(
        dio: dio,
        baseUrl: 'https://example.test',
        tokenProvider: () async => null,
        correlationIdGenerator: generator,
      );
    }

    test('stamps outbound requests with a 32-hex x-correlation-id', () async {
      final adapter = _CapturingAdapter();
      final client = buildClient(adapter);
      await client.getJson<Map<String, dynamic>>('/ping', (json) => json);
      final header = adapter.lastOptions?.headers[kCorrelationIdHeader];
      expect(header, isA<String>());
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(header as String), isTrue);
    });

    test('propagates an explicit generator value onto the wire', () async {
      final adapter = _CapturingAdapter();
      final client = buildClient(adapter, generator: () => 'b' * 32);
      await client.getJson<Map<String, dynamic>>('/ping', (json) => json);
      expect(adapter.lastOptions?.headers[kCorrelationIdHeader], 'b' * 32);
    });
  });
}
