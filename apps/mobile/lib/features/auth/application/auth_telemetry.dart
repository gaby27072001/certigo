import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_diagnostics.dart';
import 'auth_gateway.dart';
import 'auth_state.dart';

/// Méthode de connexion mesurée (label non sensible, jamais l'e-mail réel).
enum AuthMethod { email, register, microsoft, google, apple, restore, refresh }

extension AuthMethodX on AuthMethod {
  String get label => switch (this) {
        AuthMethod.email => 'email',
        AuthMethod.register => 'register',
        AuthMethod.microsoft => 'microsoft',
        AuthMethod.google => 'google',
        AuthMethod.apple => 'apple',
        AuthMethod.restore => 'restore',
        AuthMethod.refresh => 'refresh',
      };

  static AuthMethod fromProvider(AuthProvider provider) => switch (provider) {
        AuthProvider.microsoft => AuthMethod.microsoft,
        AuthProvider.google => AuthMethod.google,
        AuthProvider.apple => AuthMethod.apple,
        AuthProvider.email => AuthMethod.email,
      };
}

/// Flux social concerné par un échec.
enum AuthFlow {
  /// Connexion depuis l'écran d'accueil ou de connexion.
  signIn,

  /// Ré-authentification exigée avant une opération sensible (suppression).
  reauthentication,
}

/// Contexte technique d'un échec, **sans donnée personnelle** : le flux, la
/// dernière étape franchie du flux social et la signature de l'erreur.
@immutable
class AuthFailureDetail {
  const AuthFailureDetail({this.flow = AuthFlow.signIn, this.lastStep, this.signature});

  final AuthFlow flow;
  final AuthDiagnosticStep? lastStep;
  final AuthFailureSignature? signature;
}

/// Fixed SDK/protocol identifiers only; symbol-shaped personal data is not safe.
bool isSafeAuthFailureTag(String key, String value) => switch (key) {
      'auth.method' => AuthMethod.values.any((AuthMethod method) => method.label == value),
      'auth.cause' => AuthFailureCause.values.any((AuthFailureCause cause) => cause.name == value),
      'auth.flow' => AuthFlow.values.any((AuthFlow flow) => flow.name == value),
      'auth.step' => AuthDiagnosticStep.values.any((AuthDiagnosticStep step) => step.name == value),
      _ => _authSignatureValues[key]?.contains(value) ?? false,
    };

const Map<String, Set<String>> _authSignatureValues = <String, Set<String>>{
  'auth.plugin_code': <String>{
    'authorize_failed',
    'authorize_and_exchange_code_failed',
    'token_failed',
    'discovery_failed',
    'end_session_failed',
    'user_cancelled',
  },
  'auth.native_type': <String>{
    'org.openid.appauth.general',
    'org.openid.appauth.oauth_authorization',
    'org.openid.appauth.oauth_token',
    'org.openid.appauth.oauth_registration',
    'OIDGeneralErrorDomain',
    'OIDOAuthAuthorizationErrorDomain',
    'OIDOAuthTokenErrorDomain',
    'OIDOAuthRegistrationErrorDomain',
  },
  'auth.native_code': <String>{
    '-1',
    '-2',
    '-3',
    '-4',
    '-5',
    '-6',
    '-7',
    '-8',
    '-9',
    '-10',
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '1000',
    '1001',
    '1002',
    '1003',
    '1004',
    '1005',
    '1006',
    '1007',
    '1008',
    '2000',
    '2001',
    '2002',
    '2003',
    '2004',
    '2005',
    '2006',
    '2007',
  },
  'auth.oauth_error': <String>{
    'invalid_request',
    'unauthorized_client',
    'access_denied',
    'unsupported_response_type',
    'invalid_scope',
    'server_error',
    'temporarily_unavailable',
    'invalid_client',
    'invalid_grant',
    'unsupported_grant_type',
    'interaction_required',
    'login_required',
    'consent_required',
    'account_selection_required',
  },
  'auth.underlying_domain': <String>{
    'com.apple.AuthenticationServices.WebAuthenticationSession',
    'com.apple.AuthenticationServices.AuthorizationError',
    'NSURLErrorDomain',
    'NSOSStatusErrorDomain',
  },
  'auth.error_type': <String>{
    'FlutterAppAuthUserCancelledException',
    'FlutterAppAuthPlatformException',
    'PlatformException',
    'MissingPluginException',
    'EmptyAccessToken',
    'MissingAuthorizationCode',
    'StateError',
    'FormatException',
    'TimeoutException',
    'SocketException',
    'Exception',
  },
};

/// Abstraction d'événements d'authentification.
///
/// Remplace l'instrumentation `[LOGIN-DBG]` (bruyante, temporaire) par une API
/// stable et **sans donnée sensible** : on ne transmet jamais de jeton, mot de
/// passe ou e-mail — uniquement la méthode (label), la cause normalisée d'un
/// échec, et un timing bout-en-bout. Un vrai puits (Application Insights) pourra
/// implémenter cette interface sans toucher au reste du code d'auth.
///
/// KPI cibles dérivables de ces événements (voir docs/CONFIG_AUTH.md) :
/// - taux de succès login/inscription par méthode (success / start) ≥ 98 % ;
/// - latence médiane de connexion (durationMs des succès) ≤ 3 s ;
/// - taux d'abandon (cancelled / start) ;
/// - répartition des échecs par [AuthFailureCause].
abstract interface class AuthTelemetry {
  /// Début d'une tentative de connexion/inscription.
  void authStart(AuthMethod method);

  /// Succès, avec la durée bout-en-bout mesurée par le contrôleur.
  void authSuccess(AuthMethod method, {int? durationMs});

  /// Échec, avec la cause normalisée, la durée jusqu'à l'échec et, pour un flux
  /// social, l'étape atteinte et la signature technique de l'erreur.
  void authFailure(
    AuthMethod method,
    AuthFailureCause cause, {
    int? durationMs,
    AuthFailureDetail? detail,
  });
}

/// Implémentation neutre (aucun effet) : défaut hors debug quand le démarrage
/// n'installe pas d'autre puits. Garantit qu'aucune donnée ne fuit par défaut.
class NoopAuthTelemetry implements AuthTelemetry {
  const NoopAuthTelemetry();

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
  }) {}
}

/// Implémentation de développement : journalise via [debugPrint] (remplace
/// proprement `[LOGIN-DBG]`). N'émet rien en release (debugPrint est no-op).
class DebugAuthTelemetry implements AuthTelemetry {
  const DebugAuthTelemetry();

  @override
  void authStart(AuthMethod method) => debugPrint('[auth] start method=${method.label}');

  @override
  void authSuccess(AuthMethod method, {int? durationMs}) =>
      debugPrint('[auth] success method=${method.label} durationMs=${durationMs ?? '-'}');

  @override
  void authFailure(
    AuthMethod method,
    AuthFailureCause cause, {
    int? durationMs,
    AuthFailureDetail? detail,
  }) =>
      debugPrint(
        '[auth] failure method=${method.label} cause=${cause.name} '
        'durationMs=${durationMs ?? '-'} step=${detail?.lastStep?.name ?? '-'} '
        'plugin=${detail?.signature?.pluginCode ?? '-'} '
        'oauth=${detail?.signature?.oauthError ?? '-'}',
      );
}

/// Puits de télémétrie d'auth injecté dans le contrôleur.
///
/// Debug par défaut en développement (utile localement), neutre sinon. Hors
/// debug, `bootstrap.dart` le remplace par `SentryAuthTelemetry` : seuls les
/// échecs de connexion sociale partent, sous forme de balises techniques.
/// Surchargeable dans les tests par un faux vérifiable.
final authTelemetryProvider = Provider<AuthTelemetry>(
  (Ref ref) => kDebugMode ? const DebugAuthTelemetry() : const NoopAuthTelemetry(),
);
