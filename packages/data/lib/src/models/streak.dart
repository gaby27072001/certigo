/// The learner's streak and its paid repair, as `GET /streak` and
/// `POST /streak/repair` report them.
///
/// The server is authoritative for the streak, the gem balance and the repair
/// window. Every value the repair screen shows therefore comes from one server
/// snapshot, [StreakStatus]: whether a repair is offered, what it costs, the
/// balance it is paid from, when the offer closes, and whether a freeze token
/// already covers the gap. The client formats these values; it never re-derives
/// them. The wire format is pinned by `docs/contracts/learner-streak/v1`.
library;

/// What the server offers for the learner's streak right now.
enum StreakRepairOffer {
  /// Broken recently enough to be bought back.
  available,

  /// Active today or yesterday: nothing to repair.
  intact,

  /// Broken too long ago: the streak can no longer be bought back.
  expired,

  /// No streak to repair yet.
  none,

  /// Not offered, for a reason this client version does not know. Treated as an
  /// unavailable offer rather than guessed at.
  unavailable,
}

/// The server's streak snapshot and repair offer.
class StreakStatus {
  const StreakStatus({
    required this.streakDays,
    required this.lastActiveDate,
    required this.freezeTokens,
    required this.repairable,
    required this.repairCostGems,
    this.reason,
    this.gems,
    this.repairExpiresAt,
    this.coveredByFreeze = false,
  });

  final int streakDays;

  /// Last UTC calendar day on which the daily goal was met, as a UTC midnight.
  final DateTime? lastActiveDate;

  final int freezeTokens;
  final bool repairable;
  final int repairCostGems;

  /// Why no repair is offered; null when [repairable] is true.
  final String? reason;

  /// Gem balance read in the same snapshot as the offer. Null when an older
  /// server omits it: the balance is then unknown, never assumed.
  final int? gems;

  /// First UTC instant at which the repair is no longer accepted (exclusive).
  /// Null when nothing is offered, or when an older server omits it.
  final DateTime? repairExpiresAt;

  /// True when a freeze token will absorb the missed day if today's goal is met:
  /// the paid repair stays available but is not needed to save the streak.
  final bool coveredByFreeze;

  StreakRepairOffer get offer {
    if (repairable) return StreakRepairOffer.available;
    return switch (reason) {
      'intact' => StreakRepairOffer.intact,
      'expired' => StreakRepairOffer.expired,
      'noStreak' => StreakRepairOffer.none,
      _ => StreakRepairOffer.unavailable,
    };
  }

  /// Gems still missing to pay for the repair: 0 when the known balance covers
  /// it, null when the balance is unknown. Arithmetic on two server values, so
  /// it can disagree with the server only if the balance moved since the read —
  /// and the server re-checks the balance when it rules anyway.
  int? get gemsShort {
    final int? balance = gems;
    if (balance == null) return null;
    final int missing = repairCostGems - balance;
    return missing > 0 ? missing : 0;
  }

  factory StreakStatus.fromJson(Map<String, dynamic> json) => StreakStatus(
        streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
        lastActiveDate: parseCalendarDay(json['lastActiveDate']),
        freezeTokens: (json['freezeTokens'] as num?)?.toInt() ?? 0,
        repairable: json['repairable'] as bool? ?? false,
        repairCostGems: (json['repairCostGems'] as num?)?.toInt() ?? 0,
        reason: json['reason'] as String?,
        gems: (json['gems'] as num?)?.toInt(),
        repairExpiresAt: _parseInstant(json['repairExpiresAt']),
        coveredByFreeze: json['coveredByFreeze'] as bool? ?? false,
      );
}

/// Request body for `POST /streak/repair`. Carries only the idempotency key: the
/// learner is identified by the JWT, never by the body.
class StreakRepairRequest {
  const StreakRepairRequest({required this.clientRepairId});

  final String clientRepairId;

  Map<String, dynamic> toJson() => <String, dynamic>{'clientRepairId': clientRepairId};
}

/// Why the server refused a repair.
enum StreakRepairRefusal {
  /// The balance does not cover the price.
  insufficientGems,

  /// Nothing to repair any more: the streak is intact, or it was extended while
  /// the request was in flight.
  alreadyIntact,

  /// The window closed.
  expired,

  /// There is no streak to repair.
  noStreak,

  /// A concurrent write won; the operation was marked failed.
  conflict,

  /// A cause this client version does not know.
  unknown,
}

/// The server's ruling on one repair request — granted or refused. A refusal is
/// a ruling, not a transport failure: it travels as this same shape under a 400.
class StreakRepairResult {
  const StreakRepairResult({
    required this.success,
    required this.streakDays,
    required this.gemsSpent,
    required this.gemsBalance,
    this.lastActiveDate,
    this.error,
  });

  final bool success;
  final int streakDays;
  final int gemsSpent;

  /// Balance after the ruling, reconciled by the server — also on a refusal.
  final int gemsBalance;
  final DateTime? lastActiveDate;
  final String? error;

  /// Null when the repair was granted.
  StreakRepairRefusal? get refusal {
    if (success) return null;
    return switch (error) {
      'insufficientGems' => StreakRepairRefusal.insufficientGems,
      'intact' || 'noLongerRepairable' => StreakRepairRefusal.alreadyIntact,
      'expired' => StreakRepairRefusal.expired,
      'noStreak' => StreakRepairRefusal.noStreak,
      'conflict' => StreakRepairRefusal.conflict,
      _ => StreakRepairRefusal.unknown,
    };
  }

  factory StreakRepairResult.fromJson(Map<String, dynamic> json) => StreakRepairResult(
        success: json['success'] as bool? ?? false,
        streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
        gemsSpent: (json['gemsSpent'] as num?)?.toInt() ?? 0,
        gemsBalance: (json['gemsBalance'] as num?)?.toInt() ?? 0,
        lastActiveDate: parseCalendarDay(json['lastActiveDate']),
        error: json['error'] as String?,
      );
}

final RegExp _calendarDay = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Parses a .NET `DateOnly` (`yyyy-MM-dd`) as the UTC midnight of that day.
///
/// `DateTime.parse` would read the same string as a *local* midnight, which
/// names a different instant on every device; a calendar day has no instant, so
/// it is kept as UTC fields and formatted as-is.
DateTime? parseCalendarDay(Object? value) {
  if (value is! String) return null;
  final RegExpMatch? match = _calendarDay.firstMatch(value);
  if (match == null) return null;
  return DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

DateTime? _parseInstant(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}
