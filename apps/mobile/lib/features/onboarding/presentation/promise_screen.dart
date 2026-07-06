import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'onboarding_common.dart';
import 'value_list_screen.dart';

/// The value screen — "Ce que tu peux accomplir en 3 mois". Three concrete,
/// icon-led benefits that sell the outcome before the paywall, built on the
/// reusable [ValueListScreen] pattern.
class PromiseScreen extends StatelessWidget {
  const PromiseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListScreen(
      progress: 0.86,
      onBack: () => context.go(OnboardingRoutes.widget),
      message: 'Voici ce que tu peux accomplir en 3 mois.',
      primaryLabel: 'CONTINUER',
      onPrimary: () => context.go(OnboardingRoutes.paywall),
      benefits: const <ValueBenefit>[
        ValueBenefit(
          icon: Icons.hub_rounded,
          title: 'Comprendre les services Azure clés',
          subtitle: 'Compute, stockage, réseau, IA — les fondamentaux, sans jargon.',
        ),
        ValueBenefit(
          icon: Icons.quiz_rounded,
          title: 'Enchaîner les quiz avec confiance',
          subtitle: 'Des questions type examen jusqu\'à ce que ça devienne un réflexe.',
        ),
        ValueBenefit(
          icon: Icons.local_fire_department_rounded,
          title: 'Installer une habitude d\'apprentissage',
          subtitle: 'Quelques minutes par jour, une série qui te tire vers le haut.',
        ),
      ],
    );
  }
}
