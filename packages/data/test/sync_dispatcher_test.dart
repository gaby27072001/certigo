import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:test/test.dart';

void main() {
  group('classifyFailure', () {
    test('network failures are retryable', () {
      expect(classifyFailure(const NetworkFailure()), SyncDispatch.retryable);
    });

    test('auth failures are retryable (a later token refresh may unblock)', () {
      expect(classifyFailure(const AuthFailure()), SyncDispatch.retryable);
    });

    test('unknown failures are retryable by default', () {
      expect(classifyFailure(const UnknownFailure()), SyncDispatch.retryable);
    });

    test('not-found, parse and cache failures are permanent', () {
      expect(classifyFailure(const NotFoundFailure()), SyncDispatch.permanent);
      expect(classifyFailure(const ParseFailure()), SyncDispatch.permanent);
      expect(classifyFailure(const CacheFailure()), SyncDispatch.permanent);
    });

    test('server 5xx and 429 are retryable', () {
      expect(classifyFailure(const ServerFailure('boom', statusCode: 500)), SyncDispatch.retryable);
      expect(classifyFailure(const ServerFailure('busy', statusCode: 503)), SyncDispatch.retryable);
      expect(classifyFailure(const ServerFailure('slow', statusCode: 429)), SyncDispatch.retryable);
    });

    test('server other 4xx are permanent', () {
      expect(classifyFailure(const ServerFailure('bad', statusCode: 400)), SyncDispatch.permanent);
      expect(
        classifyFailure(const ServerFailure('unprocessable', statusCode: 422)),
        SyncDispatch.permanent,
      );
    });

    test('server failure without a status code is retryable', () {
      expect(classifyFailure(const ServerFailure('weird')), SyncDispatch.retryable);
    });
  });
}
