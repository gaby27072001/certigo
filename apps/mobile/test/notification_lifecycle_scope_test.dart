import 'package:certigo/features/notifications/notification_lifecycle_scope.dart';
import 'package:certigo/features/notifications/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'resume refreshes timezone and reschedules without requesting permission',
    (WidgetTester tester) async {
      var timezoneLoads = 0;
      var permissionRequests = 0;
      var schedules = 0;
      String? savedTimezone;
      NotificationService.debugConfigure(
        loadLocalTimezone: () async {
          timezoneLoads++;
          return timezoneLoads < 3 ? 'UTC' : 'Europe/Paris';
        },
        initializePlugin: (_) async => true,
        requestPlatformPermission: () async {
          permissionRequests++;
          return true;
        },
        loadReminderTime: () async => const TimeOfDay(hour: 19, minute: 0),
        loadReminderTimezone: () async => 'UTC',
        cancelReminder: () async {},
        scheduleReminder: (_, NotificationDetails __) async => schedules++,
        saveReminder: (_, String timezone) async {
          savedTimezone = timezone;
        },
      );

      await tester.pumpWidget(
        const NotificationLifecycleScope(child: SizedBox()),
      );
      await tester.pump();
      expect(permissionRequests, 0);
      expect(schedules, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(permissionRequests, 0);
      expect(schedules, 1);
      expect(savedTimezone, 'Europe/Paris');
    },
  );
}
