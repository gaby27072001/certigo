import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'providers.dart';
import 'router.dart';

/// The root widget. Wires the Prism themes, localization scaffolding and the
/// GoRouter instance. Stateless + Riverpod: theme mode and routing come from
/// providers so the whole app rebuilds correctly on changes.
class MicrolingoApp extends ConsumerWidget {
  const MicrolingoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Microlingo',
      debugShowCheckedModeBanner: false,
      theme: PrismTheme.light(),
      darkTheme: PrismTheme.dark(),
      themeMode: mode,
      routerConfig: router,
      supportedLocales: const <Locale>[Locale('fr'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
