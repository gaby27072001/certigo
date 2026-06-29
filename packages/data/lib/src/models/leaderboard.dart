/// Weekly league standings ("Momentum Leagues"). Opt-in, cohort-based (~30
/// learners per bucket), tiered Bronze → Diamond. Promotion/relegation is shown
/// but framed positively (no public shaming of the bottom).
library;

enum LeagueTier { bronze, silver, gold, platinum, diamond }

LeagueTier leagueTierFrom(String? raw) => switch (raw) {
      'silver' => LeagueTier.silver,
      'gold' => LeagueTier.gold,
      'platinum' => LeagueTier.platinum,
      'diamond' => LeagueTier.diamond,
      _ => LeagueTier.bronze,
    };

class League {
  const League({
    required this.periodLeagueId,
    required this.tier,
    required this.endsAt,
    required this.promoteCount,
    required this.entries,
    required this.meUserId,
  });

  final String periodLeagueId;
  final LeagueTier tier;
  final DateTime endsAt;

  /// Top N who promote at week end.
  final int promoteCount;
  final List<LeaderboardEntry> entries;

  /// Id used to highlight the current user's row.
  final String meUserId;

  factory League.fromJson(Map<String, dynamic> json) => League(
        periodLeagueId: json['periodLeagueId'] as String,
        tier: leagueTierFrom(json['tier'] as String?),
        endsAt:
            DateTime.parse(json['endsAt'] as String? ?? DateTime.now().toUtc().toIso8601String()),
        promoteCount: (json['promoteCount'] as num?)?.toInt() ?? 7,
        meUserId: json['meUserId'] as String? ?? '',
        entries: (json['entries'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.rank,
    required this.weeklyXp,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int rank;
  final int weeklyXp;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String? ?? 'Apprenant',
        avatarUrl: json['avatarUrl'] as String?,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        weeklyXp: (json['weeklyXp'] as num?)?.toInt() ?? 0,
      );
}

// ---------------------------------------------------------------------------
// League resolution — result delivered at the end of each weekly period.
// ---------------------------------------------------------------------------

/// Outcome of a completed weekly league period for the learner.
enum ResolutionOutcome { promoted, stayed, relegated }

ResolutionOutcome _resolutionOutcomeFrom(String? raw) => switch (raw) {
      'promoted' => ResolutionOutcome.promoted,
      'relegated' => ResolutionOutcome.relegated,
      _ => ResolutionOutcome.stayed,
    };

/// Delivered by `GET /me/league/resolution` once the weekly period closes.
/// Null when there is no completed period yet (first‑ever league week).
class LeagueResolution {
  const LeagueResolution({
    required this.periodLeagueId,
    required this.oldTier,
    required this.newTier,
    required this.outcome,
    required this.finalRank,
    required this.finalWeeklyXp,
  });

  final String periodLeagueId;
  final LeagueTier oldTier;
  final LeagueTier newTier;
  final ResolutionOutcome outcome;
  final int finalRank;
  final int finalWeeklyXp;

  factory LeagueResolution.fromJson(Map<String, dynamic> json) =>
      LeagueResolution(
        periodLeagueId: json['periodLeagueId'] as String? ?? '',
        oldTier: leagueTierFrom(json['oldTier'] as String?),
        newTier: leagueTierFrom(json['newTier'] as String?),
        outcome: _resolutionOutcomeFrom(json['outcome'] as String?),
        finalRank: (json['finalRank'] as num?)?.toInt() ?? 0,
        finalWeeklyXp: (json['finalWeeklyXp'] as num?)?.toInt() ?? 0,
      );
}
