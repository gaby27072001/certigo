import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:microlingo/app/providers.dart';
import 'package:microlingo/features/quests/presentation/quests_screen.dart';
import 'package:prism_ui/prism_ui.dart';

/// Widget test for [QuestsScreen].
///
/// The screen is presented above the app shell and reads the daily board from
/// [questBoardProvider]; here we override that provider with a deterministic
/// fake and host the screen under a one-route [GoRouter] so we can assert it
/// renders the header, the static section title and an individual quest. We
/// never call [WidgetTester.pumpAndSettle] — the aurora background never
/// settles.
void main() {
  QuestBoard fakeBoard() => const QuestBoard(
        date: '2025-01-01',
        gems: 10,
        quests: <Quest>[
          Quest(
            id: 'q1',
            kind: 'lessons',
            title: 'Termine 3 leçons',
            target: 3,
            current: 1,
            rewardGems: 15,
            completed: false,
            claimed: false,
            claimable: false,
          ),
        ],
      );

  Future<void> pumpQuests(WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/quests',
      routes: <RouteBase>[
        GoRoute(
          path: '/quests',
          builder: (BuildContext context, GoRouterState state) => const QuestsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          questBoardProvider.overrideWith((Ref ref) async => fakeBoard()),
        ],
        child: MaterialApp.router(
          theme: PrismTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('renders the header, the section title and a quest', (tester) async {
    await pumpQuests(tester);

    expect(find.text('Quêtes du jour'), findsOneWidget);
    expect(find.text('Objectifs du jour'), findsOneWidget);
    expect(find.text('Termine 3 leçons'), findsOneWidget);
  });
}
