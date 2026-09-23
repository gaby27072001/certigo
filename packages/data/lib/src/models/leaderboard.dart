/// Weekly league standings ("Momentum Leagues"). Opt-in, cohort-based (~30
/// learners per bucket), tiered Bronze → Diamond. Promotion/relegation is shown
/// but framed positively (no public shaming of the bottom).
library;

enum LeagueTier {
  bronze,
  silver,
  gold,
  platinum,
  sapphire,
  ruby,
  emerald,
  amethyst,
  pearl,
  diamond,
  obsidian,
  unknown
}

LeagueTier leagueTierFrom(String? raw) => switch (raw) {
      'silver' => LeagueTier.silver,
      'gold' => LeagueTier.gold,
      'platinum' => LeagueTier.platinum,
      'sapphire' => LeagueTier.sapphire,
      'ruby' => LeagueTier.ruby,
      'emerald' => LeagueTier.emerald,
      'amethyst' => LeagueTier.amethyst,
      'pearl' => LeagueTier.pearl,
      'diamond' => LeagueTier.diamond,
      'obsidian' => LeagueTier.obsidian,
      'bronze' => LeagueTier.bronze,
      _ => LeagueTier.unknown,
    };

enum LeagueZone { promotion, safe, relegation }

LeagueZone? leagueZoneFrom(String? raw) {
  for (final LeagueZone zone in LeagueZone.values) {
    if (zone.name == raw) return zone;
  }
  return null;
}

class League {
  const League({
    required this.periodLeagueId,
    required this.tier,
    required this.endsAt,
    required this.promoteCount,
    required this.entries,
    required this.meUserId,
    this.tierIndex,
    this.tierName,
    this.relegateCount,
    this.nextTier,
    this.previousTier,
    this.myRank,
    this.myWeeklyXp,
    this.myZone,
    this.resetsInSeconds,
  });

  final String periodLeagueId;
  final LeagueTier tier;
  final DateTime endsAt;

  /// Top N who promote at week end.
  final int promoteCount;
  final List<LeaderboardEntry> entries;

  /// Id used to highlight the current user's row.
  final String meUserId;
  final int? tierIndex;
  final String? tierName;
  final int? relegateCount;
  final String? nextTier;
  final String? previousTier;
  final int? myRank;
  final int? myWeeklyXp;
  final LeagueZone? myZone;
  final int? resetsInSeconds;

  factory League.fromJson(Map<String, dynamic> json) => League(
        periodLeagueId: json['periodLeagueId'] as String,
        tier: leagueTierFrom(json['tier'] as String?),
        endsAt: DateTime.parse(json['endsAt'] as String),
        promoteCount: json['promoteCount'] as int,
        meUserId: json['meUserId'] as String,
        tierIndex: json['tierIndex'] as int?,
        tierName: json['tierName'] as String?,
        relegateCount: json['relegateCount'] as int?,
        nextTier: json['nextTier'] as String?,
        previousTier: json['previousTier'] as String?,
        myRank: json['myRank'] as int?,
        myWeeklyXp: json['myWeeklyXp'] as int?,
        myZone: leagueZoneFrom(json['myZone'] as String?),
        resetsInSeconds: json['resetsInSeconds'] as int?,
        entries: (json['entries'] as List<dynamic>)
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
    this.zone,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int rank;
  final int weeklyXp;
  final LeagueZone? zone;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String? ?? 'Apprenant',
        avatarUrl: json['avatarUrl'] as String?,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        weeklyXp: (json['weeklyXp'] as num?)?.toInt() ?? 0,
        zone: leagueZoneFrom(json['zone'] as String?),
      );
}

class LeagueResolution {
  const LeagueResolution({
    required this.periodLeagueId,
    required this.tier,
    required this.outcomes,
  });

  final String periodLeagueId;
  final LeagueTier tier;
  final List<LeagueOutcome> outcomes;

  factory LeagueResolution.fromJson(Map<String, dynamic> json) => LeagueResolution(
        periodLeagueId: json['periodLeagueId'] as String,
        tier: leagueTierFrom(json['tier'] as String),
        outcomes: (json['outcomes'] as List<dynamic>)
            .map((dynamic e) => LeagueOutcome.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

enum LeagueMovement { promoted, held, relegated }

class LeagueOutcome {
  const LeagueOutcome({
    required this.userId,
    required this.displayName,
    required this.rank,
    required this.zone,
    required this.movement,
    required this.fromTier,
    required this.toTier,
    required this.gemReward,
  });

  final String userId;
  final String displayName;
  final int rank;
  final LeagueZone? zone;
  final LeagueMovement movement;
  final String fromTier;
  final String toTier;
  final int gemReward;

  factory LeagueOutcome.fromJson(Map<String, dynamic> json) => LeagueOutcome(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        rank: json['rank'] as int,
        zone: leagueZoneFrom(json['zone'] as String),
        movement: LeagueMovement.values.firstWhere(
          (LeagueMovement value) => value.name == json['movement'],
          orElse: () => throw const FormatException('Unknown league movement'),
        ),
        fromTier: json['fromTier'] as String,
        toTier: json['toTier'] as String,
        gemReward: json['gemReward'] as int,
      );
}
