import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Global test harness (auto-loaded by `flutter test` for every test under
/// `test/`).
///
/// `flutter_secure_storage` has no platform implementation under `flutter test`,
/// so its `MethodChannel` never replies. Any widget/router test that builds the
/// real provider graph transitively constructs `SecureSessionStore`, whose
/// `read()` now guards the call with `.timeout(...)` (the production fix for the
/// infinite splash hang). Without a channel reply that timeout would schedule a
/// timer that stays pending until the widget tree is disposed, tripping the
/// "A Timer is still pending" assertion.
///
/// Registering a mock handler that resolves the storage calls immediately lets
/// the underlying future complete before the timeout fires, so the timer is
/// cancelled and no timer leaks. Tests that inject an in-memory fake store never
/// hit this channel, so the mock is simply unused for them.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    switch (call.method) {
      case 'read':
        return null;
      case 'readAll':
        return <String, String>{};
      case 'containsKey':
      case 'isProtectedDataAvailable':
        return false;
      default:
        // write, delete, deleteAll and friends return void.
        return null;
    }
  });

  await testMain();
}
