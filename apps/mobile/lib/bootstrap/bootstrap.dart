import 'dart:io';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app.dart';
import '../app/active_track_store.dart';
import '../app/content/runtime_content_providers.dart';
import '../app/mascots.dart';
import '../app/offline/offline_sync_scope.dart';
import '../app/offline/prefs_catalog_store.dart';
import '../app/offline/prefs_lesson_cache_store.dart';
import '../app/offline/prefs_sync_store.dart';
import '../app/providers.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/notifications/notification_lifecycle_scope.dart';
import '../features/notifications/notification_service.dart';
import 'config_error_app.dart';
import 'crash_reporting.dart';
import 'crash_smoke_test_app.dart';

/// Centralized app bootstrap.
///
/// Keeps `main()` trivial and gives us one place to wire crash reporting,
/// orientation locks, and the root [ProviderScope]. Anything async that must
/// finish before the first frame goes here.
///
/// L'appelant doit exécuter cette fonction dans la même zone que
/// l'initialisation du crash reporter. [runWithCrashReporting] garantit cet
/// invariant pour `ensureInitialized`, les method channels et `runApp`.
Future<void> bootstrap({
  required CrashReporter crashReporter,
  AppConfigReport? configuration,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Voies 1 & 2 : erreurs synchrones du framework (FlutterError.onError) et
  // erreurs asynchrones du moteur (PlatformDispatcher.onError).
  installCrashReporting(crashReporter);

  // Garde-fou de configuration : on valide la config compile-time AVANT de
  // démarrer l'app. En prod/staging, une config d'auth invalide (API dev en
  // prod, Entra partiel, schéma de redirection incompatible…) **bloque** le
  // lancement sur un écran explicite plutôt que de laisser un login échouer
  // silencieusement. En dev, on journalise fort (et `assert` en debug) mais
  // on n'empêche pas le démarrage.
  final AppConfigReport config = configuration ?? AppEnv.validate();
  _reportConfig(config);
  final bool failClosed = AppEnv.isStrictFlavor ||
      AppEnv.crashReportingEnabled ||
      AppEnv.crashReportingRequired ||
      AppEnv.crashSmokeTestEnabled;
  if (!config.isValid && failClosed) {
    runApp(ConfigErrorApp(report: config));
    return;
  }
  assert(
    config.isValid,
    'Configuration d\'authentification invalide (voir logs [config]) :\n${config.describe()}',
  );

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);

  if (AppEnv.crashSmokeTestEnabled) {
    runApp(const CrashSmokeTestApp());
    return;
  }

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  try {
    await NotificationService.initialize();
  } on Object catch (error, stackTrace) {
    crashReporter.report(
      CrashReport(
        error: error,
        stackTrace: stackTrace,
        source: CrashSource.zone,
        context: 'notification bootstrap initialization',
        library: 'certigo.notifications',
      ),
    );
  }

  // Wire mascot artwork (built-in faces by default; see app/mascots.dart).
  configureMascots();

  // Restore the offline action queue from disk so a submission made while
  // offline in a previous session is replayed as soon as the engine flushes.
  final List<Override> overrides = <Override>[
    authLocalAccountCleanupProvider.overrideWith((Ref ref) {
      return () async {
        await ref.read(syncEngineProvider).waitForIdle();
        await ref.read(activeTrackProvider.notifier).clear();
      };
    }),
    activeTrackStoreProvider.overrideWithValue(SharedPreferencesActiveTrackStore(prefs)),
    catalogStoreProvider.overrideWithValue(prefsCatalogCacheStore(prefs)),
    lessonStoreProvider.overrideWithValue(prefsLessonCacheStore(prefs)),
    syncStoreProvider.overrideWithValue(prefsSyncQueueStore(prefs)),
  ];
  if (kRuntimeContentMobileEnabled) {
    final FileRuntimeContentStore? store = await resolveFileRuntimeContentStore();
    if (store != null) {
      overrides.add(runtimeContentStoreProvider.overrideWithValue(store));
    }
  }

  runApp(
    ProviderScope(
      overrides: overrides,
      child: const NotificationLifecycleScope(child: OfflineSyncScope(child: CertigoApp())),
    ),
  );
}

/// Résout le cache disque du contenu runtime, ou `null` si la plateforme ne
/// peut pas le fournir.
///
/// Invariant : le démarrage ne doit jamais échouer à cause du cache. Le store
/// disque dépend de `path_provider`, qui n'a pas d'implémentation sur toutes
/// les plateformes (le web lève `MissingPluginException`) et peut échouer si le
/// dossier support est indisponible. Sans ce repli, activer
/// `RUNTIME_CONTENT_MOBILE` tue l'application avant `runApp` : l'écran reste
/// vide. En renvoyant `null`, on conserve le store en mémoire par défaut et le
/// contenu continue d'être servi par le réseau.
Future<FileRuntimeContentStore?> resolveFileRuntimeContentStore() async {
  try {
    final Directory support = await getApplicationSupportDirectory();
    final Directory root = Directory(
      '${support.path}${Platform.pathSeparator}certigo${Platform.pathSeparator}'
      'runtime-content${Platform.pathSeparator}v1',
    );
    return FileRuntimeContentStore(root: root, spaceScope: runtimeContentSpaceScope());
  } on Object catch (error) {
    debugPrint('[runtime-content] cache disque indisponible, repli en mémoire : $error');
    return null;
  }
}

/// Journalise chaque problème de configuration (erreurs + avertissements) avec
/// un préfixe repérable, sans jamais exposer de valeur sensible.
void _reportConfig(AppConfigReport report) {
  if (report.issues.isEmpty) return;
  for (final AppConfigIssue issue in report.issues) {
    debugPrint('[config] $issue');
  }
}
