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
      expect(AppEnv.entraRedirectUri, 'certigo://auth/');
      expect(AppEnv.entraScopes, contains('openid'));
      expect(AppEnv.accountDeletionEnabled, isFalse);
      expect(
        AppEnv.capabilityRuntimePolicy.availabilityOf(
          ReleaseProfile.full,
          AppCapability.accountDeletion,
        ),
        CapabilityAvailability.off,
      );
    });
  });

  group('AppEnv.validateConfig', () {
    // Config prod complète et valide : sert de base à muter par cas.
    AppConfigReport validate({
      AppFlavor flavor = AppFlavor.prod,
      String apiBaseUrl = 'https://api.example.invalid/api',
      String entraClientId = 'client-123',
      String entraAuthority = 'https://tenant.ciamlogin.com/tid/v2.0',
      String entraRedirectUri = 'certigo://auth/',
      String entraApiScope = 'api://client-123/user_impersonation',
      bool entraOptional = false,
      String releaseProfileName = 'full',
    }) =>
        AppEnv.validateConfig(
          flavor: flavor,
          apiBaseUrl: apiBaseUrl,
          entraClientId: entraClientId,
          entraAuthority: entraAuthority,
          entraRedirectUri: entraRedirectUri,
          entraApiScope: entraApiScope,
          entraOptional: entraOptional,
          releaseProfileName: releaseProfileName,
        );

    bool hasError(AppConfigReport r, String key) =>
        r.errors.any((AppConfigIssue i) => i.key == key);
    bool hasWarning(AppConfigReport r, String key) =>
        r.warnings.any((AppConfigIssue i) => i.key == key);

    test('une config prod complète est valide (aucune erreur)', () {
      final AppConfigReport r = validate();
      expect(r.isValid, isTrue);
      expect(r.errors, isEmpty);
    });

    test('prod sans Entra → erreur bloquante ENTRA_CLIENT_ID', () {
      final AppConfigReport r = validate(entraClientId: '', entraAuthority: '');
      expect(r.isValid, isFalse);
      expect(hasError(r, 'ENTRA_CLIENT_ID'), isTrue);
    });

    test('prod sans Entra mais ENTRA_OPTIONAL=true → avertissement, pas d\'erreur', () {
      final AppConfigReport r = validate(
        entraClientId: '',
        entraAuthority: '',
        entraApiScope: '',
        entraOptional: true,
      );
      expect(r.isValid, isTrue);
      expect(hasWarning(r, 'ENTRA_CLIENT_ID'), isTrue);
    });

    test('prod pointant sur l\'API dev par défaut → erreur bloquante', () {
      final AppConfigReport r = validate(apiBaseUrl: AppEnv.devApiBaseUrl);
      expect(r.isValid, isFalse);
      expect(hasError(r, 'API_BASE_URL'), isTrue);
    });

    test('prod avec API en HTTP (non https) → erreur bloquante', () {
      final AppConfigReport r = validate(apiBaseUrl: 'http://api.example.invalid/api');
      expect(hasError(r, 'API_BASE_URL'), isTrue);
    });

    test('API_BASE_URL vide → erreur bloquante quel que soit le flavor', () {
      final AppConfigReport r = validate(flavor: AppFlavor.dev, apiBaseUrl: '');
      expect(hasError(r, 'API_BASE_URL'), isTrue);
    });

    test('Entra partiel (client sans autorité) → erreur bloquante', () {
      final AppConfigReport r = validate(entraAuthority: '');
      expect(r.isValid, isFalse);
      expect(hasError(r, 'ENTRA_AUTHORITY'), isTrue);
    });

    test('schéma de redirection non-certigo avec Entra configuré → erreur', () {
      final AppConfigReport r = validate(entraRedirectUri: 'microlingo://auth');
      expect(r.isValid, isFalse);
      expect(hasError(r, 'ENTRA_REDIRECT_URI'), isTrue);
    });

    test('Entra configuré sans API scope → avertissement (risque 401)', () {
      final AppConfigReport r = validate(entraApiScope: '');
      expect(r.isValid, isTrue);
      expect(hasWarning(r, 'ENTRA_API_SCOPE'), isTrue);
    });

    test('dev sans Entra → avertissements seulement, démarrage autorisé', () {
      final AppConfigReport r = validate(
        flavor: AppFlavor.dev,
        apiBaseUrl: AppEnv.devApiBaseUrl,
        entraClientId: '',
        entraAuthority: '',
        entraApiScope: '',
      );
      expect(r.isValid, isTrue);
      expect(r.hasWarnings, isTrue);
    });

    test('profil absent bloque même le flavor dev', () {
      final AppConfigReport report = AppEnv.validate();
      expect(report.isValid, isFalse);
      expect(report.hasReleaseProfileError, isTrue);
      expect(AppEnv.releaseProfileResolution.profile, same(ReleaseProfile.failClosed));
    });

    test('profil inconnu est une erreur bloquante', () {
      final AppConfigReport report = validate(releaseProfileName: 'preview');
      expect(report.isValid, isFalse);
      expect(hasError(report, 'CERTIGO_RELEASE_PROFILE'), isTrue);
    });
  });
}
