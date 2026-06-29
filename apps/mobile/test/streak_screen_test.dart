import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:certigo/app/providers.dart';
import 'package:certigo/features/home/presentation/streak_screen.dart';
import 'package:prism_ui/prism_ui.dart';

/// Fake [StreakRepository] used in widget tests — no network calls.
class _FakeStreakRepository implements StreakRepository {
  _FakeStreakRepository({required this.streak, this.repairResult});

  final Streak streak;
  final RepairStreakResult? repairResult;

  int repairCalls = 0;

  @override
  Future<Result<Streak>> getStreak() async => Success(streak);

  @override
  Future<Result<RepairStreakResult>> repairStreak() async {
    repairCalls++;
    if (repairResult != null) return Success(repairResult!);
    return const Err(ServerFailure('repair failed'));
  }
}

Future<void> pumpStreak(
  WidgetTester tester,
  Streak streak, {
  _FakeStreakRepository? repo,
}) async {
  final _FakeStreakRepository fakeRepo =
      repo ?? _FakeStreakRepository(streak: streak);

  final GoRouter router = GoRouter(
    initialLocation: '/streak',
    routes: <RouteBase>[
      GoRoute(
        path: '/streak',
        builder: (_, __) => const StreakScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        streakRepositoryProvider.overrideWithValue(fakeRepo),
        streakProvider.overrideWith((Ref ref) async => streak),
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
  testWidgets('renders streak count and "jours de série"', (
    WidgetTester tester,
  ) async {
    const Streak streak = Streak(
      days: 14,
      canRepair: false,
      repairCostGems: 10,
      repairedToday: false,
      freezeTokens: 2,
    );

    await pumpStreak(tester, streak);

    expect(find.text('14'), findsOneWidget);
    expect(find.text('14 jours de série'), findsOneWidget);
  });

  testWidgets('shows repair button when canRepair is true', (
    WidgetTester tester,
  ) async {
    const Streak streak = Streak(
      days: 5,
      canRepair: true,
      repairCostGems: 10,
      repairedToday: false,
      freezeTokens: 0,
    );

    await pumpStreak(tester, streak);

    expect(find.text('Réparer la série'), findsOneWidget);
    expect(find.textContaining('10'), findsWidgets);
  });

  testWidgets('does not show repair button when canRepair is false', (
    WidgetTester tester,
  ) async {
    const Streak streak = Streak(
      days: 10,
      canRepair: false,
      repairCostGems: 10,
      repairedToday: false,
      freezeTokens: 1,
    );

    await pumpStreak(tester, streak);

    expect(find.text('Réparer la série'), findsNothing);
  });

  testWidgets('shows "Réparée aujourd\'hui" chip when repairedToday', (
    WidgetTester tester,
  ) async {
    const Streak streak = Streak(
      days: 7,
      canRepair: false,
      repairCostGems: 10,
      repairedToday: true,
      freezeTokens: 0,
    );

    await pumpStreak(tester, streak);

    expect(find.text('Réparée aujourd\'hui'), findsOneWidget);
  });

  testWidgets('shows freeze tokens count', (WidgetTester tester) async {
    const Streak streak = Streak(
      days: 3,
      canRepair: false,
      repairCostGems: 10,
      repairedToday: false,
      freezeTokens: 3,
    );

    await pumpStreak(tester, streak);

    expect(find.text('3 gels'), findsOneWidget);
  });

  testWidgets('repair button calls repairStreak on the repository', (
    WidgetTester tester,
  ) async {
    const Streak streak = Streak(
      days: 4,
      canRepair: true,
      repairCostGems: 10,
      repairedToday: false,
      freezeTokens: 0,
    );
    final _FakeStreakRepository repo = _FakeStreakRepository(
      streak: streak,
      repairResult: const RepairStreakResult(days: 5, gemsBalance: 90),
    );

    await pumpStreak(tester, streak, repo: repo);

    final Finder repairBtn = find.textContaining('Réparer (');
    expect(repairBtn, findsOneWidget);

    await tester.tap(repairBtn);
    await tester.pump();

    expect(repo.repairCalls, 1);
  });
}
