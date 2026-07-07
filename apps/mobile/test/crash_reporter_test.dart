import 'dart:async';
import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:certigo/bootstrap/crash_reporting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Puits de crash factice : capture les [CrashReport] en mémoire, sans aucune
/// I/O ni dépendance réseau/police (test hermétique).
class _FakeCrashReporter implements CrashReporter {
  final List<CrashReport> reports = <CrashReport>[];

  @override
  void report(CrashReport report) => reports.add(report);
}

void main() {
  // Binding léger requis pour accéder à FlutterError / PlatformDispatcher.
  TestWidgetsFlutterBinding.ensureInitialized();

  // On sauvegarde les handlers globaux et on les restaure après CHAQUE test :
  // le lot ne doit laisser aucun effet de bord sur le harnais de test.
  FlutterExceptionHandler? savedOnError;
  late FlutterExceptionHandler savedPresentError;
  ErrorCallback? savedPlatformOnError;

  setUp(() {
    savedOnError = FlutterError.onError;
    savedPresentError = FlutterError.presentError;
    savedPlatformOnError = PlatformDispatcher.instance.onError;
    // Silence le rendu d'erreur natif : évite le bruit console et empêche le
    // harnais de marquer le test en échec quand on déclenche une erreur.
    FlutterError.presentError = (FlutterErrorDetails details) {};
  });

  tearDown(() {
    FlutterError.onError = savedOnError;
    FlutterError.presentError = savedPresentError;
    PlatformDispatcher.instance.onError = savedPlatformOnError;
  });

  test('installe FlutterError.onError et route le crash vers le sink', () {
    final _FakeCrashReporter fake = _FakeCrashReporter();
    installCrashReporting(fake);

    final StackTrace stack = StackTrace.current;
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('fw'),
        stack: stack,
        library: 'certigo test lib',
        context: ErrorDescription('during a test'),
      ),
    );

    expect(fake.reports, hasLength(1));
    final CrashReport report = fake.reports.single;
    expect(report.source, CrashSource.flutterFramework);
    expect(report.error, isA<StateError>());
    expect(report.stackTrace, same(stack));
    expect(report.library, 'certigo test lib');
    expect(report.context, 'during a test');
  });

  test('installe PlatformDispatcher.onError, route, et retourne true', () {
    final _FakeCrashReporter fake = _FakeCrashReporter();
    installCrashReporting(fake);

    final bool handled = PlatformDispatcher.instance.onError!(
      StateError('async'),
      StackTrace.current,
    );

    // true => l'erreur est considérée gérée, on évite un crash dur du moteur.
    expect(handled, isTrue);
    expect(fake.reports, hasLength(1));
    final CrashReport report = fake.reports.single;
    expect(report.source, CrashSource.platformDispatcher);
    expect(report.fatal, isTrue);
    expect(report.error, isA<StateError>());
  });

  test('runGuarded capture les erreurs de zone non gérées', () async {
    final _FakeCrashReporter fake = _FakeCrashReporter();

    await runGuarded(() async {
      // Erreur asynchrone non gérée dans la zone gardée : remonte au handler.
      scheduleMicrotask(() => throw StateError('boom-zone'));
    }, fake);

    // Laisse la microtask planifiée s'exécuter et atteindre le handler de zone.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fake.reports, hasLength(1));
    final CrashReport report = fake.reports.single;
    expect(report.source, CrashSource.zone);
    expect(report.fatal, isTrue);
    expect(report.error, isA<StateError>());
  });

  test('installCrashReporting(enabled: false) est un no-op (rollback)', () {
    final _FakeCrashReporter fake = _FakeCrashReporter();
    final FlutterExceptionHandler? beforeOnError = FlutterError.onError;
    final ErrorCallback? beforePlatform = PlatformDispatcher.instance.onError;

    installCrashReporting(fake, enabled: false);

    // Handlers d'origine inchangés + aucun report : comportement natif restauré.
    expect(FlutterError.onError, same(beforeOnError));
    expect(PlatformDispatcher.instance.onError, same(beforePlatform));
    expect(fake.reports, isEmpty);
  });

  test('runGuarded(enabled: false) propage sans capturer (rollback)', () async {
    final _FakeCrashReporter fake = _FakeCrashReporter();

    // Sans zone gardée, l'erreur se propage à l'appelant, rien n'est reporté.
    await expectLater(
      runGuarded(() async => throw StateError('direct'), fake, enabled: false),
      throwsA(isA<StateError>()),
    );

    expect(fake.reports, isEmpty);
  });
}
