import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../application/account_deletion_controller.dart';

class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key, this.expectedUserId});

  final String? expectedUserId;

  @override
  ConsumerState<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  final TextEditingController _password = TextEditingController();
  bool _understood = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AccountDeletionState state = ref.watch(accountDeletionControllerProvider);
    final AuthState auth = ref.watch(authControllerProvider);
    final bool emailAccount = auth is Authenticated && auth.session.provider == AuthProvider.email;
    final bool locked = state.requestRecorded || state.busy;

    return PopScope(
      canPop: !locked,
      child: Scaffold(
        appBar: AppBar(title: const Text('Supprimer mon compte')),
        body: SafeArea(
          child: ListView(
            padding: PrismSpacing.scrollBody(),
            children: <Widget>[
              Text(
                'Cette suppression est définitive',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: PrismSpacing.sm),
              const Text(
                'Certigo supprimera votre profil, progression, tentatives, '
                'récompenses, relations sociales et identifiants de connexion. '
                'Vous perdrez immédiatement l’accès au compte.',
              ),
              const SizedBox(height: PrismSpacing.sm),
              const Text(
                'Les sauvegardes techniques Azure suivent leur cycle de rétention '
                'et ne sont pas utilisées pour restaurer un compte supprimé.',
              ),
              const SizedBox(height: PrismSpacing.lg),
              if (state.stage == AccountDeletionStage.loading)
                const Center(child: CircularProgressIndicator())
              else if (state.requestRecorded)
                _PendingDeletion(
                  state: state,
                  onRetry: ref.read(accountDeletionControllerProvider.notifier).retry,
                )
              else ...<Widget>[
                if (emailAccount)
                  TextField(
                    key: const Key('account-deletion-password'),
                    controller: _password,
                    obscureText: true,
                    enabled: !state.busy,
                    autofillHints: const <String>[AutofillHints.password],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe actuel',
                      helperText: 'Requis pour vérifier votre identité.',
                    ),
                  ),
                CheckboxListTile(
                  key: const Key('account-deletion-understood'),
                  contentPadding: EdgeInsets.zero,
                  value: _understood,
                  onChanged: state.busy
                      ? null
                      : (bool? value) => setState(() => _understood = value ?? false),
                  title: const Text(
                    'Je comprends que mon compte et les données associées '
                    'seront supprimés définitivement.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: PrismSpacing.sm),
                FilledButton.icon(
                  key: const Key('account-deletion-confirm'),
                  onPressed: !_understood ||
                          state.busy ||
                          widget.expectedUserId == null ||
                          (emailAccount && _password.text.isEmpty)
                      ? null
                      : () => ref.read(accountDeletionControllerProvider.notifier).start(
                            expectedUserId: widget.expectedUserId!,
                            password: emailAccount ? _password.text : null,
                          ),
                  icon: state.busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever_rounded),
                  label: Text(
                    state.stage == AccountDeletionStage.verifying
                        ? 'Vérification…'
                        : state.stage == AccountDeletionStage.deleting
                            ? 'Suppression…'
                            : 'Supprimer définitivement',
                  ),
                ),
              ],
              if (state.message != null) ...<Widget>[
                const SizedBox(height: PrismSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    state.message!,
                    key: const Key('account-deletion-status'),
                    style: TextStyle(
                      color: state.stage == AccountDeletionStage.failure
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ),
              ],
              if (state.stage == AccountDeletionStage.failure) ...<Widget>[
                const SizedBox(height: PrismSpacing.sm),
                OutlinedButton(
                  onPressed: state.requestRecorded
                      ? ref.read(accountDeletionControllerProvider.notifier).retry
                      : ref.read(accountDeletionControllerProvider.notifier).load,
                  child: Text(state.requestRecorded ? 'Reprendre la suppression' : 'Réessayer'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingDeletion extends StatelessWidget {
  const _PendingDeletion({required this.state, required this.onRetry});

  final AccountDeletionState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AccountDeletion deletion = state.deletion!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          key: const Key('account-deletion-progress-semantics'),
          label: '${deletion.completedSteps} étapes sur ${deletion.totalSteps} terminées',
          value: '${(deletion.progress * 100).round()} %',
          child: LinearProgressIndicator(
            key: const Key('account-deletion-progress'),
            value: deletion.progress,
          ),
        ),
        const SizedBox(height: PrismSpacing.md),
        const Text(
          'Votre demande est enregistrée. Les appels hors suppression sont '
          'bloqués et une relance reprend uniquement les étapes restantes.',
        ),
        const SizedBox(height: PrismSpacing.md),
        if (state.stage != AccountDeletionStage.failure)
          FilledButton(
            onPressed: state.busy ? null : onRetry,
            child: const Text('Reprendre maintenant'),
          ),
      ],
    );
  }
}

class AccountDeletionCompletedScreen extends ConsumerWidget {
  const AccountDeletionCompletedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(PrismSpacing.lg),
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.check_circle_rounded, size: 72),
                    const SizedBox(height: PrismSpacing.md),
                    Text('Compte supprimé', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: PrismSpacing.sm),
                    const Text(
                      'Votre compte Certigo et ses données actives ont été supprimés. '
                      'La session et les données locales de cet appareil ont été effacées.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: PrismSpacing.lg),
                    FilledButton(
                      key: const Key('account-deletion-finish'),
                      onPressed: ref.read(authControllerProvider.notifier).finishAccountDeletion,
                      child: const Text('Terminer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
