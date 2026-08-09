import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// "Comment nous as-tu connus ?" — single-select attribution. Collected for the
/// picture but not yet wired to any analytics, so it carries a discreet
/// "bientôt" tag; the answer is stored on the controller for later.
class AttributionScreen extends ConsumerWidget {
  const AttributionScreen({super.key});

  static const List<(AttributionSource, String, String)> _options =
      <(AttributionSource, String, String)>[
        (AttributionSource.search, '🔎', 'Recherche Google / Bing'),
        (AttributionSource.friendsFamily, '👋', 'Proches ou collègues'),
        (AttributionSource.youtube, '▶️', 'YouTube'),
        (AttributionSource.tiktok, '🎵', 'TikTok'),
        (AttributionSource.social, '💬', 'Réseaux sociaux'),
        (AttributionSource.appStore, '🛍️', 'App Store / Play Store'),
        (AttributionSource.newsBlog, '📰', 'Presse ou blog'),
        (AttributionSource.other, '✨', 'Autre'),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);

    return OnboardingScaffold(
      progress: 0.30,
      onBack: () => context.go(OnboardingRoutes.domains),
      primaryLabel: 'CONTINUER',
      onPrimary: c.attributionSource == null ? null : () => context.go(OnboardingRoutes.level),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Comment nous as-tu connus ?'),
          const SizedBox(height: 8),
          const SoonTag(),
          const SizedBox(height: 16),
          for (final (AttributionSource value, String emoji, String label) in _options) ...<Widget>[
            ChoiceTile(
              title: label,
              showCheckbox: false,
              leading: Text(emoji, style: const TextStyle(fontSize: 22)),
              selected: c.attributionSource == value,
              onTap: () => c.setAttributionSource(value),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
