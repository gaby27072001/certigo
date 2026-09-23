import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// Replies with one scripted status and JSON body, and records the request.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.status, this.body);

  final int status;
  final Object body;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _UnreachableAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
  }

  @override
  void close({bool force = false}) {}
}

/// Replies with a raw body and content type, as a gateway or host can.
class _RawAdapter implements HttpClientAdapter {
  _RawAdapter(this.status, this.body, this.contentType);

  final int status;
  final String body;
  final String contentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const StreakRepairRequest _request = StreakRepairRequest(clientRepairId: 'repair-1');

({RemoteStreakRepository repository, _ScriptedAdapter adapter, List<int> unauthorized}) _harness(
  int status,
  Object body,
) {
  final _ScriptedAdapter adapter = _ScriptedAdapter(status, body);
  final List<int> unauthorized = <int>[];
  final RemoteStreakRepository repository = RemoteStreakRepository(
    ApiClient(
      dio: Dio()..httpClientAdapter = adapter,
      baseUrl: 'https://example.test/api',
      tokenProvider: () async => 'token',
      onUnauthorized: () async => unauthorized.add(1),
    ),
  );
  return (repository: repository, adapter: adapter, unauthorized: unauthorized);
}

Failure _failureOf<T>(Result<T> result) => result.when(
      success: (T value) => fail('expected a failure, got $value'),
      failure: (Failure f) => f,
    );

T _valueOf<T>(Result<T> result) => result.when(
      success: (T value) => value,
      failure: (Failure f) => fail('expected a value, got $f'),
    );

void main() {
  group('getStatus', () {
    test('reads GET /streak into the server snapshot', () async {
      final h = _harness(200, <String, dynamic>{
        'streakDays': 12,
        'lastActiveDate': '2025-01-03',
        'freezeTokens': 0,
        'repairable': true,
        'repairCostGems': 50,
        'reason': null,
        'gems': 120,
        'repairExpiresAt': '2025-01-12T00:00:00+00:00',
        'coveredByFreeze': false,
      });

      final StreakStatus status = _valueOf(await h.repository.getStatus());

      expect(h.adapter.request?.method, 'GET');
      expect(h.adapter.request?.path, '/streak');
      expect(status.offer, StreakRepairOffer.available);
      expect(status.gems, 120);
    });
  });

  group('repair', () {
    Map<String, dynamic> ruling({required bool success, String? error}) => <String, dynamic>{
          'success': success,
          'streakDays': 12,
          'gemsSpent': success ? 50 : 0,
          'gemsBalance': success ? 70 : 30,
          'lastActiveDate': success ? '2025-01-05' : '2025-01-03',
          'error': error,
        };

    test('posts only the idempotency key to POST /streak/repair', () async {
      final h = _harness(200, ruling(success: true));

      await h.repository.repair(_request);

      expect(h.adapter.request?.method, 'POST');
      expect(h.adapter.request?.path, '/streak/repair');
      expect(h.adapter.request?.data, <String, dynamic>{'clientRepairId': 'repair-1'});
    });

    test('a granted repair is a successful ruling', () async {
      final h = _harness(200, ruling(success: true));

      final StreakRepairResult result = _valueOf(await h.repository.repair(_request));

      expect(result.success, isTrue);
      expect(result.gemsBalance, 70);
    });

    test('a 400 carrying the result shape is a refusal the learner can read', () async {
      // The defect this guards: `postJson` maps every 4xx to a ServerFailure and
      // drops the body, which would show "request failed" where the server said
      // exactly why — and would keep the idempotency key alive for a spent ruling.
      final h = _harness(400, ruling(success: false, error: 'insufficientGems'));

      final StreakRepairResult result = _valueOf(await h.repository.repair(_request));

      expect(result.success, isFalse);
      expect(result.refusal, StreakRepairRefusal.insufficientGems);
      expect(result.gemsBalance, 30);
    });

    test('a 400 ProblemDetails is a rejected request, not a ruling', () async {
      final h = _harness(400, <String, dynamic>{
        'title': 'Invalid request',
        'status': 400,
        'detail': 'Request body is required.',
      });

      final Failure failure = _failureOf(await h.repository.repair(_request));

      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, 400);
    });

    final Map<String, ({String body, String contentType})> notAnObject =
        <String, ({String body, String contentType})>{
      'vide': (body: '', contentType: Headers.jsonContentType),
      'HTML d\u2019une passerelle': (
        body: '<html><body>Bad Request</body></html>',
        contentType: 'text/html'
      ),
      'tableau JSON': (body: '[]', contentType: Headers.jsonContentType),
    };
    notAnObject.forEach((String name, ({String body, String contentType}) reply) {
      test('a 400 with a body that is not a JSON object ($name) is a rejected request', () async {
        // Found in review: such a body used to become a ParseFailure, which the
        // screen reads as « mets l'app à jour » — no retry, for a gateway hiccup.
        final RemoteStreakRepository repository = RemoteStreakRepository(
          ApiClient(
            dio: Dio()..httpClientAdapter = _RawAdapter(400, reply.body, reply.contentType),
            baseUrl: 'https://example.test/api',
            tokenProvider: () async => 'token',
          ),
        );

        final Failure failure = _failureOf(await repository.repair(_request));

        expect(failure, isA<ServerFailure>());
        expect((failure as ServerFailure).statusCode, 400);
      });
    });

    test('a 200 whose body is not a JSON object still breaks the contract', () async {
      final RemoteStreakRepository repository = RemoteStreakRepository(
        ApiClient(
          dio: Dio()..httpClientAdapter = _RawAdapter(200, '[]', Headers.jsonContentType),
          baseUrl: 'https://example.test/api',
          tokenProvider: () async => 'token',
        ),
      );

      expect(_failureOf(await repository.repair(_request)), isA<ParseFailure>());
    });

    test('a 200 without the result shape breaks the contract', () async {
      final h = _harness(200, <String, dynamic>{'ok': true});

      expect(_failureOf(await h.repository.repair(_request)), isA<ParseFailure>());
    });

    test('a mistyped field breaks the contract instead of throwing', () async {
      final h = _harness(400, ruling(success: false, error: 'expired')..['gemsBalance'] = 'trente');

      expect(_failureOf(await h.repository.repair(_request)), isA<ParseFailure>());
    });

    test('a 401 still reaches the re-authentication hook', () async {
      final h = _harness(401, <String, dynamic>{'title': 'Unauthorized'});

      final Failure failure = _failureOf(await h.repository.repair(_request));

      expect(failure, isA<AuthFailure>());
      expect(h.unauthorized, hasLength(1), reason: 'accepting 400 must not swallow 401');
    });

    test('a 409 is a failure whose outcome the server did not rule on', () async {
      final h = _harness(409, <String, dynamic>{'title': 'Conflict', 'status': 409});

      final Failure failure = _failureOf(await h.repository.repair(_request));

      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, 409);
    });

    test('a 5xx is a server failure', () async {
      final h = _harness(503, <String, dynamic>{'title': 'Unavailable', 'status': 503});

      final Failure failure = _failureOf(await h.repository.repair(_request));

      expect((failure as ServerFailure).statusCode, 503);
    });

    test('an unreachable server is a network failure', () async {
      final RemoteStreakRepository repository = RemoteStreakRepository(
        ApiClient(
          dio: Dio()..httpClientAdapter = _UnreachableAdapter(),
          baseUrl: 'https://example.test/api',
          tokenProvider: () async => null,
        ),
      );

      final Failure failure = _failureOf(await repository.repair(_request));

      expect(failure, isA<NetworkFailure>());
    });
  });
}
