/// Daily share card payload returned by `GET /share/daily`.
library;

class ShareCard {
  const ShareCard({
    required this.shareId,
    required this.displayName,
    required this.handle,
    required this.streakDays,
    required this.level,
    required this.dailyXp,
    required this.dailyGoalXp,
    required this.goalMet,
    required this.readinessScore,
    required this.trackCode,
    required this.mascot,
    required this.headline,
    required this.caption,
    required this.referralCode,
    required this.generatedAt,
  });

  final String shareId;
  final String displayName;
  final String handle;
  final int streakDays;
  final int level;
  final int dailyXp;
  final int dailyGoalXp;
  final bool goalMet;
  final int readinessScore;
  final String trackCode;
  final String mascot;
  final String headline;
  final String caption;
  final String referralCode;
  final DateTime generatedAt;

  bool get hasDailyGoal => dailyGoalXp > 0;

  double get goalProgress {
    if (dailyGoalXp <= 0) {
      return goalMet ? 1 : 0;
    }
    return (dailyXp / dailyGoalXp).clamp(0.0, 1.0).toDouble();
  }

  String get formattedHandle => handle.trim().isEmpty ? '' : '@${handle.trim()}';

  factory ShareCard.fromJson(Map<String, dynamic> json) => ShareCard(
        shareId: json['shareId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'Apprenant',
        handle: json['handle'] as String? ?? '',
        streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
        level: (json['level'] as num?)?.toInt() ?? 1,
        dailyXp: (json['dailyXp'] as num?)?.toInt() ?? 0,
        dailyGoalXp: (json['dailyGoalXp'] as num?)?.toInt() ?? 0,
        goalMet: json['goalMet'] as bool? ?? false,
        readinessScore: (json['readinessScore'] as num?)?.toInt() ?? 0,
        trackCode: json['trackCode'] as String? ?? '',
        mascot: json['mascot'] as String? ?? '',
        headline: json['headline'] as String? ?? '',
        caption: json['caption'] as String? ?? '',
        referralCode: json['referralCode'] as String? ?? '',
        generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}
