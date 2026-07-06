import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../onboarding/presentation/onboarding_common.dart';

/// Écran post-création **placeholder** : primer visuel de synchronisation des
/// contacts. Aucune permission réelle n'est demandée (le paquet
/// `permission_handler` n'est pas au `pubspec`) — d'où le tag « Bientôt ». Les
/// deux actions mènent à l'écran suivant (ajouter des amis).
class RegisterSyncContactsScreen extends StatelessWidget {
  const RegisterSyncContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return OnboardingScaffold(
      progress: 0.7,
      primaryLabel: 'AUTORISER LES CONTACTS',
      onPrimary: () => context.go('/register/friends'),
      secondary: TextButton(
        key: const Key('register-skip-contacts'),
        onPressed: () => context.go('/register/friends'),
        child: const Text('CONTINUER SANS CONTACTS'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Retrouve tes amis déjà sur Certigo'),
          const SizedBox(height: 12),
          const Align(alignment: Alignment.centerLeft, child: SoonTag()),
          const SizedBox(height: 28),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: p.primary.withOpacity(0.10),
                shape: BoxShape.circle,
                border: Border.all(color: p.primary.withOpacity(0.30), width: 1.5),
              ),
              child: Icon(Icons.contacts_rounded, size: 56, color: p.primary),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'En synchronisant tes contacts, on pourra te suggérer des amis qui '
            'révisent déjà leurs certifications. On ne publie jamais rien en ton nom.',
            style: t.bodyMedium?.copyWith(color: p.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}
