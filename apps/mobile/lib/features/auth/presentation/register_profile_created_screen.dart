import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/register_draft.dart';

/// Dernier écran du flux d'inscription progressif : « Bienvenue {prénom} ! Ton
/// profil a été créé ». Célébration Nimbus + bulle qui s'écrit (typewriter).
///
/// Le « CONTINUER » remet le brouillon à zéro et vise l'accueil : le garde
/// d'auth prend alors le relais et route vers l'onboarding (Partie 2) si celui-ci
/// n'est pas terminé, sinon vers `/home`.
class RegisterProfileCreatedScreen extends ConsumerWidget {
  const RegisterProfileCreatedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme t = Theme.of(context).textTheme;
    final String firstName = ref.watch(registerDraftProvider).firstName;
    final String message = firstName.isEmpty
        ? 'Bienvenue ! Ton profil a été créé.'
        : 'Bienvenue $firstName ! Ton profil a été créé.';

    void onContinue() {
      ref.read(registerDraftProvider.notifier).reset();
      context.go('/home');
    }

    return OnboardingScaffold(
      primaryLabel: 'CONTINUER',
      onPrimary: onContinue,
      scrollable: false,
      child: Column(
        children: <Widget>[
          const Spacer(flex: 2),
          const MascotHero(mascot: AuroraMascot.nimbus, mood: MascotMood.celebrate, size: 150),
          const SizedBox(height: 22),
          SpeechBubble(
            tail: SpeechTail.up,
            maxWidth: 320,
            child: TypewriterText(
              message,
              key: ValueKey<String>(message),
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
