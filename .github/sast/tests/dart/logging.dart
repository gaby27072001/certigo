// Fixture for .github/sast/rules/dart-security.yaml — logging / leakage rules.
import 'dart:developer' as developer;
import 'dart:io';

void logging(
  AuthSession session,
  String token,
  String password,
  String operation,
  Object error,
  dynamic logger,
  dynamic diagnostics,
  void Function(String message)? debugLog,
  bool hasToken,
  String tokenProvider,
) {
  // ruleid: dart-sensitive-data-logged
  debugPrint('session restored with $token');

  // ruleid: dart-sensitive-data-logged
  print('access=${session.accessToken}');

  // ruleid: dart-sensitive-data-logged
  developer.log('refresh failed', error: session.refreshToken);

  // ruleid: dart-sensitive-data-logged
  logger.info('login', password);

  // ruleid: dart-sensitive-data-logged
  diagnostics.mark(AuthDiagnosticStep.tokenReceived, detail: 'id=${session.idToken}');

  // ruleid: dart-sensitive-data-logged
  debugLog?.call('[LOGIN-DBG] bearer ${session.accessToken}');

  // ruleid: dart-sensitive-data-logged
  stderr.writeln(session);

  // ruleid: dart-sensitive-data-logged
  Sentry.captureMessage('auth header $authorizationHeader');

  // ruleid: dart-sensitive-data-logged
  _logAuthDetail('refresh', refreshToken);

  // ok: dart-sensitive-data-logged
  debugPrint('access len=${session.accessToken.length}, id len=${session.idToken?.length ?? 0}');

  // ok: dart-sensitive-data-logged
  debugPrint('[auth] has token: ${token.isNotEmpty} ${session.refreshToken != null}');

  // ok: dart-sensitive-data-logged
  debugPrint('[AuthController] $operation failed: $error');

  // ok: dart-sensitive-data-logged
  debugPrint('flags hasToken=$hasToken provider=$tokenProvider');

  // ok: dart-sensitive-data-logged
  Sentry.captureException(error);

  // ruleid: dart-dio-log-interceptor-headers
  dio.interceptors.add(LogInterceptor());

  // ruleid: dart-dio-log-interceptor-headers
  dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));

  // ok: dart-dio-log-interceptor-headers
  dio.interceptors.add(LogInterceptor(requestHeader: false, responseHeader: false));

  // ruleid: dart-dio-log-interceptor-headers
  dio.interceptors.add(PrettyDioLogger(requestHeader: true));

  // ok: dart-dio-log-interceptor-headers
  dio.interceptors.add(PrettyDioLogger(requestHeader: false));

  // ruleid: dart-sentry-send-default-pii
  options.sendDefaultPii = true;

  // ruleid: dart-sentry-send-default-pii
  final SentryFlutterOptions cascade = SentryFlutterOptions()..sendDefaultPii = true;

  // ok: dart-sentry-send-default-pii
  options.sendDefaultPii = false;

  // ruleid: dart-sensitive-data-to-clipboard
  Clipboard.setData(ClipboardData(text: session.accessToken));

  // ok: dart-sensitive-data-to-clipboard
  Clipboard.setData(ClipboardData(text: referralCode));
}
