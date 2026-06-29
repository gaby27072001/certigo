import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// Step 1 — "Que veux-tu faire ?". A single-choice question that sets the tone,
/// echoing the opening question of a returning-user flow but themed for certs.
class StartChoiceScreen extends ConsumerWidget {
  const StartChoiceScreen({super.key});

  static const List<(StartChoice, IconData, String)> _options = <(StartChoice, IconData, String)>[
    (StartChoice.continueTrack, Icons.play_circle_rounded, 'Je continue ma préparation'),
    (StartChoice.switchTrack, Icons.swap_horiz_rounded, 'Je vise une autre certification'),
    (StartChoice.explore, Icons.explore_rounded, 'Je découvre Certigo'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);
    final PrismColorScheme p = context.prism;

    return OnboardingScaffold(
      progress: 0.2,
      onBack: () => context.go(OnboardingRoutes.welcome),
      primaryLabel: 'CONTINUER',
      onPrimary: () => context.go(OnboardingRoutes.reasons),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Salut ! Que veux-tu faire aujourd\'hui ?'),
          const SizedBox(height: 24),
          for (final (StartChoice value, IconData icon, String label) in _options) ...<Widget>[
            ChoiceTile(
              title: label,
              showCheckbox: false,
              leading: Icon(icon, color: c.start == value ? p.primary : p.textSecondary, size: 24),
              selected: c.start == value,
              onTap: () => c.setStart(value),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
