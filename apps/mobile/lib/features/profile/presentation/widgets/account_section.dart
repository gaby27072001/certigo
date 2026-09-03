import 'package:data/data.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../../app/capabilities/release_profile_provider.dart';
import '../../../../app/capabilities/release_widgets.dart';
import '../../../../app/router.dart';
import '../../application/settings_preferences.dart';
import 'tappable_row.dart';

class AccountSection extends ConsumerStatefulWidget {
  const AccountSection({super.key, required this.me});

  final UserProfile me;

  @override
  ConsumerState<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<AccountSection> {
  Future<void> _editDisplayName() async {
    final String current = ref.read(displayNameOverrideProvider) ?? widget.me.displayName;
    final TextEditingController ctrl = TextEditingController(text: current);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Modifier le nom d\'affichage'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nom d\'affichage'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      await ref.read(displayNameOverrideProvider.notifier).set(result);
    }
  }

  Future<void> _editHandle() async {
    final String current = ref.read(handleOverrideProvider) ?? widget.me.handle;
    final TextEditingController ctrl = TextEditingController(text: current);
    String? validationError;
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx2, StateSetter setDialogState) => AlertDialog(
          title: const Text('Modifier le pseudo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Pseudo', prefixText: '@'),
                onChanged: (String v) {
                  final bool valid = RegExp(r'^[a-z0-9_]*$').hasMatch(v);
                  setDialogState(() {
                    validationError = valid ? null : 'Minuscules, chiffres et _ uniquement';
                  });
                },
              ),
              if (validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: PrismSpacing.debt6),
                  child: Text(
                    validationError!,
                    style: TextStyle(color: Theme.of(ctx2).colorScheme.error, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx2).pop(), child: const Text('Annuler')),
            TextButton(
              onPressed: validationError == null ? () => Navigator.of(ctx2).pop(ctrl.text) : null,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      await ref.read(handleOverrideProvider.notifier).set(result);
    }
  }

  Future<void> _deleteAccount() async {
    await context.push(Routes.accountDeletion, extra: widget.me.id);
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final String? nameOverride = ref.watch(displayNameOverrideProvider);
    final String? handleOverride = ref.watch(handleOverrideProvider);
    final String displayName = nameOverride ?? widget.me.displayName;
    final String handle = handleOverride ?? widget.me.handle;
    final CapabilityAvailability accountDeletion = ref.watch(
      capabilityAvailabilityProvider(AppCapability.accountDeletion),
    );

    return PrismCard(
      child: Column(
        children: <Widget>[
          TappableRow(
            icon: Icons.person_rounded,
            label: 'Modifier le nom d\'affichage',
            trailing: displayName,
            onTap: _editDisplayName,
          ),
          Divider(color: p.border, height: 24),
          TappableRow(
            icon: Icons.alternate_email_rounded,
            label: 'Modifier le pseudo',
            trailing: handle.isEmpty ? null : '@$handle',
            onTap: _editHandle,
          ),
          if (!accountDeletion.isOff) ...<Widget>[
            Divider(color: p.border, height: 24),
            if (accountDeletion.isEnabled)
              TappableRow(
                icon: Icons.delete_outline_rounded,
                label: 'Supprimer le compte',
                trailingColor: p.error,
                onTap: _deleteAccount,
              )
            else
              CapabilityAction(
                capability: AppCapability.accountDeletion,
                semanticLabel: 'Supprimer le compte',
                onPressed: _deleteAccount,
                builder: (BuildContext context, CapabilityAvailability availability) => Row(
                  children: <Widget>[
                    Icon(Icons.delete_outline_rounded, color: p.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Supprimer le compte', style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 4),
                          CapabilityStatusBadge(availability: availability),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
