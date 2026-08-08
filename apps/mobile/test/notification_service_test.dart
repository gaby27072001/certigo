import 'dart:async';

import 'package:certigo/features/notifications/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'initialize shares one in-flight bootstrap and loads the device timezone',
    () async {
      final Completer<bool?> pluginGate = Completer<bool?>();
      var timezoneLoads = 0;
      var pluginInitializations = 0;
      var permissionRequests = 0;
      NotificationService.debugConfigure(
        loadLocalTimezone: () async {
          timezoneLoads++;
          return 'Europe/Paris';
        },
        initializePlugin: (InitializationSettings settings) {
          pluginInitializations++;
          expect(settings.iOS?.requestAlertPermission, isFalse);
          return pluginGate.future;
        },
        requestPlatformPermission: () async {
          permissionRequests++;
          return true;
        },
      );

      final Future<void> first = NotificationService.initialize();
      final Future<void> second = NotificationService.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(identical(first, second), isTrue);
      expect(timezoneLoads, 1);
      expect(pluginInitializations, 1);
      expect(permissionRequests, 0);

      pluginGate.complete(true);
      await Future.wait(<Future<void>>[first, second]);
      expect(tz.local.name, 'Europe/Paris');
    },
  );

  test('a denied permission does not cancel or schedule a reminder', () async {
    var cancellations = 0;
    var schedules = 0;
    NotificationService.debugConfigure(
      loadLocalTimezone: () async => 'Europe/Paris',
      initializePlugin: (_) async => true,
      requestPlatformPermission: () async => false,
      cancelReminder: () async => cancellations++,
      scheduleReminder: (_, __) async => schedules++,
    );

    final bool scheduled = await NotificationService.scheduleDailyReminder(
      const TimeOfDay(hour: 9, minute: 30),
    );

    expect(scheduled, isFalse);
    expect(cancellations, 0);
    expect(schedules, 0);
  });

  test(
    'a deferred iOS permission result does not fail initialization',
    () async {
      var permissionRequests = 0;
      NotificationService.debugConfigure(
        loadLocalTimezone: () async => 'Europe/Paris',
        initializePlugin: (_) async => false,
        requestPlatformPermission: () async {
          permissionRequests++;
          return true;
        },
      );

      expect(await NotificationService.requestPermission(), isTrue);
      expect(permissionRequests, 1);
    },
  );

  test(
    'scheduling uses the device timezone after permission is granted',
    () async {
      tz.TZDateTime? captured;
      NotificationService.debugConfigure(
        loadLocalTimezone: () async => 'America/Toronto',
        initializePlugin: (_) async => true,
        requestPlatformPermission: () async => true,
        loadReminderTime: () async => null,
        scheduleReminder: (tz.TZDateTime date, NotificationDetails _) async {
          captured = date;
        },
        saveReminder: (_, __) async {},
      );

      final bool scheduled = await NotificationService.scheduleDailyReminder(
        const TimeOfDay(hour: 7, minute: 15),
      );

      expect(scheduled, isTrue);
      expect(captured, isNotNull);
      expect(captured!.location.name, 'America/Toronto');
      expect(captured!.hour, 7);
      expect(captured!.minute, 15);
    },
  );

  test('failed initialization can be retried', () async {
    var attempts = 0;
    NotificationService.debugConfigure(
      loadLocalTimezone: () async => 'UTC',
      initializePlugin: (_) async {
        attempts++;
        if (attempts == 1) throw StateError('plugin unavailable');
        return true;
      },
    );

    await expectLater(NotificationService.initialize(), throwsStateError);
    await NotificationService.initialize();

    expect(attempts, 2);
  });

  test('the next reminder preserves wall-clock time across DST', () async {
    tz.TZDateTime? captured;
    NotificationService.debugConfigure(
      loadLocalTimezone: () async => 'Europe/Paris',
      initializePlugin: (_) async => true,
      requestPlatformPermission: () async => true,
      loadReminderTime: () async => null,
      cancelReminder: () async {},
      scheduleReminder: (tz.TZDateTime date, NotificationDetails _) async {
        captured = date;
      },
      saveReminder: (_, __) async {},
      now: (tz.Location location) =>
          tz.TZDateTime(location, 2024, DateTime.march, 30, 10),
    );

    await NotificationService.scheduleDailyReminder(
      const TimeOfDay(hour: 9, minute: 0),
    );

    expect(captured, isNotNull);
    expect(captured!.year, 2024);
    expect(captured!.month, DateTime.march);
    expect(captured!.day, 31);
    expect(captured!.hour, 9);
    expect(captured!.timeZoneOffset, const Duration(hours: 2));
  });

  test(
    'a changed timezone reschedules the persisted time without a permission prompt',
    () async {
      tz.TZDateTime? captured;
      TimeOfDay? savedTime;
      String? savedTimezone;
      var permissionRequests = 0;
      NotificationService.debugConfigure(
        loadLocalTimezone: () async => 'America/Toronto',
        initializePlugin: (_) async => true,
        requestPlatformPermission: () async {
          permissionRequests++;
          return true;
        },
        loadReminderTime: () async => const TimeOfDay(hour: 8, minute: 45),
        loadReminderTimezone: () async => 'Europe/Paris',
        scheduleReminder: (tz.TZDateTime date, NotificationDetails _) async {
          captured = date;
        },
        saveReminder: (TimeOfDay time, String timezone) async {
          savedTime = time;
          savedTimezone = timezone;
        },
      );

      final bool rescheduled =
          await NotificationService.refreshTimezoneAndReschedule();

      expect(rescheduled, isTrue);
      expect(permissionRequests, 0);
      expect(captured?.location.name, 'America/Toronto');
      expect(captured?.hour, 8);
      expect(captured?.minute, 45);
      expect(savedTime, const TimeOfDay(hour: 8, minute: 45));
      expect(savedTimezone, 'America/Toronto');
    },
  );

  test(
    'an unchanged timezone leaves the persisted reminder untouched',
    () async {
      var permissionRequests = 0;
      var schedules = 0;
      NotificationService.debugConfigure(
        loadLocalTimezone: () async => 'Europe/Paris',
        initializePlugin: (_) async => true,
        requestPlatformPermission: () async {
          permissionRequests++;
          return true;
        },
        loadReminderTime: () async => const TimeOfDay(hour: 19, minute: 0),
        loadReminderTimezone: () async => 'Europe/Paris',
        scheduleReminder: (_, __) async => schedules++,
      );

      final bool rescheduled =
          await NotificationService.refreshTimezoneAndReschedule();

      expect(rescheduled, isFalse);
      expect(permissionRequests, 0);
      expect(schedules, 0);
    },
  );

  test(
    'resume reconciliation cannot overwrite a newer explicit schedule',
    () async {
      final Completer<void> oldReminderRead = Completer<void>();
      TimeOfDay storedTime = const TimeOfDay(hour: 8, minute: 0);
      String storedTimezone = 'Europe/Paris';
      final List<int> scheduledHours = <int>[];
      var firstRead = true;
      NotificationService.debugConfigure(
        loadLocalTimezone: () async => 'America/Toronto',
        initializePlugin: (_) async => true,
        requestPlatformPermission: () async => true,
        loadReminderTime: () async {
          if (firstRead) {
            firstRead = false;
            await oldReminderRead.future;
          }
          return storedTime;
        },
        loadReminderTimezone: () async => storedTimezone,
        cancelReminder: () async {},
        scheduleReminder: (tz.TZDateTime date, _) async {
          scheduledHours.add(date.hour);
        },
        saveReminder: (TimeOfDay time, String timezone) async {
          storedTime = time;
          storedTimezone = timezone;
        },
      );

      final Future<bool> reconcile =
          NotificationService.refreshTimezoneAndReschedule();
      await Future<void>.delayed(Duration.zero);
      final Future<bool> explicit = NotificationService.scheduleDailyReminder(
        const TimeOfDay(hour: 21, minute: 0),
      );
      oldReminderRead.complete();

      expect(await reconcile, isTrue);
      expect(await explicit, isTrue);
      expect(scheduledHours, <int>[8, 21]);
      expect(storedTime, const TimeOfDay(hour: 21, minute: 0));
      expect(storedTimezone, 'America/Toronto');
    },
  );

  test('a persistence failure restores the previous reminder time', () async {
    final List<int> scheduledHours = <int>[];
    var cancellations = 0;
    TimeOfDay storedTime = const TimeOfDay(hour: 8, minute: 0);
    NotificationService.debugConfigure(
      loadLocalTimezone: () async => 'Europe/Paris',
      initializePlugin: (_) async => true,
      requestPlatformPermission: () async => true,
      loadReminderTime: () async => storedTime,
      cancelReminder: () async => cancellations++,
      scheduleReminder: (tz.TZDateTime date, _) async {
        scheduledHours.add(date.hour);
      },
      saveReminder: (TimeOfDay time, _) async {
        storedTime = time;
        throw StateError('preferences unavailable');
      },
    );

    await expectLater(
      NotificationService.scheduleDailyReminder(
        const TimeOfDay(hour: 21, minute: 0),
      ),
      throwsStateError,
    );

    expect(scheduledHours, <int>[21, 8]);
    expect(cancellations, 0);
  });
}
