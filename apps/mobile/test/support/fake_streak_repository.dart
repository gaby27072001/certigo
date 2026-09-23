import 'dart:async';

import 'package:core/core.dart';
import 'package:data/data.dart';

/// A repairable snapshot shaped like the golden vector
/// `docs/contracts/learner-streak/v1/status-repairable.golden.json`.
StreakStatus repairableStatus({
  int streakDays = 12,
  int? gems = 120,
  int freezeTokens = 0,
  bool coveredByFreeze = false,
  DateTime? repairExpiresAt,
  bool withDeadline = true,
  int cost = 50,
}) =>
    StreakStatus(
      streakDays: streakDays,
      lastActiveDate: DateTime.utc(2025, 1, 3),
      freezeTokens: freezeTokens,
      repairable: true,
      repairCostGems: cost,
      gems: gems,
      repairExpiresAt: withDeadline ? (repairExpiresAt ?? DateTime.utc(2025, 1, 12)) : null,
      coveredByFreeze: coveredByFreeze,
    );

StreakStatus blockedStatus(String? reason, {int streakDays = 12, int freezeTokens = 0}) =>
    StreakStatus(
      streakDays: streakDays,
      lastActiveDate: DateTime.utc(2025, 1, 5),
      freezeTokens: freezeTokens,
      repairable: false,
      repairCostGems: 50,
      reason: reason,
      gems: 120,
    );

const StreakRepairResult grantedRepair = StreakRepairResult(
  success: true,
  streakDays: 12,
  gemsSpent: 50,
  gemsBalance: 70,
);

StreakRepairResult refusedRepair(String error, {int gemsBalance = 30}) => StreakRepairResult(
      success: false,
      streakDays: 12,
      gemsSpent: 0,
      gemsBalance: gemsBalance,
      error: error,
    );

/// Serves scripted statuses and repair outcomes, and records every request, so
/// assertions bear on what the app actually sent.
class FakeStreakRepository implements StreakRepository {
  FakeStreakRepository({List<Result<StreakStatus>>? statuses})
      : _statuses = statuses ?? <Result<StreakStatus>>[Success<StreakStatus>(repairableStatus())];

  final List<Result<StreakStatus>> _statuses;
  final List<Result<StreakRepairResult>> _repairs = <Result<StreakRepairResult>>[];
  final List<StreakRepairRequest> requests = <StreakRepairRequest>[];
  int statusCalls = 0;

  /// When set, the next repair waits on it: the request is in flight.
  Completer<void>? hold;

  /// When set, the next status read waits on it.
  Completer<void>? holdStatus;

  /// Serves the scripted statuses in order; the last one repeats.
  @override
  Future<Result<StreakStatus>> getStatus() async {
    statusCalls++;
    final Completer<void>? gate = holdStatus;
    if (gate != null) await gate.future;
    return _statuses.length > 1 ? _statuses.removeAt(0) : _statuses.first;
  }

  void enqueueRepair(Result<StreakRepairResult> outcome) => _repairs.add(outcome);

  /// Replaces what the next status reads return.
  void serveStatus(Result<StreakStatus> status) => _statuses
    ..clear()
    ..add(status);

  @override
  Future<Result<StreakRepairResult>> repair(StreakRepairRequest request) async {
    requests.add(request);
    final Completer<void>? gate = hold;
    if (gate != null) await gate.future;
    if (_repairs.isEmpty) {
      return const Err<StreakRepairResult>(UnknownFailure('no scripted outcome left'));
    }
    return _repairs.removeAt(0);
  }
}
