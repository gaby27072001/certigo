/// Domain models shared between the API layer and the UI.
///
/// We hand-write `fromJson`/`toJson` (no build_runner codegen) so the package
/// compiles standalone and stays easy to audit. JSON keys are camelCase to
/// match the .NET backend's `System.Text.Json` configuration.
library;

/// The signed-in learner's profile + headline gamification stats.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.handle,
    this.avatarUrl,
    required this.xp,
    required this.level,
    required this.streakDays,
    required this.freezeTokens,
    required this.gems,
    required this.dailyGoalXp,
    required this.dailyXpEarned,
    required this.activeTrackId,
  });

  final String id;
  final String displayName;
  final String handle;
  final String? avatarUrl;
  final int xp;
  final int level;
  final int streakDays;
  final int freezeTokens;

  /// Soft currency earned from lessons, quests and leagues; spent in the shop.
  final int gems;
  final int dailyGoalXp;
  final int dailyXpEarned;
  final String? activeTrackId;

  double get dailyProgress =>
      dailyGoalXp == 0 ? 0 : (dailyXpEarned / dailyGoalXp).clamp(0, 1).toDouble();

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        displayName: json['displayName'] as String? ?? 'Apprenant',
        handle: json['handle'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        level: (json['level'] as num?)?.toInt() ?? 1,
        streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
        freezeTokens: (json['freezeTokens'] as num?)?.toInt() ?? 0,
        gems: (json['gems'] as num?)?.toInt() ?? 0,
        dailyGoalXp: (json['dailyGoalXp'] as num?)?.toInt() ?? 50,
        dailyXpEarned: (json['dailyXpEarned'] as num?)?.toInt() ?? 0,
        activeTrackId: json['activeTrackId'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'displayName': displayName,
        'handle': handle,
        'avatarUrl': avatarUrl,
        'xp': xp,
        'level': level,
        'streakDays': streakDays,
        'freezeTokens': freezeTokens,
        'gems': gems,
        'dailyGoalXp': dailyGoalXp,
        'dailyXpEarned': dailyXpEarned,
        'activeTrackId': activeTrackId,
      };
}
