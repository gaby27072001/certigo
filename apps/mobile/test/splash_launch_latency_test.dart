import 'package:certigo/features/onboarding/presentation/onboarding_common.dart';
import 'package:certigo/features/onboarding/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

/// Garde de **latence de lancement**.
///
/// Le splash de marque a le droit d'être vu le temps de son entrée ; il n'a pas
/// le droit d'avoir une horloge à lui. La borne retenue est donc le jeton de
/// mouvement qu'il rend ([PrismMotion.slow]), et **zéro** quand la plateforme
/// demande un mouvement réduit — car il n'y a alors aucune entrée à laisser
/// atterrir.
///
/// Ce que la garde empêche : le retour d'une temporisation purement temporelle
/// sur le chemin de lancement (DESIGN.md §10, règle 6 — « le mouvement informe ;
/// il ne décore pas »).
void main() {
  // Un frame à 60 Hz. La tolérance de toutes les bornes ci-dessous, parce
  // qu'une navigation planifiée en post-frame se lit au frame suivant.
  const Duration frame60Hz = Duration(milliseconds: 16);

  // Pas d'échantillonnage : le budget d'un frame à 120 Hz. Mesurer plus fin
  // que ce que l'écran peut montrer n'apporterait aucune information.
  const Duration samplingStep = Duration(milliseconds: 8);

  // Plafond de sécurité : au-delà, la boucle de mesure rend la main plutôt que
  // de tourner sans fin si le splash ne relâche jamais l'utilisateur.
  const Duration ceiling = Duration(seconds: 5);

  String locationOf(GoRouter router) => router.routerDelegate.currentConfiguration.uri.path;

  Future<GoRouter> pumpSplash(WidgetTester tester, {required bool reduceMotion}) async {
    final GoRouter router = GoRouter(
      initialLocation: OnboardingRoutes.splash,
      routes: <RouteBase>[
        GoRoute(path: OnboardingRoutes.splash, builder: (_, __) => const SplashScreen()),
        GoRoute(
          path: OnboardingRoutes.welcome,
          builder: (_, __) => const Scaffold(body: Text('WELCOME')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: PrismTheme.light(),
        routerConfig: router,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: child!,
          );
        },
      ),
    );
    return router;
  }

  /// Temps réellement retenu par le splash avant qu'il ne relâche la
  /// navigation. Zéro signifie « relâché avant le second frame ».
  Future<Duration> timeHeldOnSplash(WidgetTester tester, GoRouter router) async {
    Duration elapsed = Duration.zero;
    while (locationOf(router) == OnboardingRoutes.splash && elapsed < ceiling) {
      await tester.pump(samplingStep);
      elapsed += samplingStep;
    }
    return elapsed;
  }

  group('latence de lancement — splash de marque', () {
    testWidgets('relâche la navigation dès que son entrée a atterri', (WidgetTester tester) async {
      final GoRouter router = await pumpSplash(tester, reduceMotion: false);

      final Duration held = await timeHeldOnSplash(tester, router);

      expect(
        locationOf(router),
        OnboardingRoutes.welcome,
        reason: 'le splash doit finir par relâcher la navigation',
      );
      expect(
        held,
        lessThanOrEqualTo(PrismMotion.slow + frame60Hz),
        reason: 'le splash ne doit pas retenir plus longtemps que son entrée '
            '(${PrismMotion.slow.inMilliseconds} ms) : au-delà, il attend une '
            'horloge, pas une donnée ni une animation',
      );
    });

    testWidgets('sous mouvement réduit, ne retient pas du tout', (WidgetTester tester) async {
      final GoRouter router = await pumpSplash(tester, reduceMotion: true);

      final Duration held = await timeHeldOnSplash(tester, router);

      expect(locationOf(router), OnboardingRoutes.welcome);
      expect(
        held,
        lessThanOrEqualTo(frame60Hz),
        reason: 'sans entrée à laisser atterrir, il ne reste rien à attendre — '
            'retenir quand même serait le pire des deux mondes : ni mouvement, '
            'ni contenu',
      );
    });

    testWidgets('relâcher une fois suffit — aucune navigation en double', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpSplash(tester, reduceMotion: false);
      await timeHeldOnSplash(tester, router);

      // Bien au-delà de toute borne d'entrée : si une seconde navigation était
      // programmée, elle se serait déclenchée ici.
      await tester.pump(const Duration(seconds: 2));

      expect(locationOf(router), OnboardingRoutes.welcome);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un appui court-circuite l’attente', (WidgetTester tester) async {
      final GoRouter router = await pumpSplash(tester, reduceMotion: false);
      await tester.pump(const Duration(milliseconds: 16));

      await tester.tap(find.byType(SplashScreen));
      await tester.pump();

      expect(locationOf(router), OnboardingRoutes.welcome);
    });
  });
}
