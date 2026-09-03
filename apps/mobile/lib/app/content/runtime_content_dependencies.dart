import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capabilities/release_profile_provider.dart';

/// Compatibility adapter for callers that still override the former runtime
/// content flag. The typed release capability is now authoritative.
final runtimeContentSyncEnabledProvider = Provider<bool>(
  (Ref ref) => ref.watch(capabilityAvailabilityProvider(AppCapability.versionedContent)).isEnabled,
);

final runtimeContentStoreProvider = Provider<RuntimeContentStore>((Ref ref) {
  requireEnabledCapability(ref, AppCapability.versionedContent);
  return InMemoryRuntimeContentStore();
});

final runtimeContentPinRegistryProvider = Provider<RuntimeContentPinRegistry>((Ref ref) {
  requireEnabledCapability(ref, AppCapability.versionedContent);
  return RuntimeContentPinRegistry();
});
