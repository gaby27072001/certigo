import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app.dart';
import '../app/mascots.dart';
import '../app/offline/offline_sync_scope.dart';
import '../app/offline/prefs_catalog_store.dart';
import '../app/offline/prefs_sync_store.dart';
import '../app/providers.dart';

/// Centralized app bootstrap.
///
/// Keeps `main()` trivial and gives us one place to wire crash reporting,
/// orientation locks, and the root [ProviderScope]. Anything async that must
/// finish before the first frame goes here.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);

  FlutterError.onError = (FlutterErrorDetails details) {
    // Logs widget-tree errors to the console. To forward to a crash service,
    // replace this body with a call to your crash reporter, for example:
    //   FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    //   AppInsights.trackException(details.exception, details.stack);
    // TODO(observability): wire Firebase Crashlytics or Application Insights.
    //   Run: flutter pub add firebase_crashlytics   (or applicationinsights)
    FlutterError.presentError(details);
  };

  // Catch uncaught async errors on the platform dispatcher (e.g. isolate errors,
  // platform-channel failures) that FlutterError.onError does not see.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    // TODO(observability): forward to crash service (same as FlutterError.onError above).
    //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
    return true; // handled — do not re-throw
  };

  // Wire mascot artwork (built-in faces by default; see app/mascots.dart).
  configureMascots();

  // Restore the offline action queue from disk so a submission made while
  // offline in a previous session is replayed as soon as the engine flushes.
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: <Override>[
        catalogStoreProvider.overrideWithValue(prefsCatalogCacheStore(prefs)),
        syncStoreProvider.overrideWithValue(prefsSyncQueueStore(prefs)),
      ],
      child: const OfflineSyncScope(child: CertigoApp()),
    ),
  );
}
