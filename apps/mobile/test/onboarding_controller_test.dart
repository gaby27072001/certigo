import 'package:flutter_test/flutter_test.dart';
import 'package:certigo/features/onboarding/application/onboarding_controller.dart';

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

  test('Part-2 single-select fields default to null and set independently', () {
    final OnboardingController c = OnboardingController();
    expect(c.targetCertification, isNull);
    expect(c.attributionSource, isNull);
    expect(c.premiumChoice, isNull);
    expect(c.startMode, isNull);

    c.setTargetCertification(TargetCertification.az900);
    c.setAttributionSource(AttributionSource.youtube);
    c.setPremiumChoice(PremiumChoice.premium);
    c.setStartMode(StartMode.findLevel);

    expect(c.targetCertification, TargetCertification.az900);
    expect(c.attributionSource, AttributionSource.youtube);
    expect(c.premiumChoice, PremiumChoice.premium);
    expect(c.startMode, StartMode.findLevel);
  });

  test('readinessScore climbs with the knowledge level and never starts at 0', () {
    final OnboardingController c = OnboardingController();
    expect(c.readinessScore, 5); // no level yet, still non-zero
    c.setLevel(KnowledgeLevel.beginner);
    final int beginner = c.readinessScore;
    c.setLevel(KnowledgeLevel.expert);
    expect(c.readinessScore, greaterThan(beginner));
  });

  test('restart clears the Part-2 fields too', () {
    final OnboardingController c = OnboardingController()
      ..setTargetCertification(TargetCertification.dp900)
      ..setPremiumChoice(PremiumChoice.free)
      ..setStartMode(StartMode.scratch);
    c.restart();
    expect(c.targetCertification, isNull);
    expect(c.premiumChoice, isNull);
    expect(c.startMode, isNull);
  });

  test('certification exposes code/title/domainIndex', () {
    expect(TargetCertification.az900.code, 'AZ-900');
    expect(TargetCertification.az900.title, 'Microsoft Azure Fundamentals');
    expect(TargetCertification.ai900.title, 'Microsoft Azure AI Fundamentals');
    expect(TargetCertification.ai900.isAvailableForNewLearners, isFalse);
    expect(availableTargetCertifications, isNot(contains(TargetCertification.ai900)));
    expect(TargetCertification.ai901.code, 'AI-901');
    expect(TargetCertification.ai901.isAvailableForNewLearners, isTrue);
    expect(availableTargetCertifications, contains(TargetCertification.ai901));
    expect(TargetCertification.sc900.domainIndex, isNonNegative);
  });
}
