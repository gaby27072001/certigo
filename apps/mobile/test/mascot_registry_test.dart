import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Unit tests for the mascot swap-in system.
///
/// They prove the contract the onboarding/home/path screens rely on: with no
/// art the registry returns null (procedural face), and once art is wired (via
/// convention or explicit registration) it resolves with the documented
/// fallback chain (mood → idle).
void main() {
  setUp(() => MascotRegistry.instance.reset());
  tearDown(() => MascotRegistry.instance.reset());

  test('returns null with no art configured (procedural fallback)', () {
    expect(MascotRegistry.instance.hasCustomArt, isFalse);
    expect(MascotRegistry.instance.resolve(AuroraMascot.nimbus, MascotMood.happy), isNull);
  });

  test('useImageAssets resolves the convention path', () {
    MascotRegistry.instance.useImageAssets();
    final MascotArt? art = MascotRegistry.instance.resolve(AuroraMascot.volt, MascotMood.celebrate);
    expect(art, isNotNull);
    expect(art!.assetPath, 'assets/mascots/volt/celebrate.png');
    expect(MascotRegistry.instance.hasCustomArt, isTrue);
  });

  test('explicit mood registration takes priority', () {
    MascotRegistry.instance.useImageAssets();
    MascotRegistry.instance
        .registerMood(AuroraMascot.nimbus, MascotMood.happy, 'custom/nimbus_happy.png');
    expect(
      MascotRegistry.instance.resolve(AuroraMascot.nimbus, MascotMood.happy)!.assetPath,
      'custom/nimbus_happy.png',
    );
  });

  test('falls back to idle art when a mood is not explicitly registered', () {
    MascotRegistry.instance.registerMood(AuroraMascot.pip, MascotMood.idle, 'pip/idle.png');
    expect(
      MascotRegistry.instance.resolve(AuroraMascot.pip, MascotMood.sad)!.assetPath,
      'pip/idle.png',
    );
  });

  testWidgets('MascotAvatar renders without art (drawn face)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: MascotAvatar(mascot: AuroraMascot.nimbus)),
        ),
      ),
    );
    expect(find.byType(MascotAvatar), findsOneWidget);
  });

  testWidgets('MascotHero renders a figure', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: MascotHero(mascot: AuroraMascot.nimbus)),
        ),
      ),
    );
    expect(find.byType(MascotHero), findsOneWidget);
    expect(find.byType(MascotAvatar), findsOneWidget);
  });
}
