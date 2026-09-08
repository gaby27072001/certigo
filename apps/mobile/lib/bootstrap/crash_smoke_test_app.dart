import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class CrashSmokeTestDartError extends Error {}

/// Destructive diagnostics UI included only in explicitly flagged internal builds.
class CrashSmokeTestApp extends StatelessWidget {
  const CrashSmokeTestApp({VoidCallback? onDartCrash, VoidCallback? onNativeCrash, super.key})
      : _onDartCrash = onDartCrash ?? _triggerDartCrash,
        _onNativeCrash = onNativeCrash ?? _triggerNativeCrash;

  final VoidCallback _onDartCrash;
  final VoidCallback _onNativeCrash;

  static void _triggerDartCrash() {
    unawaited(Future<void>.microtask(() => throw CrashSmokeTestDartError()));
  }

  static void _triggerNativeCrash() {
    unawaited(SentryFlutter.nativeCrash());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Crash reporting - test interne')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Cette build est destructive. Déclenchez un scénario à la fois, '
                  'relancez l’application, puis vérifiez l’événement symboliqué dans Sentry.',
                ),
                const SizedBox(height: 16),
                const Text('Release : ${AppEnv.sentryRelease}'),
                const Text('Distribution : ${AppEnv.sentryDist}'),
                Text('Environnement : ${AppEnv.sentryEnvironment}'),
                const SizedBox(height: 32),
                FilledButton(
                  key: const Key('dart-crash-button'),
                  onPressed: _onDartCrash,
                  child: const Text('Déclencher une erreur Dart non gérée'),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  key: const Key('native-crash-button'),
                  onPressed: _onNativeCrash,
                  child: const Text('Déclencher un crash natif iOS'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
