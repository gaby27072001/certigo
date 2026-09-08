import 'package:certigo/bootstrap/crash_smoke_test_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke UI requires an explicit action for each crash path', (
    WidgetTester tester,
  ) async {
    int dartCrashes = 0;
    int nativeCrashes = 0;
    await tester.pumpWidget(
      CrashSmokeTestApp(
        onDartCrash: () => dartCrashes += 1,
        onNativeCrash: () => nativeCrashes += 1,
      ),
    );

    expect(find.textContaining('destructive'), findsOneWidget);
    expect(dartCrashes, 0);
    expect(nativeCrashes, 0);

    await tester.tap(find.byKey(const Key('dart-crash-button')));
    await tester.tap(find.byKey(const Key('native-crash-button')));

    expect(dartCrashes, 1);
    expect(nativeCrashes, 1);
  });
}
