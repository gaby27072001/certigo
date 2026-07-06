import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// "Par où commencer ?" — the final question before entering the app. Two big
/// [RecommendedOptionCard]s: start from scratch, or (recommended) find your
/// level so the track calibrates to what you already know. Maps to [StartMode].
class StartChoiceScreen extends ConsumerWidget {
  const StartChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);
    final PrismColorScheme p = context.prism;

    return OnboardingScaffold(
      progress: 0.97,
      onBack: () => context.go(OnboardingRoutes.paywallReaction),
      primaryLabel: 'CONTINUER',
      onPrimary: c.startMode == null ? null : () => context.go(OnboardingRoutes.startReaction),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Par où veux-tu commencer ?'),
          const SizedBox(height: 24),
          RecommendedOptionCard(
            title: 'Repartir de zéro',
            subtitle: 'On reprend les bases pas à pas, tranquillement.',
            leading: Icon(Icons.play_circle_rounded, color: p.textSecondary, size: 26),
            selected: c.startMode == StartMode.scratch,
            onTap: () => c.setStartMode(StartMode.scratch),
          ),
          const SizedBox(height: 16),
          RecommendedOptionCard(
            title: 'Trouver mon niveau',
            subtitle: 'Un test rapide pour démarrer pile là où tu en es.',
            recommended: true,
            leading: Icon(Icons.speed_rounded, color: p.primary, size: 26),
            selected: c.startMode == StartMode.findLevel,
            onTap: () => c.setStartMode(StartMode.findLevel),
          ),
        ],
      ),
    );
  }
}
