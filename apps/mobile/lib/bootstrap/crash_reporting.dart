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
      ..write('fatal: $fatal, ')
      ..write('errorType: ${CrashPrivacy.errorType(error)})');
    return buffer.toString();
  }
}

/// Puits de crash abstrait.
///
/// L'interface garde les hooks Flutter indépendants du fournisseur distant.
abstract class CrashReporter {
  /// Route un [CrashReport] vers le backend de crash concret.
  void report(CrashReport report);
}

/// Sink local de développement. Le texte et la pile sont nettoyés avant log.
class LoggingCrashReporter implements CrashReporter {
  LoggingCrashReporter({void Function(String message)? sink}) : _sink = sink ?? _defaultSink;

  final void Function(String message) _sink;

  static void _defaultSink(String message) => debugPrint(message);

  @override
  void report(CrashReport report) {
    _sink('[crash] $report');
    _sink('[crash] stackTrace:\n${CrashPrivacy.stackTrace(report.stackTrace)}');
  }
}

/// Privacy boundary shared by local logs and the remote payload.
class CrashPrivacy {
  const CrashPrivacy._();

  static const int maxStackCharacters = 12000;

  static final RegExp _bearer = RegExp(r'\bBearer\s+[^\s,;]+', caseSensitive: false);
  static final RegExp _email = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );
  static final RegExp _jwt = RegExp(
    r'\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b',
  );
  static final RegExp _querySecret = RegExp(
    r'([?&](?:access_token|token|code|secret|api_key)=)[^&#\s]+',
    caseSensitive: false,
  );
  static final RegExp _urlQueryValue = RegExp(r'([?&][^=\s&#]{1,80}=)[^&#\s]+');
  static final RegExp _secretAssignment = RegExp(
    r'\b(?:token|secret|password|authorization|api[-_]?key)\b\s*[:=]\s*[^\s,;]+',
    caseSensitive: false,
  );
  static final RegExp _url = RegExp(r'''https?://[^\s)\]}>"']+''', caseSensitive: false);
  static final RegExp _ipv4 = RegExp(
    r'\b(?:25[0-5]|2[0-4]\d|1?\d?\d)(?:\.(?:25[0-5]|2[0-4]\d|1?\d?\d)){3}\b',
  );
  static final RegExp _ipv6 = RegExp(
    r'(?<![A-Za-z0-9])(?:[0-9a-f]{1,4}:){2,7}[0-9a-f]{0,4}(?![A-Za-z0-9])',
    caseSensitive: false,
  );
  static final RegExp _userPath = RegExp(
    r'((?:[A-Za-z]:\\Users\\|/Users/))[^/\\\s]+',
    caseSensitive: false,
  );
  static final RegExp _uuid = RegExp(
    r'\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b',
    caseSensitive: false,
  );
  static final RegExp _safeErrorType = RegExp(r'^[A-Za-z0-9_.$<>-]{1,120}$');

  static String errorType(Object error) {
    final String type = error.runtimeType.toString();
    return _safeErrorType.hasMatch(type) ? type : 'UnknownError';
  }

  static String stackTrace(StackTrace stackTrace) => sanitizeStack(stackTrace.toString());

  static String text(String raw, {int maxCharacters = 2048}) {
    String value = raw
        .replaceAll(_bearer, '<redacted>')
        .replaceAll(_email, '<redacted>')
        .replaceAll(_jwt, '<redacted>')
        .replaceAllMapped(_querySecret, (Match match) => '${match.group(1)}<redacted>')
        .replaceAllMapped(_urlQueryValue, (Match match) => '${match.group(1)}<redacted>')
        .replaceAll(_secretAssignment, '<redacted>')
        .replaceAllMapped(_userPath, (Match match) => '${match.group(1)}<redacted>')
        .replaceAll(_uuid, '<redacted>')
        .replaceAll(_ipv4, '<redacted>')
        .replaceAll(_ipv6, '<redacted>')
        .replaceAllMapped(_url, (Match match) {
      final Uri? uri = Uri.tryParse(match.group(0)!);
      return uri == null ? '<redacted-url>' : '${uri.scheme}://${uri.host}/<redacted>';
    }).trim();
    if (value.isEmpty) return '<unavailable>';
    if (value.length > maxCharacters) {
      value = '${value.substring(0, maxCharacters)}<truncated>';
    }
    return value;
  }

  @visibleForTesting
  static String sanitizeStack(String raw) {
    String value = raw
        .replaceAll(_bearer, 'Bearer <redacted>')
        .replaceAll(_email, '<redacted>')
        .replaceAll(_jwt, '<redacted>')
        .replaceAllMapped(_querySecret, (Match match) => '${match.group(1)}<redacted>')
        .replaceAllMapped(_urlQueryValue, (Match match) => '${match.group(1)}<redacted>')
        .replaceAll(_secretAssignment, '<redacted>')
        .replaceAllMapped(_userPath, (Match match) => '${match.group(1)}<redacted>')
        .replaceAll(_uuid, '<redacted>')
        .replaceAll(_ipv4, '<redacted>')
        .replaceAll(_ipv6, '<redacted>')
        .replaceAllMapped(_url, (Match match) {
      final Uri? uri = Uri.tryParse(match.group(0)!);
      return uri == null ? '<redacted-url>' : '${uri.scheme}://${uri.host}/<redacted>';
    }).trim();

    if (value.isEmpty) return '<unavailable>';
    if (value.length > maxStackCharacters) {
      value = '${value.substring(0, maxStackCharacters)}\n<truncated>';
    }
    return value;
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
