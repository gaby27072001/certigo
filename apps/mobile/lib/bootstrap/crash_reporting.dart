import 'dart:async';

import 'package:flutter/foundation.dart';

/// Drapeau de rollback du crash reporting.
///
/// À `false`, [installCrashReporting] et [runGuarded] deviennent des no-op :
/// on restaure intégralement le comportement Flutter d'origine (aucun handler
/// custom installé, aucune zone de capture). Permet un retour arrière immédiat
/// sans supprimer de code — voir la clause de rollback du lot MOB-CRASH.
const bool kCrashReportingEnabled = true;

/// Origine d'un crash capturé, utile pour le triage et la symbolisation aval.
enum CrashSource {
  /// Erreur synchrone remontée par le framework ([FlutterError.onError]).
  flutterFramework,

  /// Erreur asynchrone non capturée au niveau moteur
  /// ([PlatformDispatcher.onError]).
  platformDispatcher,

  /// Erreur non capturée dans la zone d'exécution ([runZonedGuarded]).
  zone,
}

/// Enregistrement normalisé d'un crash, indépendant de tout SDK tiers.
///
/// C'est le contrat d'échange entre les hooks Flutter et un [CrashReporter].
@immutable
class CrashReport {
  const CrashReport({
    required this.error,
    required this.stackTrace,
    required this.source,
    this.fatal = false,
    this.context,
    this.library,
  });

  /// L'objet d'erreur (souvent une [Exception] ou un [Error]).
  final Object error;

  /// La pile d'appels associée, pour la symbolisation.
  final StackTrace stackTrace;

  /// D'où provient le crash.
  final CrashSource source;

  /// `true` si l'erreur aurait fait planter l'app sans capture.
  final bool fatal;

  /// Contexte lisible fourni par le framework (branche [flutterFramework]).
  final String? context;

  /// Bibliothèque d'origine signalée par le framework, si connue.
  final String? library;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('CrashReport(')
      ..write('source: ${source.name}, ')
      ..write('fatal: $fatal');
    if (library != null) buffer.write(', library: $library');
    if (context != null) buffer.write(', context: $context');
    buffer.write(', error: $error)');
    return buffer.toString();
  }
}

/// Puits de crash abstrait.
///
/// Implémentation par défaut : [LoggingCrashReporter]. On garde l'intégration
/// branchable (Crashlytics / Sentry / Application Insights ultérieurs) sans
/// dépendre d'un SDK tiers ici.
abstract class CrashReporter {
  /// Route un [CrashReport] vers le backend de crash concret.
  void report(CrashReport report);
}

/// Implémentation par défaut : journal structuré + point d'extension pour la
/// symbolisation aval.
///
/// Le [sink] est injectable (défaut : [debugPrint]) pour rester testable et
/// pour permettre de brancher un transport réel (Application Insights…) sans
/// modifier les appelants.
class LoggingCrashReporter implements CrashReporter {
  LoggingCrashReporter({void Function(String message)? sink}) : _sink = sink ?? _defaultSink;

  final void Function(String message) _sink;

  static void _defaultSink(String message) => debugPrint(message);

  @override
  void report(CrashReport report) {
    // Ligne d'en-tête structurée, repérable dans les logs agrégés.
    _sink('[crash] $report');
    // Pile brute émise séparément : point d'ancrage pour la symbolisation.
    _sink('[crash] stackTrace:\n${report.stackTrace}');
  }
}

/// Installe les hooks d'erreurs globaux et les route vers [reporter].
///
/// Couvre deux des trois voies de capture (la 3e, la zone, est fournie par
/// [runGuarded]) :
///  - [FlutterError.onError] : erreurs synchrones du framework ;
///  - [PlatformDispatcher.onError] : erreurs asynchrones du moteur.
///
/// Si [enabled] est `false`, no-op total (rollback → comportement d'origine).
void installCrashReporting(CrashReporter reporter, {bool enabled = kCrashReportingEnabled}) {
  if (!enabled) return;

  FlutterError.onError = (FlutterErrorDetails details) {
    // On préserve le rendu d'erreur natif (bandeau rouge en debug, log sinon)…
    FlutterError.presentError(details);
    // …puis on route vers le puits de crash.
    reporter.report(
      CrashReport(
        error: details.exception,
        stackTrace: details.stack ?? StackTrace.current,
        source: CrashSource.flutterFramework,
        context: details.context?.toDescription(),
        library: details.library,
      ),
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    reporter.report(
      CrashReport(
        error: error,
        stackTrace: stack,
        source: CrashSource.platformDispatcher,
        fatal: true,
      ),
    );
    // `true` : l'erreur est considérée gérée, on évite un crash dur du moteur.
    return true;
  };
}

/// Exécute [body] dans une zone gardée qui capture les erreurs non gérées et
/// les route vers [reporter] (3e voie de capture : la zone).
///
/// [WidgetsFlutterBinding.ensureInitialized] et `runApp` DOIVENT être appelés
/// à l'intérieur de [body] afin de partager la même zone.
///
/// Si [enabled] est `false`, [body] est exécuté directement, sans zone de
/// capture (rollback → comportement d'origine ; les erreurs se propagent).
Future<void> runGuarded(
  Future<void> Function() body,
  CrashReporter reporter, {
  bool enabled = kCrashReportingEnabled,
}) async {
  if (!enabled) {
    await body();
    return;
  }

  await runZonedGuarded<Future<void>>(body, (Object error, StackTrace stack) {
    reporter.report(
      CrashReport(error: error, stackTrace: stack, source: CrashSource.zone, fatal: true),
    );
  });
}
