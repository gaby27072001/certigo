import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// The heart of the adaptation — the Certigo equivalent of the reference flow's
/// "which language?" question: pick the certification you're aiming for. Each
/// option is a [ChoiceTile] tagged with its exam-domain accent chip.
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
            ChoiceTile(
              title: cert.code,
              trailingLabel: cert.title,
              showCheckbox: false,
              leading: _CertChip(cert: cert),
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

/// A rounded, accent-tinted chip showing the exam family initials — the
/// per-domain color cue that tags each certification.
class _CertChip extends StatelessWidget {
  const _CertChip({required this.cert});

  final TargetCertification cert;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.prism.accentFor(cert.domainIndex);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.15),
        borderRadius: PrismRadii.cardSm,
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      alignment: Alignment.center,
      child: Text(
        cert.code.split('-').first,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent),
      ),
    );
  }
}
