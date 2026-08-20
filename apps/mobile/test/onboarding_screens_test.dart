import 'package:certigo/app/active_track_store.dart';
import 'package:certigo/app/providers.dart';
import 'package:certigo/features/onboarding/application/onboarding_controller.dart';
import 'package:certigo/features/onboarding/presentation/certification_screen.dart';
import 'package:certigo/features/onboarding/presentation/onboarding_common.dart';
import 'package:certigo/features/onboarding/presentation/welcome_screen.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_user_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  final List<TrackSummary> tracks = <TrackSummary>[
    for (final TargetCertification certification in availableTargetCertifications)
      TrackSummary(
        id: certification.trackId,
        code: certification.code,
        title: certification.title,
        level: 'fundamentals',
        summary: '',
        unitCount: 1,
        lessonCount: 1,
      ),
  ];

  Future<({ProviderContainer container, FakeUserRepository users})> pumpCertification(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final FakeUserRepository users = FakeUserRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        activeTrackStoreProvider.overrideWithValue(InMemoryActiveTrackStore()),
        activeTrackOwnerIdProvider.overrideWithValue('user-1'),
        onboardingControllerProvider.overrideWith(
          (Ref ref) => OnboardingController(ownerId: 'user-1'),
        ),
        userRepositoryProvider.overrideWithValue(users),
        catalogProvider.overrideWith((Ref ref) async => tracks),
      ],
    );
    addTearDown(container.dispose);
    final GoRouter router = GoRouter(
      initialLocation: OnboardingRoutes.certification,
      routes: <RouteBase>[
        GoRoute(
          path: OnboardingRoutes.certification,
          builder: (_, __) => const CertificationScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              return Scaffold(body: Text('HOME:${ref.watch(activeTrackProvider).asData?.value}'));
            },
          ),
        ),
        GoRoute(path: OnboardingRoutes.welcome, builder: (_, __) => const WelcomeScreen()),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: PrismTheme.light(),
          routerConfig: router,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    return (container: container, users: users);
  }

  for (final TargetCertification certification in availableTargetCertifications) {
    testWidgets('${certification.code} persists and opens its own Home', (
      WidgetTester tester,
    ) async {
      final result = await pumpCertification(tester);
      await tester.scrollUntilVisible(
        find.text(certification.code),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(certification.code));
      await tester.pump();
      await tester.ensureVisible(find.text('COMMENCER CE PARCOURS'));
      await tester.tap(find.text('COMMENCER CE PARCOURS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('HOME:${certification.trackId}'), findsOneWidget);
      expect(result.users.setActiveTrackCalls, <String>[certification.trackId]);
      expect(result.container.read(activeTrackProvider).asData?.value, certification.trackId);
    });
  }

  testWidgets('welcome and certification expose no unsupported product promise', (
    WidgetTester tester,
  ) async {
    await pumpCertification(tester);

    for (final String text in <String>[
      'Certigo Premium',
      'Essai gratuit de 7 jours',
      'AJOUTER LE WIDGET',
      'AJOUTER 1 AMI',
      'J\'AI DÉJÀ UN COMPTE',
    ]) {
      expect(find.textContaining(text), findsNothing);
    }
    expect(OnboardingRoutes.all, <String>{
      OnboardingRoutes.splash,
      OnboardingRoutes.welcome,
      OnboardingRoutes.certification,
    });
  });
}
