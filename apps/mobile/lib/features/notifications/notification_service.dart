import 'package:data/data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'notification_migration.dart';

/// Bounded, non-repeating local delivery of server-selected UTC instants.
/// No preference or scheduling rule is inferred locally.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const int _planBaseId = 1000;
  static const int _planCapacity = 10;
  static const String _localTitle = 'Un moment pour Certigo ?';
  static const String _localBody =
      'Si tu le souhaites, ouvre Certigo pour découvrir tes activités du moment.';
  static Future<void>? _initialization;
  static Future<void> _mutationTail = Future<void>.value();
  static int _generation = 0;
  static final ValueNotifier<int> scheduledCount = ValueNotifier<int>(0);
  static final ValueNotifier<bool> cancellationFailed = ValueNotifier<bool>(false);
  static Future<bool?> Function(InitializationSettings) _initializePlugin = _plugin.initialize;
  static Future<bool?> Function() _requestPermission = _requestPermissionFromPlugin;
  static Future<void> Function(int) _cancel = _plugin.cancel;
  static Future<void> Function(int, PlannedNotification) _schedule = _scheduleEntry;
  static DateTime Function() _now = () => DateTime.now().toUtc();
  static Future<void> Function(LegacyNotificationChoice) _restoreLegacy = _restoreLegacyWithPlugin;

  /// Pending legacy choices remain authoritative, even offline. This is a
  /// migration bridge only; new reminders always use the server plan.
  static Future<void> reconcileLifecycle(String? owner, {bool restoringSession = false}) async {
    _generation++;
    scheduledCount.value = 0;
    try {
      await initialize();
      await _serialize(() async {
        final LegacyNotificationChoice? legacy =
            owner == null ? null : await LegacyNotificationChoice.load(owner);
        final bool keepLegacy = legacy != null && legacy.enabled == true && legacy.hour != null ||
            owner == null &&
                restoringSession &&
                await LegacyNotificationChoice.preserveUntilSessionRestored();
        await _cancelAll(preserveLegacy: keepLegacy);
        if (legacy != null && legacy.enabled == true && legacy.hour != null) {
          await _restoreLegacy(legacy);
        }
      });
    } on Object {
      cancellationFailed.value = true;
      rethrow;
    }
  }

  static Future<void> _restoreLegacyWithPlugin(LegacyNotificationChoice choice) async {
    final TimezoneInfo timezone = await FlutterTimezone.getLocalTimezone();
    final tz.Location location = tz.getLocation(timezone.identifier);
    final tz.TZDateTime now = tz.TZDateTime.from(_now(), location);
    tz.TZDateTime date =
        tz.TZDateTime(location, now.year, now.month, now.day, choice.hour!, choice.minute!);
    if (!date.isAfter(now)) {
      date =
          tz.TZDateTime(location, now.year, now.month, now.day + 1, choice.hour!, choice.minute!);
    }
    await _plugin.zonedSchedule(
      1,
      _localTitle,
      _localBody,
      date,
      const NotificationDetails(
        android: AndroidNotificationDetails('daily_reminder', 'Rappels Certigo'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> initialize() {
    final Future<void>? existing = _initialization;
    if (existing != null) return existing;
    final Future<void> future = _initialize();
    _initialization = future;
    future.then<void>((_) {}, onError: (Object _, StackTrace __) {
      if (identical(_initialization, future)) _initialization = null;
    });
    return future;
  }

  static Future<void> _initialize() async {
    tz.initializeTimeZones();
    if (kIsWeb) return;
    await _initializePlugin(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
  }

  /// Null means permission denied or unavailable. Zero means no future instant,
  /// a disabled plan, or invalidation during the permission interaction.
  static Future<int?> scheduleServerPlan(
    NotificationSettings settings,
    NotificationPlan plan,
  ) async {
    final int generation = _generation;
    await initialize();
    return _serialize(() async {
      await _cancelAll();
      if (!settings.enabled || generation != _generation) return 0;
      final DateTime now = _now().toUtc();
      final String localDate =
          now.add(Duration(minutes: settings.utcOffsetMinutes)).toIso8601String().substring(0, 10);
      if (plan.localDate != localDate) {
        throw StateError('The server notification plan is stale');
      }
      final List<PlannedNotification> future = plan.notifications
          .where((PlannedNotification entry) => entry.scheduledUtc.isAfter(now))
          .toList();
      if (future.any((PlannedNotification entry) =>
          entry.scheduledUtc
              .add(Duration(minutes: settings.utcOffsetMinutes))
              .toIso8601String()
              .substring(0, 10) !=
          plan.localDate)) {
        throw StateError('Notification instant does not belong to the server plan day');
      }
      if (future.length > _planCapacity ||
          future.map((PlannedNotification entry) => entry.dedupeKey).toSet().length !=
              future.length) {
        throw StateError('Invalid notification plan size or duplicate keys');
      }
      if (future.isEmpty) return 0;
      if (await _requestPermission() != true) return null;
      if (generation != _generation) return 0;
      try {
        for (int index = 0; index < future.length; index++) {
          if (future[index].scheduledUtc.isAfter(_now().toUtc())) {
            await _schedule(_planBaseId + index, future[index]);
            scheduledCount.value++;
          }
        }
        if (generation != _generation) await _cancelAll();
        return scheduledCount.value;
      } on Object catch (error, stackTrace) {
        try {
          await _cancelAll();
        } on Object catch (rollbackError, rollbackStack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: rollbackError,
            stack: rollbackStack,
            library: 'certigo.notifications',
            context: ErrorDescription('while cancelling a partial server plan'),
          ));
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  /// Also removes ID 1 from the retired daily reminder implementation.
  /// Legacy preferences are preserved until their server migration succeeds.
  static Future<void> cancelDailyReminder() async {
    _generation++;
    scheduledCount.value = 0;
    try {
      await initialize();
      await _serialize(_cancelAll);
    } on Object {
      cancellationFailed.value = true;
      rethrow;
    }
  }

  static Future<void> _cancelAll({bool preserveLegacy = false}) async {
    scheduledCount.value = 0;
    cancellationFailed.value = true;
    // Attempt every known ID even when one fails, then surface the first error.
    Object? firstError;
    StackTrace? firstStack;
    for (final int id in <int>[
      if (!preserveLegacy) 1,
      for (int i = 0; i < _planCapacity; i++) _planBaseId + i,
    ]) {
      try {
        if (!kIsWeb) await _cancel(id);
      } on Object catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
    cancellationFailed.value = false;
  }

  static Future<T> _serialize<T>(Future<T> Function() operation) {
    final Future<T> result = _mutationTail.then<T>((_) => operation());
    _mutationTail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<void> _scheduleEntry(int id, PlannedNotification entry) => _plugin.zonedSchedule(
        id,
        _localTitle,
        _localBody,
        tz.TZDateTime.from(entry.scheduledUtc, tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails('daily_reminder', 'Rappels Certigo'),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

  static Future<bool?> _requestPermissionFromPlugin() async {
    if (kIsWeb) return null;
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return android.requestNotificationsPermission();
    final IOSFlutterLocalNotificationsPlugin? ios =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  @visibleForTesting
  static void debugConfigure({
    Future<bool?> Function(InitializationSettings)? initializePlugin,
    Future<bool?> Function()? requestPermission,
    Future<void> Function(int)? cancel,
    Future<void> Function(int, PlannedNotification)? schedule,
    DateTime Function()? now,
    Future<void> Function(LegacyNotificationChoice)? restoreLegacy,
  }) {
    _initialization = null;
    _mutationTail = Future<void>.value();
    _generation = 0;
    scheduledCount.value = 0;
    cancellationFailed.value = false;
    _initializePlugin = initializePlugin ?? _plugin.initialize;
    _requestPermission = requestPermission ?? _requestPermissionFromPlugin;
    _cancel = cancel ?? _plugin.cancel;
    _schedule = schedule ?? _scheduleEntry;
    _now = now ?? () => DateTime.now().toUtc();
    _restoreLegacy = restoreLegacy ?? _restoreLegacyWithPlugin;
  }
}
