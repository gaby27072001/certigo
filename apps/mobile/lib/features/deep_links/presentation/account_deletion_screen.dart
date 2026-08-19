import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

/// Public instructions required for the account-deletion HTTPS route.
///
/// No authenticated provider is read here so the page remains available while
/// signed out or while session restoration is in progress.
class AccountDeletionScreen extends StatelessWidget {
  const AccountDeletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: SafeArea(
        child: PrismContentFrame(
          child: ListView(
            padding: PrismSpacing.scrollBody(),
            children: <Widget>[
              Text('Supprimer votre compte', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: PrismSpacing.md),
              const PrismCard(
                child: Text(
                  'Dans l’application, connectez-vous puis ouvrez Profil > Supprimer le compte. '
                  'Si vous ne pouvez plus accéder à votre compte, écrivez à '
                  'gabriel.chambaud@icloud.com depuis l’adresse associée au compte.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
