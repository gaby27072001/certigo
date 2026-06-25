import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Manages daily reminder push notifications using [flutter_local_notifications].
///
/// Call [initialize] once at app start (e.g. in `main.dart`), then
/// [scheduleDailyReminder] / [cancelDailyReminder] from the profile screen.
class NotificationService {
  NotificationService._();

  static const int _dailyReminderId = 1;
  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Rappels quotidiens';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: ios,
    );
    await _plugin.initialize(settings);
  }

  static Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await cancelDailyReminder();

    final tz.TZDateTime scheduledDate = _nextInstanceOf(time);

    const AndroidNotificationDetails android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(
      android: android,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Microlingo 🎓',
      'Ta leçon du jour t\'attend ! Garde ta série active.',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_dailyReminderId);
  }

  static tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
