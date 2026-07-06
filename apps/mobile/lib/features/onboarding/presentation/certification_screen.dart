import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

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

    return OnboardingScaffold(
      progress: 0.16,
      onBack: () => context.go(OnboardingRoutes.birthYear),
      primaryLabel: 'CONTINUER',
      onPrimary: c.targetCertification == null ? null : () => context.go(OnboardingRoutes.domains),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Quelle certification veux-tu décrocher ?'),
          const SizedBox(height: 24),
          for (final TargetCertification cert in TargetCertification.values) ...<Widget>[
            CertificationCard(
              code: cert.code,
              title: cert.title,
              accent: context.prism.accentFor(cert.domainIndex),
              selected: c.targetCertification == cert,
              onTap: () => c.setTargetCertification(cert),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
