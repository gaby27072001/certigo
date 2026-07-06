import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/onboarding_controller.dart';
import 'mascot_reaction_screen.dart';
import 'onboarding_common.dart';

/// "On part de ce que tu sais !" — the beat after the knowledge-level question.
class LevelReactionScreen extends StatelessWidget {
  const LevelReactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MascotReactionScreen(
      message: 'On part de ce que tu sais déjà — pas besoin de tout reprendre à zéro !',
      onBack: () => context.go(OnboardingRoutes.level),
      onPrimary: () => context.go(OnboardingRoutes.reasons),
    );
  }
}

/// "Excellent choix !" — the beat after the motivations question.
class ReasonsReactionScreen extends StatelessWidget {
  const ReasonsReactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MascotReactionScreen(
      message: 'Excellent choix ! On va garder ta motivation intacte.',
      onBack: () => context.go(OnboardingRoutes.reasons),
      onPrimary: () => context.go(OnboardingRoutes.routineIntro),
    );
  }
}

/// The metric payoff after the daily-goal question — projects the number of
/// notions the learner will cover in their first week.
class GoalReactionScreen extends ConsumerWidget {
  const GoalReactionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);
    return MascotReactionScreen(
      message: 'À ce rythme, tu vas apprendre vite !',
      onBack: () => context.go(OnboardingRoutes.goal),
      onPrimary: () => context.go(OnboardingRoutes.notifications),
      highlight: MetricBadge(
        value: '≈ ${c.weeklyNotions}',
        label: 'notions ta 1re semaine',
      ),
    );
  }
}

/// "OK, tu pourras l'ajouter quand tu veux" — the beat after the widget promo.
class WidgetReactionScreen extends StatelessWidget {
  const WidgetReactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MascotReactionScreen(
      message: 'Pas de souci, tu pourras ajouter le widget quand tu voudras.',
      onBack: () => context.go(OnboardingRoutes.widget),
      onPrimary: () => context.go(OnboardingRoutes.promise),
    );
  }
}

/// "Tu pourras passer Premium quand tu veux" — the beat after the paywall.
class PaywallReactionScreen extends StatelessWidget {
  const PaywallReactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MascotReactionScreen(
      message: 'Parfait — tu pourras passer Premium quand tu voudras, sans pression.',
      onBack: () => context.go(OnboardingRoutes.paywall),
      onPrimary: () => context.go(OnboardingRoutes.start),
    );
  }
}

/// The closing Readiness reveal — since the learner already knows some notions,
/// the track starts at a non-zero Readiness Score. The last screen of the flow:
/// marks onboarding complete and enters the app.
class StartReactionScreen extends ConsumerWidget {
  const StartReactionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);
    return MascotReactionScreen(
      message: 'Comme tu connais déjà des notions, on démarre plus haut. C\'est parti !',
      primaryLabel: 'JE COMMENCE',
      progress: 1,
      onBack: () => context.go(OnboardingRoutes.start),
      onPrimary: () {
        c.complete();
        context.go('/home');
      },
      highlight: MetricBadge(
        value: '${c.readinessScore}',
        label: 'Readiness Score de départ',
      ),
    );
  }
}
