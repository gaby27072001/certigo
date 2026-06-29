import 'package:data/data.dart';
import 'package:test/test.dart';

void main() {
  group('ShareCard.fromJson', () {
    test('parses a full share payload and computes derived progress', () {
      final ShareCard card = ShareCard.fromJson(<String, dynamic>{
        'shareId': 'share-2025-01-06',
        'displayName': 'Alex Martin',
        'handle': 'alex#4242',
        'streakDays': 12,
        'level': 7,
        'dailyXp': 42,
        'dailyGoalXp': 50,
        'goalMet': false,
        'readinessScore': 68,
        'trackCode': 'AZ-900',
        'mascot': 'Nimbus',
        'headline': '12 jours de serie',
        'caption': '68% de preparation sur Certigo !',
        'referralCode': 'ABCD12',
        'generatedAt': '2025-01-06T12:00:00Z',
      });

      expect(card.shareId, 'share-2025-01-06');
      expect(card.displayName, 'Alex Martin');
      expect(card.formattedHandle, '@alex#4242');
      expect(card.streakDays, 12);
      expect(card.level, 7);
      expect(card.dailyXp, 42);
      expect(card.dailyGoalXp, 50);
      expect(card.goalMet, isFalse);
      expect(card.goalProgress, closeTo(0.84, 0.001));
      expect(card.readinessScore, 68);
      expect(card.trackCode, 'AZ-900');
      expect(card.referralCode, 'ABCD12');
      expect(card.generatedAt, DateTime.utc(2025, 1, 6, 12));
    });

    test('tolerates a sparse payload with safe defaults', () {
      final ShareCard card = ShareCard.fromJson(<String, dynamic>{});

      expect(card.shareId, isEmpty);
      expect(card.displayName, 'Apprenant');
      expect(card.formattedHandle, isEmpty);
      expect(card.level, 1);
      expect(card.dailyGoalXp, 0);
      expect(card.goalProgress, 0);
      expect(
        card.generatedAt,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    });
  });
}
