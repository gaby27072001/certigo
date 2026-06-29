import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:certigo/app/providers.dart';
import 'package:certigo/features/leaderboard/presentation/league_resolution_screen.dart';
import 'package:prism_ui/prism_ui.dart';

Future<void> pumpResolution(
  WidgetTester tester,
  LeagueResolution? resolution,
) async {
  final GoRouter router = GoRouter(
    initialLocation: '/league/resolution',
    routes: <RouteBase>[
      GoRoute(
        path: '/league/resolution',
        builder: (_, __) => const LeagueResolutionScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        leagueResolutionProvider.overrideWith(
          (Ref ref) async => resolution,
        ),
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

void main() {
  testWidgets('shows "Promotion" headline for a promoted outcome', (
    WidgetTester tester,
  ) async {
    final LeagueResolution promoted = const LeagueResolution(
      periodLeagueId: 'wk-2025-01',
      oldTier: LeagueTier.bronze,
      newTier: LeagueTier.silver,
      outcome: ResolutionOutcome.promoted,
      finalRank: 3,
      finalWeeklyXp: 520,
    );

    await pumpResolution(tester, promoted);

    expect(find.text('Promotion !'), findsOneWidget);
    expect(find.text('Ligue Argent'), findsOneWidget);
    expect(find.text('#3'), findsOneWidget);
    expect(find.text('520 XP'), findsOneWidget);
  });

  testWidgets('shows "Relégation" headline for a relegated outcome', (
    WidgetTester tester,
  ) async {
    final LeagueResolution relegated = const LeagueResolution(
      periodLeagueId: 'wk-2025-01',
      oldTier: LeagueTier.gold,
      newTier: LeagueTier.silver,
      outcome: ResolutionOutcome.relegated,
      finalRank: 27,
      finalWeeklyXp: 40,
    );

    await pumpResolution(tester, relegated);

    expect(find.text('Relégation'), findsOneWidget);
    expect(find.text('Ligue Argent'), findsOneWidget);
  });

  testWidgets('shows "Tu restes !" headline for a stayed outcome', (
    WidgetTester tester,
  ) async {
    final LeagueResolution stayed = const LeagueResolution(
      periodLeagueId: 'wk-2025-01',
      oldTier: LeagueTier.gold,
      newTier: LeagueTier.gold,
      outcome: ResolutionOutcome.stayed,
      finalRank: 10,
      finalWeeklyXp: 220,
    );

    await pumpResolution(tester, stayed);

    expect(find.text('Tu restes !'), findsOneWidget);
    expect(find.text('Ligue Or'), findsOneWidget);
  });

  testWidgets('shows "Aucun résultat" message when resolution is null', (
    WidgetTester tester,
  ) async {
    await pumpResolution(tester, null);

    expect(find.text('Aucun résultat disponible'), findsOneWidget);
  });
}
