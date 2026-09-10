import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// Adaptateur Dio qui échoue toujours avec un type d'exception imposé.
///
/// Permet d'exercer la classification des échecs de transport sans réseau réel
/// et sans dépendance Flutter (hermétique — exécutable via `dart test`).
class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter(this.type);

  final DioExceptionType type;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(requestOptions: options, type: type);
  }

  @override
  void close({bool force = false}) {}
}

Future<Failure> failureFor(DioExceptionType type) async {
  final Dio dio = Dio()..httpClientAdapter = _FailingAdapter(type);
  final ApiClient client = ApiClient(
    dio: dio,
    tokenProvider: () async => null,
    baseUrl: 'https://example.invalid/api',
  );
  final Result<Map<String, dynamic>> result =
      await client.getJson<Map<String, dynamic>>('/ping', (Map<String, dynamic> json) => json);
  return result.when(
    success: (Map<String, dynamic> _) => fail('attendu : un échec, obtenu : une réussite'),
    failure: (Failure f) => f,
  );
}

void main() {
  group('classification des échecs de transport', () {
    // Non-régression du défaut mesuré : les trois causes étaient écrasées en un
    // seul NetworkFailure, ce qui faisait afficher « vérifiez votre réseau » à
    // un utilisateur dont la connexion venait pourtant d'aboutir.
    test('une absence de connectivité reste « injoignable »', () async {
      final Failure f = await failureFor(DioExceptionType.connectionError);
      expect(f, isA<NetworkFailure>());
      expect((f as NetworkFailure).kind, NetworkFailureKind.unreachable);
    });

    test('un délai de connexion est distingué de l\'absence de connectivité', () async {
      final Failure f = await failureFor(DioExceptionType.connectionTimeout);
      expect(f, isA<NetworkFailure>());
      expect((f as NetworkFailure).kind, NetworkFailureKind.connectTimeout);
    });

    test('un délai de RÉPONSE est distingué : la connexion, elle, a abouti', () async {
      final Failure f = await failureFor(DioExceptionType.receiveTimeout);
      expect(f, isA<NetworkFailure>());
      expect((f as NetworkFailure).kind, NetworkFailureKind.responseTimeout);
    });

    test('les trois restent des NetworkFailure de code « network »', () async {
      // Garantit que les appelants existants — dont `classifyFailure`, qui
      // classe NetworkFailure comme reprenable — ne changent pas de
      // comportement du fait de cette distinction.
      for (final DioExceptionType type in <DioExceptionType>[
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final Failure f = await failureFor(type);
        expect(f, isA<NetworkFailure>(), reason: '$type');
        expect(f.code, 'network', reason: '$type');
        expect(classifyFailure(f), SyncDispatch.retryable, reason: '$type');
      }
    });
  });
}
