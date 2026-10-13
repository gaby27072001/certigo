import 'package:certigo/features/auth/application/auth_diagnostics.dart';
import 'package:certigo/features/auth/application/auth_gateway.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';

/// AppAuth factice : capture chaque requête et rejoue un résultat scripté, sans
/// canal de plateforme. C'est la requête réellement passée au SDK qui est
/// vérifiée, pas une reconstruction.
class _RecordingAppAuth extends FlutterAppAuth {
  _RecordingAppAuth({this.authorizeError, this.authorizationCode = 'code'});

  final Object? authorizeError;
  final String? authorizationCode;
  final List<AuthorizationRequest> authorizeRequests = <AuthorizationRequest>[];
  final List<TokenRequest> tokenRequests = <TokenRequest>[];

  @override
  Future<AuthorizationResponse> authorize(AuthorizationRequest request) async {
    authorizeRequests.add(request);
    final Object? error = authorizeError;
    if (error != null) throw error;
    return AuthorizationResponse(
      authorizationCode: authorizationCode,
      codeVerifier: 'verifier',
      nonce: 'nonce',
    );
  }

  @override
  Future<TokenResponse> token(TokenRequest request) async {
    tokenRequests.add(request);
    return TokenResponse('access', 'refresh', null, null, 'Bearer', null, null);
  }
}

/// Puits de diagnostic factice : garde l'ordre des étapes tracées.
class _RecordingDiagnostics implements AuthDiagnostics {
  final List<AuthDiagnosticStep> steps = <AuthDiagnosticStep>[];

  @override
  void mark(AuthDiagnosticStep step, {String? detail}) => steps.add(step);
}

Future<AuthGatewayException> _failure(Future<AuthSession> attempt) async {
  try {
    await attempt;
  } on AuthGatewayException catch (error) {
    return error;
  }
  fail('la tentative aurait dû échouer');
}

void main() {
  group('requête d’autorisation envoyée à CIAM', () {
    Future<AuthorizationRequest> authorizeFor(
      AuthProvider provider, {
      bool reauthenticate = false,
    }) async {
      final _RecordingAppAuth appAuth = _RecordingAppAuth();
      final AppAuthGateway gateway = AppAuthGateway(appAuth: appAuth);
      if (reauthenticate) {
        await gateway.reauthenticate(provider);
      } else {
        await gateway.signIn(provider);
      }
      expect(appAuth.tokenRequests, hasLength(1));
      return appAuth.authorizeRequests.single;
    }

    test('Apple : prompt=login et domain_hint=apple, qui mènent au formulaire Apple', () async {
      final AuthorizationRequest request = await authorizeFor(AuthProvider.apple);

      // Mesuré le 2026-09-27 dans un navigateur sans cookies : avec
      // `select_account`, CIAM ignorait l'indice et réaffichait sa page de
      // choix (« c'est une boucle ») ; `apple.com` menait à AppleConnect.
      expect(request.promptValues, <String>['login']);
      expect(request.additionalParameters, <String, String>{'domain_hint': 'apple'});
    });

    test('Microsoft : prompt=login et domain_hint=live.com (comptes personnels)', () async {
      final AuthorizationRequest request = await authorizeFor(AuthProvider.microsoft);

      expect(request.promptValues, <String>['login']);
      expect(request.additionalParameters, <String, String>{'domain_hint': 'live.com'});
    });

    test('Google : prompt=login et domain_hint=google (valeur documentée)', () async {
      final AuthorizationRequest request = await authorizeFor(AuthProvider.google);

      expect(request.promptValues, <String>['login']);
      expect(request.additionalParameters, <String, String>{'domain_hint': 'google'});
    });

    test('ré-authentification avant suppression : login, max_age=0 et domain_hint=apple', () async {
      final AuthorizationRequest request = await authorizeFor(
        AuthProvider.apple,
        reauthenticate: true,
      );

      expect(request.promptValues, <String>['login']);
      expect(
        request.additionalParameters,
        <String, String>{'domain_hint': 'apple', 'max_age': '0'},
      );
    });

    test('iOS : session web éphémère, sans cookies partagés (condition des mesures)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final AuthorizationRequest request = await authorizeFor(AuthProvider.apple);

      expect(request.externalUserAgent, ExternalUserAgent.ephemeralAsWebAuthenticationSession);
    });
  });

  group('signature d’un échec, sans donnée personnelle', () {
    test('annulation iOS : identifiants AppAuth gardés, textes libres écartés', () async {
      final _RecordingDiagnostics diagnostics = _RecordingDiagnostics();
      final AppAuthGateway gateway = AppAuthGateway(
        diagnostics: diagnostics,
        appAuth: _RecordingAppAuth(
          authorizeError: FlutterAppAuthUserCancelledException(
            code: 'authorize_failed',
            message: 'Failed to authorize: user@example.com',
            platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
              type: 'org.openid.appauth.general',
              code: '-3',
              errorDescription: 'user@example.com https://certigoapp.ciamlogin.com/?code=x',
              domain: 'com.apple.AuthenticationServices.WebAuthenticationSession',
              rootCauseDebugDescription: 'user@example.com',
              errorDebugDescription: 'user@example.com',
            ),
          ),
        ),
      );

      final AuthGatewayException error = await _failure(gateway.signIn(AuthProvider.apple));

      expect(error.cause, AuthFailureCause.cancelled);
      final AuthFailureSignature signature = error.signature!;
      expect(signature.pluginCode, 'authorize_failed');
      expect(signature.nativeType, 'org.openid.appauth.general');
      expect(signature.nativeCode, '-3');
      expect(
        signature.underlyingDomain,
        'com.apple.AuthenticationServices.WebAuthenticationSession',
      );
      expect(signature.oauthError, isNull);
      expect(signature.errorType, 'FlutterAppAuthUserCancelledException');
      expect(
        diagnostics.steps,
        <AuthDiagnosticStep>[AuthDiagnosticStep.authorizeOpened, AuthDiagnosticStep.failed],
      );
    });

    test('refus du serveur : le code OAuth est gardé, sa description non', () async {
      final AppAuthGateway gateway = AppAuthGateway(
        appAuth: _RecordingAppAuth(
          authorizeError: FlutterAppAuthPlatformException(
            code: 'authorize_failed',
            message: 'Invalid web redirect url',
            platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
              type: 'org.openid.appauth.oauth_authorization',
              code: '-2',
              error: 'invalid_request',
              errorDescription: 'Invalid web redirect url',
            ),
          ),
        ),
      );

      final AuthGatewayException error = await _failure(gateway.signIn(AuthProvider.apple));

      expect(error.cause, AuthFailureCause.providerError);
      expect(error.signature?.oauthError, 'invalid_request');
      expect(error.signature?.nativeType, 'org.openid.appauth.oauth_authorization');
      expect(error.signature?.nativeCode, '-2');
      expect(error.signature?.errorType, 'FlutterAppAuthPlatformException');
    });

    test('retour sans code d’autorisation : signature dédiée', () async {
      final AppAuthGateway gateway = AppAuthGateway(
        appAuth: _RecordingAppAuth(authorizationCode: null),
      );

      final AuthGatewayException error = await _failure(gateway.signIn(AuthProvider.google));

      expect(error.cause, AuthFailureCause.providerError);
      expect(error.signature?.errorType, 'MissingAuthorizationCode');
    });
  });
}
