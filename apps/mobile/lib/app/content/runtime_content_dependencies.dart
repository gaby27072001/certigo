import 'package:data/data.dart';
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
