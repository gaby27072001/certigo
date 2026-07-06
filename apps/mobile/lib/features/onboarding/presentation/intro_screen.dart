import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

/// A full-screen greeting from the guide — a large Nimbus with a typewriter
/// speech bubble and a sticky CTA. Reused for the opening "Salut, moi c'est
/// Nimbus !" beat and the "On installe ta routine" interstitial.
class NimbusIntroScreen extends StatelessWidget {
  const NimbusIntroScreen({
    super.key,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.onBack,
    this.progress,
    this.mood = MascotMood.celebrate,
  });

  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback? onBack;
  final double? progress;
  final MascotMood mood;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;

    return OnboardingScaffold(
      progress: progress,
      onBack: onBack,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      scrollable: false,
      child: Column(
        children: <Widget>[
          const Spacer(flex: 2),
          MascotHero(mascot: AuroraMascot.nimbus, mood: mood, size: 160),
          const SizedBox(height: 24),
          SpeechBubble(
            tail: SpeechTail.up,
            maxWidth: 320,
            child: TypewriterText(
              message,
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
