import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../bootstrap/reduce_transparency_scope.dart';
import '../features/profile/application/settings_preferences.dart';
import 'providers.dart';
import 'router.dart';

/// The root widget. Wires the Prism themes, localization scaffolding and the
/// GoRouter instance. Stateless + Riverpod: theme mode and routing come from
/// providers so the whole app rebuilds correctly on changes.
///
/// `builder` porte les axes d'accessibilité. Il s'exécute **sous** le
/// `MediaQuery` installé par `MaterialApp` — donc là où `highContrast` et
/// `boldText` sont lisibles — et **au-dessus** de toutes les routes, donc le
/// thème résolu descend partout sans qu'aucun écran n'ait à le savoir.
class CertigoApp extends ConsumerWidget {
  const CertigoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final GoRouter router = ref.watch(routerProvider);

    // Crée le notifier des vibrations dès le démarrage. C'est **lui** qui
    // pousse la préférence stockée dans `PrismHaptics` ; un provider Riverpod
    // étant paresseux, sans cette ligne la porte resterait ouverte jusqu'à la
    // première ouverture du profil — un utilisateur ayant coupé les vibrations
    // les retrouverait à chaque lancement de l'application.
    ref.watch(hapticsEnabledProvider);

    return MaterialApp.router(
      title: 'Certigo',
      debugShowCheckedModeBanner: false,
      theme: PrismTheme.light(),
      darkTheme: PrismTheme.dark(),
      themeMode: mode,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        return ReduceTransparencyScope(child: child ?? const SizedBox.shrink());
      },
      supportedLocales: const <Locale>[Locale('fr'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
