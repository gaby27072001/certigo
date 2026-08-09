import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// The paywall — "Comment veux-tu avancer ?" with two big cards (Certigo
/// **Premium**, recommended, and Gratuit). A deliberate placeholder: there's no
/// billing yet, so it carries a discreet "bientôt" tag and simply records the
/// learner's preference before continuing.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);
    final PrismColorScheme p = context.prism;

    return OnboardingScaffold(
      progress: 0.92,
      onBack: () => context.go(OnboardingRoutes.promise),
      primaryLabel: 'CONTINUER',
      onPrimary: c.premiumChoice == null
          ? null
          : () => context.go(OnboardingRoutes.paywallReaction),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Comment veux-tu avancer ?'),
          const SizedBox(height: 8),
          const SoonTag(),
          const SizedBox(height: 20),
          RecommendedOptionCard(
            title: 'Certigo Premium',
            subtitle: 'Leçons illimitées, examens blancs et zéro pub. Essai gratuit de 7 jours.',
            recommended: true,
            leading: Icon(Icons.workspace_premium_rounded, color: p.xpGold, size: 26),
            accent: p.primary,
            selected: c.premiumChoice == PremiumChoice.premium,
            onTap: () => c.setPremiumChoice(PremiumChoice.premium),
          ),
          const SizedBox(height: 16),
          RecommendedOptionCard(
            title: 'Continuer gratuitement',
            subtitle: 'Accès aux leçons de base, avec quelques limites.',
            leading: Icon(Icons.emoji_people_rounded, color: p.textSecondary, size: 26),
            accent: p.primary,
            selected: c.premiumChoice == PremiumChoice.free,
            onTap: () => c.setPremiumChoice(PremiumChoice.free),
          ),
        ],
      ),
    );
  }
}
