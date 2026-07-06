import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// Step 3 — "Quel objectif quotidien ?". Single-select minute target with a mood
/// caption on the right, mirroring the daily-goal picker.
class GoalScreen extends ConsumerWidget {
  const GoalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);

    return OnboardingScaffold(
      progress: 0.60,
      onBack: () => context.go(OnboardingRoutes.routineIntro),
      primaryLabel: 'CONTINUER',
      onPrimary: c.goal == null ? null : () => context.go(OnboardingRoutes.goalReaction),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Combien de temps par jour ?'),
          const SizedBox(height: 24),
          for (final DailyGoalOption option in DailyGoalOption.values) ...<Widget>[
            ChoiceTile(
              title: '${option.minutes} min / jour',
              trailingLabel: option.label,
              showCheckbox: false,
              selected: c.goal == option,
              onTap: () => c.setGoal(option),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
