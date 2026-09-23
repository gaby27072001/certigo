import 'dart:io';

import 'package:certigo/features/notifications/notification_permissions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('com.certigo.mobileapp/notifications');
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('settings action uses the native channel and checks its result', () async {
    String? invoked;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      invoked = call.method;
      return true;
    });
    await NotificationPermissions.openSettings();
    expect(invoked, 'openSettings');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);
    await expectLater(NotificationPermissions.openSettings(), throwsStateError);
  });

  test('iOS settings channel is registered by implicit engine, not window', () {
    final String source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final String registration = source.substring(
      source.indexOf('func didInitializeImplicitFlutterEngine'),
      source.indexOf('private func registerCrashReportingHealthChannel'),
    );
    expect(registration, contains('com.certigo.mobileapp/notifications'));
    expect(registration, contains('engineBridge.applicationRegistrar.messenger()'));
    expect(registration, contains('UIApplication.openSettingsURLString'));
    expect(registration, isNot(contains('window?.rootViewController')));
  });

  test('Android settings target only this application', () {
    final String source = File('android/app/src/main/kotlin/com/certigo/mobileapp/MainActivity.kt')
        .readAsStringSync();
    expect(source, contains('com.certigo.mobileapp/notifications'));
    expect(source, contains('Settings.ACTION_APP_NOTIFICATION_SETTINGS'));
    expect(source, contains('Settings.EXTRA_APP_PACKAGE, packageName'));
  });
}
