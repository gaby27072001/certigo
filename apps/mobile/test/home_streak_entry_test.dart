import 'dart:async';

import 'package:certigo/app/providers.dart';
import 'package:certigo/app/router.dart';
import 'package:certigo/features/home/application/home_controller.dart';
import 'package:certigo/features/home/presentation/home_screen.dart';
import 'package:certigo/features/streak/presentation/streak_copy.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'support/fake_streak_repository.dart';
import 'support/fake_user_repository.dart';

/// Home is where a repairable streak becomes *visible*: the offer would
/// otherwise exist only for a learner who thought to tap the streak badge.
void main() {
  const String trackId = 'microsoft.az-900.track.main';

  LearningPath path() => const LearningPath(
        trackId: trackId,
        trackName: 'Azure Fundamentals',
        exam: 'AZ-900',
        readinessScore: 62,
        readinessTrend7d: 4,
        units: <PathUnit>[],
        domains: <DomainProgress>[],
      );

  Future<void> pumpHome(WidgetTester tester, FakeStreakRepository repo) async {
    await tester.binding.setSurfaceSize(const Size(800, 2800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GoRouter router = GoRouter(
      initialLocation: Routes.home,
      routes: <RouteBase>[
        GoRoute(
          path: Routes.home,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: HomeScreen()),
        ),
        GoRoute(
          path: Routes.streak,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('MA SÉRIE')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          meProvider.overrideWith((Ref ref) async => testUserProfile()),
          homePathProvider.overrideWith((Ref ref) async => path()),
          nextBestProvider(trackId).overrideWith((Ref ref) async => throw StateError('offline')),
          streakRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(theme: PrismTheme.light(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  FakeStreakRepository serving(Result<StreakStatus> status) =>
      FakeStreakRepository(statuses: <Result<StreakStatus>>[status]);

  Future<void> openFrom(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('l\'invite de réparation', () {
    testWidgets('une série réparable s\'annonce, avec son prix et sa fenêtre', (
      WidgetTester tester,
    ) async {
      final StreakStatus status = repairableStatus();
      await pumpHome(tester, serving(Success<StreakStatus>(status)));

      expect(find.text(StreakLabels.bannerTitle(12)), findsOneWidget);
      expect(
        find.text(
          StreakLabels.bannerBody(
            50,
            formatRepairDeadline(
              const DefaultMaterialLocalizations(),
              status.repairExpiresAt!.toLocal(),
              alwaysUse24HourFormat: false,
            ),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('la toucher ouvre « Ma série »', (WidgetTester tester) async {
      await pumpHome(tester, serving(Success<StreakStatus>(repairableStatus())));

      await openFrom(tester, find.text(StreakLabels.bannerTitle(12)));

      expect(find.text('MA SÉRIE'), findsOneWidget);
    });

    testWidgets('un gel qui couvre le jour manqué rassure au lieu de vendre', (
      WidgetTester tester,
    ) async {
      await pumpHome(
        tester,
        serving(
          Success<StreakStatus>(repairableStatus(freezeTokens: 1, coveredByFreeze: true)),
        ),
      );

      expect(find.text(StreakLabels.bannerFreezeTitle), findsOneWidget);
      expect(find.text(StreakLabels.bannerFreezeBody(12)), findsOneWidget);
      expect(find.text(StreakLabels.bannerTitle(12)), findsNothing);
    });

    final Map<String, Result<StreakStatus>> silent = <String, Result<StreakStatus>>{
      'intacte': Success<StreakStatus>(blockedStatus('intact')),
      'expirée': Success<StreakStatus>(blockedStatus('expired')),
      'sans série': Success<StreakStatus>(blockedStatus('noStreak', streakDays: 0)),
      'en échec': const Err<StreakStatus>(NetworkFailure()),
    };
    silent.forEach((String name, Result<StreakStatus> status) {
      testWidgets('$name : rien de plus sur l\'accueil, et rien de moins', (
        WidgetTester tester,
      ) async {
        await pumpHome(tester, serving(status));

        expect(find.text(StreakLabels.bannerTitle(12)), findsNothing);
        expect(find.text(StreakLabels.bannerFreezeTitle), findsNothing);
        // A self-hiding prompt must not take its neighbours with it.
        expect(find.byType(StreakBadge), findsOneWidget);
        expect(find.text('Objectif du jour'), findsOneWidget);
        expect(find.text('Explorer'), findsOneWidget);
      });
    });

    testWidgets('en chargement : l\'accueil n\'attend pas la série', (WidgetTester tester) async {
      final FakeStreakRepository repo = FakeStreakRepository()..holdStatus = Completer<void>();
      await pumpHome(tester, repo);

      expect(find.text(StreakLabels.bannerTitle(12)), findsNothing);
      expect(find.text('Objectif du jour'), findsOneWidget);

      repo.holdStatus!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text(StreakLabels.bannerTitle(12)), findsOneWidget);
    });

    testWidgets('revenir au premier plan relit la série : le jour a pu changer', (
      WidgetTester tester,
    ) async {
      final FakeStreakRepository repo = serving(Success<StreakStatus>(blockedStatus('intact')));
      await pumpHome(tester, repo);
      expect(repo.statusCalls, 1);
      expect(find.text(StreakLabels.bannerTitle(12)), findsNothing);

      // Overnight, the streak broke.
      repo.serveStatus(Success<StreakStatus>(repairableStatus()));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(repo.statusCalls, 2);
      expect(find.text(StreakLabels.bannerTitle(12)), findsOneWidget);
    });
  });

  group('le badge de série', () {
    testWidgets('ouvre toujours « Ma série », même quand rien n\'est à réparer', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester, serving(Success<StreakStatus>(blockedStatus('intact'))));

      await openFrom(tester, find.byType(StreakBadge));

      expect(find.text('MA SÉRIE'), findsOneWidget);
    });

    testWidgets('est un bouton de 44 pt, nommé par la série et elle seule', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpHome(tester, serving(Success<StreakStatus>(blockedStatus('intact'))));

      final Finder badge = find.bySemanticsLabel(RegExp('Série de 3 jours'));
      expect(badge, findsOneWidget);
      final SemanticsNode node = tester.getSemantics(badge);
      expect(
        node,
        containsSemantics(isButton: true, hasTapAction: true, hint: StreakLabels.badgeHint),
      );
      // Measured before the container was added: the row's gems and XP were
      // read as part of this same button.
      expect(node.label, isNot(contains('gemmes')));

      final Size target = tester.getSize(
        find.ancestor(of: find.byType(StreakBadge), matching: find.byType(PrismPressable)),
      );
      expect(target.width, greaterThanOrEqualTo(kPrismMinTapTarget));
      expect(target.height, greaterThanOrEqualTo(kPrismMinTapTarget));
      handle.dispose();
    });
  });
}
