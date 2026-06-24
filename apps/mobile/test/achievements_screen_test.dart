import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:microlingo/app/providers.dart';
import 'package:microlingo/features/achievements/presentation/achievements_screen.dart';
import 'package:prism_ui/prism_ui.dart';

/// Widget test for [AchievementsScreen].
///
/// The screen is presented above the app shell and reads its board from
/// [achievementBoardProvider]; here we override that provider with a
/// deterministic fake and host the screen under a tiny one-route [GoRouter] so
/// we can assert it renders the header, the unlocked-tally label and an
/// individual trophy card. We never call [WidgetTester.pumpAndSettle] because
/// the shared aurora background runs a looping animation that never settles.
void main() {
  AchievementBoard fakeBoard() => const AchievementBoard(
        unlocked: 1,
        total: 2,
        achievements: <Achievement>[
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
          Achievement(
            id: 'lessons-50',
            kind: 'lessons',
            name: 'Marathonien',
            description: 'Termine 50 leçons.',
            tier: 'silver',
            threshold: 50,
            progress: 12,
            rewardGems: 30,
            unlocked: false,
          ),
        ],
      );

  Future<void> pumpAchievements(WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/achievements',
      routes: <RouteBase>[
        GoRoute(
          path: '/achievements',
          builder: (BuildContext context, GoRouterState state) =>
              const AchievementsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          achievementBoardProvider.overrideWith((Ref ref) async => fakeBoard()),
        ],
        child: MaterialApp.router(
          theme: PrismTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    // Resolve the async provider, then advance one short frame without settling
    // the looping background animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('renders the header, the unlocked tally and a trophy',
      (tester) async {
    await pumpAchievements(tester);

    expect(find.text('Succès'), findsOneWidget);
    expect(find.text('Trophées débloqués'), findsOneWidget);
    expect(find.text('Série de feu'), findsOneWidget);
  });
}
