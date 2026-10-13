import 'dart:convert';

import 'package:certigo/bootstrap/sentry_auth_telemetry.dart';
import 'package:certigo/bootstrap/sentry_crash_reporting.dart';
import 'package:certigo/features/auth/application/auth_diagnostics.dart';
import 'package:certigo/features/auth/application/auth_gateway.dart';
import 'package:certigo/features/auth/application/auth_state.dart';
import 'package:certigo/features/auth/application/auth_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

typedef _Captured = ({SocialSignInFailure failure, SentryLevel level, Map<String, String> tags});

/// Puits Sentry des échecs de connexion sociale : il doit rendre un échec sur
/// l'iPhone d'un testeur lisible (étape, type d'erreur), sans jamais emporter
/// de donnée personnelle.
void main() {
  const AuthFailureDetail appleCancelled = AuthFailureDetail(
    lastStep: AuthDiagnosticStep.authorizeOpened,
    signature: AuthFailureSignature(
      pluginCode: 'authorize_failed',
      nativeType: 'org.openid.appauth.general',
      nativeCode: '-3',
      underlyingDomain: 'com.apple.AuthenticationServices.WebAuthenticationSession',
      errorType: 'FlutterAppAuthUserCancelledException',
    ),
  );

  late List<_Captured> captured;
  late bool sentryEnabled;
  late SentryAuthTelemetry telemetry;

  setUp(() {
    captured = <_Captured>[];
    sentryEnabled = true;
    telemetry = SentryAuthTelemetry(
      capture: (SocialSignInFailure failure, SentryLevel level, Map<String, String> tags) async {
        captured.add((failure: failure, level: level, tags: tags));
        return SentryId.newId();
      },
      isEnabled: () => sentryEnabled,
    );
  });

  test('un échec Apple part avec ses seules balises techniques', () async {
    telemetry.authFailure(AuthMethod.apple, AuthFailureCause.cancelled, detail: appleCancelled);
    await Future<void>.delayed(Duration.zero);

    // Annulation : niveau info, car AppAuth iOS y range aussi une page qui ne
    // s'est pas ouverte ; le domaine sous-jacent permet de les distinguer.
    expect(captured.single.level, SentryLevel.info);
    expect(captured.single.failure.toString(), 'SocialSignInFailure');
    expect(captured.single.tags, <String, String>{
      'auth.method': 'apple',
      'auth.cause': 'cancelled',
      'auth.flow': 'signIn',
      'auth.step': 'authorizeOpened',
      'auth.plugin_code': 'authorize_failed',
      'auth.native_type': 'org.openid.appauth.general',
      'auth.native_code': '-3',
      'auth.underlying_domain': 'com.apple.AuthenticationServices.WebAuthenticationSession',
      'auth.error_type': 'FlutterAppAuthUserCancelledException',
    });
  });

  test('un refus pendant la vérification avant suppression part en avertissement', () async {
    telemetry.authFailure(
      AuthMethod.apple,
      AuthFailureCause.providerError,
      detail: const AuthFailureDetail(
        flow: AuthFlow.reauthentication,
        signature: AuthFailureSignature(oauthError: 'invalid_request'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(captured.single.level, SentryLevel.warning);
    expect(captured.single.tags['auth.flow'], 'reauthentication');
    expect(captured.single.tags['auth.oauth_error'], 'invalid_request');
    expect(captured.single.tags.containsKey('auth.step'), isFalse);
  });

  test('rien ne part pour l’e-mail, la restauration, ou quand Sentry est éteint', () async {
    telemetry.authFailure(AuthMethod.email, AuthFailureCause.invalidCredentials);
    telemetry.authFailure(AuthMethod.restore, AuthFailureCause.providerError);
    telemetry.authFailure(AuthMethod.refresh, AuthFailureCause.network);
    sentryEnabled = false;
    telemetry.authFailure(AuthMethod.google, AuthFailureCause.providerError);
    await Future<void>.delayed(Duration.zero);

    expect(captured, isEmpty);
  });

  test('un échec d’envoi vers Sentry ne remonte jamais dans le flux de connexion', () async {
    final List<String> diagnostics = <String>[];
    final SentryAuthTelemetry failing = SentryAuthTelemetry(
      capture: (_, __, ___) async => throw StateError('user@example.com token=secret'),
      isEnabled: () => true,
      diagnosticSink: diagnostics.add,
    );

    failing.authFailure(AuthMethod.apple, AuthFailureCause.providerError);
    await Future<void>.delayed(Duration.zero);
    expect(diagnostics, <String>['[crash] Sentry capture failed (StateError).']);
  });

  test('un rejet Sentry est diagnostiqué sans contenu de la tentative', () async {
    final List<String> diagnostics = <String>[];
    final SentryAuthTelemetry rejected = SentryAuthTelemetry(
      capture: (_, __, ___) async => const SentryId.empty(),
      isEnabled: () => true,
      diagnosticSink: diagnostics.add,
    );
    rejected.authFailure(AuthMethod.apple, AuthFailureCause.providerError);
    await Future<void>.delayed(Duration.zero);
    expect(diagnostics, <String>['[crash] Sentry rejected the event.']);
  });

  test('une capture qui lève immédiatement utilise aussi le diagnostic propre', () async {
    final List<String> diagnostics = <String>[];
    final SentryAuthTelemetry failing = SentryAuthTelemetry(
      capture: (_, __, ___) => throw StateError('user@example.com'),
      isEnabled: () => true,
      diagnosticSink: diagnostics.add,
    );
    failing.authFailure(AuthMethod.apple, AuthFailureCause.providerError);
    await Future<void>.delayed(Duration.zero);
    expect(diagnostics, <String>['[crash] Sentry capture failed (StateError).']);
  });

  test('une valeur qui n’a pas la forme d’un symbole est écartée, jamais nettoyée', () {
    final Map<String, String> tags = authFailureTags(
      AuthMethod.google,
      AuthFailureCause.providerError,
      AuthFailureDetail(
        signature: AuthFailureSignature(
          pluginCode: 'authorize_failed',
          oauthError: 'invalid_request user@example.com',
          nativeType: 'https://evil.example/?token=secret',
          underlyingDomain: '',
          errorType: 'E' * 121,
        ),
      ),
    );

    expect(tags, <String, String>{
      'auth.method': 'google',
      'auth.cause': 'providerError',
      'auth.flow': 'signIn',
      'auth.plugin_code': 'authorize_failed',
    });
  });

  test('le filtre Sentry garde les balises auth sûres et rejette les autres', () {
    final SentryPrivacyScrubber scrubber = SentryPrivacyScrubber(
      release: 'com.certigo.mobileapp@1.1.3+12',
      dist: '12',
      environment: 'prod',
    );
    final SentryEvent event = SentryEvent(
      level: SentryLevel.warning,
      tags: <String, String>{
        'auth.method': 'apple',
        'auth.oauth_error': 'invalid_request',
        'auth.native_type': 'user@example.com',
        'auth.error_type': 'Invalid web redirect url',
        'auth.email': 'user@example.com',
        'account': 'user@example.com',
      },
      exceptions: <SentryException>[
        SentryException(type: 'SocialSignInFailure', value: 'user@example.com'),
      ],
    );

    final SentryEvent sanitized = scrubber.beforeSend(event, Hint())!;

    expect(sanitized.tags, <String, String>{
      'auth.method': 'apple',
      'auth.oauth_error': 'invalid_request',
    });
    expect(sanitized.level, SentryLevel.warning);
    expect(sanitized.exceptions!.single.type, 'SocialSignInFailure');
    expect(jsonEncode(sanitized.toJson()), isNot(contains('user@example.com')));
    expect(jsonEncode(sanitized.toJson()), isNot(contains('redirect url')));
  });

  test('un nom ou un jeton de forme symbole est refusé pour chaque balise', () {
    final SentryPrivacyScrubber scrubber = SentryPrivacyScrubber(
      release: 'test',
      dist: 'test',
      environment: 'test',
    );
    for (final String value in <String>['Learner.Name', 'opaque-secret-123', '123456789']) {
      final SentryEvent sanitized = scrubber.beforeSend(
        SentryEvent(tags: <String, String>{
          for (final String key in authFailureTagKeys) key: value,
        }),
        Hint(),
      )!;
      expect(sanitized.tags, isNull, reason: value);
      expect(
        authFailureTags(
          AuthMethod.apple,
          AuthFailureCause.providerError,
          AuthFailureDetail(
            signature: AuthFailureSignature(
              pluginCode: value,
              nativeType: value,
              nativeCode: value,
              oauthError: value,
              underlyingDomain: value,
              errorType: value,
            ),
          ),
        ).keys,
        <String>['auth.method', 'auth.cause', 'auth.flow'],
      );
    }
  });
}
