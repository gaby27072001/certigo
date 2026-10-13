import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../features/auth/application/auth_state.dart';
import '../features/auth/application/auth_telemetry.dart';
import 'sentry_crash_reporting.dart';

/// Marqueur sans contenu d'un échec de connexion sociale. Seuls son type et les
/// balises `auth.*` partent vers Sentry ; [SentryPrivacyScrubber] efface tout le
/// reste (valeur, utilisateur, requête).
class SocialSignInFailure implements Exception {
  const SocialSignInFailure();

  @override
  String toString() => 'SocialSignInFailure';
}

typedef SentryAuthCapture = Future<SentryId> Function(
  SocialSignInFailure failure,
  SentryLevel level,
  Map<String, String> tags,
);

/// Balises acceptées pour un échec de connexion sociale. Elles ne portent que
/// des identifiants techniques fixes : jamais d'e-mail, de nom, de jeton, d'URL
/// ni de texte libre.
const Set<String> authFailureTagKeys = <String>{
  'auth.method',
  'auth.cause',
  'auth.flow',
  'auth.step',
  'auth.plugin_code',
  'auth.native_type',
  'auth.native_code',
  'auth.oauth_error',
  'auth.underlying_domain',
  'auth.error_type',
};

/// Rend diagnosticable depuis Sentry un échec de connexion Microsoft, Google ou
/// Apple survenu sur l'iPhone d'un testeur : les builds de release n'affichent
/// pas la trace de diagnostic et n'en gardent aucune autre.
class SentryAuthTelemetry implements AuthTelemetry {
  SentryAuthTelemetry({
    SentryAuthCapture? capture,
    bool Function()? isEnabled,
    void Function(String message)? diagnosticSink,
  })  : _capture = capture ?? _captureWithSentry,
        _isEnabled = isEnabled ?? _sentryIsEnabled,
        _diagnosticSink = diagnosticSink ?? debugPrint;

  final SentryAuthCapture _capture;
  final bool Function() _isEnabled;
  final void Function(String message) _diagnosticSink;

  static bool _sentryIsEnabled() => Sentry.isEnabled;

  @override
  void authStart(AuthMethod method) {}

  @override
  void authSuccess(AuthMethod method, {int? durationMs}) {}

  @override
  void authFailure(
    AuthMethod method,
    AuthFailureCause cause, {
    int? durationMs,
    AuthFailureDetail? detail,
  }) {
    if (!_isSocial(method) || !_isEnabled()) return;
    final SentryLevel level =
        cause == AuthFailureCause.cancelled ? SentryLevel.info : SentryLevel.warning;
    unawaited(
      captureSentryEvent(
        capture: () =>
            _capture(const SocialSignInFailure(), level, authFailureTags(method, cause, detail)),
        diagnosticSink: _diagnosticSink,
      ),
    );
  }

  static bool _isSocial(AuthMethod method) =>
      method == AuthMethod.microsoft || method == AuthMethod.google || method == AuthMethod.apple;

  static Future<SentryId> _captureWithSentry(
    SocialSignInFailure failure,
    SentryLevel level,
    Map<String, String> tags,
  ) {
    return Sentry.captureException(
      failure,
      withScope: (Scope scope) async {
        scope.level = level;
        for (final MapEntry<String, String> tag in tags.entries) {
          await scope.setTag(tag.key, tag.value);
        }
      },
    );
  }
}

/// Balises d'un échec social, réduites aux identifiants connus.
@visibleForTesting
Map<String, String> authFailureTags(
  AuthMethod method,
  AuthFailureCause cause,
  AuthFailureDetail? detail,
) {
  final Map<String, String?> candidates = <String, String?>{
    'auth.method': method.label,
    'auth.cause': cause.name,
    'auth.flow': detail?.flow.name,
    'auth.step': detail?.lastStep?.name,
    'auth.plugin_code': detail?.signature?.pluginCode,
    'auth.native_type': detail?.signature?.nativeType,
    'auth.native_code': detail?.signature?.nativeCode,
    'auth.oauth_error': detail?.signature?.oauthError,
    'auth.underlying_domain': detail?.signature?.underlyingDomain,
    'auth.error_type': detail?.signature?.errorType,
  };
  return <String, String>{
    for (final MapEntry<String, String?> entry in candidates.entries)
      if (entry.value != null && isSafeAuthFailureTag(entry.key, entry.value!))
        entry.key: entry.value!,
  };
}
