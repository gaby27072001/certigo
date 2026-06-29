/// Streak — daily‑learning series state + repair mechanics.
library;

/// The learner's current streak: consecutive days of learning,
/// whether it can be repaired (missed yesterday + enough gems),
/// and its repair cost.
class Streak {
  const Streak({
    required this.days,
    required this.canRepair,
    required this.repairCostGems,
    required this.repairedToday,
    required this.freezeTokens,
  });

  final int days;
  final bool canRepair;
  final int repairCostGems;
  final bool repairedToday;

  /// Freeze tokens act as one‑day shields; shown alongside the streak.
  final int freezeTokens;

  factory Streak.fromJson(Map<String, dynamic> json) => Streak(
        days: (json['days'] as num?)?.toInt() ?? 0,
        canRepair: json['canRepair'] as bool? ?? false,
        repairCostGems: (json['repairCostGems'] as num?)?.toInt() ?? 10,
        repairedToday: json['repairedToday'] as bool? ?? false,
        freezeTokens: (json['freezeTokens'] as num?)?.toInt() ?? 0,
      );
}

/// Returned by `POST /streak/repair`.
class RepairStreakResult {
  const RepairStreakResult({
    required this.days,
    required this.gemsBalance,
  });

  /// Updated streak length after repair.
  final int days;

  /// Learner's gem balance after deducting the repair cost.
  final int gemsBalance;

  factory RepairStreakResult.fromJson(Map<String, dynamic> json) =>
      RepairStreakResult(
        days: (json['days'] as num?)?.toInt() ?? 0,
        gemsBalance: (json['gemsBalance'] as num?)?.toInt() ?? 0,
      );
}
