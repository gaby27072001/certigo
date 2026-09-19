import 'package:certigo/app/providers.dart';
import 'package:certigo/features/achievements/presentation/achievements_screen.dart';
import 'package:certigo/features/friends/presentation/friends_screen.dart';
import 'package:certigo/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:certigo/features/seasons/presentation/seasons_screen.dart';
import 'package:certigo/features/share/presentation/daily_share_screen.dart';
import 'package:certigo/features/shop/presentation/shop_screen.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'support/fake_user_repository.dart';

/// The states matrix, pinned on the six secondary surfaces.
///
/// Three properties are asserted here, and each of them failed on `main` before
/// this file existed:
///
/// 1. **Erreur partielle** — a source that fails cold degrades its own module.
///    The screen's persistent chrome stays on screen, so the learner keeps the
///    way back and the controls that do not depend on that source.
/// 2. **Refresh conserve le contenu** — a refresh that *fails* leaves the
///    content it failed to replace on screen. This is the one `AsyncValue.when`
///    gets wrong: it branches on `hasError` without consulting `hasValue`, so a
///    network blip during a pull-to-refresh used to swap a populated list for
///    "Connexion impossible".
/// 3. **Empty state actionnable** — an empty module names a way out of itself,
///    and does not label that way out with a refresh glyph (the regression
///    [PrismStatusView.actionIcon] was introduced to prevent).
///
/// A note on what is *not* claimed: a successful refresh was already safe.
/// `when` defaults to `skipLoadingOnRefresh: true`, and a resolved provider
/// that is invalidated keeps painting its previous value while the new one is
/// in flight. Only the failing refresh lost content.
void main() {
  // ── Fixtures ────────────────────────────────────────────────────────────
  ShopCatalog catalog({bool empty = false}) => ShopCatalog(
        gems: 50,
        items: empty
            ? const <ShopItem>[]
            : const <ShopItem>[
                ShopItem(
                  id: 'freeze',
                  name: 'Gel de série',
                  description: 'Protège ta série un jour sans activité.',
                  priceGems: 30,
                  kind: 'StreakFreeze',
                  amount: 1,
                ),
              ],
      );

  AchievementBoard board({bool empty = false}) => AchievementBoard(
        unlocked: empty ? 0 : 1,
        total: empty ? 0 : 1,
        achievements: empty
            ? const <Achievement>[]
            : const <Achievement>[
                Achievement(
                  id: 'streak-7',
                  kind: 'streak',
                  name: 'Série de feu',
                  description: 'Atteins une série de 7 jours.',
                  tier: 'gold',
                  threshold: 7,
                  progress: 7,
                  rewardGems: 50,
                  unlocked: true,
                ),
              ],
      );

  FriendList friends({bool empty = false}) => FriendList(
        count: empty ? 0 : 1,
        friends: empty
            ? const <Friend>[]
            : <Friend>[
                Friend(
                  userId: 'u-alex',
                  displayName: 'Alex Martin',
                  handle: 'alex#1234',
                  level: 7,
                  streakDays: 12,
                  xp: 3400,
                  friendsSince: DateTime(2024, 1, 1),
                ),
              ],
      );

  League league({bool empty = false}) => League(
        periodLeagueId: 'w-1',
        tier: LeagueTier.bronze,
        endsAt: DateTime(2030, 1, 1),
        promoteCount: 7,
        meUserId: 'u1',
        entries: empty
            ? const <LeaderboardEntry>[]
            : const <LeaderboardEntry>[
                LeaderboardEntry(
                  userId: 'u1',
                  displayName: 'Alex Martin',
                  rank: 1,
                  weeklyXp: 480,
                ),
              ],
      );

  Season season() => const Season(
        id: '2025-01',
        year: 2025,
        month: 1,
        theme: 'Forge cosmique',
        tagline: 'Allume les étoiles, une leçon à la fois.',
        mascot: 'nova',
        accent: '#7C5CFC',
        badgeId: 'badge-jan',
        badgeTitle: 'Forgeron stellaire',
        gems: 120,
        badgesEarned: 1,
        challenge: SeasonChallenge(
          kind: 'lessons',
          title: 'Termine 30 leçons',
          target: 30,
          current: 12,
          rewardGems: 80,
          completed: false,
          claimed: false,
          claimable: false,
        ),
      );

  ShareCard shareCard() => ShareCard(
        shareId: 'share-1',
        displayName: 'Alex Martin',
        handle: 'alex#4242',
        streakDays: 12,
        level: 7,
        dailyXp: 42,
        dailyGoalXp: 50,
        goalMet: false,
        readinessScore: 68,
        trackCode: 'AZ-900',
        mascot: 'Nimbus',
        headline: '12 jours de serie',
        caption: 'Rejoins-moi sur Certigo',
        referralCode: 'ABCD12',
        generatedAt: DateTime.utc(2025, 1, 6, 12),
      );

  // ── Override builders ───────────────────────────────────────────────────

  /// Never resolves a value: the cold-failure path.
  Override coldFailure<T>(AutoDisposeFutureProvider<T> provider) =>
      provider.overrideWith((Ref ref) async => throw StateError('source down'));

  /// Resolves once, then fails: the failed-refresh path. Throwing inside the
  /// provider body (rather than completing a future with an error) keeps the
  /// failure inside Riverpod, where it becomes an `AsyncError` that still
  /// carries the previous value.
  Override resolvesThenFails<T>(AutoDisposeFutureProvider<T> provider, T value) {
    int calls = 0;
    return provider.overrideWith((Ref ref) async {
      calls++;
      if (calls == 1) {
        return value;
      }
      throw StateError('refresh down');
    });
  }

  /// Re-runs [provider] and waits for the outcome, swallowing a failure exactly
  /// as `refreshQuietly` does behind the indicator.
  Future<void> Function(ProviderContainer) refresher<T>(
    AutoDisposeFutureProvider<T> provider,
  ) {
    return (ProviderContainer container) async {
      try {
        await container.refresh(provider.future);
      } catch (_) {
        return;
      }
    };
  }

  /// One screen under test, described by what must survive each failure.
  final List<_Surface> surfaces = <_Surface>[
    _Surface(
      name: 'Boutique',
      route: '/shop',
      build: () => const ShopScreen(),
      refresh: refresher(shopCatalogProvider),
      // The back bar: without it a failed load strands the learner on a screen
      // with no way out, and Boutique has no bottom-nav tab of its own.
      chrome: () => find.text('Boutique'),
      content: () => find.text('Gel de série'),
      unavailable: ShopLabels.unavailable,
      cold: () => coldFailure(shopCatalogProvider),
      flaky: () => resolvesThenFails(shopCatalogProvider, catalog()),
      empty: () => shopCatalogProvider.overrideWith((Ref ref) async => catalog(empty: true)),
      emptyTitle: ShopLabels.emptyTitle,
      emptyAction: ShopLabels.emptyAction,
    ),
    _Surface(
      name: 'Succès',
      route: '/achievements',
      build: () => const AchievementsScreen(),
      refresh: refresher(achievementBoardProvider),
      chrome: () => find.text('Succès'),
      content: () => find.text('Série de feu'),
      unavailable: AchievementLabels.unavailable,
      cold: () => coldFailure(achievementBoardProvider),
      flaky: () => resolvesThenFails(achievementBoardProvider, board()),
      empty: () => achievementBoardProvider.overrideWith((Ref ref) async => board(empty: true)),
      emptyTitle: AchievementLabels.emptyTitle,
      emptyAction: AchievementLabels.emptyAction,
    ),
    _Surface(
      name: 'Amis',
      route: '/friends',
      build: () => const FriendsScreen(),
      refresh: refresher(friendListProvider),
      // Amis keeps more than a back bar: the add-friend field is the one
      // control that does not read the roster, so a roster failure must leave
      // it usable.
      chrome: () => find.byType(TextField),
      content: () => find.text('Alex Martin'),
      unavailable: FriendLabels.unavailable,
      cold: () => coldFailure(friendListProvider),
      flaky: () => resolvesThenFails(friendListProvider, friends()),
      empty: () => friendListProvider.overrideWith((Ref ref) async => friends(empty: true)),
      emptyTitle: FriendLabels.emptyTitle,
      emptyAction: FriendLabels.emptyAction,
    ),
    _Surface(
      name: 'Saison',
      route: '/seasons',
      build: () => const SeasonsScreen(),
      refresh: refresher(seasonProvider),
      chrome: () => find.text('Saison'),
      content: () => find.text('Forge cosmique'),
      unavailable: SeasonLabels.unavailable,
      cold: () => coldFailure(seasonProvider),
      flaky: () => resolvesThenFails(seasonProvider, season()),
    ),
    _Surface(
      name: 'Partage du jour',
      route: '/share-daily',
      build: () => const DailyShareScreen(),
      refresh: refresher(dailyShareCardProvider),
      chrome: () => find.text('Partage du jour'),
      content: () => find.text('12 jours de serie'),
      unavailable: DailyShareLabels.unavailable,
      cold: () => coldFailure(dailyShareCardProvider),
      flaky: () => resolvesThenFails(dailyShareCardProvider, shareCard()),
    ),
    _Surface(
      // Leaderboard is a bottom-nav tab, so it carries no back bar to preserve;
      // the shell supplies its chrome. What it must not do is lose standings
      // the learner is reading because a refresh failed.
      name: 'Ligue',
      route: '/leaderboard',
      build: () => const LeaderboardScreen(),
      refresh: refresher(leagueProvider),
      chrome: null,
      content: () => find.text('Alex Martin'),
      unavailable: LeagueLabels.unavailable,
      cold: () => coldFailure(leagueProvider),
      flaky: () => resolvesThenFails(leagueProvider, league()),
      empty: () => leagueProvider.overrideWith((Ref ref) async => league(empty: true)),
      emptyTitle: LeagueLabels.emptyTitle,
      emptyAction: LeagueLabels.emptyAction,
    ),
  ];

  /// Hosts [surface] on its own route with [override] applied, returning the
  /// container so a test can drive a refresh through it.
  Future<ProviderContainer> pump(
    WidgetTester tester,
    _Surface surface,
    Override override,
  ) async {
    // Tall enough that lazy lists build their whole body under the Ahem test
    // font, wide enough that one-square-em glyphs do not manufacture overflows.
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        override,
        // Boutique reads the freeze reserve off the profile. It is a second,
        // independent source — the shop stays usable without it — but left
        // un-overridden it reaches for the network and poisons the test.
        meProvider.overrideWith((Ref ref) async => testUserProfile()),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: surface.route,
      routes: <RouteBase>[
        GoRoute(
          path: surface.route,
          builder: (BuildContext context, GoRouterState state) => surface.build(),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: PrismTheme.light(), routerConfig: router),
      ),
    );
    // Never pumpAndSettle: the aurora background loops forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  group('une source en échec froid ne vide que son module', () {
    for (final _Surface surface in surfaces) {
      testWidgets('${surface.name} garde son chrome et nomme ce qui a échoué', (
        WidgetTester tester,
      ) async {
        await pump(tester, surface, surface.cold());

        // The failure is named in this module's own words, not as a generic
        // screen-wide takeover.
        expect(
          find.text(surface.unavailable),
          findsOneWidget,
          reason: '${surface.name}: the error must say what could not be loaded',
        );
        expect(find.text('Réessayer'), findsOneWidget, reason: 'the module offers its own retry');

        final Finder? chrome = surface.chrome?.call();
        if (chrome != null) {
          expect(
            chrome,
            findsWidgets,
            reason: '${surface.name}: a failing source must not take the screen chrome with it',
          );
        }
      });
    }
  });

  group('un rafraîchissement qui échoue conserve le contenu affiché', () {
    for (final _Surface surface in surfaces) {
      testWidgets('${surface.name} garde ses données quand la mise à jour échoue', (
        WidgetTester tester,
      ) async {
        final ProviderContainer container = await pump(tester, surface, surface.flaky());

        // Baseline: the content the learner is reading.
        expect(
          surface.content(),
          findsWidgets,
          reason: '${surface.name}: fixture must render before the refresh',
        );

        // Refresh — and it fails. Awaiting the provider's own future (rather
        // than invalidating and hoping a pump lands after it) makes the failure
        // observable at a known point.
        await surface.refresh(container);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          surface.content(),
          findsWidgets,
          reason: '${surface.name}: a failed refresh must not cost the learner '
              'the content they already had',
        );
        // The failure is reported beside the content, never instead of it.
        expect(
          find.text(AsyncModuleLabels.stale),
          findsOneWidget,
          reason: '${surface.name}: the stale banner reports the failed update',
        );
        expect(
          find.text(surface.unavailable),
          findsNothing,
          reason: '${surface.name}: the module-wide error view must not take over',
        );
      });
    }
  });

  group('un module vide propose une action', () {
    for (final _Surface surface in surfaces.where((_Surface s) => s.empty != null)) {
      testWidgets('${surface.name} nomme la suite', (WidgetTester tester) async {
        await pump(tester, surface, surface.empty!());

        expect(find.text(surface.emptyTitle!), findsOneWidget);

        final PrismStatusView view = tester.widget<PrismStatusView>(
          find.byType(PrismStatusView),
        );
        expect(
          view.onAction,
          isNotNull,
          reason: '${surface.name}: an empty state without an action is a dead end',
        );
        expect(view.actionLabel, surface.emptyAction);
        // A control must name its own action. "Voir la bibliothèque" behind a
        // refresh glyph is the regression `actionIcon` was added to prevent.
        expect(
          view.actionIcon,
          isNot(Icons.refresh_rounded),
          reason: '${surface.name}: this action does not refresh anything',
        );
      });
    }

    testWidgets('Amis donne le champ à l\'apprenant au lieu de le nommer', (
      WidgetTester tester,
    ) async {
      final _Surface amis = surfaces.firstWhere((_Surface s) => s.name == 'Amis');
      await pump(tester, amis, amis.empty!());

      final Finder field = find.byType(TextField);
      expect(
        tester.widget<TextField>(field).focusNode?.hasFocus,
        isFalse,
        reason: 'nothing is focused before the action is taken',
      );

      await tester.tap(find.text(FriendLabels.emptyAction));
      await tester.pump();

      // A non-null `onAction` can still be a no-op. The roster's way out is the
      // field directly above it, so the action has to actually land there.
      expect(
        tester.widget<TextField>(field).focusNode?.hasFocus,
        isTrue,
        reason: 'the action must hand over the field, not merely describe it',
      );
    });
  });

  group('le geste de rafraîchissement est réellement câblé', () {
    testWidgets('tirer vers le bas sur la Boutique redemande le catalogue', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      final Override counted = shopCatalogProvider.overrideWith((Ref ref) async {
        calls++;
        return catalog();
      });
      await pump(tester, surfaces.first, counted);
      expect(calls, 1, reason: 'one load on mount');

      // A RefreshIndicator that is present but not wired to a scrollable is a
      // decoration; only the gesture proves it. The drag has to clear
      // `_kDragContainerExtentPercentage` — a quarter of the viewport — before
      // the indicator arms, which on this 1600px surface is about 390px.
      await tester.fling(find.byType(ListView), const Offset(0, 600), 1200);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(calls, greaterThan(1), reason: 'the pull must re-request the catalog');

      // Let the indicator retract before the test tears the tree down.
      await tester.pump(const Duration(seconds: 1));
    });
  });
}

/// Copy shared with `AsyncModule`, kept here so the guard names the string it
/// asserts instead of duplicating a literal.
abstract final class AsyncModuleLabels {
  static const String stale = 'Mise à jour impossible. Voici les dernières données reçues.';
}

class _Surface {
  _Surface({
    required this.name,
    required this.route,
    required this.build,
    required this.refresh,
    required this.chrome,
    required this.content,
    required this.unavailable,
    required this.cold,
    required this.flaky,
    this.empty,
    this.emptyTitle,
    this.emptyAction,
  });

  final String name;
  final String route;
  final Widget Function() build;

  /// Re-runs the surface's source and waits for the outcome, swallowing a
  /// failure exactly as `refreshQuietly` does behind the indicator.
  final Future<void> Function(ProviderContainer container) refresh;

  /// What must outlive a cold failure, or null where the shell owns the chrome.
  final Finder Function()? chrome;
  final Finder Function() content;
  final String unavailable;
  final Override Function() cold;
  final Override Function() flaky;

  /// Null where the surface has no empty state: the server always returns a
  /// season and a share card.
  final Override Function()? empty;
  final String? emptyTitle;
  final String? emptyAction;
}
