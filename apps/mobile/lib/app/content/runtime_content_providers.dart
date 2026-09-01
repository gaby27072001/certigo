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
  );
  ref.onDispose(() => unawaited(synchronizer.dispose()));
  return synchronizer;
});

class RuntimeContentController extends StateNotifier<RuntimeContentStatus> {
  RuntimeContentController({
    required RuntimeContentSynchronizer synchronizer,
    required RuntimeContentPinRegistry pins,
    required SyncEngine syncEngine,
  })  : _synchronizer = synchronizer,
        // Public constructor names stay stable for provider overrides and tests.
        // ignore: prefer_initializing_formals
        _pins = pins,
        // ignore: prefer_initializing_formals
        _syncEngine = syncEngine,
        super(synchronizer.currentStatus) {
    _subscription = synchronizer.statuses.listen((RuntimeContentStatus status) {
      state = status;
    });
  }

  final RuntimeContentSynchronizer _synchronizer;
  final RuntimeContentPinRegistry _pins;
  final SyncEngine _syncEngine;
  late final StreamSubscription<RuntimeContentStatus> _subscription;

  Future<void> syncNow(String ownerId) async {
    await _syncEngine.ensureLoaded();
    final Set<String> queuedPins = _syncEngine.actions
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

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

final runtimeContentControllerProvider =
    StateNotifierProvider<RuntimeContentController, RuntimeContentStatus>((Ref ref) {
  return RuntimeContentController(
    synchronizer: ref.watch(runtimeContentSynchronizerProvider),
    pins: ref.watch(runtimeContentPinRegistryProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});

String runtimeContentSpaceScope() {
  final Uri api = Uri.parse(AppEnv.apiBaseUrl);
  return runtimeContentScopeKey('${AppEnv.flavor.name}|${api.origin}');
}
