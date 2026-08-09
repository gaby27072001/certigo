/// Seasons & the monthly themed challenge. A "season" is the live monthly event
/// (theme, mascot, accent) carrying one community challenge the learner can
/// claim a badge + gems for once it is completed.
library;

/// The single themed challenge attached to the active season.
class SeasonChallenge {
  const SeasonChallenge({
    required this.kind,
    required this.title,
    required this.target,
    required this.current,
    required this.rewardGems,
    required this.completed,
    required this.claimed,
    required this.claimable,
  });

  final String kind;
  final String title;
  final int target;
  final int current;
  final int rewardGems;
  final bool completed;
  final bool claimed;
  final bool claimable;

  factory SeasonChallenge.fromJson(Map<String, dynamic> json) => SeasonChallenge(
    kind: json['kind'] as String? ?? '',
    title: json['title'] as String? ?? '',
    target: (json['target'] as num?)?.toInt() ?? 0,
    current: (json['current'] as num?)?.toInt() ?? 0,
    rewardGems: (json['rewardGems'] as num?)?.toInt() ?? 0,
    completed: json['completed'] as bool? ?? false,
    claimed: json['claimed'] as bool? ?? false,
    claimable: json['claimable'] as bool? ?? false,
  );
}

/// The active monthly season: theme, mascot, accent + this month's challenge.
class Season {
  const Season({
    required this.id,
    required this.year,
    required this.month,
    required this.theme,
    required this.tagline,
    required this.mascot,
    required this.accent,
    required this.badgeId,
    required this.badgeTitle,
    required this.gems,
    required this.badgesEarned,
    required this.challenge,
  });

  final String id;
  final int year;
  final int month;
  final String theme;
  final String tagline;
  final String mascot;

  /// Hex accent colour the UI tints the season card with (e.g. `#7C3AED`).
  final String accent;
  final String badgeId;
  final String badgeTitle;
  final int gems;
  final int badgesEarned;
  final SeasonChallenge challenge;

  factory Season.fromJson(Map<String, dynamic> json) => Season(
    id: json['id'] as String,
    year: (json['year'] as num?)?.toInt() ?? 0,
    month: (json['month'] as num?)?.toInt() ?? 0,
    theme: json['theme'] as String? ?? '',
    tagline: json['tagline'] as String? ?? '',
    mascot: json['mascot'] as String? ?? '',
    accent: json['accent'] as String? ?? '',
    badgeId: json['badgeId'] as String? ?? '',
    badgeTitle: json['badgeTitle'] as String? ?? '',
    gems: (json['gems'] as num?)?.toInt() ?? 0,
    badgesEarned: (json['badgesEarned'] as num?)?.toInt() ?? 0,
    challenge: SeasonChallenge.fromJson(
      json['challenge'] as Map<String, dynamic>? ?? <String, dynamic>{},
    ),
  );
}

/// Request body for `POST /season/claim`.
class ClaimSeasonRequest {
  const ClaimSeasonRequest({required this.seasonId});

  final String seasonId;

  Map<String, dynamic> toJson() => <String, dynamic>{'seasonId': seasonId};
}

/// Server result of claiming the season's challenge reward.
class ClaimSeasonResult {
  const ClaimSeasonResult({
    required this.success,
    required this.seasonId,
    this.badgeId,
    required this.gemsAwarded,
    required this.gemsBalance,
    required this.claimed,
    this.error,
  });

  final bool success;
  final String seasonId;
  final String? badgeId;
  final int gemsAwarded;
  final int gemsBalance;
  final bool claimed;
  final String? error;

  factory ClaimSeasonResult.fromJson(Map<String, dynamic> json) => ClaimSeasonResult(
    success: json['success'] as bool? ?? false,
    seasonId: json['seasonId'] as String? ?? '',
    badgeId: json['badgeId'] as String?,
    gemsAwarded: (json['gemsAwarded'] as num?)?.toInt() ?? 0,
    gemsBalance: (json['gemsBalance'] as num?)?.toInt() ?? 0,
    claimed: json['claimed'] as bool? ?? false,
    error: json['error'] as String?,
  );
}
