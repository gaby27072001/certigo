import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../application/settings_preferences.dart';
import 'profile_sheets.dart';
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
    final String? result = await showProfileTextSheet(
      context: context,
      title: 'Modifier le nom d\'affichage',
      hint: 'Nom d\'affichage',
      initial: current,
    );
    if (result != null && mounted) {
      await ref.read(displayNameOverrideProvider.notifier).set(result);
    }
  }

  Future<void> _editHandle() async {
    final String current = ref.read(handleOverrideProvider) ?? widget.me.handle;
    final String? result = await showProfileTextSheet(
      context: context,
      title: 'Modifier le pseudo',
      hint: 'Pseudo',
      initial: current,
      validate: (String v) =>
          RegExp(r'^[a-z0-9_]*$').hasMatch(v) ? null : ProfileSheetLabels.handleRule,
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
          if (ref.watch(accountDeletionEnabledProvider)) ...<Widget>[
            Divider(color: p.border, height: 24),
            TappableRow(
              icon: Icons.delete_outline_rounded,
              label: 'Supprimer le compte',
              trailingColor: p.error,
              onTap: _deleteAccount,
            ),
          ],
        ],
      ),
    );
  }
}
