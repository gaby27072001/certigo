import 'dart:math' as math;

import 'package:certigo/app/providers.dart';
import 'package:certigo/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

League _league({required int count, int promote = 7}) => League(
      periodLeagueId: 'w-1',
      tier: LeagueTier.bronze,
      endsAt: DateTime.now().add(const Duration(days: 3)),
      promoteCount: promote,
      meUserId: 'u3',
      entries: <LeaderboardEntry>[
        for (int i = 0; i < count; i++)
          LeaderboardEntry(
            userId: 'u${i + 1}',
            displayName: 'Apprenant numéro ${i + 1} au nom délibérément long',
            rank: i + 1,
            weeklyXp: 480 - i * 47,
          ),
      ],
    );

void main() {
  group('podium tones clear the contrast floor in both themes', () {
    // The regression this pinned: rank 2 was the bare literal `Color(0xFFB8C2D9)`
    // with no dark counterpart, scoring 1.79:1 on the white card — the numeral
    // was very nearly invisible in the light theme, while fine in the dark one.
    //
    // The medals are now roles on [PrismColorScheme], so the authoritative
    // check is `prism_contrast_contract_test` in `prism_ui`: it measures them
    // against `surface`, `background`, `surfaceAlt` *and* the glass, across all
    // eight shipped appearances, where this file only ever saw the card in two.
    // Promoting them found a defect this test could not: the light silver had
    // to move from `#5F6980` to `#566076`, because 5.50:1 on the card hid
    // **4.18:1** on `surfaceAlt`.
    //
    // What remains here is what the design system cannot know — that the
    // leaderboard reads the medals in rank order, and stops at three.
    const double floor = 4.5;

    for (final (String name, PrismColorScheme scheme, Color card) cases
        in <(String, PrismColorScheme, Color)>[
      ('light', PrismColorScheme.light, PrismColors.lightSurface),
      ('dark', PrismColorScheme.dark, PrismColors.darkSurface),
    ]) {
      final (String name, PrismColorScheme scheme, Color card) = cases;
      for (int rank = 1; rank <= 3; rank++) {
        test('rank $rank on the $name card', () {
          final Color? tone = podiumTone(scheme, rank);
          expect(tone, isNotNull, reason: 'ranks 1-3 are the podium');
          expect(
            _contrast(tone!, card),
            greaterThanOrEqualTo(floor),
            reason: 'rank $rank must stay legible on the $name card',
          );
        });
      }
    }

    test('rank 4 and beyond carry no podium tone', () {
      expect(podiumTone(PrismColorScheme.light, 4), isNull);
      expect(podiumTone(PrismColorScheme.light, 30), isNull);
    });

    test('the podium is three distinct tones, not one repeated', () {
      final Set<int> light = <int>{
        for (int r = 1; r <= 3; r++) podiumTone(PrismColorScheme.light, r)!.toARGB32(),
      };
      expect(light.length, 3);
    });
  });

  group('the header only promises a cut the list can draw', () {
    Future<void> pump(WidgetTester tester, League league) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[leagueProvider.overrideWith((Ref ref) async => league)],
          child: MaterialApp(
            theme: PrismTheme.light(),
            home: const Scaffold(body: LeaderboardScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
    }

    testWidgets('a cohort smaller than the promotion count promises no cut', (
      WidgetTester tester,
    ) async {
      await pump(tester, _league(count: 4));

      expect(find.text(LeagueLabels.cut(7)), findsNothing);
      expect(find.text(LeagueLabels.promotionZone), findsNothing);
      // ...and says what is actually true of this cohort, exactly once.
      expect(find.text(LeagueLabels.everyonePromotes), findsOneWidget);
    });

    testWidgets('a cohort larger than the promotion count promises and draws the cut', (
      WidgetTester tester,
    ) async {
      await pump(tester, _league(count: 9));

      expect(find.text(LeagueLabels.cut(7)), findsOneWidget);
      expect(find.text(LeagueLabels.promotionZone), findsOneWidget);
      expect(find.text(LeagueLabels.everyonePromotes), findsNothing);
    });

    testWidgets('a cohort exactly at the promotion count promises no cut', (
      WidgetTester tester,
    ) async {
      await pump(tester, _league(count: 7));

      expect(find.text(LeagueLabels.cut(7)), findsNothing);
      expect(find.text(LeagueLabels.promotionZone), findsNothing);
      expect(find.text(LeagueLabels.everyonePromotes), findsOneWidget);
    });
  });

  group('the learner keeps their marker', () {
    testWidgets('a long name yields before the "(vous)" marker does', (WidgetTester tester) async {
      // Narrow on purpose: this is the width at which the suffix used to wrap
      // the row onto two lines, and at which an ellipsis would eat it.
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            leagueProvider.overrideWith((Ref ref) async => _league(count: 4)),
          ],
          child: MaterialApp(
            theme: PrismTheme.light(),
            home: const Scaffold(body: LeaderboardScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.text(' (vous)'), findsOneWidget);
    });
  });
}
