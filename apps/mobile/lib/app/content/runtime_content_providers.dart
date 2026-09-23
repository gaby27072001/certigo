import 'dart:async';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'runtime_content_dependencies.dart';

export 'runtime_content_dependencies.dart';

final runtimeContentSourceProvider = Provider<PublicContentSource>(
  (Ref ref) => ApiPublicContentSource(ref.watch(apiClientProvider)),
);

final runtimeContentSynchronizerProvider = Provider<RuntimeContentSynchronizer>((Ref ref) {
  final RuntimeContentSynchronizer synchronizer = RuntimeContentSynchronizer(
    source: ref.watch(runtimeContentSourceProvider),
    store: ref.watch(runtimeContentStoreProvider),
    pins: ref.watch(runtimeContentPinRegistryProvider),
    telemetry: ref.watch(runtimeContentTelemetryProvider),
  );
  return synchronizer;
});

class RuntimeContentController extends StateNotifier<RuntimeContentStatus> {
  factory RuntimeContentController.withSyncEngine({
    required RuntimeContentSynchronizer synchronizer,
    required RuntimeContentPinRegistry pins,
    required SyncEngine syncEngine,
  }) {
    return RuntimeContentController(
      synchronizer: synchronizer,
      pins: pins,
      ensureSyncQueueLoaded: syncEngine.ensureLoaded,
      syncActions: () => syncEngine.actions,
    );
  }

  RuntimeContentController({
    required RuntimeContentSynchronizer synchronizer,
    required RuntimeContentPinRegistry pins,
    required Future<void> Function() ensureSyncQueueLoaded,
    required List<SyncAction> Function() syncActions,
  })  : _synchronizer = synchronizer,
        // Public constructor names stay stable for provider overrides and tests.
        // ignore: prefer_initializing_formals
        _pins = pins,
        // ignore: prefer_initializing_formals
        _ensureSyncQueueLoaded = ensureSyncQueueLoaded,
        // ignore: prefer_initializing_formals
        _syncActions = syncActions,
        super(synchronizer.currentStatus) {
    _subscription = synchronizer.statuses.listen((RuntimeContentStatus status) {
      state = status;
    });
  }

  final RuntimeContentSynchronizer _synchronizer;
  final RuntimeContentPinRegistry _pins;
  final Future<void> Function() _ensureSyncQueueLoaded;
  final List<SyncAction> Function() _syncActions;
  late final StreamSubscription<RuntimeContentStatus> _subscription;
  Future<void>? _shutdown;

  Future<void> syncNow(String ownerId) async {
    await _ensureSyncQueueLoaded();
    final Set<String> queuedPins = _syncActions()
        .where((SyncAction action) => action.isPending)
        .map((SyncAction action) => action.publicManifestId)
        .whereType<String>()
        .toSet();
    await _synchronizer.sync(
      ownerId: ownerId,
      pinnedManifestIds: <String>{..._pins.manifestIds, ...queuedPins},
    );
  }

  Future<void> rollback(String ownerId) async {
    await _synchronizer.rollback(ownerId: ownerId);
  }

  Future<void> shutdown() {
    final Future<void>? running = _shutdown;
    if (running != null) return running;
    final Future<void> cancellation = _subscription.cancel();
    final Future<void> streamClosure = _synchronizer.dispose();
    final Future<void> operation = Future.wait<void>(
      <Future<void>>[cancellation, streamClosure],
    );
    _shutdown = operation;
    return operation;
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }
}

final runtimeContentControllerProvider =
    StateNotifierProvider<RuntimeContentController, RuntimeContentStatus>((Ref ref) {
  final SyncEngine syncEngine = ref.watch(syncEngineProvider);
  return RuntimeContentController.withSyncEngine(
    synchronizer: ref.watch(runtimeContentSynchronizerProvider),
    pins: ref.watch(runtimeContentPinRegistryProvider),
    syncEngine: syncEngine,
  );
});

String runtimeContentSpaceScope() {
  return runtimeContentSpaceScopeFor(
    flavor: AppEnv.flavor.name,
    apiBaseUri: Uri.parse(AppEnv.apiBaseUrl),
  );
}

String runtimeContentSpaceScopeFor({
  required String flavor,
  required Uri apiBaseUri,
}) {
  final Uri normalizedUri = apiBaseUri.replace(query: null, fragment: null).normalizePath();
  final String normalized = normalizedUri.toString().replaceFirst(RegExp(r'/$'), '');
  return runtimeContentScopeKey('$flavor|$normalized');
}
