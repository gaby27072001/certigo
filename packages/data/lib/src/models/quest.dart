/// Daily quests. A small board of per-day goals (target/current) the learner can
/// claim gems for once each is completed. The board resets every day server-side.
library;

/// One daily quest with its live progress and claim state.
class Quest {
  const Quest({
    required this.id,
    required this.kind,
    required this.title,
    required this.target,
    required this.current,
    required this.rewardGems,
    required this.completed,
    required this.claimed,
    required this.claimable,
  });

  final String id;
  final String kind;
  final String title;
  final int target;
  final int current;
  final int rewardGems;
  final bool completed;
  final bool claimed;
  final bool claimable;

  factory Quest.fromJson(Map<String, dynamic> json) => Quest(
        id: json['id'] as String,
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

/// The learner's quest board for one day.
class QuestBoard {
  const QuestBoard({required this.date, required this.gems, required this.quests});

  /// The board's day, `yyyy-MM-dd` (server `DateOnly`).
  final String date;
  final int gems;
  final List<Quest> quests;

  factory QuestBoard.fromJson(Map<String, dynamic> json) => QuestBoard(
        date: json['date'] as String? ?? '',
        gems: (json['gems'] as num?)?.toInt() ?? 0,
        quests: (json['quests'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Quest.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Request body for `POST /quests/claim`.
class ClaimQuestRequest {
  const ClaimQuestRequest({required this.questId});

  final String questId;

  Map<String, dynamic> toJson() => <String, dynamic>{'questId': questId};
}

/// Server result of claiming a completed quest's gems.
class ClaimQuestResult {
  const ClaimQuestResult({
    required this.success,
    required this.questId,
    required this.gemsAwarded,
    required this.gemsBalance,
    required this.claimed,
    this.error,
  });

  final bool success;
  final String questId;
  final int gemsAwarded;
  final int gemsBalance;
  final bool claimed;
  final String? error;

  factory ClaimQuestResult.fromJson(Map<String, dynamic> json) => ClaimQuestResult(
        success: json['success'] as bool? ?? false,
        questId: json['questId'] as String? ?? '',
        gemsAwarded: (json['gemsAwarded'] as num?)?.toInt() ?? 0,
        gemsBalance: (json['gemsBalance'] as num?)?.toInt() ?? 0,
        claimed: json['claimed'] as bool? ?? false,
        error: json['error'] as String?,
      );
}
