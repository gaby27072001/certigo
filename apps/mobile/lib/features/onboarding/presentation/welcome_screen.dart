import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import 'onboarding_common.dart';

/// Welcome — the first interactive screen. A large guide, a confident tagline
/// and the two opening actions: start fresh, or sign in to an existing account.
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
              const MascotHero(
                mascot: AuroraMascot.nimbus,
                mood: MascotMood.celebrate,
                size: 168,
              ),
              const SizedBox(height: 28),
              Text(
                'Apprends Azure\nsans y penser',
                textAlign: TextAlign.center,
                style: t.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  fontSize: 30,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Des leçons courtes, ludiques et gratuites pour décrocher tes certifications Microsoft.',
                textAlign: TextAlign.center,
                style: t.bodyLarge?.copyWith(color: p.textSecondary, height: 1.4),
              ),
              const Spacer(flex: 3),
              PrismButton(
                label: 'C\'EST PARTI',
                onPressed: () => context.go(OnboardingRoutes.intro),
              ),
              const SizedBox(height: 12),
              PrismButton.secondary(
                label: 'J\'AI DÉJÀ UN COMPTE',
                onPressed: () => context.go(OnboardingRoutes.login),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
