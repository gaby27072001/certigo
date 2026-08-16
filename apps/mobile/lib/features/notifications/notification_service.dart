import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const String _reminderScheduleKey = 'daily_reminder_schedule';
  static const String _legacyReminderTimeKey = 'daily_reminder_time';

  /// Default chosen during onboarding when the learner enables reminders.
  static const TimeOfDay defaultReminderTime = TimeOfDay(hour: 19, minute: 0);

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static Future<void>? _initialization;
  static Future<void> _mutationTail = Future<void>.value();

  static Future<bool?> Function(InitializationSettings settings) _initializePlugin =
      _plugin.initialize;
  static Future<bool?> Function() _requestPlatformPermission = _requestPermissionFromPlugin;
  static Future<String> Function() _loadLocalTimezone = () async {
    final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
    return info.identifier;
  };
  static Future<void> Function() _cancelReminder = () => _plugin.cancel(_dailyReminderId);
  static Future<void> Function(
    tz.TZDateTime scheduledDate,
    NotificationDetails details,
  ) _scheduleReminder = _scheduleWithPlugin;
  static tz.TZDateTime Function(tz.Location location) _now = tz.TZDateTime.now;
  static Future<TimeOfDay?> Function() _loadReminderTime = _loadReminderTimeFromPreferences;
  static Future<String?> Function() _loadReminderTimezone = _loadReminderTimezoneFromPreferences;
  static Future<void> Function(TimeOfDay time, String timezone) _saveReminder =
      _saveReminderToPreferences;

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
    await _refreshLocalTimezone();

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
    return _serializeMutation(() async {
      await _refreshLocalTimezone();
      if (await _requestPlatformPermission() == false) return false;

      final TimeOfDay? previousTime = await _loadReminderTime();
      await _replaceScheduledReminder(time);
      try {
        await _saveReminder(time, tz.local.name);
      } on Object catch (error, stackTrace) {
        try {
          if (previousTime == null) {
            await _cancelReminder();
          } else {
            await _replaceScheduledReminder(previousTime);
          }
        } on Object catch (rollbackError, rollbackStackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: rollbackError,
              stack: rollbackStackTrace,
              library: 'certigo.notifications',
              context: ErrorDescription(
                'while restoring a reminder after persistence failure',
              ),
            ),
          );
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
      return true;
    });
  }

  static Future<void> _replaceScheduledReminder(TimeOfDay time) async {
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
  }

  /// Refreshes the device timezone and reschedules an existing reminder only
  /// when its persisted timezone differs. This never requests permission.
  static Future<bool> refreshTimezoneAndReschedule() async {
    await initialize();
    return _serializeMutation(() async {
      await _refreshLocalTimezone();
      final TimeOfDay? time = await _loadReminderTime();
      if (time == null) return false;

      final String? scheduledTimezone = await _loadReminderTimezone();
      if (scheduledTimezone == tz.local.name) return false;

      await _replaceScheduledReminder(time);
      await _saveReminder(time, tz.local.name);
      return true;
    });
  }

  static Future<TimeOfDay?> loadDailyReminderTime() => _serializeMutation(_loadReminderTime);

  static Future<T> _serializeMutation<T>(Future<T> Function() operation) {
    final Future<T> result = _mutationTail.then<T>((_) => operation());
    _mutationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  static Future<bool> _refreshLocalTimezone() async {
    final String timezoneName = await _loadLocalTimezone();
    final bool changed = tz.local.name != timezoneName;
    if (changed) tz.setLocalLocation(tz.getLocation(timezoneName));
    return changed;
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
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDailyReminder() async {
    await initialize();
    await _serializeMutation(_cancelReminder);
  }

  static Future<TimeOfDay?> _loadReminderTimeFromPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored =
        prefs.getString(_reminderScheduleKey) ?? prefs.getString(_legacyReminderTimeKey);
    if (stored == null) return null;
    final List<String> parts = stored.split('|').first.split(':');
    if (parts.length != 2) return null;
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  static Future<String?> _loadReminderTimezoneFromPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_reminderScheduleKey);
    if (stored == null) return null;
    final List<String> parts = stored.split('|');
    return parts.length == 2 && parts[1].isNotEmpty ? parts[1] : null;
  }

  static Future<void> _saveReminderToPreferences(
    TimeOfDay time,
    String timezone,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool saved = await prefs.setString(
      _reminderScheduleKey,
      '${time.hour}:${time.minute}|$timezone',
    );
    if (!saved) {
      throw StateError('Daily reminder preference could not be persisted');
    }
    await prefs.remove(_legacyReminderTimeKey);
  }

  static Future<bool?> _requestPermissionFromPlugin() async {
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return android.requestNotificationsPermission();

    final IOSFlutterLocalNotificationsPlugin? ios =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
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
    )? scheduleReminder,
    tz.TZDateTime Function(tz.Location location)? now,
    Future<TimeOfDay?> Function()? loadReminderTime,
    Future<String?> Function()? loadReminderTimezone,
    Future<void> Function(TimeOfDay time, String timezone)? saveReminder,
  }) {
    _initialization = null;
    _mutationTail = Future<void>.value();
    _initializePlugin = initializePlugin ?? _plugin.initialize;
    _requestPlatformPermission = requestPlatformPermission ?? _requestPermissionFromPlugin;
    _loadLocalTimezone = loadLocalTimezone ??
        () async {
          final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
          return info.identifier;
        };
    _cancelReminder = cancelReminder ?? () => _plugin.cancel(_dailyReminderId);
    _scheduleReminder = scheduleReminder ?? _scheduleWithPlugin;
    _now = now ?? tz.TZDateTime.now;
    _loadReminderTime = loadReminderTime ?? _loadReminderTimeFromPreferences;
    _loadReminderTimezone = loadReminderTimezone ?? _loadReminderTimezoneFromPreferences;
    _saveReminder = saveReminder ?? _saveReminderToPreferences;
  }
}
