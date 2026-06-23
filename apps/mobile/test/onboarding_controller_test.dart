import 'package:flutter_test/flutter_test.dart';
import 'package:microlingo/features/onboarding/application/onboarding_controller.dart';

/// Tests the onboarding state machine that drives the wizard and gates the app.
void main() {
  test('starts incomplete with sensible defaults', () {
    final OnboardingController c = OnboardingController();
    expect(c.completed, isFalse);
    expect(c.start, StartChoice.continueTrack);
    expect(c.reasons, isEmpty);
    expect(c.goal, isNull);
    expect(c.reminders, isTrue);
  });

  test('toggleReason adds then removes (multi-select)', () {
    final OnboardingController c = OnboardingController();
    c.toggleReason(LearnReason.career);
    c.toggleReason(LearnReason.certification);
    expect(c.reasons, <LearnReason>{LearnReason.career, LearnReason.certification});
    c.toggleReason(LearnReason.career);
    expect(c.reasons, <LearnReason>{LearnReason.certification});
  });

  test('weeklyNotions scales with the chosen daily goal', () {
    final OnboardingController c = OnboardingController();
    c.setGoal(DailyGoalOption.chill); // 3 min → 3*7/2 = 11 (rounded)
    expect(c.weeklyNotions, 11);
    c.setGoal(DailyGoalOption.intense); // 30 min → 105
    expect(c.weeklyNotions, 105);
  });

  test('complete flips the gate exactly once and notifies', () {
    final OnboardingController c = OnboardingController();
    var notifications = 0;
    c.addListener(() => notifications++);
    c.complete();
    expect(c.completed, isTrue);
    expect(notifications, 1);
    c.complete(); // idempotent
    expect(notifications, 1);
  });

  test('restart clears answers and re-locks the gate', () {
    final OnboardingController c = OnboardingController()
      ..setGoal(DailyGoalOption.serious)
      ..toggleReason(LearnReason.raise)
      ..complete();
    c.restart();
    expect(c.completed, isFalse);
    expect(c.goal, isNull);
    expect(c.reasons, isEmpty);
  });

  test('daily goal options expose minutes/xp/label', () {
    expect(DailyGoalOption.regular.minutes, 10);
    expect(DailyGoalOption.regular.xp, 50);
    expect(DailyGoalOption.intense.label, 'Extrême');
  });
}
