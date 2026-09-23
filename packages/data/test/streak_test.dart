import 'package:data/data.dart';
import 'package:test/test.dart';

void main() {
  group('StreakStatus', () {
    Map<String, dynamic> repairable() => <String, dynamic>{
          'streakDays': 12,
          'lastActiveDate': '2025-01-03',
          'freezeTokens': 0,
          'repairable': true,
          'repairCostGems': 50,
          'reason': null,
          'gems': 120,
          'repairExpiresAt': '2025-01-12T00:00:00+00:00',
          'coveredByFreeze': false,
        };

    test('reads every field of a repairable snapshot', () {
      final StreakStatus s = StreakStatus.fromJson(repairable());

      expect(s.streakDays, 12);
      expect(s.lastActiveDate, DateTime.utc(2025, 1, 3));
      expect(s.freezeTokens, 0);
      expect(s.repairable, isTrue);
      expect(s.repairCostGems, 50);
      expect(s.reason, isNull);
      expect(s.gems, 120);
      expect(s.repairExpiresAt, DateTime.utc(2025, 1, 12));
      expect(s.repairExpiresAt!.isUtc, isTrue);
      expect(s.coveredByFreeze, isFalse);
      expect(s.offer, StreakRepairOffer.available);
    });

    test('keeps a calendar day as UTC fields, never as a local midnight', () {
      // `DateTime.parse('2025-01-03')` is a *local* midnight: a different instant
      // on every device, and a different day once shifted to UTC east of Greenwich.
      final DateTime day = StreakStatus.fromJson(repairable()).lastActiveDate!;

      expect(day.isUtc, isTrue);
      expect(<int>[day.year, day.month, day.day], <int>[2025, 1, 3]);
    });

    test('an instant with a non-zero offset lands on the same UTC instant', () {
      final StreakStatus s = StreakStatus.fromJson(
        repairable()..['repairExpiresAt'] = '2025-01-12T02:00:00+02:00',
      );

      expect(s.repairExpiresAt, DateTime.utc(2025, 1, 12));
    });

    test('fields an older server omits stay unknown instead of being invented', () {
      final Map<String, dynamic> legacy = repairable()
        ..remove('gems')
        ..remove('repairExpiresAt')
        ..remove('coveredByFreeze');

      final StreakStatus s = StreakStatus.fromJson(legacy);

      expect(s.gems, isNull);
      expect(s.gemsShort, isNull, reason: 'an unknown balance cannot be short');
      expect(s.repairExpiresAt, isNull);
      expect(s.coveredByFreeze, isFalse);
      expect(s.offer, StreakRepairOffer.available);
    });

    test('maps every documented reason, and an unknown one to unavailable', () {
      StreakRepairOffer offerFor(String? reason) => StreakStatus.fromJson(
            repairable()
              ..['repairable'] = false
              ..['reason'] = reason,
          ).offer;

      expect(offerFor('intact'), StreakRepairOffer.intact);
      expect(offerFor('expired'), StreakRepairOffer.expired);
      expect(offerFor('noStreak'), StreakRepairOffer.none);
      expect(offerFor('somethingNew'), StreakRepairOffer.unavailable);
      expect(offerFor(null), StreakRepairOffer.unavailable);
    });

    test('an offer the server makes wins over any reason it also sends', () {
      final StreakStatus s = StreakStatus.fromJson(repairable()..['reason'] = 'expired');

      expect(s.offer, StreakRepairOffer.available);
    });

    test('gemsShort is exact arithmetic on the two server values', () {
      StreakStatus withGems(int gems) => StreakStatus.fromJson(repairable()..['gems'] = gems);

      expect(withGems(30).gemsShort, 20);
      expect(withGems(50).gemsShort, 0);
      expect(withGems(120).gemsShort, 0);
    });

    test('a malformed date is unknown, not a crash', () {
      final StreakStatus s = StreakStatus.fromJson(
        repairable()
          ..['lastActiveDate'] = '03/01/2025'
          ..['repairExpiresAt'] = 'bientôt',
      );

      expect(s.lastActiveDate, isNull);
      expect(s.repairExpiresAt, isNull);
    });
  });

  group('StreakRepairRequest', () {
    test('carries the idempotency key and nothing that could name a user', () {
      expect(
        const StreakRepairRequest(clientRepairId: 'r-1').toJson(),
        <String, dynamic>{'clientRepairId': 'r-1'},
      );
    });
  });

  group('StreakRepairResult', () {
    StreakRepairResult ruling({required bool success, String? error}) =>
        StreakRepairResult.fromJson(<String, dynamic>{
          'success': success,
          'streakDays': 12,
          'gemsSpent': success ? 50 : 0,
          'gemsBalance': 70,
          'lastActiveDate': '2025-01-05',
          'error': error,
        });

    test('a granted repair has no refusal', () {
      final StreakRepairResult r = ruling(success: true);

      expect(r.refusal, isNull);
      expect(r.gemsSpent, 50);
      expect(r.gemsBalance, 70);
      expect(r.lastActiveDate, DateTime.utc(2025, 1, 5));
    });

    test('maps every documented refusal code', () {
      expect(
        ruling(success: false, error: 'insufficientGems').refusal,
        StreakRepairRefusal.insufficientGems,
      );
      expect(ruling(success: false, error: 'intact').refusal, StreakRepairRefusal.alreadyIntact);
      expect(
        ruling(success: false, error: 'noLongerRepairable').refusal,
        StreakRepairRefusal.alreadyIntact,
        reason: 'extended while in flight: the same thing for the learner',
      );
      expect(ruling(success: false, error: 'expired').refusal, StreakRepairRefusal.expired);
      expect(ruling(success: false, error: 'noStreak').refusal, StreakRepairRefusal.noStreak);
      expect(ruling(success: false, error: 'conflict').refusal, StreakRepairRefusal.conflict);
    });

    test('an unknown or absent refusal code is unknown, not granted', () {
      expect(ruling(success: false, error: 'brandNew').refusal, StreakRepairRefusal.unknown);
      expect(ruling(success: false).refusal, StreakRepairRefusal.unknown);
    });
  });
}
