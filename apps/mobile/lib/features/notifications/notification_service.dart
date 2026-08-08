import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Manages daily reminder push notifications using [flutter_local_notifications].
///
/// [initialize] is idempotent and safe to call from bootstrap and scheduling
/// paths. Permission prompts happen only in [requestPermission], after an
/// explicit learner action.
class NotificationService {
  NotificationService._();

  static const int _dailyReminderId = 1;
  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Rappels quotidiens';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static Future<void>? _initialization;

  static Future<bool?> Function(InitializationSettings settings)
  _initializePlugin = _plugin.initialize;
  static Future<bool?> Function() _requestPlatformPermission =
      _requestPermissionFromPlugin;
  static Future<String> Function() _loadLocalTimezone = () async {
    final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
    return info.identifier;
  };
  static Future<void> Function() _cancelReminder = () =>
      _plugin.cancel(_dailyReminderId);
  static Future<void> Function(
    tz.TZDateTime scheduledDate,
    NotificationDetails details,
  )
  _scheduleReminder = _scheduleWithPlugin;
  static tz.TZDateTime Function(tz.Location location) _now = tz.TZDateTime.now;

  static Future<void> initialize() {
    final Future<void>? running = _initialization;
    if (running != null) return running;
    final Future<void> initialization = _initialize();
    _initialization = initialization;
    initialization.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {
        if (identical(_initialization, initialization)) {
          _initialization = null;
        }
      },
    );
    return initialization;
  }

  static Future<void> _initialize() async {
    tz.initializeTimeZones();
    final String timezoneName = await _loadLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));

    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: ios,
    );
    // On iOS, false means initialization deliberately skipped permission
    // requests. Platform failures are surfaced as exceptions.
    await _initializePlugin(settings);
  }

  static Future<bool> requestPermission() async {
    await initialize();
    return await _requestPlatformPermission() ?? true;
  }

  static Future<bool> scheduleDailyReminder(TimeOfDay time) async {
    await initialize();
    if (!await requestPermission()) return false;
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

    await _scheduleReminder(scheduledDate, details);
    return true;
  }

  static Future<void> _scheduleWithPlugin(
    tz.TZDateTime scheduledDate,
    NotificationDetails details,
  ) {
    return _plugin.zonedSchedule(
      _dailyReminderId,
      'Certigo 🎓',
      'Ta leçon du jour t\'attend ! Garde ta série active.',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDailyReminder() async {
    await initialize();
    await _cancelReminder();
  }

  static Future<bool?> _requestPermissionFromPlugin() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) return android.requestNotificationsPermission();

    final IOSFlutterLocalNotificationsPlugin? ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return ios.requestPermissions(alert: true, badge: true, sound: true);
    }
    return null;
  }

  static tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final tz.TZDateTime now = _now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        time.hour,
        time.minute,
      );
    }
    return scheduled;
  }

  @visibleForTesting
  static void debugConfigure({
    Future<bool?> Function(InitializationSettings settings)? initializePlugin,
    Future<bool?> Function()? requestPlatformPermission,
    Future<String> Function()? loadLocalTimezone,
    Future<void> Function()? cancelReminder,
    Future<void> Function(
      tz.TZDateTime scheduledDate,
      NotificationDetails details,
    )?
    scheduleReminder,
    tz.TZDateTime Function(tz.Location location)? now,
  }) {
    _initialization = null;
    _initializePlugin = initializePlugin ?? _plugin.initialize;
    _requestPlatformPermission =
        requestPlatformPermission ?? _requestPermissionFromPlugin;
    _loadLocalTimezone =
        loadLocalTimezone ??
        () async {
          final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
          return info.identifier;
        };
    _cancelReminder = cancelReminder ?? () => _plugin.cancel(_dailyReminderId);
    _scheduleReminder = scheduleReminder ?? _scheduleWithPlugin;
    _now = now ?? tz.TZDateTime.now;
  }
}
