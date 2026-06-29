/// Notification plan + settings — server‑authoritative scheduling.
library;

/// The server's estimate of the best time to deliver a daily reminder,
/// computed from the learner's past activity rhythm.
///
/// Both fields are `null` when the server has insufficient data.
class NotificationPlan {
  const NotificationPlan({this.suggestedHour, this.suggestedMinute});

  /// Suggested hour in 24‑h format (0‑23).
  final int? suggestedHour;

  /// Suggested minute (0‑59).
  final int? suggestedMinute;

  factory NotificationPlan.fromJson(Map<String, dynamic> json) =>
      NotificationPlan(
        suggestedHour: (json['suggestedHour'] as num?)?.toInt(),
        suggestedMinute: (json['suggestedMinute'] as num?)?.toInt(),
      );
}

/// The learner's notification preferences, both readable and writable.
class NotificationSettings {
  const NotificationSettings({
    required this.dailyReminderEnabled,
    this.reminderHour,
    this.reminderMinute,
  });

  final bool dailyReminderEnabled;

  /// Hour (0‑23) for the daily reminder; null if reminders are disabled.
  final int? reminderHour;

  /// Minute (0‑59) for the daily reminder; null if reminders are disabled.
  final int? reminderMinute;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        dailyReminderEnabled:
            json['dailyReminderEnabled'] as bool? ?? false,
        reminderHour: (json['reminderHour'] as num?)?.toInt(),
        reminderMinute: (json['reminderMinute'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dailyReminderEnabled': dailyReminderEnabled,
        if (reminderHour != null) 'reminderHour': reminderHour,
        if (reminderMinute != null) 'reminderMinute': reminderMinute,
      };
}
