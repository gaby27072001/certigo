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

/// Onboarding contre un catalogue servi en mode `versioned`.
///
/// Invariant : l'identifiant de piste du catalogue dépend de
/// `CONTENT_REPOSITORY_MODE` côté backend. En `legacy` il vaut `az-900` ; en
/// `versioned` il vaut `microsoft.az-900.track.main`. `onboarding_screens_test`
/// ne couvre que la première forme — il construit son catalogue avec
/// `id: certification.trackId` — donc il ne peut pas voir la panne mesurée le
/// 2026-09-10 sur l'environnement de développement, où l'écran n'offrait
/// aucune certification et affichait « Aucun parcours disponible ».
///
/// Ce fichier couvre la seconde forme : les cartes doivent s'afficher, et la
/// sélection doit envoyer l'id **du catalogue**, jamais l'id historique — sans
/// quoi `POST /me/active-track` répond 404 et l'onboarding est infranchissable.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // Libellé du bouton principal de l'écran de choix. Extrait en constante parce
  // que sa casse a déjà changé une fois (#468, « une seule convention de casse
  // pour les libellés d'action ») et avait alors cassé ce test en silence.
  const String primaryActionLabel = 'Commencer ce parcours';

  /// Forme exacte renvoyée par `GET /catalog/tracks` quand le backend tourne en
  /// `versioned` (relevée sur l'environnement de développement).
  String versionedIdFor(TargetCertification certification) =>
      'microsoft.${certification.trackId}.track.main';

  final List<TrackSummary> versionedTracks = <TrackSummary>[
    for (final TargetCertification certification in availableTargetCertifications)
      TrackSummary(
        id: versionedIdFor(certification),
        code: certification.code,
        title: certification.title,
        level: 'fundamentals',
        summary: '',
        unitCount: 1,
        lessonCount: 1,
        slug: certification.trackId,
        officialCode: certification.code,
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
        catalogProvider.overrideWith((Ref ref) async => versionedTracks),
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

  testWidgets('a versioned catalog still offers every certification', (WidgetTester tester) async {
    await pumpCertification(tester);

    expect(find.text('Aucun parcours disponible'), findsNothing);
    for (final TargetCertification certification in availableTargetCertifications) {
      await tester.scrollUntilVisible(
        find.text(certification.code),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(certification.code), findsOneWidget);
    }
  });

  for (final TargetCertification certification in availableTargetCertifications) {
    testWidgets('${certification.code} sends the versioned catalog id, not the legacy id', (
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
      await tester.ensureVisible(find.text(primaryActionLabel));
      await tester.tap(find.text(primaryActionLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final String expected = versionedIdFor(certification);
      expect(result.users.setActiveTrackCalls, <String>[expected]);
      expect(result.container.read(activeTrackProvider).asData?.value, expected);
      expect(find.text('HOME:$expected'), findsOneWidget);
    });
  }

  test('certification matching accepts both id namespaces and is not code-blind', () {
    const TargetCertification az900 = TargetCertification.az900;

    TrackSummary track({String id = '', String code = '', String? slug}) => TrackSummary(
          id: id,
          code: code,
          title: '',
          level: 'fundamentals',
          summary: '',
          unitCount: 1,
          lessonCount: 1,
          slug: slug,
        );

    expect(az900.matchesTrack(track(id: 'az-900', code: 'AZ-900')), isTrue);
    expect(az900.matchesTrack(track(id: 'microsoft.az-900.track.main', code: 'AZ-900')), isTrue);
    expect(az900.matchesTrack(track(id: 'x', code: '', slug: 'az-900')), isTrue);
    expect(az900.matchesTrack(track(id: 'microsoft.az-104.track.main', code: 'AZ-104')), isFalse);
    expect(az900.matchesTrack(track(id: '', code: '')), isFalse);
  });
}
