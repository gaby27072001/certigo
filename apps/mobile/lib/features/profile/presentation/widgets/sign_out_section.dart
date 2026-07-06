import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';

/// "Se déconnecter" — shown only when real authentication is wired (Entra
/// configured, or the auth UI is force-enabled for a build). In dev/passthrough
/// builds there is no real session to end, so the row stays hidden.
class SignOutSection extends ConsumerWidget {
  const SignOutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!(AppEnv.entraConfigured || AppEnv.forceAuthUi)) {
      return const SizedBox.shrink();
    }
    final PrismColorScheme p = context.prism;
    final AuthState state = ref.watch(authControllerProvider);
    final bool busy = state is AuthLoading;
    return Padding(
      padding: const EdgeInsets.only(top: PrismSpacing.lg),
      child: PrismCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PrismButton(
              label: 'Se déconnecter',
              variant: PrismButtonVariant.secondary,
              tone: p.error,
              icon: Icons.logout_rounded,
              loading: busy,
              onPressed: busy ? null : () => ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
