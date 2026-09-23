import 'package:certigo/app/providers.dart';
import 'package:certigo/features/notifications/notification_lifecycle_scope.dart';
import 'package:certigo/features/notifications/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('permission inactive/resume preserves batch; background resume invalidates it',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    int cancellations = 0;
    NotificationService.debugConfigure(
        initializePlugin: (_) async => true,
        cancel: (_) async => cancellations++,
        requestPermission: () async => throw StateError('no permission at lifecycle'));
    await tester.pumpWidget(ProviderScope(overrides: [
      activeTrackOwnerIdProvider.overrideWithValue('learner'),
    ], child: const NotificationLifecycleScope(child: SizedBox())));
    await tester.pumpAndSettle();
    expect(cancellations, 11);
    NotificationService.scheduledCount.value = 2;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(NotificationService.scheduledCount.value, 2);
    expect(cancellations, 11);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(cancellations, 22);
    expect(NotificationService.scheduledCount.value, 0);
  });
}
