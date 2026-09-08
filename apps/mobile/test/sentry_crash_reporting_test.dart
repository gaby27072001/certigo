import 'dart:async';
import 'dart:convert';

import 'package:certigo/bootstrap/app_startup.dart';
import 'package:certigo/bootstrap/crash_reporting.dart';
import 'package:certigo/bootstrap/sentry_crash_reporting.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class _FakeCrashReporter implements CrashReporter {
  final List<CrashReport> reports = <CrashReport>[];

  @override
  void report(CrashReport report) => reports.add(report);
}

void main() {
  test('startup keeps remote initialization, verification and bootstrap in one zone', () async {
    final _FakeCrashReporter local = _FakeCrashReporter();
    final _FakeCrashReporter remote = _FakeCrashReporter();
    late Zone initializationZone;
    late Zone verificationZone;
    late Zone bootstrapZone;

    await runWithCrashReporting(
      configuration: const AppConfigReport(<AppConfigIssue>[]),
      remoteCrashReportingEnabled: true,
      localReporter: local,
      remoteReporter: remote,
      initializeRemote: () async => initializationZone = Zone.current,
      verifyNative: () async => verificationZone = Zone.current,
      closeRemote: () async {},
      bootstrapApp: (
          {required CrashReporter crashReporter, required AppConfigReport configuration}) async {
        bootstrapZone = Zone.current;
        crashReporter.report(
          CrashReport(
            error: StateError('remote'),
            stackTrace: StackTrace.current,
            source: CrashSource.zone,
          ),
        );
      },
    );

    expect(initializationZone, same(verificationZone));
    expect(verificationZone, same(bootstrapZone));
    expect(bootstrapZone, isNot(same(Zone.root)));
    expect(local.reports, isEmpty);
    expect(remote.reports, hasLength(1));
  });

  test('startup fails closed when native Sentry verification fails', () async {
    final _FakeCrashReporter local = _FakeCrashReporter();
    final _FakeCrashReporter remote = _FakeCrashReporter();
    bool remoteClosed = false;
    late AppConfigReport bootConfiguration;

    await runWithCrashReporting(
      configuration: const AppConfigReport(<AppConfigIssue>[]),
      remoteCrashReportingEnabled: true,
      localReporter: local,
      remoteReporter: remote,
      initializeRemote: () async {},
      verifyNative: () async => throw const SentryNativeInitializationException(),
      closeRemote: () async => remoteClosed = true,
      bootstrapApp: (
          {required CrashReporter crashReporter, required AppConfigReport configuration}) async {
        bootConfiguration = configuration;
      },
    );

    expect(remoteClosed, isTrue);
    expect(local.reports, hasLength(1));
    expect(local.reports.single.fatal, isTrue);
    expect(remote.reports, isEmpty);
    expect(
      bootConfiguration.issues,
      contains(
        isA<AppConfigIssue>().having((AppConfigIssue issue) => issue.key, 'key', 'SENTRY_INIT'),
      ),
    );
  });

  test('native verifier rejects false status and channel failures', () async {
    final SentryNativeIntegrationVerifier disabled = SentryNativeIntegrationVerifier(
      requiresNativeVerification: () => true,
      readStatus: () async => false,
    );
    final SentryNativeIntegrationVerifier unavailable = SentryNativeIntegrationVerifier(
      requiresNativeVerification: () => true,
      readStatus: () async => throw StateError('channel details must not escape'),
    );

    await expectLater(disabled.verify(), throwsA(isA<SentryNativeInitializationException>()));
    await expectLater(unavailable.verify(), throwsA(isA<SentryNativeInitializationException>()));
  });

  test('native verifier accepts an enabled SDK and skips non-iOS platforms', () async {
    int reads = 0;
    final SentryNativeIntegrationVerifier enabled = SentryNativeIntegrationVerifier(
      requiresNativeVerification: () => true,
      readStatus: () async {
        reads++;
        return true;
      },
    );
    final SentryNativeIntegrationVerifier skipped = SentryNativeIntegrationVerifier(
      requiresNativeVerification: () => false,
      readStatus: () async {
        reads++;
        return false;
      },
    );

    await enabled.verify();
    await skipped.verify();

    expect(reads, 1);
  });

  test('fatal Dart reports use an explicitly unhandled Sentry mechanism', () {
    final StateError error = StateError('fatal');
    final ThrowableMechanism throwable = sentryThrowable(
      CrashReport(
        error: error,
        stackTrace: StackTrace.current,
        source: CrashSource.zone,
        fatal: true,
      ),
    );

    expect(throwable.throwable, same(error));
    expect(throwable.mechanism.type, 'certigo.zone');
    expect(throwable.mechanism.handled, isFalse);
  });

  test('non-fatal Dart reports use a handled Sentry mechanism', () {
    final ThrowableMechanism throwable = sentryThrowable(
      CrashReport(
        error: StateError('recoverable'),
        stackTrace: StackTrace.current,
        source: CrashSource.flutterFramework,
      ),
    );

    expect(throwable.mechanism.type, 'certigo.flutterFramework');
    expect(throwable.mechanism.handled, isTrue);
  });

  test('rate limiter bounds events within a rolling window', () {
    final CrashEventRateLimiter limiter = CrashEventRateLimiter(
      maxEvents: 2,
      window: const Duration(minutes: 1),
    );
    final DateTime start = DateTime.utc(2026, 1, 1);

    expect(limiter.allow(start), isTrue);
    expect(limiter.allow(start.add(const Duration(seconds: 10))), isTrue);
    expect(limiter.allow(start.add(const Duration(seconds: 20))), isFalse);
    expect(limiter.allow(start.add(const Duration(minutes: 1))), isTrue);
  });

  test('beforeSend strips free-form PII but preserves symbolication fields', () {
    final SentryPrivacyScrubber scrubber = SentryPrivacyScrubber(
      release: 'com.certigo.mobileapp@1.2.3+45',
      dist: '45',
      environment: 'prod',
    );
    final SentryStackTrace trace = SentryStackTrace(
      frames: <SentryStackFrame>[
        SentryStackFrame(
          absPath: '/Users/alice/private.dart',
          fileName: '/Users/alice/private.dart',
          function: 'user@example.com',
          contextLine: 'Bearer secret-token',
          vars: <String, String>{'token': 'secret-token'},
          instructionAddr: '0x1234',
          imageAddr: '0x1000',
          symbolAddr: '0x1200',
        ),
      ],
    );
    final SentryEvent event = SentryEvent(
      message: SentryMessage('user@example.com'),
      transaction: '/users/alice',
      culprit: '10.20.30.40',
      user: SentryUser(
        id: '550e8400-e29b-41d4-a716-446655440000',
        email: 'user@example.com',
        ipAddress: '10.20.30.40',
      ),
      request: SentryRequest(
        url: 'https://api.example.test/users/alice?token=secret-token',
        headers: <String, String>{'Authorization': 'Bearer secret-token'},
      ),
      tags: <String, String>{
        'crash.source': 'zone',
        'crash.fatal': 'true',
        'account': 'user@example.com',
      },
      extra: <String, Object>{'token': 'secret-token'},
      breadcrumbs: <Breadcrumb>[
        Breadcrumb(
          category: 'auth',
          message: 'user@example.com',
          data: <String, Object>{'token': 'secret-token'},
        ),
      ],
      exceptions: <SentryException>[
        SentryException(
          type: 'StateError',
          value: 'user@example.com secret-token',
          stackTrace: trace,
        ),
      ],
      threads: <SentryThread>[
        SentryThread(name: 'user@example.com', crashed: true, stacktrace: trace),
      ],
      debugMeta: DebugMeta(
        images: <DebugImage>[
          DebugImage(
            type: 'macho',
            uuid: 'A1B2C3D4-E5F6-1234-9876-A1B2C3D4E5F6',
            codeFile:
                '/private/var/containers/Bundle/Application/user@example.com/Runner.app/Runner',
            debugFile: '/Users/alice/Runner.app.dSYM',
            imageAddr: '0x1000',
          ),
        ],
      ),
    );

    final SentryEvent sanitized = scrubber.beforeSend(event, Hint())!;
    final String json = jsonEncode(sanitized.toJson());

    expect(sanitized.release, 'com.certigo.mobileapp@1.2.3+45');
    expect(sanitized.dist, '45');
    expect(sanitized.environment, 'prod');
    expect(sanitized.user, isNull);
    expect(sanitized.request, isNull);
    expect(sanitized.message, isNull);
    expect(sanitized.transaction, isNull);
    expect(sanitized.tags, <String, String>{'crash.source': 'zone', 'crash.fatal': 'true'});
    expect(sanitized.exceptions!.single.value, '<redacted>');
    expect(sanitized.exceptions!.single.stackTrace!.frames.single.instructionAddr, '0x1234');
    expect(sanitized.exceptions!.single.stackTrace!.frames.single.contextLine, isNull);
    expect(sanitized.threads!.single.name, isNull);
    expect(sanitized.breadcrumbs!.single.message, isNull);
    expect(sanitized.breadcrumbs!.single.data, isNull);
    expect(sanitized.debugMeta!.images.single.codeFile, 'Runner');
    expect(sanitized.debugMeta!.images.single.debugFile, 'Runner.app.dSYM');
    expect(sanitized.debugMeta!.images.single.imageAddr, '0x1000');
    expect(sanitized.debugMeta!.images.single.uuid, 'A1B2C3D4-E5F6-1234-9876-A1B2C3D4E5F6');
    expect(json, isNot(contains('user@example.com')));
    expect(json, isNot(contains('secret-token')));
    expect(json, isNot(contains('10.20.30.40')));
    expect(json, isNot(contains('/Users/alice')));
  });

  test('beforeBreadcrumb retains only bounded classification metadata', () {
    final SentryPrivacyScrubber scrubber = SentryPrivacyScrubber(
      release: 'com.certigo.mobileapp@1.2.3+45',
      dist: '45',
      environment: 'prod',
    );

    final Breadcrumb sanitized = scrubber.beforeBreadcrumb(
      Breadcrumb(
        category: 'navigation',
        type: 'default',
        message: 'user@example.com',
        data: <String, Object>{'authorization': 'Bearer secret-token'},
      ),
      Hint(),
    )!;

    expect(sanitized.category, 'navigation');
    expect(sanitized.type, 'default');
    expect(sanitized.message, isNull);
    expect(sanitized.data, isNull);
  });

  test('Sentry options disable PII, tracing, profiling, replay and attachments', () {
    final SentryFlutterOptions options = SentryFlutterOptions();
    configureSentryOptions(
      options,
      privacyScrubber: SentryPrivacyScrubber(
        release: 'com.certigo.mobileapp@1.2.3+45',
        dist: '45',
        environment: 'prod',
      ),
    );

    expect(options.sendDefaultPii, isFalse);
    expect(options.tracesSampleRate, isNull);
    // ignore: experimental_member_use
    expect(options.profilesSampleRate, isNull);
    expect(options.replay.sessionSampleRate, 0);
    expect(options.replay.onErrorSampleRate, 0);
    expect(options.enableNativeCrashHandling, isTrue);
    expect(options.enableWatchdogTerminationTracking, isTrue);
    expect(options.enableAppHangTracking, isFalse);
    expect(options.enableAutoPerformanceTracing, isFalse);
    expect(options.enableUserInteractionTracing, isFalse);
    expect(options.enableFramesTracking, isFalse);
    expect(options.enableLogs, isFalse);
    expect(options.enableMetrics, isFalse);
    expect(options.captureFailedRequests, isFalse);
    expect(options.captureNativeFailedRequests, isFalse);
    expect(options.recordHttpBreadcrumbs, isFalse);
    expect(options.attachScreenshot, isFalse);
    // ignore: experimental_member_use
    expect(options.attachViewHierarchy, isFalse);
    expect(options.maxCacheItems, 30);
  });

  test('Sentry reporter surfaces disabled, rejected and failed captures', () async {
    final List<String> diagnostics = <String>[];
    final SentryCrashReporter disabled = SentryCrashReporter(
      isEnabled: () => false,
      diagnosticSink: diagnostics.add,
    );
    disabled.report(
      CrashReport(
        error: StateError('never sent'),
        stackTrace: StackTrace.current,
        source: CrashSource.zone,
      ),
    );
    expect(diagnostics.single, contains('disabled'));

    final SentryCrashReporter rejected = SentryCrashReporter(
      isEnabled: () => true,
      diagnosticSink: diagnostics.add,
      capture: (CrashReport report) async => const SentryId.empty(),
    );
    rejected.report(
      CrashReport(
        error: StateError('rejected'),
        stackTrace: StackTrace.current,
        source: CrashSource.zone,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(diagnostics.last, contains('rejected'));

    final SentryCrashReporter failed = SentryCrashReporter(
      isEnabled: () => true,
      diagnosticSink: diagnostics.add,
      capture: (CrashReport report) => Future<SentryId>.error(StateError('token=user@example.com')),
    );
    failed.report(
      CrashReport(
        error: StateError('not logged'),
        stackTrace: StackTrace.current,
        source: CrashSource.zone,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(diagnostics.last, '[crash] Sentry capture failed (StateError).');
    expect(diagnostics.last, isNot(contains('user@example.com')));
  });
}
