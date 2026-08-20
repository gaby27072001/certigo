import 'package:certigo/features/onboarding/application/onboarding_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('available certifications map to distinct backend track ids', () {
    expect(
      availableTargetCertifications.map((TargetCertification cert) => cert.trackId).toSet(),
      hasLength(availableTargetCertifications.length),
    );
    expect(TargetCertification.az900.trackId, 'az-900');
    expect(TargetCertification.dp900.trackId, 'dp-900');
    expect(TargetCertification.sc900.trackId, 'sc-900');
    expect(TargetCertification.az104.trackId, 'az-104');
  });

  test('completion is persisted before the onboarding gate opens', () async {
    final OnboardingController controller = OnboardingController(ownerId: 'user-1');

    await controller.complete();

    expect(controller.completed, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool('onboarding_completed:user-1'),
      isTrue,
    );
  });

  test('restart clears the selected certification and completion flag', () async {
    final OnboardingController controller = OnboardingController(ownerId: 'user-1')
      ..setTargetCertification(TargetCertification.dp900);
    await controller.complete();

    await controller.restart();

    expect(controller.completed, isFalse);
    expect(controller.targetCertification, isNull);
    expect(
      (await SharedPreferences.getInstance()).getBool('onboarding_completed:user-1'),
      isFalse,
    );
  });

  test('completion is restored only for the authenticated owner', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_completed:user-a': true,
    });
    final OnboardingController controller = OnboardingController();

    await controller.restoreForOwner('user-a');
    expect(controller.completed, isTrue);

    await controller.restoreForOwner('user-b');
    expect(controller.completed, isFalse);
  });
}
