import 'dart:convert';
import 'dart:io';

import 'package:data/data.dart';
import 'package:test/test.dart';

/// Reads the same golden vectors as
/// `backend/tests/Certigo.Api.Tests/StreakContractGoldenVectorTests.cs`.
///
/// That test proves the real API emits these exact bytes; this one proves the real
/// mobile parser understands them. Neither side can pass by construction, because
/// the bytes under test are produced by the other language.
void main() {
  Map<String, dynamic> golden(String name) =>
      jsonDecode(_locateGolden(name).readAsStringSync()) as Map<String, dynamic>;

  test('a repairable snapshot carries the whole offer', () {
    final StreakStatus s = StreakStatus.fromJson(golden('status-repairable.golden.json'));

    expect(s.offer, StreakRepairOffer.available);
    expect(s.streakDays, 12);
    expect(s.lastActiveDate, DateTime.utc(2025, 1, 3));
    expect(s.repairCostGems, 50);
    expect(s.gems, 120);
    expect(s.gemsShort, 0);
    expect(s.repairExpiresAt, DateTime.utc(2025, 1, 12));
    expect(s.coveredByFreeze, isFalse);
  });

  test('an intact snapshot publishes no window', () {
    final StreakStatus s = StreakStatus.fromJson(golden('status-intact.golden.json'));

    expect(s.offer, StreakRepairOffer.intact);
    expect(s.repairExpiresAt, isNull);
    expect(s.freezeTokens, 1);
    expect(s.gems, 120);
  });

  test('a granted repair reports the reconciled balance', () {
    final StreakRepairResult r = StreakRepairResult.fromJson(golden('repair-granted.golden.json'));

    expect(r.success, isTrue);
    expect(r.refusal, isNull);
    expect(r.gemsSpent, 50);
    expect(r.gemsBalance, 70);
    expect(r.lastActiveDate, DateTime.utc(2025, 1, 5));
  });

  test('a refused repair is recognised as a ruling and names its cause', () {
    final Map<String, dynamic> json = golden('repair-refused.golden.json');

    // The repository tells a ruling from a malformed-request 400 by this field.
    expect(json['success'], isA<bool>());
    final StreakRepairResult r = StreakRepairResult.fromJson(json);
    expect(r.refusal, StreakRepairRefusal.insufficientGems);
    expect(r.gemsBalance, 30);
  });
}

File _locateGolden(String name) {
  Directory directory = Directory.current;
  while (true) {
    final File candidate = File('${directory.path}/docs/contracts/learner-streak/v1/$name');
    if (candidate.existsSync()) {
      return candidate;
    }
    final Directory parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('$name was not found under docs/contracts/learner-streak/v1.');
    }
    directory = parent;
  }
}
