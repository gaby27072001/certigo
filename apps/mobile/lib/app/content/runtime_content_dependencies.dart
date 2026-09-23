import 'dart:convert';

import 'package:data/data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const bool kRuntimeContentMobileEnabled = bool.fromEnvironment(
  'RUNTIME_CONTENT_MOBILE',
  defaultValue: false,
);

final runtimeContentSyncEnabledProvider = Provider<bool>(
  (Ref ref) => kRuntimeContentMobileEnabled,
);

final runtimeContentStoreProvider = Provider<RuntimeContentStore>(
  (Ref ref) => InMemoryRuntimeContentStore(),
);

final runtimeContentPinRegistryProvider = Provider<RuntimeContentPinRegistry>(
  (Ref ref) => RuntimeContentPinRegistry(),
);

/// Development sink: prints the allow-listed event map only, so a debug log
/// never contains study content, answers, file identifiers or the learner.
class DebugRuntimeContentTelemetry implements RuntimeContentTelemetry {
  const DebugRuntimeContentTelemetry();

  @override
  void syncFinished(RuntimeContentSyncEvent event) =>
      debugPrint('[runtime-content] sync ${jsonEncode(event.toMap())}');

  @override
  void rollbackFinished(RuntimeContentRollbackEvent event) =>
      debugPrint('[runtime-content] rollback ${jsonEncode(event.toMap())}');
}

/// Runtime content telemetry: debug output in development, nothing in release
/// until a real sink is wired (same policy as the authentication telemetry).
final runtimeContentTelemetryProvider = Provider<RuntimeContentTelemetry>(
  (Ref ref) =>
      kDebugMode ? const DebugRuntimeContentTelemetry() : const NoopRuntimeContentTelemetry(),
);
