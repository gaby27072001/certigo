import 'package:core/core.dart';
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
import 'config_error_app.dart';

/// Centralized app bootstrap.
///
/// Keeps `main()` trivial and gives us one place to wire crash reporting,
/// orientation locks, and the root [ProviderScope]. Anything async that must
/// finish before the first frame goes here.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Garde-fou de configuration : on valide la config compile-time AVANT de
  // démarrer l'app. En prod/staging, une config d'auth invalide (API dev en
  // prod, Entra partiel, schéma de redirection incompatible…) **bloque** le
  // lancement sur un écran explicite plutôt que de laisser un login échouer
  // silencieusement. En dev, on journalise fort (et `assert` en debug) mais on
  // n'empêche pas le démarrage.
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

  FlutterError.onError = (FlutterErrorDetails details) {
    // TODO(observability): forward to Application Insights via a Crash service.
    FlutterError.presentError(details);
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

/// Journalise chaque problème de configuration (erreurs + avertissements) avec
/// un préfixe repérable, sans jamais exposer de valeur sensible.
void _reportConfig(AppConfigReport report) {
  if (report.issues.isEmpty) return;
  for (final AppConfigIssue issue in report.issues) {
    debugPrint('[config] $issue');
  }
}
