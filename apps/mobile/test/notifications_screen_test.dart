import 'dart:async';

import 'package:certigo/app/providers.dart';
import 'package:certigo/app/router.dart';
import 'package:certigo/features/notifications/notification_destination.dart';
import 'package:certigo/features/notifications/notification_migration.dart';
import 'package:certigo/features/notifications/notification_providers.dart';
import 'package:certigo/features/notifications/notification_service.dart';
import 'package:certigo/features/notifications/notifications_screen.dart';
import 'package:certigo/features/profile/presentation/widgets/preference_rows.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service_test.dart' show settings, entry, plan;

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _Repository implements NotificationRepository {
  NotificationSettings current = settings.copyWith(utcOffsetMinutes: 345, questAlerts: false);
  Failure? getFailure;
  Failure? saveFailure;
  Failure? planFailure;
  final List<NotificationSettings> writes = <NotificationSettings>[];
  Completer<Result<NotificationSettings>>? pendingSave;
  int planReads = 0;

  @override
  Future<Result<NotificationSettings>> getSettings() async =>
      getFailure == null ? Success(current) : Err(getFailure!);
  @override
  Future<Result<NotificationSettings>> updateSettings(NotificationSettings next) async {
    writes.add(next);
    if (pendingSave != null) return pendingSave!.future;
    if (saveFailure != null) return Err(saveFailure!);
    current = next;
    return Success(current);
  }

  @override
  Future<Result<NotificationPlan>> getPlan() async {
    planReads++;
    return planFailure == null
        ? Success(plan(<PlannedNotification>[entry(18)]))
        : Err(planFailure!);
  }
}

void main() {
  late _Repository repository;
  bool allowPermission = true;
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = _Repository();
    NotificationService.debugConfigure(
      initializePlugin: (_) async => true,
      cancel: (_) async {},
      requestPermission: () async => true,
      schedule: (_, __) async {},
      now: () => DateTime.utc(2026, 9, 23, 12),
      restoreLegacy: (_) async {},
    );
    await Future<void>.delayed(Duration.zero);
  });

  Future<void> pump(WidgetTester tester, {double textScale = 1, bool profile = false}) async {
    NotificationService.debugConfigure(
      initializePlugin: (_) async => true,
      cancel: (_) async {},
      requestPermission: () async => allowPermission,
      schedule: (_, __) async {},
      now: () => DateTime.utc(2026, 9, 23, 12),
      restoreLegacy: (_) async {},
    );
    final GoRouter router =
        GoRouter(initialLocation: profile ? '/profile' : '/notifications', routes: <RouteBase>[
      GoRoute(path: '/profile', builder: (_, __) => const Scaffold(body: NotificationPrefRow())),
      GoRoute(path: Routes.notifications, builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: Routes.home, builder: (_, __) => const Scaffold(body: Text('Accueil cible'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          activeTrackOwnerIdProvider.overrideWithValue('learner'),
          notificationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
            theme: PrismTheme.light(),
            routerConfig: router,
            builder: (_, Widget? child) => MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ))));
    await _settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final Finder target = find.text(text);
    await tester.scrollUntilVisible(target, 350, scrollable: find.byType(Scrollable).first);
    await _settle(tester);
    await tester.ensureVisible(target);
    await _settle(tester);
    if (text == 'Enregistrer les réglages') {
      final ProviderContainer container =
          ProviderScope.containerOf(tester.element(find.byType(NotificationsScreen)));
      expect(
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, text)).onPressed, isNotNull,
          reason: 'Save must be available after loading: '
              '${container.read(retireLegacyReminderProvider)} '
              '${container.read(notificationSettingsProvider)}');
    }
    await tester.tap(target);
    await _settle(tester);
  }

  test('destinations are an exact allow-list with no arbitrary URLs', () {
    expect(notificationDestination('certigo://home'), Routes.home);
    expect(notificationDestination('certigo://lesson/next'), Routes.home);
    expect(notificationDestination('certigo://quests'), Routes.quests);
    expect(notificationDestination('certigo://league'), Routes.leaderboard);
    for (final String link in <String>[
      'https://evil.test',
      '/home',
      'certigo://home?x=1',
      'certigo://league/other',
      'certigo://account/delete'
    ]) {
      expect(notificationDestination(link), isNull);
    }
  });
  testWidgets('profile link opens notifications', (WidgetTester tester) async {
    await pump(tester, profile: true);
    await tester.tap(find.text('Notifications et rappels'));
    await _settle(tester);
    expect(find.text('Réglages serveur'), findsOneWidget);
  });
  testWidgets('full replacement preserves untouched fields and shows no push promise',
      (WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.text('Activer le plan serveur'));
    await tapText(tester, 'Enregistrer les réglages');
    expect(repository.writes.single.enabled, isFalse);
    expect(repository.writes.single.utcOffsetMinutes, 345);
    expect(repository.writes.single.questAlerts, isFalse);
    expect(repository.writes.single.toJson().length, 9);
  });
  testWidgets('failed save retains draft and never claims success', (WidgetTester tester) async {
    repository.saveFailure = const NetworkFailure('private exception details');
    await pump(tester);
    await tapText(tester, 'Enregistrer les réglages');
    expect(find.textContaining('Réglages enregistrés'), findsNothing);
    expect(find.textContaining('private exception'), findsNothing);
    expect(repository.writes.length, 1);
    expect(find.text('Tu es hors ligne'), findsOneWidget);
  });
  testWidgets('404 settings does not block plan and never invents defaults',
      (WidgetTester tester) async {
    repository.getFailure = const NotFoundFailure();
    await pump(tester);
    expect(find.text('Les réglages : indisponible sur ce serveur'), findsOneWidget);
    expect(find.text('Activer le plan serveur'), findsNothing);
    await tester.scrollUntilVisible(find.text('stale assertion'), 400,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('stale assertion'), findsOneWidget);
  });
  testWidgets('permission denial offers settings and no active batch', (WidgetTester tester) async {
    allowPermission = false;
    addTearDown(() => allowPermission = true);
    await pump(tester);
    await tapText(tester, 'Programmer sur cet appareil');
    expect(NotificationService.scheduledCount.value, 0);
    expect(find.text('Ouvrir les Réglages'), findsOneWidget);
  });
  testWidgets('resume cancellation changes the visible delivery state',
      (WidgetTester tester) async {
    await pump(tester);
    await tapText(tester, 'Programmer sur cet appareil');
    expect(NotificationService.scheduledCount.value, 1);
    await NotificationService.cancelDailyReminder();
    await _settle(tester);
    expect(find.text('Aucun lot local actif.'), findsOneWidget);
    expect(find.textContaining('1 rappel(s) confié(s)'), findsNothing);
  });
  testWidgets('large text has no overflow and no truncated controls', (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, textScale: 2);
    await tester.scrollUntilVisible(find.text('Enregistrer les réglages'), 350,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
    await tapText(tester, 'Programmer sur cet appareil');
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    semantics.dispose();
  });
  testWidgets('nonzero legacy minutes require explicit confirmation before replacement',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'daily_reminder_time': '19:37'});
    await pump(tester);
    expect(repository.writes, isEmpty);
    expect(find.textContaining('19:37 reste conservé'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Enregistrer les réglages'), 350,
        scrollable: find.byType(Scrollable).first);
    final FilledButton button =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Enregistrer les réglages'));
    expect(button.onPressed, isNull);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_reminder_time'), '19:37');
  });

  testWidgets('explicit legacy confirmation migrates without retaining duplicate reminder',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'daily_reminder_time': '19:37'});
    await pump(tester);
    await tapText(tester, 'Remplacer 19:37 par 19 h');
    await tapText(tester, 'Enregistrer les réglages');
    expect(repository.writes.single.preferredHour, 19);
    expect(repository.writes.single.utcOffsetMinutes, 345);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_reminder_time'), isNull);
    expect(prefs.getBool('notification_migrated:learner'), isTrue);
    expect(NotificationService.scheduledCount.value, 0);
  });

  testWidgets('save is single flight', (WidgetTester tester) async {
    repository.pendingSave = Completer<Result<NotificationSettings>>();
    await pump(tester);
    await tapText(tester, 'Enregistrer les réglages');
    expect(repository.writes.length, 1);
    expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Enregistrement…')).onPressed,
        isNull);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Programmer sur cet appareil'))
            .onPressed,
        isNull);
    repository.pendingSave!.complete(Success(repository.current));
    await _settle(tester);
    expect(repository.writes.length, 1);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Programmer sur cet appareil'))
            .onPressed,
        isNotNull);
  });

  testWidgets('explicit disable survives failed nonzero-minute migration offline',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'daily_reminder_time': '19:37'});
    repository.saveFailure = const NetworkFailure();
    await pump(tester);
    await tapText(tester, 'Activer le plan serveur');
    await tapText(tester, 'Enregistrer les réglages');
    final LegacyNotificationChoice? choice = await LegacyNotificationChoice.load('learner');
    expect(choice?.enabled, isFalse);
    expect(choice?.timeLabel, '19:37');
    expect(repository.writes.single.preferredHour, settings.preferredHour);
    expect(NotificationService.scheduledCount.value, 0);
  });

  test('whole-hour migration uses GET and full POST once, preserving server fields', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_reminder_time': '17:00',
      'pref_streak_reminder': false,
    });
    final ProviderContainer container = ProviderContainer(overrides: [
      activeTrackOwnerIdProvider.overrideWithValue('learner'),
      notificationRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(notificationSettingsProvider, (_, __) {});
    addTearDown(subscription.close);
    await container.read(notificationSettingsProvider.future);
    await Future<void>.delayed(Duration.zero);
    await container.read(notificationSettingsProvider.future);
    expect(repository.writes.length, 1);
    expect(repository.writes.single.enabled, isFalse);
    expect(repository.writes.single.preferredHour, 17);
    expect(repository.writes.single.utcOffsetMinutes, 345);
    expect(repository.writes.single.questAlerts, isFalse);
    expect(await LegacyNotificationChoice.load('learner'), isNull);
    expect(await LegacyNotificationChoice.load('other'), isNull);
  });
  test('failed migration keeps local disabled choice and no success marker', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_reminder_time': '17:00',
      'pref_streak_reminder': false,
    });
    repository.saveFailure = const NetworkFailure();
    final ProviderContainer container = ProviderContainer(overrides: [
      activeTrackOwnerIdProvider.overrideWithValue('learner'),
      notificationRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    await expectLater(
        container.read(notificationSettingsProvider.future), throwsA(isA<NetworkFailure>()));
    expect((await LegacyNotificationChoice.load('learner'))?.enabled, isFalse);
    expect(await LegacyNotificationChoice.load('other'), isNull);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('notification_migrated:learner'), isNull);
    expect(prefs.getString('daily_reminder_time'), '17:00');
  });
}
