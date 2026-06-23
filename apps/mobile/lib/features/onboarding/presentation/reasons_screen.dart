import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// Step 2 — "Pourquoi veux-tu te certifier ?". Multi-select motivations that
/// later let the coach tailor its encouragement.
class ReasonsScreen extends ConsumerWidget {
  const ReasonsScreen({super.key});

  static const List<(LearnReason, String, String)> _options = <(LearnReason, String, String)>[
    (LearnReason.career, '🚀', 'Booster ma carrière'),
    (LearnReason.certification, '🎓', 'Décrocher une certification'),
    (LearnReason.upskill, '💼', 'Monter en compétences au travail'),
    (LearnReason.raise, '💰', 'Viser une augmentation'),
    (LearnReason.curiosity, '✨', 'Par curiosité'),
    (LearnReason.time, '⏳', 'Bien occuper mon temps'),
    (LearnReason.other, '🎯', 'Une autre raison'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);

    return OnboardingScaffold(
      progress: 0.4,
      onBack: () => context.go(OnboardingRoutes.start),
      primaryLabel: 'CONTINUER',
      onPrimary: c.reasons.isEmpty ? null : () => context.go(OnboardingRoutes.goal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Pourquoi veux-tu te certifier ?'),
          const SizedBox(height: 24),
          for (final (LearnReason value, String emoji, String label) in _options) ...<Widget>[
            ChoiceTile(
              title: label,
              leading: Text(emoji, style: const TextStyle(fontSize: 22)),
              selected: c.reasons.contains(value),
              onTap: () => c.toggleReason(value),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
