import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('Success exposes its value and the success flags', () {
      const Result<int> r = Success<int>(42);
      expect(r.isSuccess, isTrue);
      expect(r.isFailure, isFalse);
      expect(r.valueOrNull, 42);
    });

    test('Err exposes no value and the failure flags', () {
      const Result<int> r = Err<int>(NetworkFailure());
      expect(r.isSuccess, isFalse);
      expect(r.isFailure, isTrue);
      expect(r.valueOrNull, isNull);
    });

    test('when routes a Success to the success branch', () {
      const Result<int> r = Success<int>(7);
      final String out = r.when(
        success: (int v) => 'ok:$v',
        failure: (Failure f) => 'err:${f.code}',
      );
      expect(out, 'ok:7');
    });

    test('when routes an Err to the failure branch with the failure instance', () {
      const Result<int> r = Err<int>(AuthFailure());
      final String out = r.when(
        success: (int v) => 'ok:$v',
        failure: (Failure f) => 'err:${f.code}',
      );
      expect(out, 'err:auth');
    });

    test('map transforms a success value, preserving the Result shape', () {
      const Result<int> r = Success<int>(3);
      final Result<String> mapped = r.map((int v) => 'n$v');
      expect(mapped.isSuccess, isTrue);
      expect(mapped.valueOrNull, 'n3');
    });

    test('map leaves a failure untouched', () {
      const Result<int> r = Err<int>(NotFoundFailure());
      final Result<String> mapped = r.map((int v) => 'n$v');
      expect(mapped.isFailure, isTrue);
      expect(mapped.valueOrNull, isNull);
    });
  });

  group('Failure', () {
    test('each typed failure carries a stable code and default message', () {
      expect(const NetworkFailure().code, 'network');
      expect(const NetworkFailure().message, 'Connexion indisponible');
      expect(const AuthFailure().code, 'auth');
      expect(const NotFoundFailure().code, 'not_found');
      expect(const CacheFailure().code, 'cache');
      expect(const ParseFailure().code, 'parse');
      expect(const UnknownFailure().code, 'unknown');
    });

    test('a custom message overrides the default', () {
      expect(const NetworkFailure('hors-ligne').message, 'hors-ligne');
    });

    test('ServerFailure keeps its HTTP status code', () {
      const ServerFailure f = ServerFailure('boom', statusCode: 503);
      expect(f.code, 'server');
      expect(f.statusCode, 503);
    });

    test('toString surfaces the code and the message for diagnostics', () {
      final String text = const NetworkFailure().toString();
      expect(text, contains('network'));
      expect(text, contains('Connexion indisponible'));
    });
  });

  group('AppEnv', () {
    test('defaults to the dev flavor when no dart-define is provided', () {
      expect(AppEnv.flavor, AppFlavor.dev);
      expect(AppEnv.isProd, isFalse);
      expect(AppEnv.analyticsEnabled, isFalse);
    });

    test('ships sensible default endpoints and Entra scopes', () {
      expect(AppEnv.apiBaseUrl, isNotEmpty);
      expect(AppEnv.entraRedirectUri, 'certigo://auth');
      expect(AppEnv.entraScopes, contains('openid'));
    });
  });
}
