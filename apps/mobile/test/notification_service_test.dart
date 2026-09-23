import 'dart:async';

import 'package:certigo/features/notifications/notification_migration.dart';
import 'package:certigo/features/notifications/notification_service.dart';
import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const NotificationSettings settings = NotificationSettings(
    enabled: true,
    utcOffsetMinutes: 0,
    quietHoursStart: 22,
    quietHoursEnd: 7,
    preferredHour: 19,
    maxPerDay: 3,
    streakAlerts: true,
    questAlerts: true,
    leagueAlerts: true);

PlannedNotification entry(int hour, {String key = 'one'}) => PlannedNotification(
    kind: 'Streak',
    priority: 'High',
    scheduledUtc: DateTime.utc(2026, 9, 23, hour),
    localHour: hour,
    mascot: 'nova',
    title: 'stale assertion',
    body: 'already completed?',
    deeplink: 'certigo://home',
    dedupeKey: key);
NotificationPlan plan(List<PlannedNotification> entries) =>
    NotificationPlan(localDate: '2026-09-23', notifications: entries);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<int> cancelled;
  late List<PlannedNotification> scheduled;
  late int requests;
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    cancelled = <int>[];
    scheduled = <PlannedNotification>[];
    requests = 0;
    NotificationService.debugConfigure(
      initializePlugin: (settings) async {
        expect(settings.iOS?.requestAlertPermission, isFalse);
        expect(settings.iOS?.requestSoundPermission, isFalse);
        return false;
      },
      requestPermission: () async {
        requests++;
        return true;
      },
      cancel: (int id) async => cancelled.add(id),
      schedule: (_, PlannedNotification item) async => scheduled.add(item),
      now: () => DateTime.utc(2026, 9, 23, 12),
    );
  });
  test('initialization is shared, permission-free, and retryable after failure', () async {
    final Future<void> first = NotificationService.initialize();
    expect(identical(first, NotificationService.initialize()), isTrue);
    await first;
    expect(requests, 0);
    int attempts = 0;
    NotificationService.debugConfigure(initializePlugin: (_) async {
      if (++attempts == 1) throw StateError('failure');
      return true;
    });
    await expectLater(NotificationService.initialize(), throwsStateError);
    await NotificationService.initialize();
    expect(attempts, 2);
  });
  test('only future UTC instants are scheduled, replacing the old batch', () async {
    expect(
        await NotificationService.scheduleServerPlan(
            settings, plan(<PlannedNotification>[entry(11), entry(19, key: 'two')])),
        1);
    expect(scheduled.single.scheduledUtc.hour, 19);
    expect(cancelled, containsAll(<int>[1, 1000, 1009]));
    expect(requests, 1);
    expect(NotificationService.scheduledCount.value, 1);
  });
  test('disabled settings and empty plans never request permission', () async {
    expect(
        await NotificationService.scheduleServerPlan(
            settings.copyWith(enabled: false), plan(<PlannedNotification>[entry(19)])),
        0);
    expect(
        await NotificationService.scheduleServerPlan(settings, plan(<PlannedNotification>[])), 0);
    expect(requests, 0);
    expect(scheduled, isEmpty);
  });
  test('denied or unknown permission cannot be reported as scheduled', () async {
    for (final bool? permission in <bool?>[false, null]) {
      NotificationService.debugConfigure(
          initializePlugin: (_) async => true,
          cancel: (_) async {},
          requestPermission: () async => permission,
          now: () => DateTime.utc(2026, 9, 23, 12));
      expect(
          await NotificationService.scheduleServerPlan(
              settings, plan(<PlannedNotification>[entry(19)])),
          isNull);
      expect(NotificationService.scheduledCount.value, 0);
    }
  });
  test('stale date and duplicate keys fail explicitly', () async {
    await expectLater(
        NotificationService.scheduleServerPlan(
            settings,
            NotificationPlan(
                localDate: '2026-09-22', notifications: <PlannedNotification>[entry(19)])),
        throwsStateError);
    await expectLater(
        NotificationService.scheduleServerPlan(
            settings, plan(<PlannedNotification>[entry(18), entry(19)])),
        throwsStateError);
    expect(requests, 0);
  });
  test('plugin scheduling failure rolls back all known IDs', () async {
    NotificationService.debugConfigure(
        initializePlugin: (_) async => true,
        cancel: (int id) async => cancelled.add(id),
        requestPermission: () async => true,
        schedule: (_, __) async => throw StateError('plugin failure'),
        now: () => DateTime.utc(2026, 9, 23, 12));
    await expectLater(
        NotificationService.scheduleServerPlan(settings, plan(<PlannedNotification>[entry(19)])),
        throwsStateError);
    expect(cancelled.length, 22);
    expect(NotificationService.scheduledCount.value, 0);
  });
  test('cancellation failure is visible and does not skip remaining IDs', () async {
    NotificationService.debugConfigure(
        initializePlugin: (_) async => true,
        cancel: (int id) async {
          cancelled.add(id);
          if (id == 1) throw StateError('failure');
        });
    await expectLater(NotificationService.cancelDailyReminder(), throwsStateError);
    expect(cancelled.length, 11);
    expect(NotificationService.cancellationFailed.value, isTrue);
  });
  test('account invalidation during permission prevents any new schedule', () async {
    final Completer<bool?> permission = Completer<bool?>();
    NotificationService.debugConfigure(
        initializePlugin: (_) async => true,
        cancel: (_) async {},
        requestPermission: () => permission.future,
        schedule: (_, PlannedNotification item) async => scheduled.add(item),
        now: () => DateTime.utc(2026, 9, 23, 12));
    final Future<int?> pending =
        NotificationService.scheduleServerPlan(settings, plan(<PlannedNotification>[entry(19)]));
    await Future<void>.delayed(Duration.zero);
    final Future<void> cancellation = NotificationService.cancelDailyReminder();
    permission.complete(true);
    expect(await pending, 0);
    await cancellation;
    expect(scheduled, isEmpty);
  });
  test('legacy 19:37 survives restart and resume without permission or cancellation of ID 1',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'daily_reminder_time': '19:37'});
    final List<String> restored = <String>[];
    NotificationService.debugConfigure(
        initializePlugin: (_) async => true,
        cancel: (int id) async => cancelled.add(id),
        restoreLegacy: (LegacyNotificationChoice choice) async => restored.add(choice.timeLabel),
        requestPermission: () async {
          requests++;
          return false;
        });
    await NotificationService.reconcileLifecycle('learner');
    await NotificationService.reconcileLifecycle('learner');
    expect(restored, <String>['19:37', '19:37']);
    expect(cancelled, isNot(contains(1)));
    expect(requests, 0);
    await NotificationService.reconcileLifecycle('other');
    expect(cancelled, contains(1));
    expect(restored.length, 2);
  });
  test('legacy disabled remains disabled offline across lifecycle calls', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_reminder_time': '19:37',
      'pref_streak_reminder': false,
    });
    NotificationService.debugConfigure(
        initializePlugin: (_) async => true,
        cancel: (_) async {},
        restoreLegacy: (_) async => fail('must never resurrect disabled reminder'));
    await NotificationService.reconcileLifecycle('learner');
    await NotificationService.reconcileLifecycle('learner');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('pref_streak_reminder'), isFalse);
    expect(prefs.getString('daily_reminder_time'), '19:37');
  });
}
