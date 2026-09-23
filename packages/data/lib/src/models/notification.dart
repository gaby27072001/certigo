/// Complete server preferences. Missing fields must never become defaults:
/// POST replaces the entire document, including categories not being edited.
class NotificationSettings {
  const NotificationSettings({
    required this.enabled,
    required this.utcOffsetMinutes,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.preferredHour,
    required this.maxPerDay,
    required this.streakAlerts,
    required this.questAlerts,
    required this.leagueAlerts,
  });

  final bool enabled;
  final int utcOffsetMinutes;
  final int quietHoursStart;
  final int quietHoursEnd;
  final int preferredHour;
  final int maxPerDay;
  final bool streakAlerts;
  final bool questAlerts;
  final bool leagueAlerts;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) => NotificationSettings(
        enabled: _required<bool>(json, 'enabled'),
        utcOffsetMinutes: _bounded(json, 'utcOffsetMinutes', -720, 840),
        quietHoursStart: _bounded(json, 'quietHoursStart', 0, 23),
        quietHoursEnd: _bounded(json, 'quietHoursEnd', 0, 23),
        preferredHour: _bounded(json, 'preferredHour', 0, 23),
        maxPerDay: _bounded(json, 'maxPerDay', 0, 10),
        streakAlerts: _required<bool>(json, 'streakAlerts'),
        questAlerts: _required<bool>(json, 'questAlerts'),
        leagueAlerts: _required<bool>(json, 'leagueAlerts'),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'utcOffsetMinutes': utcOffsetMinutes,
        'quietHoursStart': quietHoursStart,
        'quietHoursEnd': quietHoursEnd,
        'preferredHour': preferredHour,
        'maxPerDay': maxPerDay,
        'streakAlerts': streakAlerts,
        'questAlerts': questAlerts,
        'leagueAlerts': leagueAlerts,
      };

  NotificationSettings copyWith({
    bool? enabled,
    int? utcOffsetMinutes,
    int? quietHoursStart,
    int? quietHoursEnd,
    int? preferredHour,
    int? maxPerDay,
    bool? streakAlerts,
    bool? questAlerts,
    bool? leagueAlerts,
  }) =>
      NotificationSettings(
        enabled: enabled ?? this.enabled,
        utcOffsetMinutes: utcOffsetMinutes ?? this.utcOffsetMinutes,
        quietHoursStart: quietHoursStart ?? this.quietHoursStart,
        quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
        preferredHour: preferredHour ?? this.preferredHour,
        maxPerDay: maxPerDay ?? this.maxPerDay,
        streakAlerts: streakAlerts ?? this.streakAlerts,
        questAlerts: questAlerts ?? this.questAlerts,
        leagueAlerts: leagueAlerts ?? this.leagueAlerts,
      );
}

class NotificationPlan {
  NotificationPlan({required this.localDate, required List<PlannedNotification> notifications})
      : notifications = List<PlannedNotification>.unmodifiable(notifications);

  /// Date-only in the server's configured offset, not a device-local instant.
  final String localDate;
  final List<PlannedNotification> notifications;

  factory NotificationPlan.fromJson(Map<String, dynamic> json) {
    final String date = _required<String>(json, 'localDate');
    final DateTime? parsed = DateTime.tryParse(date);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        parsed == null ||
        parsed.toIso8601String().substring(0, 10) != date) {
      throw const FormatException('Invalid notification local date');
    }
    final List<dynamic> entries = _required<List<dynamic>>(json, 'notifications');
    return NotificationPlan(
      localDate: date,
      notifications: entries.map((dynamic entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('Invalid planned notification');
        }
        return PlannedNotification.fromJson(entry);
      }).toList(),
    );
  }
}

class PlannedNotification {
  const PlannedNotification({
    required this.kind,
    required this.priority,
    required this.scheduledUtc,
    required this.localHour,
    required this.mascot,
    required this.title,
    required this.body,
    required this.deeplink,
    required this.dedupeKey,
  });

  final String kind;
  final String priority;
  final DateTime scheduledUtc;
  final int localHour;
  final String mascot;
  final String title;
  final String body;
  final String deeplink;
  final String dedupeKey;

  factory PlannedNotification.fromJson(Map<String, dynamic> json) {
    final String timestamp = _required<String>(json, 'scheduledUtc');
    final DateTime? instant = DateTime.tryParse(timestamp);
    if (instant == null || !RegExp(r'T.*(?:Z|[+-]\d{2}:\d{2})$').hasMatch(timestamp)) {
      throw const FormatException('Notification timestamp must include an offset');
    }
    return PlannedNotification(
      kind: _required<String>(json, 'kind'),
      priority: _required<String>(json, 'priority'),
      scheduledUtc: instant.toUtc(),
      localHour: _bounded(json, 'localHour', 0, 23),
      mascot: _required<String>(json, 'mascot'),
      title: _required<String>(json, 'title'),
      body: _required<String>(json, 'body'),
      deeplink: _required<String>(json, 'deeplink'),
      dedupeKey: _required<String>(json, 'dedupeKey'),
    );
  }
}

T _required<T>(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! T) throw FormatException('Missing or invalid notification field: $key');
  return value;
}

int _bounded(Map<String, dynamic> json, String key, int min, int max) {
  final int value = _required<int>(json, key);
  if (value < min || value > max) throw FormatException('Invalid notification range: $key');
  return value;
}
