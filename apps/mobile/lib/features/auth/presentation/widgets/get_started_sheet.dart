import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../application/auth_controller.dart';
import '../../application/auth_state.dart';
import 'auth_provider_button.dart';

/// Ouvre la **bottom sheet « Commencer »** façon Luma : propose les modes de
/// connexion (Microsoft en tête, puis Google/Apple si Entra est configuré, et
/// « Continuer avec un e-mail »).
///
/// Modale glass, présentée au-dessus de la racine pour couvrir tout l'écran de
/// landing. Retourne quand la feuille est fermée (par la croix, un tap dehors,
/// ou une navigation e-mail).
Future<void> showGetStartedSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (BuildContext context) => const GetStartedSheet(),
  );
}

/// Contenu de la bottom sheet d'authentification.
///
/// Câble les fournisseurs sociaux sur [authControllerProvider] avec un état de
/// chargement par bouton, exactement comme `SignInScreen`. Le bouton e-mail
/// **ferme la feuille** puis ouvre le flux d'inscription progressive
/// (`/register/name`), qui expose aussi la connexion à un compte existant.
class GetStartedSheet extends ConsumerStatefulWidget {
  const GetStartedSheet({super.key});

  @override
  ConsumerState<GetStartedSheet> createState() => _GetStartedSheetState();
}

class _GetStartedSheetState extends ConsumerState<GetStartedSheet> {
  /// Fournisseur social dont la connexion est en cours (spinner du bouton).
  AuthProvider? _pending;

  void _signInSocial(AuthProvider provider) {
    setState(() => _pending = provider);
    ref.read(authControllerProvider.notifier).signIn(provider);
  }

  void _continueWithEmail() {
    // Ferme la feuille avant de lancer le flux d'inscription progressif (façon
    // Duo) : nom → e-mail → mot de passe → écrans post-création. La connexion à
    // un compte existant reste accessible depuis le 1er écran de ce flux.
    Navigator.of(context).pop();
    context.go('/register/name');
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;

    // Réarme les boutons dès que le flux retombe sur un état non authentifié
    // (annulation, échec) — le message détaillé reste porté par l'écran e-mail.
    ref.listen<AuthState>(authControllerProvider, (AuthState? prev, AuthState next) {
      if (next is Unauthenticated && _pending != null) {
        setState(() => _pending = null);
      }
    });

    final AuthState state = ref.watch(authControllerProvider);
    final bool busy = state is AuthLoading || _pending != null;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          // Fond quasi-opaque (et non plus translucide) pour une lecture nette
          // des boutons, tout en gardant un léger reflet en haut façon glass.
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(PrismRadii.xxl)),
          border: Border.all(color: p.border, width: 1),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(p.brightness == Brightness.dark ? 0.5 : 0.18),
              blurRadius: 32,
              offset: const Offset(0, -8),
              spreadRadius: -4,
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.alphaBlend(
                Colors.white.withOpacity(p.brightness == Brightness.dark ? 0.05 : 0.5),
                p.surface,
              ),
              p.surface,
            ],
            stops: const <double>[0.0, 0.35],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          PrismSpacing.lg,
          PrismSpacing.sm,
          PrismSpacing.lg,
          PrismSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Poignée de préhension.
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: PrismSpacing.md),
                decoration: BoxDecoration(
                  color: p.textSecondary.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(PrismRadii.pill),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                Icon(Icons.auto_awesome_rounded, color: p.primary, size: 22),
                const Spacer(),
                IconButton(
                  key: const Key('get-started-close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Fermer',
                  color: p.textSecondary,
                ),
              ],
            ),
            Text(
              'Commencer',
              style: text.headlineSmall?.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: PrismSpacing.xxs),
            Text(
              'Choisis comment te connecter pour lancer ta progression.',
              style: text.titleMedium?.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: PrismSpacing.lg),
            // Fournisseurs sociaux — toujours proposés depuis l'écran
            // d'ouverture (Microsoft mis en avant, puis Google et Apple).
            _RecommendedTag(color: p.primary),
            const SizedBox(height: PrismSpacing.xs),
            AuthProviderButton(
              provider: AuthProvider.microsoft,
              loading: _pending == AuthProvider.microsoft,
              enabled: !busy,
              onPressed: () => _signInSocial(AuthProvider.microsoft),
            ),
            const SizedBox(height: PrismSpacing.sm),
            AuthProviderButton(
              provider: AuthProvider.google,
              loading: _pending == AuthProvider.google,
              enabled: !busy,
              onPressed: () => _signInSocial(AuthProvider.google),
            ),
            const SizedBox(height: PrismSpacing.sm),
            AuthProviderButton(
              provider: AuthProvider.apple,
              loading: _pending == AuthProvider.apple,
              enabled: !busy,
              onPressed: () => _signInSocial(AuthProvider.apple),
            ),
            const SizedBox(height: PrismSpacing.sm),
            AuthProviderButton(
              key: const Key('get-started-email'),
              provider: AuthProvider.email,
              enabled: !busy,
              onPressed: _continueWithEmail,
            ),
            const SizedBox(height: PrismSpacing.md),
            Text(
              'En continuant, tu acceptes nos conditions d’utilisation et '
              'notre politique de confidentialité.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Petit badge « Recommandé » posé au-dessus du fournisseur principal.
class _RecommendedTag extends StatelessWidget {
  const _RecommendedTag({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.xs, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(PrismRadii.pill),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(
          'Recommandé',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
