import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:certigo/app/providers.dart';
import 'package:certigo/features/seasons/presentation/seasons_screen.dart';
import 'package:prism_ui/prism_ui.dart';

/// Widget test for [SeasonsScreen].
///
/// The screen is presented above the app shell and reads the current season
/// from [seasonProvider]; here we override that provider with a deterministic
/// fake and host the screen under a one-route [GoRouter] so we can assert it
/// renders the header, the season theme and its tagline. We never call
/// [WidgetTester.pumpAndSettle] — the shared aurora background loops forever.
void main() {
  Season fakeSeason() => const Season(
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

  Future<void> pumpSeasons(WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/seasons',
      routes: <RouteBase>[
        GoRoute(
          path: '/seasons',
          builder: (BuildContext context, GoRouterState state) => const SeasonsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[seasonProvider.overrideWith((Ref ref) async => fakeSeason())],
        child: MaterialApp.router(theme: PrismTheme.light(), routerConfig: router),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('renders the header, the season theme and its tagline', (tester) async {
    await pumpSeasons(tester);

    expect(find.text('Saison'), findsOneWidget);
    expect(find.text('Forge cosmique'), findsOneWidget);
    expect(find.text('Allume les étoiles, une leçon à la fois.'), findsOneWidget);
  });
}
