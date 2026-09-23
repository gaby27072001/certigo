import 'dart:async';

import 'package:certigo/app/providers.dart';
import 'package:certigo/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:certigo/features/leaderboard/presentation/league_resolution_card.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

League _league({LeagueTier tier = LeagueTier.obsidian}) => League(
      periodLeagueId: 'week',
      tier: tier,
      endsAt: DateTime.utc(2030),
      promoteCount: 0,
      meUserId: 'me',
      myRank: 3,
      myWeeklyXp: 42,
      myZone: LeagueZone.relegation,
      relegateCount: 1,
      previousTier: 'Diamant',
      entries: const <LeaderboardEntry>[
        LeaderboardEntry(
            userId: 'me',
            displayName: 'Éléonore au nom très long',
            rank: 3,
            weeklyXp: 42,
            zone: LeagueZone.relegation),
      ],
    );

const LeagueResolution _resolution = LeagueResolution(
  periodLeagueId: 'week',
  tier: LeagueTier.obsidian,
  outcomes: <LeagueOutcome>[
    LeagueOutcome(
        userId: 'me',
        displayName: 'Éléonore',
        rank: 3,
        zone: LeagueZone.relegation,
        movement: LeagueMovement.relegated,
        fromTier: 'Obsidienne',
        toTier: 'Diamant',
        gemReward: 12),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  League? league,
  double scale = 1,
  Future<LeagueResolution> Function()? resolution,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      leagueProvider.overrideWith((Ref ref) async => league ?? _league()),
      leagueResolutionProvider('week').overrideWith(
          (Ref ref) => resolution?.call() ?? Future<LeagueResolution>.value(_resolution)),
    ],
    child: MaterialApp(
      theme: PrismTheme.light(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const Scaffold(body: LeaderboardScreen()),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('apex shows authoritative rank and no promotion promise', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(find.text('Ligue Obsidienne'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    expect(find.text(LeagueLabels.everyonePromotes), findsNothing);
    expect(find.text(LeagueLabels.promotionZone), findsNothing);
    expect(find.textContaining('Aucune promotion'), findsOneWidget);
    expect(
        find.bySemanticsLabel(RegExp('Rang 3, Éléonore.*42 XP, Zone de descente')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('future league has a neutral title rather than Bronze', (tester) async {
    await _pump(tester, league: _league(tier: LeagueTier.unknown));
    expect(find.text('Ligue'), findsOneWidget);
    expect(find.text('Ligue Bronze'), findsNothing);
  });

  testWidgets('projection is lazy, conditional, and never claims a reward', (tester) async {
    var reads = 0;
    await _pump(tester, resolution: () async {
      reads++;
      return _resolution;
    });
    expect(reads, 0);
    await tester.tap(find.text('Voir la projection de fin de semaine'));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(find.textContaining('aucune gemme n’est attribuée ici'), findsOneWidget);
    expect(find.textContaining('12 gemmes potentielles'), findsOneWidget);
    expect(find.textContaining('Descente prévue : Obsidienne → Diamant'), findsOneWidget);
  });

  testWidgets('missing resolution affects only projection and can be retried', (tester) async {
    var reads = 0;
    await _pump(tester, resolution: () async {
      if (++reads == 1) throw const NotFoundFailure('technical backend detail');
      return _resolution;
    });
    await tester.tap(find.text('Voir la projection de fin de semaine'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Projection indisponible'), findsOneWidget);
    expect(find.text('42 XP'), findsOneWidget);
    expect(find.textContaining('technical backend detail'), findsNothing);
    await tester.tap(find.text('Actualiser la projection'));
    await tester.pumpAndSettle();
    expect(find.textContaining('12 gemmes potentielles'), findsOneWidget);
  });

  testWidgets('period rollover does not display previous week outcome', (tester) async {
    await _pump(tester, resolution: () async => throw const LeaguePeriodChanged());
    await tester.tap(find.text('Voir la projection de fin de semaine'));
    await tester.pumpAndSettle();
    expect(find.textContaining('La semaine a changé'), findsOneWidget);
    expect(find.textContaining('gemmes potentielles'), findsNothing);
  });

  testWidgets('projection has a loading state without hiding the league', (tester) async {
    final Completer<LeagueResolution> gate = Completer<LeagueResolution>();
    await _pump(tester, resolution: () => gate.future);
    await tester.tap(find.text('Voir la projection de fin de semaine'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('42 XP'), findsOneWidget);
    gate.complete(_resolution);
    await tester.pumpAndSettle();
  });

  testWidgets('large text wraps full names and counters without overflow', (tester) async {
    await _pump(tester, scale: 2);
    await tester.scrollUntilVisible(find.text('42 XP'), 200);
    expect(tester.takeException(), isNull);
    final Text name = tester.widget(find.text('Éléonore au nom très long'));
    expect(name.maxLines, isNull);
    expect(name.overflow, isNot(TextOverflow.ellipsis));
  });
}
