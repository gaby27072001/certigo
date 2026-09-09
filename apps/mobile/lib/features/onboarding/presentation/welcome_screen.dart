import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'onboarding_common.dart';

/// Welcome shown after real authentication and before track selection.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            children: <Widget>[
              const Spacer(flex: 2),
              const MascotHero(mascot: AuroraMascot.nimbus, mood: MascotMood.celebrate, size: 168),
              const SizedBox(height: 28),
              Text(
                'Choisis ton objectif,\npuis commence',
                textAlign: TextAlign.center,
                style: t.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  fontSize: 30,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ton compte est prêt. Sélectionne une certification disponible '
                'pour ouvrir le parcours correspondant.',
                textAlign: TextAlign.center,
                style: t.bodyLarge?.copyWith(color: p.textSecondary, height: 1.4),
              ),
              const Spacer(flex: 3),
              PrismButton(
                label: 'CHOISIR MA CERTIFICATION',
                onPressed: () => context.push(OnboardingRoutes.certification),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
