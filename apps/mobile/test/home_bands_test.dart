import 'package:certigo/app/providers.dart';
import 'package:certigo/features/home/application/home_controller.dart';
import 'package:certigo/features/home/presentation/home_screen.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import 'support/fake_user_repository.dart';

/// Home is the landing surface: it must land. These tests pin the property that
/// makes that true — every band fails on its own, and none of them can take the
/// others down with it.
///
/// The Explorer shelf carries the strongest form of that requirement. None of
/// its six destinations is a bottom-nav tab, and five of them — Saisons,
/// Quêtes, Boutique, Amis, Examen blanc — have no other entry point anywhere in
/// the app (Succès is also linked from Profil, `profile_screen.dart:149`). A
/// Home that blanks on a data failure therefore strands five features.
void main() {
  LearningPath path() => const LearningPath(
        trackId: 'microsoft.az-900.track.main',
        trackName: 'Azure Fundamentals',
        exam: 'AZ-900',
        readinessScore: 62,
        readinessTrend7d: 4,
        units: <PathUnit>[],
        domains: <DomainProgress>[],
      );

  Future<void> pumpHome(
    WidgetTester tester, {
    required Override profile,
    required Override track,
  }) async {
    // Wide enough that the Ahem test font (one square em per glyph) does not
    // manufacture overflows that real type never produces; tall enough that the
    // lazy ListView builds every band, including the Explorer shelf at the end.
    await tester.binding.setSurfaceSize(const Size(800, 2800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          profile,
          track,
          // Keeps the suite hermetic: the coach shelf otherwise reaches for the
          // network. It self-hides on failure, so its content is not asserted.
          nextBestProvider('microsoft.az-900.track.main')
              .overrideWith((Ref ref) async => throw StateError('offline')),
        ],
        child: MaterialApp(
          theme: PrismTheme.light(),
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  final Override profileLoads = meProvider.overrideWith((Ref ref) async => testUserProfile());
  final Override profileFails =
      meProvider.overrideWith((Ref ref) async => throw StateError('profile down'));
  final Override trackLoads = homePathProvider.overrideWith((Ref ref) async => path());
  final Override trackAbsent = homePathProvider.overrideWith((Ref ref) async => null);
  final Override trackFails =
      homePathProvider.overrideWith((Ref ref) async => throw StateError('path down'));

  /// Every destination on this shelf. Five of the six have no other entry
  /// point anywhere in the app; Succès is also linked from Profil.
  void expectExplorerReachable() {
    expect(find.text('Explorer'), findsOneWidget);
    for (final String label in <String>[
      'Succès',
      'Saisons',
      'Quêtes',
      'Boutique',
      'Amis',
      'Examen blanc',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label is reachable from this shelf');
    }
  }

  group('HomeScreen degrades one band at a time', () {
    testWidgets('no certification selected keeps the learner and the Explorer shelf', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester, profile: profileLoads, track: trackAbsent);

      // The certification band invites, using ActivePathScreen's vocabulary.
      expect(find.text(HomeLabels.noTrackTitle), findsOneWidget);
      expect(find.text(HomeLabels.noTrackAction), findsOneWidget);

      // ...and nothing else on the surface was taken down with it.
      expect(find.byType(StreakBadge), findsOneWidget);
      expect(find.byType(GemCounter), findsOneWidget);
      expect(find.byType(XpChip), findsOneWidget);
      expect(find.text('Objectif du jour'), findsOneWidget);
      expectExplorerReachable();
    });

    testWidgets('a failing path keeps the learner and the Explorer shelf', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester, profile: profileLoads, track: trackFails);

      expect(find.text(HomeLabels.pathUnavailable), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);

      expect(find.byType(StreakBadge), findsOneWidget);
      expect(find.text('Objectif du jour'), findsOneWidget);
      expectExplorerReachable();
    });

    testWidgets('a failing profile keeps the certification band and the Explorer shelf', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester, profile: profileFails, track: trackLoads);

      expect(find.text(HomeLabels.profileUnavailable), findsOneWidget);

      // Readiness still renders: it reads the path, not the profile.
      expect(find.byType(ReadinessGauge), findsOneWidget);
      expect(find.textContaining('AZ-900'), findsWidgets);
      expectExplorerReachable();
    });

    testWidgets('both halves failing still leaves the Explorer shelf reachable', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester, profile: profileFails, track: trackFails);

      expectExplorerReachable();
    });

    testWidgets('a complete Home keeps every section it had before', (WidgetTester tester) async {
      await pumpHome(tester, profile: profileLoads, track: trackLoads);

      expect(find.byType(StreakBadge), findsOneWidget);
      expect(find.byType(ReadinessGauge), findsOneWidget);
      expect(find.text('Objectif du jour'), findsOneWidget);
      expect(find.text('Partage du jour'), findsOneWidget);
      expect(find.text(HomeLabels.noLessonInProgress), findsOneWidget);
      expectExplorerReachable();
      // No invitation when a track is active.
      expect(find.text(HomeLabels.noTrackTitle), findsNothing);
    });
  });

  group('homePathProvider models absence as data', () {
    test('returns null instead of throwing when no track is selected', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          activeTrackProvider.overrideWith(() => _StubActiveTrack(null)),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(homePathProvider.future), isNull);
    });
  });
}

class _StubActiveTrack extends ActiveTrackController {
  _StubActiveTrack(this._value);

  final String? _value;

  @override
  Future<String?> build() async => _value;
}
