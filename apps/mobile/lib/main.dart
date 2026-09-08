import 'package:core/core.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'bootstrap/app_startup.dart';
import 'bootstrap/bootstrap.dart';
import 'bootstrap/crash_reporting.dart';
import 'bootstrap/sentry_crash_reporting.dart';

Future<void> main() async {
  final AppConfigReport config = AppEnv.validate();
  final LoggingCrashReporter localReporter = LoggingCrashReporter();

  await runWithCrashReporting(
    configuration: config,
    remoteCrashReportingEnabled: AppEnv.crashReportingEnabled,
    localReporter: localReporter,
    remoteReporter: SentryCrashReporter(),
    initializeRemote: () => SentryFlutter.init(configureSentryOptions),
    verifyNative: const SentryNativeIntegrationVerifier().verify,
    closeRemote: Sentry.close,
    bootstrapApp: bootstrap,
  );
}
