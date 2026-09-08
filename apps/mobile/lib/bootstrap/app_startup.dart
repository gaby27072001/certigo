import 'package:core/core.dart';

import 'crash_reporting.dart';

typedef AppBootstrap = Future<void> Function({
  required CrashReporter crashReporter,
  required AppConfigReport configuration,
});

typedef RemoteCrashOperation = Future<void> Function();

/// Starts the app in one guarded zone and activates the remote sink only after
/// its native crash handler has been independently verified.
Future<void> runWithCrashReporting({
  required AppConfigReport configuration,
  required bool remoteCrashReportingEnabled,
  required CrashReporter localReporter,
  required CrashReporter remoteReporter,
  required RemoteCrashOperation initializeRemote,
  required RemoteCrashOperation verifyNative,
  required RemoteCrashOperation closeRemote,
  required AppBootstrap bootstrapApp,
}) async {
  final _SwitchingCrashReporter reporter = _SwitchingCrashReporter(localReporter);

  await runGuarded(() async {
    if (!remoteCrashReportingEnabled || !configuration.isValid) {
      await bootstrapApp(crashReporter: reporter, configuration: configuration);
      return;
    }

    try {
      await initializeRemote();
      await verifyNative();
    } on Object catch (error, stackTrace) {
      localReporter.report(
        CrashReport(error: error, stackTrace: stackTrace, source: CrashSource.zone, fatal: true),
      );
      try {
        await closeRemote();
      } on Object catch (closeError, closeStackTrace) {
        localReporter.report(
          CrashReport(error: closeError, stackTrace: closeStackTrace, source: CrashSource.zone),
        );
      }
      await bootstrapApp(
        crashReporter: reporter,
        configuration: AppConfigReport(<AppConfigIssue>[
          ...configuration.issues,
          const AppConfigIssue(
            AppConfigSeverity.error,
            'SENTRY_INIT',
            'L’initialisation native du crash reporting a échoué. '
                'Vérifiez la configuration et reconstruisez.',
          ),
        ]),
      );
      return;
    }

    reporter.delegate = remoteReporter;
    await bootstrapApp(crashReporter: reporter, configuration: configuration);
  }, reporter);
}

class _SwitchingCrashReporter implements CrashReporter {
  _SwitchingCrashReporter(this._delegate);

  CrashReporter _delegate;

  set delegate(CrashReporter value) => _delegate = value;

  @override
  void report(CrashReport report) => _delegate.report(report);
}
