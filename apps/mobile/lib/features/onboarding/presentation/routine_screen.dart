import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// Step 4 — the gentle reminder nudge. Explains the value of a daily reminder
/// and lets the learner opt in/out before the final promise screen.
class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return OnboardingScaffold(
      progress: 0.8,
      onBack: () => context.go(OnboardingRoutes.goal),
      primaryLabel: 'CONTINUER',
      onPrimary: () => context.go(OnboardingRoutes.promise),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(
            message: 'Un petit rappel par jour, et la régularité fait le reste.',
          ),
          const SizedBox(height: 24),
          PrismCard(
            variant: PrismCardVariant.tonal,
            accent: p.primary,
            borderRadius: PrismRadii.cardXl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.notifications_active_rounded, color: p.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Rappel quotidien', style: t.titleMedium)),
                    Switch(
                      value: c.reminders,
                      onChanged: c.setReminders,
                      activeColor: p.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'On te proposera un moment idéal pour ta leçon du jour. '
                  'Tu pourras tout régler plus tard dans les réglages.',
                  style: t.bodySmall?.copyWith(color: p.textSecondary, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
