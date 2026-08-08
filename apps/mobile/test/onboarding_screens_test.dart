import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'package:certigo/features/onboarding/application/onboarding_controller.dart';
import 'package:certigo/features/notifications/notification_service.dart';
import 'package:certigo/features/onboarding/presentation/attribution_screen.dart';
import 'package:certigo/features/onboarding/presentation/certification_screen.dart';
import 'package:certigo/features/onboarding/presentation/intro_screen.dart';
import 'package:certigo/features/onboarding/presentation/mascot_reaction_screen.dart';
import 'package:certigo/features/onboarding/presentation/notifications_screen.dart';
import 'package:certigo/features/onboarding/presentation/onboarding_common.dart';
import 'package:certigo/features/onboarding/presentation/path_building_screen.dart';
import 'package:certigo/features/onboarding/presentation/paywall_screen.dart';
import 'package:certigo/features/onboarding/presentation/value_list_screen.dart';
import 'package:certigo/features/onboarding/presentation/widget_promo_screen.dart';

/// Widget tests for the Part-2 onboarding screens. We host each screen under a
/// tiny [GoRouter] (its own route + a stub target) so navigation callbacks
/// resolve, and read the shared [onboardingControllerProvider] to prove that a
/// selection lights up the sticky CTA path. We never depend on real network
/// fonts and keep animations bounded so `pumpAndSettle` terminates.
void main() {
  Future<ProviderContainer> pumpScreen(
    WidgetTester tester,
    String location,
    Widget child, {
    List<GoRoute> extraRoutes = const <GoRoute>[],
  }) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final GoRouter router = GoRouter(
      initialLocation: location,
      routes: <RouteBase>[
        GoRoute(path: location, builder: (_, __) => child),
        ...extraRoutes,
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: PrismTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    return container;
  }

  testWidgets('CertificationScreen renders and a tap selects a certification', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await pumpScreen(
      tester,
      '/onboarding/certification',
      const CertificationScreen(),
    );
    expect(find.text('AZ-900'), findsOneWidget);
    expect(find.text('AI-900'), findsOneWidget);

    await tester.tap(find.text('AZ-900'));
    await tester.pump();
    // Selection recorded → the CTA is no longer disabled.
    expect(
      c.read(onboardingControllerProvider).targetCertification,
      TargetCertification.az900,
    );
  });

  testWidgets(
    'AttributionScreen shows the "bientôt" tag and records a choice',
    (WidgetTester tester) async {
      final ProviderContainer c = await pumpScreen(
        tester,
        '/onboarding/attribution',
        const AttributionScreen(),
      );
      expect(find.text('Comment nous as-tu connus ?'), findsOneWidget);
      expect(find.byType(SoonTag), findsOneWidget);

      await tester.tap(find.text('YouTube'));
      await tester.pump();
      expect(
        c.read(onboardingControllerProvider).attributionSource,
        AttributionSource.youtube,
      );
    },
  );

  testWidgets('PaywallScreen renders both plans with a RECOMMANDÉ badge', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await pumpScreen(
      tester,
      '/onboarding/paywall',
      const PaywallScreen(),
    );
    expect(find.text('Certigo Premium'), findsOneWidget);
    expect(find.text('RECOMMANDÉ'), findsOneWidget);

    await tester.tap(find.text('Certigo Premium'));
    await tester.pump();
    expect(
      c.read(onboardingControllerProvider).premiumChoice,
      PremiumChoice.premium,
    );
  });

  testWidgets('MascotReactionScreen renders its message and CTA', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      '/r',
      MascotReactionScreen(message: 'Excellent choix !', onPrimary: () {}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Excellent choix !'), findsWidgets);
    expect(find.text('CONTINUER'), findsOneWidget);
  });

  testWidgets('ValueListScreen renders its benefits', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      '/v',
      ValueListScreen(
        message: 'Voici ce que tu peux accomplir en 3 mois.',
        primaryLabel: 'CONTINUER',
        onPrimary: () {},
        benefits: const <ValueBenefit>[
          ValueBenefit(
            icon: Icons.hub_rounded,
            title: 'Bénéfice A',
            subtitle: 'sous-titre A',
          ),
          ValueBenefit(
            icon: Icons.quiz_rounded,
            title: 'Bénéfice B',
            subtitle: 'sous-titre B',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bénéfice A'), findsOneWidget);
    expect(find.text('Bénéfice B'), findsOneWidget);
  });

  testWidgets('NimbusIntroScreen types its message without exception', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      '/i',
      NimbusIntroScreen(
        message: 'Salut, moi c\'est Nimbus !',
        primaryLabel: 'CONTINUER',
        onPrimary: () {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Salut, moi c\'est Nimbus !'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NotificationsScreen renders the primer', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      '/onboarding/notifications',
      const NotificationsScreen(),
    );
    expect(find.text('Reste régulier grâce aux rappels'), findsOneWidget);
    expect(find.text('ACTIVER LES RAPPELS'), findsOneWidget);
  });

  testWidgets(
    'NotificationsScreen records a denied OS permission and continues',
    (WidgetTester tester) async {
      NotificationService.debugConfigure(
        loadLocalTimezone: () async => 'UTC',
        initializePlugin: (_) async => true,
        requestPlatformPermission: () async => false,
      );
      final ProviderContainer container = await pumpScreen(
        tester,
        '/onboarding/notifications',
        const NotificationsScreen(),
        extraRoutes: <GoRoute>[
          GoRoute(
            path: '/onboarding/widget',
            builder: (_, __) => const Scaffold(body: Text('WIDGET_STUB')),
          ),
        ],
      );

      await tester.tap(find.text('ACTIVER LES RAPPELS'));
      await tester.pumpAndSettle();

      expect(container.read(onboardingControllerProvider).reminders, isFalse);
      expect(find.text('WIDGET_STUB'), findsOneWidget);
    },
  );

  testWidgets(
    'WidgetPromoScreen renders the placeholder with a "bientôt" tag',
    (WidgetTester tester) async {
      await pumpScreen(tester, '/onboarding/widget', const WidgetPromoScreen());
      expect(find.byType(SoonTag), findsOneWidget);
      expect(find.text('AJOUTER LE WIDGET'), findsOneWidget);
    },
  );

  testWidgets('PathBuildingScreen auto-advances to attribution', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      '/onboarding/building',
      const PathBuildingScreen(),
      extraRoutes: <GoRoute>[
        GoRoute(
          path: '/onboarding/attribution',
          builder: (_, __) => const Scaffold(body: Text('ATTRIBUTION_STUB')),
        ),
      ],
    );
    expect(find.textContaining('construit ton cours'), findsOneWidget);
    // The loading beat schedules an auto-advance; let it fire.
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('ATTRIBUTION_STUB'), findsOneWidget);
  });
}
