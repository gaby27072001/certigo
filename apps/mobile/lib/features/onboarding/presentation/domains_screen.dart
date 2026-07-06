import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// Step 3 — "Quels domaines Azure t'intéressent ?". Multi-select Azure service
/// domains that personalise the learning path offered to the learner.
class DomainsScreen extends ConsumerWidget {
  const DomainsScreen({super.key});

  static const List<(AzureDomain, String, String)> _options = <(AzureDomain, String, String)>[
    (AzureDomain.compute, '☁️', 'Azure Compute (VMs, AKS, App Service)'),
    (AzureDomain.storage, '🗄️', 'Azure Storage & Databases'),
    (AzureDomain.ai, '🤖', 'Azure AI & Machine Learning'),
    (AzureDomain.security, '🔒', 'Azure Security & Identity'),
    (AzureDomain.networking, '🌐', 'Azure Networking'),
    (AzureDomain.devops, '⚙️', 'Azure DevOps & Pipelines'),
    (AzureDomain.monitoring, '📊', 'Azure Monitoring & Governance'),
    (AzureDomain.serverless, '🚀', 'Azure Serverless & Functions'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);

    return OnboardingScaffold(
      progress: 0.22,
      onBack: () => context.go(OnboardingRoutes.certification),
      primaryLabel: 'CONTINUER',
      onPrimary: c.domains.isEmpty ? null : () => context.go(OnboardingRoutes.building),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Quels domaines Azure t\'intéressent ?'),
          const SizedBox(height: 24),
          for (final (AzureDomain value, String emoji, String label) in _options) ...<Widget>[
            ChoiceTile(
              title: label,
              leading: Text(emoji, style: const TextStyle(fontSize: 22)),
              selected: c.domains.contains(value),
              onTap: () => c.toggleDomain(value),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
