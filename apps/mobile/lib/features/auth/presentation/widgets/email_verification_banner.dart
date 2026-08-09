import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../application/auth_controller.dart';
import '../../application/auth_state.dart';

/// Bandeau discret et **non bloquant** invitant l'utilisateur à confirmer son
/// adresse e-mail. Ne s'affiche que pour une session e-mail/mot de passe non
/// vérifiée ; renvoie un espace nul dans tous les autres cas (session sociale,
/// compte déjà vérifié ou historique), donc sans impact sur la mise en page.
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  ConsumerState<EmailVerificationBanner> createState() => _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends ConsumerState<EmailVerificationBanner> {
  bool _busy = false;
  String? _feedback;

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _feedback = null;
    });
    final bool ok = await ref.read(authControllerProvider.notifier).resendVerificationEmail();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = ok
          ? 'E-mail envoyé. Vérifie ta boîte de réception.'
          : 'Envoi impossible pour le moment. Réessaie dans un instant.';
    });
  }

  Future<void> _refreshStatus() async {
    setState(() => _busy = true);
    await ref.read(authControllerProvider.notifier).reloadVerificationStatus();
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final AuthState state = ref.watch(authControllerProvider);
    final bool show =
        state is Authenticated &&
        state.session.provider == AuthProvider.email &&
        !state.session.emailVerified;
    if (!show) return const SizedBox.shrink();

    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: Container(
        key: const Key('email-verify-banner'),
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(PrismSpacing.md, PrismSpacing.sm, PrismSpacing.md, 0),
        padding: const EdgeInsets.all(PrismSpacing.md),
        decoration: BoxDecoration(
          color: p.primarySoft,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: p.primary.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.mark_email_unread_outlined, color: p.primary, size: 20),
                const SizedBox(width: PrismSpacing.xs),
                Expanded(
                  child: Text(
                    'Confirme ton adresse e-mail',
                    style: text.titleSmall?.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Nous t’avons envoyé un lien de confirmation. Ton compte fonctionne '
              'déjà — c’est juste pour le sécuriser.',
              style: text.bodySmall?.copyWith(color: p.textSecondary, height: 1.3),
            ),
            if (_feedback != null) ...<Widget>[
              const SizedBox(height: PrismSpacing.xs),
              Text(
                _feedback!,
                key: const Key('email-verify-feedback'),
                style: text.bodySmall?.copyWith(color: p.primary),
              ),
            ],
            const SizedBox(height: PrismSpacing.xs),
            Row(
              children: <Widget>[
                TextButton(
                  key: const Key('email-verify-resend'),
                  onPressed: _busy ? null : _resend,
                  child: const Text('Renvoyer l’e-mail'),
                ),
                TextButton(
                  key: const Key('email-verify-refresh'),
                  onPressed: _busy ? null : _refreshStatus,
                  child: const Text('J’ai confirmé'),
                ),
                if (_busy) ...<Widget>[
                  const SizedBox(width: PrismSpacing.xs),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
