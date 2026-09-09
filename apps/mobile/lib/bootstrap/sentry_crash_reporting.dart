import 'dart:async';
import 'dart:collection';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'crash_reporting.dart';

typedef SentryCapture = Future<SentryId> Function(CrashReport report);

/// Routes provider-agnostic crash reports to the initialized Sentry hub.
class SentryCrashReporter implements CrashReporter {
  SentryCrashReporter({
    SentryCapture? capture,
    void Function(String message)? diagnosticSink,
    bool Function()? isEnabled,
  })  : _capture = capture ?? _captureWithSentry,
        _diagnosticSink = diagnosticSink ?? debugPrint,
        _isEnabled = isEnabled ?? _sentryIsEnabled;

  final SentryCapture _capture;
  final void Function(String message) _diagnosticSink;
  final bool Function() _isEnabled;

  static bool _sentryIsEnabled() => Sentry.isEnabled;

  @override
  void report(CrashReport report) {
    if (!_isEnabled()) {
      _diagnosticSink('[crash] Sentry is disabled; remote capture rejected.');
      return;
    }

    unawaited(_captureAndReport(report));
  }

  Future<void> _captureAndReport(CrashReport report) async {
    try {
      final SentryId id = await _capture(report);
      if (id == const SentryId.empty()) {
        _diagnosticSink('[crash] Sentry rejected the event.');
      }
    } on Object catch (error) {
      _diagnosticSink('[crash] Sentry capture failed (${CrashPrivacy.errorType(error)}).');
    }
  }

  static Future<SentryId> _captureWithSentry(CrashReport report) {
    return Sentry.captureException(
      sentryThrowable(report),
      stackTrace: report.stackTrace,
      withScope: (Scope scope) async {
        scope.level = report.fatal ? SentryLevel.fatal : SentryLevel.error;
        await scope.setTag('crash.source', report.source.name);
        await scope.setTag('crash.fatal', report.fatal.toString());
      },
    );
  }
}

@visibleForTesting
ThrowableMechanism sentryThrowable(CrashReport report) {
  return ThrowableMechanism(
    Mechanism(type: 'certigo.${report.source.name}', handled: !report.fatal),
    report.error,
  );
}

typedef NativeCrashStatusReader = Future<bool?> Function();

/// Verifies the iOS Sentry Cocoa process state through an app-owned channel.
///
/// The SDK's Dart integration intentionally catches native startup failures,
/// so `Sentry.isEnabled` alone cannot prove that fatal iOS capture is active.
class SentryNativeIntegrationVerifier {
  const SentryNativeIntegrationVerifier({this.readStatus, this.requiresNativeVerification});

  static const MethodChannel _channel = MethodChannel(
    'com.certigo.mobileapp/crash-reporting-health',
  );

  final NativeCrashStatusReader? readStatus;
  final bool Function()? requiresNativeVerification;

  Future<void> verify() async {
    final bool requiresVerification = requiresNativeVerification?.call() ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);
    if (!requiresVerification) return;

    bool? enabled;
    try {
      enabled = await (readStatus ?? _readNativeStatus).call();
    } on Object {
      throw const SentryNativeInitializationException();
    }
    if (enabled != true) {
      throw const SentryNativeInitializationException();
    }
  }

  static Future<bool?> _readNativeStatus() {
    return _channel.invokeMethod<bool>('isSentryNativeEnabled');
  }
}

class SentryNativeInitializationException implements Exception {
  const SentryNativeInitializationException();

  @override
  String toString() => 'SentryNativeInitializationException';
}

/// A deterministic rolling-window limiter for Dart-originated events.
///
/// Native fatal crashes are persisted and submitted by Sentry Cocoa, outside
/// this callback. Server-side project quotas remain the authoritative cost cap.
class CrashEventRateLimiter {
  CrashEventRateLimiter({this.maxEvents = 10, this.window = const Duration(minutes: 1)});

  final int maxEvents;
  final Duration window;
  final Queue<DateTime> _accepted = Queue<DateTime>();

  bool allow(DateTime now) {
    final DateTime threshold = now.subtract(window);
    while (_accepted.isNotEmpty && !_accepted.first.isAfter(threshold)) {
      _accepted.removeFirst();
    }
    if (_accepted.length >= maxEvents) return false;
    _accepted.addLast(now);
    return true;
  }
}

/// Removes free-form and identifying fields while retaining symbolication data.
class SentryPrivacyScrubber {
  SentryPrivacyScrubber({
    required this.release,
    required this.dist,
    required this.environment,
    CrashEventRateLimiter? rateLimiter,
    DateTime Function()? clock,
  })  : _rateLimiter = rateLimiter ?? CrashEventRateLimiter(),
        _clock = clock ?? DateTime.now;

  static const Set<String> _allowedTags = <String>{'crash.source', 'crash.fatal'};

  final String release;
  final String dist;
  final String environment;
  final CrashEventRateLimiter _rateLimiter;
  final DateTime Function() _clock;

  SentryEvent? beforeSend(SentryEvent event, Hint hint) {
    if (!_rateLimiter.allow(_clock().toUtc())) return null;

    return SentryEvent(
      eventId: event.eventId,
      timestamp: event.timestamp,
      platform: event.platform,
      release: release,
      dist: dist,
      environment: environment,
      level: event.level,
      tags: _sanitizeTags(event.tags),
      breadcrumbs: event.breadcrumbs
          ?.map((Breadcrumb breadcrumb) => sanitizeBreadcrumb(breadcrumb))
          .whereType<Breadcrumb>()
          .toList(growable: false),
      exceptions: event.exceptions?.map(_sanitizeException).toList(growable: false),
      threads: event.threads?.map(_sanitizeThread).toList(growable: false),
      sdk: event.sdk,
      contexts: _sanitizeContexts(event.contexts),
      debugMeta: _sanitizeDebugMeta(event.debugMeta),
      type: event.type,
    );
  }

  Breadcrumb? beforeBreadcrumb(Breadcrumb? breadcrumb, Hint hint) =>
      breadcrumb == null ? null : sanitizeBreadcrumb(breadcrumb);

  Breadcrumb? sanitizeBreadcrumb(Breadcrumb breadcrumb) {
    final String? category = _safeSymbol(breadcrumb.category, maxCharacters: 80);
    final String? type = _safeSymbol(breadcrumb.type, maxCharacters: 40);
    if (category == null && type == null) return null;
    return Breadcrumb(
      category: category,
      type: type,
      level: breadcrumb.level,
      timestamp: breadcrumb.timestamp,
    );
  }

  Map<String, String>? _sanitizeTags(Map<String, String>? tags) {
    if (tags == null) return null;
    final Map<String, String> safe = <String, String>{};
    for (final String key in _allowedTags) {
      final String? value = tags[key];
      if (value != null) {
        safe[key] = CrashPrivacy.text(value, maxCharacters: 80);
      }
    }
    return safe.isEmpty ? null : safe;
  }

  SentryException _sanitizeException(SentryException exception) {
    return SentryException(
      type: _safeSymbol(exception.type, maxCharacters: 120) ?? 'UnknownError',
      value: '<redacted>',
      module: _safeSymbol(exception.module, maxCharacters: 160),
      stackTrace: _sanitizeStackTrace(exception.stackTrace),
      mechanism: _sanitizeMechanism(exception.mechanism),
      threadId: exception.threadId,
    );
  }

  Mechanism? _sanitizeMechanism(Mechanism? mechanism) {
    if (mechanism == null) return null;
    return Mechanism(
      type: _safeSymbol(mechanism.type, maxCharacters: 80) ?? 'generic',
      handled: mechanism.handled,
      synthetic: mechanism.synthetic,
      isExceptionGroup: mechanism.isExceptionGroup,
      exceptionId: mechanism.exceptionId,
      parentId: mechanism.parentId,
    );
  }

  SentryThread _sanitizeThread(SentryThread thread) {
    return SentryThread(
      id: thread.id,
      crashed: thread.crashed,
      current: thread.current,
      stacktrace: _sanitizeStackTrace(thread.stacktrace),
    );
  }

  SentryStackTrace? _sanitizeStackTrace(SentryStackTrace? stackTrace) {
    if (stackTrace == null) return null;
    return SentryStackTrace(
      frames: stackTrace.frames.map(_sanitizeFrame).toList(growable: false),
      lang: _safeSymbol(stackTrace.lang, maxCharacters: 40),
      snapshot: stackTrace.snapshot,
    );
  }

  SentryStackFrame _sanitizeFrame(SentryStackFrame frame) {
    return SentryStackFrame(
      fileName: _safeFileName(frame.fileName),
      function: _safeSymbol(frame.function),
      module: _safeSymbol(frame.module),
      lineNo: frame.lineNo,
      colNo: frame.colNo,
      inApp: frame.inApp,
      package: _safeSymbol(frame.package),
      native: frame.native,
      platform: _safeSymbol(frame.platform, maxCharacters: 40),
      imageAddr: _safeAddress(frame.imageAddr),
      symbolAddr: _safeAddress(frame.symbolAddr),
      instructionAddr: _safeAddress(frame.instructionAddr),
      rawFunction: _safeSymbol(frame.rawFunction),
      stackStart: frame.stackStart,
      symbol: _safeSymbol(frame.symbol),
    );
  }

  DebugMeta? _sanitizeDebugMeta(DebugMeta? debugMeta) {
    if (debugMeta == null) return null;
    final SdkInfo? sdk = debugMeta.sdk;
    return DebugMeta(
      sdk: sdk == null
          ? null
          : SdkInfo(
              sdkName: _safeSymbol(sdk.sdkName),
              versionMajor: sdk.versionMajor,
              versionMinor: sdk.versionMinor,
              versionPatchlevel: sdk.versionPatchlevel,
            ),
      images: debugMeta.images.map(_sanitizeDebugImage).toList(growable: false),
    );
  }

  DebugImage _sanitizeDebugImage(DebugImage image) {
    return DebugImage(
      type: _safeSymbol(image.type, maxCharacters: 40) ?? 'unknown',
      uuid: _safeDebugIdentifier(image.uuid),
      name: _safeFileName(image.name),
      debugId: _safeDebugIdentifier(image.debugId),
      imageAddr: _safeAddress(image.imageAddr),
      imageVmAddr: _safeAddress(image.imageVmAddr),
      imageSize: image.imageSize,
      debugFile: _safeFileName(image.debugFile),
      codeFile: _safeFileName(image.codeFile),
      arch: _safeSymbol(image.arch, maxCharacters: 40),
      codeId: _safeDebugIdentifier(image.codeId, maxCharacters: 160),
      cpuType: image.cpuType,
      cpuSubtype: image.cpuSubtype,
    );
  }

  Contexts _sanitizeContexts(Contexts contexts) {
    final SentryApp? app = contexts.app;
    final SentryDevice? device = contexts.device;
    final SentryOperatingSystem? os = contexts.operatingSystem;
    return Contexts(
      app: app == null
          ? null
          : SentryApp(
              name: _safeSymbol(app.name),
              version: _safeSymbol(app.version),
              identifier: _safeSymbol(app.identifier),
              build: _safeSymbol(app.build),
              buildType: _safeSymbol(app.buildType),
              startTime: app.startTime,
              appMemory: app.appMemory,
              inForeground: app.inForeground,
            ),
      device: device == null
          ? null
          : SentryDevice(
              family: _safeSymbol(device.family),
              model: _safeSymbol(device.model),
              modelId: _safeSymbol(device.modelId),
              arch: _safeSymbol(device.arch),
              orientation: device.orientation,
              manufacturer: _safeSymbol(device.manufacturer),
              brand: _safeSymbol(device.brand),
              screenHeightPixels: device.screenHeightPixels,
              screenWidthPixels: device.screenWidthPixels,
              screenDensity: device.screenDensity,
              screenDpi: device.screenDpi,
              online: device.online,
              charging: device.charging,
              lowMemory: device.lowMemory,
              simulator: device.simulator,
              memorySize: device.memorySize,
              freeMemory: device.freeMemory,
              usableMemory: device.usableMemory,
              processorCount: device.processorCount,
            ),
      operatingSystem: os == null
          ? null
          : SentryOperatingSystem(
              name: _safeSymbol(os.name),
              version: _safeSymbol(os.version),
              build: _safeSymbol(os.build),
              rooted: os.rooted,
              theme: _safeSymbol(os.theme),
            ),
      runtimes: contexts.runtimes
          .map(
            (SentryRuntime runtime) => SentryRuntime(
              key: _safeSymbol(runtime.key),
              name: _safeSymbol(runtime.name),
              version: _safeSymbol(runtime.version),
              compiler: _safeSymbol(runtime.compiler),
              build: _safeSymbol(runtime.build),
            ),
          )
          .toList(growable: false),
    );
  }

  String? _safeFileName(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final String normalized = value.replaceAll(r'\', '/');
    return _safeSymbol(normalized.split('/').last);
  }

  String? _safeAddress(String? value) {
    if (value == null || !RegExp(r'^0x[0-9A-Fa-f]+$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  String? _safeDebugIdentifier(String? value, {int maxCharacters = 80}) {
    if (value == null ||
        value.length > maxCharacters ||
        !RegExp(r'^[0-9A-Fa-f-]+$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  String? _safeSymbol(String? value, {int maxCharacters = 240}) {
    if (value == null || value.trim().isEmpty) return null;
    return CrashPrivacy.text(value, maxCharacters: maxCharacters);
  }
}

void configureSentryOptions(
  SentryFlutterOptions options, {
  SentryPrivacyScrubber? privacyScrubber,
}) {
  final SentryPrivacyScrubber scrubber = privacyScrubber ??
      SentryPrivacyScrubber(
        release: AppEnv.sentryRelease,
        dist: AppEnv.sentryDist,
        environment: AppEnv.sentryEnvironment,
      );

  options
    ..dsn = AppEnv.sentryDsn
    ..release = AppEnv.sentryRelease
    ..dist = AppEnv.sentryDist
    ..environment = AppEnv.sentryEnvironment
    ..sendDefaultPii = false
    ..sampleRate = 1.0
    ..tracesSampleRate = null
    // ignore: experimental_member_use
    ..profilesSampleRate = null
    ..maxCacheItems = 30
    ..maxQueueSize = 10
    ..maxBreadcrumbs = 10
    ..maxRequestBodySize = MaxRequestBodySize.never
    ..attachStacktrace = true
    ..attachThreads = false
    ..captureFailedRequests = false
    ..captureNativeFailedRequests = false
    ..recordHttpBreadcrumbs = false
    ..enablePrintBreadcrumbs = false
    ..enableLogs = false
    ..enableMetrics = false
    ..enableNativeCrashHandling = true
    ..enableWatchdogTerminationTracking = true
    ..enableAppHangTracking = false
    // Release health emits a session envelope on every foreground/background
    // transition, outside any crash. It is produced natively, so it bypasses
    // the Dart allowlist, scrubber and rate limiter, and it carries a
    // persistent distinctId. The published privacy policy scopes Sentry to
    // technical errors and crashes only; keep this off so the code collects no
    // more than the policy declares.
    ..enableAutoSessionTracking = false
    ..enableAutoNativeBreadcrumbs = false
    ..enableAppLifecycleBreadcrumbs = false
    ..enableWindowMetricBreadcrumbs = false
    ..enableBrightnessChangeBreadcrumbs = false
    ..enableTextScaleChangeBreadcrumbs = false
    ..enableMemoryPressureBreadcrumbs = false
    ..enableUserInteractionBreadcrumbs = false
    ..enableAutoPerformanceTracing = false
    // ignore: experimental_member_use
    ..enableStandaloneAppStartTracing = false
    ..enableUserInteractionTracing = false
    ..enableTimeToFullDisplayTracing = false
    ..enableFramesTracking = false
    ..enableNativeTraceSync = false
    ..attachScreenshot = false
    // ignore: experimental_member_use
    ..attachViewHierarchy = false
    ..reportViewHierarchyIdentifiers = false
    ..beforeSend = scrubber.beforeSend
    ..beforeBreadcrumb = scrubber.beforeBreadcrumb;

  options.replay
    ..sessionSampleRate = 0
    ..onErrorSampleRate = 0;
}
