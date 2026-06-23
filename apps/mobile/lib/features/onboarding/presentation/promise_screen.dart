import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// Step 5 — the payoff. Celebrates the plan just built and projects a concrete,
/// motivating outcome ("≈ N notions cette semaine") before entering the app.
class PromiseScreen extends ConsumerWidget {
  const PromiseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingController c = ref.watch(onboardingControllerProvider);
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return OnboardingScaffold(
      progress: 1,
      onBack: () => context.go(OnboardingRoutes.routine),
      primaryLabel: 'JE COMMENCE',
      onPrimary: () {
        c.complete();
        context.go('/path');
      },
      scrollable: false,
      child: Column(
        children: <Widget>[
          const Spacer(flex: 2),
          const MascotHero(
            mascot: AuroraMascot.nimbus,
            mood: MascotMood.celebrate,
            size: 150,
          ),
          const SizedBox(height: 20),
          SpeechBubble(
            tail: SpeechTail.up,
            maxWidth: 320,
            child: Text(
              'C\'est prêt ! Voici ta routine sur mesure.',
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 28),
          _PromiseStat(
              value: '≈ ${c.weeklyNotions}', label: 'notions cette semaine', accent: p.primary),
          const SizedBox(height: 16),
          Text(
            'À raison de ${(c.goal ?? DailyGoalOption.regular).minutes} min par jour. '
            'Tu peux ajuster ton objectif à tout moment.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: p.textSecondary, height: 1.4),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _PromiseStat extends StatelessWidget {
  const _PromiseStat({required this.value, required this.label, required this.accent});

  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: PrismRadii.cardXxl,
        border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: t.displayMedium?.copyWith(color: accent, fontWeight: FontWeight.w800),
          ),
          Text(label, style: t.labelLarge?.copyWith(color: accent)),
        ],
      ),
    );
  }
}
