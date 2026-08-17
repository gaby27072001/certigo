import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../app/providers.dart';
import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// The heart of the adaptation — the Certigo equivalent of the reference flow's
/// "which language?" question: pick the certification you're aiming for. Each
/// option is a shared [CertificationCard] (the same design-system component the
/// library catalogue and course picker use), tinted with its exam-domain accent.
class CertificationScreen extends ConsumerWidget {
  const CertificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);
    final catalog = ref.watch(catalogProvider).asData?.value;

    bool hasPublishedLearningContent(TargetCertification cert) {
      if (cert != TargetCertification.ai901) return true;
      return catalog?.any((track) => track.code == cert.code && track.learningAvailable) ?? false;
    }

    final TargetCertification? target = c.targetCertification;

    return OnboardingScaffold(
      progress: 0.16,
      onBack: () => context.go(OnboardingRoutes.birthYear),
      primaryLabel: 'CONTINUER',
      onPrimary: target != null && hasPublishedLearningContent(target)
          ? () => context.go(OnboardingRoutes.domains)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Quelle certification veux-tu décrocher ?'),
          const SizedBox(height: 24),
          for (final TargetCertification cert in availableTargetCertifications) ...<Widget>[
            CertificationCard(
              code: cert.code,
              title: cert.title,
              accent: context.prism.accentFor(cert.domainIndex),
              levelLabel: hasPublishedLearningContent(cert) ? '' : 'Bientôt',
              selected: target == cert,
              onTap:
                  hasPublishedLearningContent(cert) ? () => c.setTargetCertification(cert) : null,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
