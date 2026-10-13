import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../application/auth_controller.dart';
import '../../application/auth_state.dart';
import 'auth_provider_button.dart';

/// Pourquoi l'utilisateur ouvre la feuille : créer un compte, ou en retrouver un.
///
/// L'écran d'accueil propose deux entrées (« Commencer » et « J'ai déjà un
/// compte ») qui menaient à une feuille **strictement identique** : le bouton
/// e-mail envoyait alors un utilisateur possédant déjà un compte sur le premier
/// écran d'inscription, barre de progression à 25 % comprise. Cette intention
/// est ce qui distingue enfin les deux entrées.
enum GetStartedIntent {
  /// « Commencer » : création de compte (flux progressif nom → e-mail → mdp).
  signUp,

  /// « J'ai déjà un compte » : retrouver un compte existant.
  signIn,
}

/// Ouvre la **bottom sheet d'authentification** façon Luma : propose les modes
/// de connexion (Microsoft en tête, puis Google et Apple, et « Continuer avec
/// un e-mail »).
///
/// Les quatre boutons sont proposés **quelle que soit** l'intention : quelqu'un
/// qui revient a pu créer son compte avec n'importe lequel d'entre eux. C'est la
/// raison pour laquelle [GetStartedIntent.signIn] n'est **pas** routé
/// directement vers `/auth?emailOnly=1` — cet écran masque les fournisseurs
/// sociaux (`sign_in_screen.dart`, `socialEnabled`), ce qui laisserait un compte
/// Microsoft/Google/Apple devant un formulaire de mot de passe qu'il ne possède
/// pas.
///
/// Modale glass, présentée au-dessus de la racine pour couvrir tout l'écran de
/// landing. Retourne quand la feuille est fermée (par la croix, un tap dehors,
/// ou une navigation e-mail).
Future<void> showGetStartedSheet(
  BuildContext context, {
  GetStartedIntent intent = GetStartedIntent.signUp,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (BuildContext context) => GetStartedSheet(intent: intent),
  );
}

/// Contenu de la bottom sheet d'authentification.
///
/// Câble les fournisseurs sociaux sur [authControllerProvider] avec un état de
/// chargement par bouton, exactement comme `SignInScreen`. Le bouton e-mail
/// **ferme la feuille** puis route selon [intent] : vers le flux d'inscription
/// progressif (`/register/name`) pour [GetStartedIntent.signUp], vers le
/// formulaire de connexion (`/auth?emailOnly=1`) pour [GetStartedIntent.signIn]
/// — cet écran masque ses propres boutons sociaux, déjà proposés ici.
class GetStartedSheet extends ConsumerStatefulWidget {
  const GetStartedSheet({super.key, this.intent = GetStartedIntent.signUp});

  /// Pourquoi la feuille a été ouverte. Pilote le titre, le sous-titre, la
  /// présence du badge « Recommandé » et la destination du bouton e-mail.
  final GetStartedIntent intent;

  @override
  ConsumerState<GetStartedSheet> createState() => _GetStartedSheetState();
}

class _GetStartedSheetState extends ConsumerState<GetStartedSheet> {
  /// Fournisseur social dont la connexion est en cours (spinner du bouton).
  AuthProvider? _pending;

  /// Échec de la dernière tentative lancée depuis CETTE feuille. Un échec
  /// s'affiche sur la surface qui a lancé la tentative, jusqu'à la suivante :
  /// la feuille reste montée pendant et après la tentative, donc c'est ici que
  /// l'apprenant doit le lire, pas derrière la feuille sur l'accueil.
  String? _error;

  bool get _isSignIn => widget.intent == GetStartedIntent.signIn;

  void _signInSocial(AuthProvider provider) {
    setState(() {
      _pending = provider;
      _error = null;
    });
    ref.read(authControllerProvider.notifier).signIn(provider);
  }

  void _continueWithEmail() {
    Navigator.of(context).pop();
    if (_isSignIn) {
      // Compte existant : droit au formulaire de connexion. `emailOnly=1` y
      // masque les fournisseurs sociaux, que cette feuille vient de proposer.
      context.go('/auth?emailOnly=1');
      return;
    }
    // Création : flux d'inscription progressif (façon Duo) nom → e-mail → mot
    // de passe → écrans post-création.
    context.go('/register/name');
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;

    // Réarme les boutons dès que le flux retombe sur un état non authentifié
    // (annulation, échec), et garde le message seulement s'il conclut une
    // tentative lancée depuis cette feuille.
    ref.listen<AuthState>(authControllerProvider, (AuthState? prev, AuthState next) {
      if (next is Unauthenticated && _pending != null) {
        final String? message = next.message;
        setState(() {
          _pending = null;
          _error = message == null || message.isEmpty ? null : message;
        });
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
              _isSignIn ? 'Content de te revoir' : 'Commencer',
              style: text.headlineSmall?.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: PrismSpacing.xxs),
            Text(
              _isSignIn
                  // Guide vers le bon bouton : choisir un autre fournisseur
                  // qu'à l'inscription ouvrirait un second compte, pas le sien.
                  ? 'Choisis le mode que tu as utilisé à l’inscription.'
                  : 'Choisis comment te connecter pour lancer ta progression.',
              style: text.titleMedium?.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: PrismSpacing.lg),
            if (_error != null) ...<Widget>[
              _SheetErrorCard(message: _error!),
              const SizedBox(height: PrismSpacing.md),
            ],
            // Fournisseurs sociaux — toujours proposés, quelle que soit
            // l'intention (Microsoft mis en avant, puis Google et Apple) : un
            // compte existant a pu être créé avec n'importe lequel.
            if (!_isSignIn) ...<Widget>[
              // « Recommandé » n'a de sens qu'à la création : quelqu'un qui
              // revient a déjà un fournisseur, lui en suggérer un induirait
              // en erreur.
              _RecommendedTag(color: p.primary),
              const SizedBox(height: PrismSpacing.xs),
            ],
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

/// Échec de la dernière tentative de la feuille, au style de la carte d'erreur
/// de l'écran e-mail. Annoncé par VoiceOver/TalkBack dès son apparition.
class _SheetErrorCard extends StatelessWidget {
  const _SheetErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('get-started-error'),
        width: double.infinity,
        padding: const EdgeInsets.all(PrismSpacing.md),
        decoration: BoxDecoration(
          color: p.error.withOpacity(0.12),
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: p.error.withOpacity(0.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.error_outline, color: p.error, size: 20),
            const SizedBox(width: PrismSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: text.bodyMedium?.copyWith(color: p.textPrimary, height: 1.35),
              ),
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
