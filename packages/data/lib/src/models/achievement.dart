/// Achievements / badges. A read-only board of long-running milestones
/// (threshold/progress) the learner unlocks for gems. Read-only here: unlocks
/// are awarded server-side as a side-effect of activity, never claimed manually.
library;

/// One achievement with its tier, progress toward [threshold] and unlock state.
class Achievement {
  const Achievement({
    required this.id,
    required this.kind,
    required this.name,
    required this.description,
    required this.tier,
    required this.threshold,
    required this.progress,
    required this.rewardGems,
    required this.unlocked,
  });

  final String id;
  final String kind;
  final String name;
  final String description;
  final String tier;
  final int threshold;
  final int progress;
  final int rewardGems;
  final bool unlocked;

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String,
        kind: json['kind'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        tier: json['tier'] as String? ?? '',
        threshold: (json['threshold'] as num?)?.toInt() ?? 0,
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        rewardGems: (json['rewardGems'] as num?)?.toInt() ?? 0,
        unlocked: json['unlocked'] as bool? ?? false,
      );
}

/// The learner's full achievements board with an unlocked/total tally.
class AchievementBoard {
  const AchievementBoard({required this.unlocked, required this.total, required this.achievements});

  final int unlocked;
  final int total;
  final List<Achievement> achievements;

  factory AchievementBoard.fromJson(Map<String, dynamic> json) => AchievementBoard(
        unlocked: (json['unlocked'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        achievements: (json['achievements'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
