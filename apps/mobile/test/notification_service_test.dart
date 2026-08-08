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
      );

      final Future<void> first = NotificationService.initialize();
      final Future<void> second = NotificationService.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(identical(first, second), isTrue);
      expect(timezoneLoads, 1);
      expect(pluginInitializations, 1);

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
      var cancellations = 0;
      NotificationService.debugConfigure(
        loadLocalTimezone: () async => 'America/Toronto',
        initializePlugin: (_) async => true,
        requestPlatformPermission: () async => true,
        cancelReminder: () async => cancellations++,
        scheduleReminder: (tz.TZDateTime date, NotificationDetails _) async {
          captured = date;
        },
      );

      final bool scheduled = await NotificationService.scheduleDailyReminder(
        const TimeOfDay(hour: 7, minute: 15),
      );

      expect(scheduled, isTrue);
      expect(cancellations, 1);
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
      cancelReminder: () async {},
      scheduleReminder: (tz.TZDateTime date, NotificationDetails _) async {
        captured = date;
      },
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
}
