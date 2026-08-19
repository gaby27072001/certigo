import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app.dart';
import '../app/active_track_store.dart';
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

/// Centralized app bootstrap.
///
/// Keeps `main()` trivial and gives us one place to wire crash reporting,
/// orientation locks, and the root [ProviderScope]. Anything async that must
/// finish before the first frame goes here.
///
/// Tout le démarrage (dont `ensureInitialized` et `runApp`) s'exécute dans une
/// **zone gardée** partagée ([runGuarded]) ; les erreurs framework/moteur sont
/// routées vers un [CrashReporter] via [installCrashReporting]. L'ensemble est
/// neutralisable via [kCrashReportingEnabled] (rollback → comportement natif).
Future<void> bootstrap() async {
  // Puits de crash par défaut (log structuré + hook symbolisation). Injectable
  // et remplaçable par un transport réel plus tard, sans toucher aux appelants.
  final CrashReporter crashReporter = LoggingCrashReporter();

  // 3e voie de capture (zone) : on englobe TOUT le bootstrap — dont
  // `ensureInitialized` et `runApp` — dans la même zone gardée.
  await runGuarded(() async {
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
    final AppConfigReport config = AppEnv.validate();
    _reportConfig(config);
    if (!config.isValid && AppEnv.isStrictFlavor) {
      runApp(ConfigErrorApp(report: config));
      return;
    }
    assert(
      config.isValid,
      'Configuration d\'authentification invalide (voir logs [config]) :\n${config.describe()}',
    );

    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);

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
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    runApp(
      ProviderScope(
        overrides: <Override>[
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
        ],
        child: const NotificationLifecycleScope(child: OfflineSyncScope(child: CertigoApp())),
      ),
    );
  }, crashReporter);
}

/// Journalise chaque problème de configuration (erreurs + avertissements) avec
/// un préfixe repérable, sans jamais exposer de valeur sensible.
void _reportConfig(AppConfigReport report) {
  if (report.issues.isEmpty) return;
  for (final AppConfigIssue issue in report.issues) {
    debugPrint('[config] $issue');
  }
}
