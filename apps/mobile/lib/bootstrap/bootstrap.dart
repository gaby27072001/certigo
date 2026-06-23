import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app.dart';
import '../app/offline/offline_sync_scope.dart';
import '../app/offline/prefs_sync_store.dart';
import '../app/providers.dart';

/// Centralized app bootstrap.
///
/// Keeps `main()` trivial and gives us one place to wire crash reporting,
/// orientation locks, and the root [ProviderScope]. Anything async that must
/// finish before the first frame goes here.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  FlutterError.onError = (FlutterErrorDetails details) {
    // TODO(observability): forward to Application Insights via a Crash service.
    FlutterError.presentError(details);
  };

  // Restore the offline action queue from disk so a submission made while
  // offline in a previous session is replayed as soon as the engine flushes.
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: <Override>[
        syncStoreProvider.overrideWithValue(prefsSyncQueueStore(prefs)),
      ],
      child: const OfflineSyncScope(child: MicrolingoApp()),
    ),
  );
}
