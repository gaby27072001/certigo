import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for [NotificationPlan] and [NotificationSettings] models,
/// and the notification repository contract's JSON round-trip.
///
/// These are pure unit tests (no widget tree) so they avoid the
/// font_awesome_flutter compilation issue on SDK ≥ 3.27.
void main() {
  group('NotificationPlan.fromJson', () {
    test('parses suggestedHour and suggestedMinute', () {
      final NotificationPlan plan = NotificationPlan.fromJson(<String, dynamic>{
        'suggestedHour': 9,
        'suggestedMinute': 30,
      });

      expect(plan.suggestedHour, 9);
      expect(plan.suggestedMinute, 30);
    });

    test('returns null fields when keys are absent', () {
      final NotificationPlan plan =
          NotificationPlan.fromJson(<String, dynamic>{});

      expect(plan.suggestedHour, isNull);
      expect(plan.suggestedMinute, isNull);
    });
  });

  group('NotificationSettings.fromJson', () {
    test('parses enabled settings with reminder time', () {
      final NotificationSettings settings =
          NotificationSettings.fromJson(<String, dynamic>{
        'dailyReminderEnabled': true,
        'reminderHour': 18,
        'reminderMinute': 0,
      });

      expect(settings.dailyReminderEnabled, isTrue);
      expect(settings.reminderHour, 18);
      expect(settings.reminderMinute, 0);
    });

    test('parses disabled settings', () {
      final NotificationSettings settings =
          NotificationSettings.fromJson(<String, dynamic>{
        'dailyReminderEnabled': false,
      });

      expect(settings.dailyReminderEnabled, isFalse);
      expect(settings.reminderHour, isNull);
      expect(settings.reminderMinute, isNull);
    });

    test('defaults dailyReminderEnabled to false when key is absent', () {
      final NotificationSettings settings =
          NotificationSettings.fromJson(<String, dynamic>{});

      expect(settings.dailyReminderEnabled, isFalse);
    });
  });

  group('NotificationSettings.toJson', () {
    test('serialises enabled settings correctly', () {
      const NotificationSettings settings = NotificationSettings(
        dailyReminderEnabled: true,
        reminderHour: 8,
        reminderMinute: 15,
      );

      final Map<String, dynamic> json = settings.toJson();

      expect(json['dailyReminderEnabled'], isTrue);
      expect(json['reminderHour'], 8);
      expect(json['reminderMinute'], 15);
    });

    test('omits null hour/minute from serialised output', () {
      const NotificationSettings settings = NotificationSettings(
        dailyReminderEnabled: false,
      );

      final Map<String, dynamic> json = settings.toJson();

      expect(json.containsKey('reminderHour'), isFalse);
      expect(json.containsKey('reminderMinute'), isFalse);
    });

    test('round-trips enabled settings through toJson → fromJson', () {
      const NotificationSettings original = NotificationSettings(
        dailyReminderEnabled: true,
        reminderHour: 20,
        reminderMinute: 45,
      );

      final NotificationSettings copy =
          NotificationSettings.fromJson(original.toJson());

      expect(copy.dailyReminderEnabled, original.dailyReminderEnabled);
      expect(copy.reminderHour, original.reminderHour);
      expect(copy.reminderMinute, original.reminderMinute);
    });
  });
}
