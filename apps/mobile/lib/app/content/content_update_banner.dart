import 'dart:async';

import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import 'runtime_content_providers.dart';

class ContentUpdateBanner extends ConsumerWidget {
  const ContentUpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(runtimeContentSyncEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final RuntimeContentStatus status = ref.watch(runtimeContentControllerProvider);
    if (status.phase == RuntimeContentPhase.idle || status.phase == RuntimeContentPhase.ready) {
      return const SizedBox.shrink();
    }

    final (String message, IconData icon, bool retry) = switch (status.phase) {
      RuntimeContentPhase.checking => (
          'Vérification du contenu disponible…',
          Icons.sync_rounded,
          false,
        ),
      RuntimeContentPhase.downloading => (
          'Mise à jour du contenu ${status.completedFiles}/${status.totalFiles}',
          Icons.download_rounded,
          false,
        ),
      RuntimeContentPhase.activating => (
          'Activation de la mise à jour…',
          Icons.verified_rounded,
          false,
        ),
      RuntimeContentPhase.rolledBack => (
          status.message ?? 'La dernière version valide a été restaurée.',
          Icons.restore_rounded,
          true,
        ),
      RuntimeContentPhase.failed => (
          status.message ?? 'Mise à jour indisponible. Le contenu actuel est conservé.',
          Icons.cloud_off_rounded,
          true,
        ),
      _ => ('', Icons.info_outline_rounded, false),
    };
    final double? progress = status.progress;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: Material(
        color: colors.surfaceContainerHighest,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              dense: true,
              leading: Icon(icon, color: colors.primary),
              title: Text(message),
              subtitle: retry
                  ? Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        children: <Widget>[
                          if (status.canRollback)
                            TextButton(
                              onPressed: () => _rollback(ref),
                              child: const Text('Version précédente'),
                            ),
                          TextButton(onPressed: () => _retry(ref), child: const Text('Réessayer')),
                        ],
                      ),
                    )
                  : null,
            ),
            if (progress != null)
              LinearProgressIndicator(
                value: progress,
                semanticsLabel: 'Progression de la mise à jour du contenu',
                semanticsValue: '${(progress * 100).round()} %',
              ),
          ],
        ),
      ),
    );
  }

  void _retry(WidgetRef ref) {
    final AuthState auth = ref.read(authControllerProvider);
    if (auth is! Authenticated) return;
    final String? ownerId = auth.session.userId;
    if (ownerId == null || ownerId.isEmpty) return;
    unawaited(
      _handleExpectedFailure(ref.read(runtimeContentControllerProvider.notifier).syncNow(ownerId)),
    );
  }

  void _rollback(WidgetRef ref) {
    final AuthState auth = ref.read(authControllerProvider);
    if (auth is! Authenticated) return;
    final String? ownerId = auth.session.userId;
    if (ownerId == null || ownerId.isEmpty) return;
    unawaited(
      _handleExpectedFailure(ref.read(runtimeContentControllerProvider.notifier).rollback(ownerId)),
    );
  }

  Future<void> _handleExpectedFailure(Future<void> operation) async {
    try {
      await operation;
    } on RuntimeContentSyncException {
      // The synchronizer has already exposed the actionable failure in the banner.
    }
  }
}
