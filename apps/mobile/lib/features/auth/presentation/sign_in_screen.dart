import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/auth_controller.dart';
import '../application/auth_diagnostics.dart';
import '../application/auth_state.dart';
import 'widgets/auth_provider_button.dart';

/// Mode du formulaire e-mail : se connecter à un compte existant, ou en créer un.
enum _AuthMode { signIn, register }

/// Premier écran à l'ouverture de l'app (tant qu'aucun compte n'est mémorisé).
///
/// Propose **toujours** la connexion par e-mail + mot de passe (gérée par notre
/// backend) avec un basculement « Se connecter » / « Créer un compte ». Quand
/// Microsoft Entra External ID est configuré, les trois boutons sociaux
/// (Microsoft, Google, Apple) s'affichent en complément.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.emailOnly = false});

  /// Quand `true`, masque les boutons sociaux (Microsoft/Google/Apple) et ne
  /// laisse que le formulaire e-mail. Utilisé quand l'écran est atteint depuis
  /// la bottom sheet « Commencer » (qui propose déjà les sociaux), pour éviter
  /// le doublon. N'affecte pas la logique d'authentification.
  final bool emailOnly;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _obscure = true;

  /// Fournisseur social dont la connexion est en cours (spinner du bouton).
  AuthProvider? _pending;

  /// Soumission e-mail en cours (spinner du bouton principal).
  bool _emailSubmitting = false;

  /// Dernier message d'échec d'authentification, affiché de façon **persistante**
  /// (jusqu'à la prochaine tentative) pour être lu et capturé — indispensable au
  /// diagnostic quand l'erreur OIDC réelle doit être remontée depuis l'appareil.
  String? _authError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _signInSocial(AuthProvider provider) {
    setState(() {
      _pending = provider;
      _authError = null;
    });
    ref.read(authControllerProvider.notifier).signIn(provider);
  }

  void _submitEmail() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    FocusScope.of(context).unfocus();
    // Hygiène d'affichage : une soumission e-mail efface la trace de diagnostic
    // d'une éventuelle tentative sociale précédente (le contrôleur e-mail, lui,
    // n'y touche pas — le diagnostic ne concerne que le flux social).
    ref.read(authDiagnosticsProvider.notifier).reset();
    setState(() {
      _emailSubmitting = true;
      _authError = null;
    });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    final AuthController notifier = ref.read(authControllerProvider.notifier);
    if (_mode == _AuthMode.register) {
      final String name = _nameController.text.trim();
      notifier.registerWithEmail(
        email: email,
        password: password,
        displayName: name.isEmpty ? null : name,
      );
    } else {
      notifier.signInWithEmail(email: email, password: password);
    }
  }

  void _toggleMode() {
    setState(() => _mode = _mode == _AuthMode.signIn ? _AuthMode.register : _AuthMode.signIn);
  }

  String? _validateEmail(String? value) {
    final String email = (value ?? '').trim();
    final int at = email.indexOf('@');
    final bool valid = at > 0 &&
        at == email.lastIndexOf('@') &&
        email.indexOf('.', at) > at &&
        !email.endsWith('.');
    return valid ? null : 'Adresse e-mail invalide.';
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 8) {
      return 'Au moins 8 caractères.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final bool socialEnabled = ref.watch(authConfiguredProvider) && !widget.emailOnly;

    // Réarme les boutons et **conserve** l'erreur à l'écran quand le flux
    // retombe sur un état non authentifié. Un SnackBar disparaîtrait trop vite
    // pour être lu/capturé : on affiche une carte persistante (voir _ErrorCard).
    ref.listen<AuthState>(authControllerProvider, (AuthState? prev, AuthState next) {
      if (next is! Unauthenticated) return;
      final String? message = next.message;
      setState(() {
        _pending = null;
        _emailSubmitting = false;
        if (message != null && message.isNotEmpty) {
          _authError = message;
        }
      });
    });

    final AuthState state = ref.watch(authControllerProvider);
    final bool busy = state is AuthLoading || _pending != null || _emailSubmitting;
    final bool retryingSignIn = state is AuthLoading && state.retrying;
    final bool registering = _mode == _AuthMode.register;

    // Message d'erreur affiché : on privilégie le message local (posé par le
    // `ref.listen` ci-dessus sur CETTE instance d'écran) et on retombe sur celui
    // porté par l'état `Unauthenticated` courant. Ce repli est ESSENTIEL au flux
    // social : le routeur démonte cet écran (AuthLoading → /splash) puis en
    // remonte un NEUF (Unauthenticated → /auth) ; ce nouvel écran n'a pas de
    // `_authError` local et son `ref.listen` a manqué l'émission — sans ce repli,
    // aucun message ne s'afficherait malgré l'échec ou le timeout (bug observé).
    final String? stateMessage = state is Unauthenticated ? state.message : null;
    final String? shownError =
        _authError ?? (stateMessage != null && stateMessage.isNotEmpty ? stateMessage : null);

    // Trace de diagnostic (étapes horodatées du dernier flux social). Portée par
    // un provider — et non par l'état local — pour survivre au démontage/remontage
    // de l'écran par le routeur pendant le flux.
    final List<AuthDiagnosticEntry> diagnostics = ref.watch(authDiagnosticsProvider);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Backdrop lumineux de marque, cohérent avec l'écran d'ouverture.
          const Positioned.fill(child: _AuthBackdrop()),
          SafeArea(
            child: Column(
              children: <Widget>[
                // Barre supérieure : retour vers l'écran d'ouverture (landing).
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: PrismSpacing.sm, top: PrismSpacing.xs),
                    child: _AuthBackButton(onTap: () => context.go('/landing')),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PrismSpacing.lg,
                        vertical: PrismSpacing.md,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const _BrandBadge(),
                            const SizedBox(height: PrismSpacing.md),
                            Text(
                              'Certigo',
                              textAlign: TextAlign.center,
                              style: text.titleMedium?.copyWith(
                                color: p.textSecondary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: PrismSpacing.xs),
                            Text(
                              registering ? 'Crée ton compte' : 'Content de te revoir',
                              textAlign: TextAlign.center,
                              style: text.displaySmall?.copyWith(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: PrismSpacing.xs),
                            Text(
                              registering
                                  ? 'Quelques secondes, et ta progression commence.'
                                  : 'Reprends tes certifs là où tu t’es arrêté.',
                              textAlign: TextAlign.center,
                              style: text.titleMedium?.copyWith(color: p.textSecondary),
                            ),
                            const SizedBox(height: PrismSpacing.xl),
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  if (registering) ...<Widget>[
                                    TextFormField(
                                      key: const Key('name-field'),
                                      controller: _nameController,
                                      enabled: !busy,
                                      textInputAction: TextInputAction.next,
                                      textCapitalization: TextCapitalization.words,
                                      decoration: const InputDecoration(
                                        labelText: 'Nom (facultatif)',
                                        prefixIcon: Icon(Icons.person_outline),
                                      ),
                                    ),
                                    const SizedBox(height: PrismSpacing.sm),
                                  ],
                                  TextFormField(
                                    key: const Key('email-field'),
                                    controller: _emailController,
                                    enabled: !busy,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autocorrect: false,
                                    autofillHints: const <String>[AutofillHints.email],
                                    decoration: const InputDecoration(
                                      labelText: 'E-mail',
                                      prefixIcon: Icon(Icons.alternate_email),
                                    ),
                                    validator: _validateEmail,
                                  ),
                                  const SizedBox(height: PrismSpacing.sm),
                                  TextFormField(
                                    key: const Key('password-field'),
                                    controller: _passwordController,
                                    enabled: !busy,
                                    obscureText: _obscure,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: <String>[
                                      registering
                                          ? AutofillHints.newPassword
                                          : AutofillHints.password,
                                    ],
                                    onFieldSubmitted: (_) => _submitEmail(),
                                    decoration: InputDecoration(
                                      labelText: 'Mot de passe',
                                      prefixIcon: const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(() => _obscure = !_obscure),
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        tooltip: _obscure ? 'Afficher' : 'Masquer',
                                      ),
                                    ),
                                    validator: _validatePassword,
                                  ),
                                  const SizedBox(height: PrismSpacing.lg),
                                  SizedBox(
                                    height: 52,
                                    child: FilledButton(
                                      key: const Key('email-submit'),
                                      onPressed: busy ? null : _submitEmail,
                                      child: _emailSubmitting
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                              ),
                                            )
                                          : Text(registering ? 'Créer un compte' : 'Se connecter'),
                                    ),
                                  ),
                                  // Deuxième et dernière tentative en cours :
                                  // l'indicateur seul ne change pas et cesse
                                  // d'informer. Ce texte suit l'état, donc il
                                  // disparaît de lui-même à l'issue — succès
                                  // comme échec.
                                  if (retryingSignIn) ...<Widget>[
                                    const SizedBox(height: PrismSpacing.sm),
                                    Text(
                                      'Le serveur démarre, on réessaie…',
                                      key: const Key('email-retry-notice'),
                                      textAlign: TextAlign.center,
                                      style: text.bodySmall?.copyWith(color: p.textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: PrismSpacing.sm),
                            TextButton(
                              key: const Key('toggle-mode'),
                              onPressed: busy ? null : _toggleMode,
                              child: Text(
                                registering
                                    ? 'Déjà un compte ? Se connecter'
                                    : 'Pas encore de compte ? Créer un compte',
                              ),
                            ),
                            if (socialEnabled) ...<Widget>[
                              const SizedBox(height: PrismSpacing.md),
                              _OrDivider(color: p.textSecondary),
                              const SizedBox(height: PrismSpacing.md),
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
                            ],
                            if (shownError != null) ...<Widget>[
                              const SizedBox(height: PrismSpacing.lg),
                              _ErrorCard(message: shownError),
                            ],
                            if (diagnostics.isNotEmpty) ...<Widget>[
                              const SizedBox(height: PrismSpacing.md),
                              _DiagnosticCard(entries: diagnostics),
                            ],
                            const SizedBox(height: PrismSpacing.xl),
                            Text(
                              'En continuant, tu acceptes nos conditions d’utilisation et '
                              'notre politique de confidentialité.',
                              textAlign: TextAlign.center,
                              style: text.bodySmall?.copyWith(color: p.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'erreur d'authentification **persistante** et **sélectionnable**.
///
/// Remplace le SnackBar (trop fugace) : reste affichée jusqu'à la prochaine
/// tentative, avec le message complet (incluant le détail technique `[technique]`
/// remonté par la passerelle/le contrôleur) afin que l'utilisateur puisse le
/// lire, le copier ou le capturer pour diagnostiquer l'échec réel.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      key: const Key('auth-error'),
      width: double.infinity,
      padding: const EdgeInsets.all(PrismSpacing.md),
      decoration: BoxDecoration(
        color: p.error.withOpacity(0.12),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: p.error.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.error_outline, color: p.error, size: 20),
              const SizedBox(width: PrismSpacing.xs),
              Expanded(
                child: Text(
                  'Échec de la connexion',
                  style: text.titleSmall?.copyWith(color: p.error, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: PrismSpacing.xs),
          SelectableText(
            message,
            style: text.bodySmall?.copyWith(color: p.textPrimary, height: 1.35),
          ),
          const SizedBox(height: PrismSpacing.xs),
          Text(
            'Copie ou capture ce message pour le diagnostic.',
            style: text.bodySmall?.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Carte de **diagnostic** du flux de connexion sociale : journal horodaté et
/// **persistant** des étapes (authorize → callback → échange → jeton → session),
/// pour localiser sur appareil réel (iOS) où le flux s'arrête. Le contenu est
/// **sélectionnable** (copiable/capturable) et reste affiché. Alimentée par
/// [authDiagnosticsProvider], donc elle survit au démontage/remontage de l'écran
/// par le routeur pendant le flux (AuthLoading → /splash → Unauthenticated → /auth).
class _DiagnosticCard extends StatelessWidget {
  const _DiagnosticCard({required this.entries});

  final List<AuthDiagnosticEntry> entries;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;
    final DateTime start = entries.first.at;
    final String trace = <String>[
      for (final AuthDiagnosticEntry e in entries)
        '[${_formatClock(e.at)}] +${e.at.difference(start).inMilliseconds}ms  '
            '${e.step.label}${e.detail == null || e.detail!.isEmpty ? '' : ' — ${e.detail}'}',
    ].join('\n');
    return Container(
      key: const Key('auth-diagnostic'),
      width: double.infinity,
      padding: const EdgeInsets.all(PrismSpacing.md),
      decoration: BoxDecoration(
        color: p.textSecondary.withOpacity(0.08),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: p.textSecondary.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.timeline, color: p.textSecondary, size: 20),
              const SizedBox(width: PrismSpacing.xs),
              Expanded(
                child: Text(
                  'Diagnostic de connexion (étapes)',
                  style: text.titleSmall?.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PrismSpacing.xs),
          SelectableText(trace, style: text.bodySmall?.copyWith(color: p.textPrimary, height: 1.4)),
          const SizedBox(height: PrismSpacing.xs),
          Text(
            'Capture ces étapes : la dernière ligne indique où le flux s\'est arrêté.',
            style: text.bodySmall?.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Formate un horodatage en `HH:mm:ss.SSS` (heure murale locale), sans dépendance
/// `intl`, pour le journal de diagnostic.
String _formatClock(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final String ms = t.millisecond.toString().padLeft(3, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.$ms';
}

/// Séparateur « ou » entre le formulaire e-mail et les fournisseurs sociaux.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Divider(color: color.withOpacity(0.30))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.sm),
          child: Text(
            'ou continuer avec',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
        Expanded(child: Divider(color: color.withOpacity(0.30))),
      ],
    );
  }
}

/// Backdrop lumineux de l'écran de connexion : dégradé de base + halos radiaux
/// teintés marque, construits localement à partir des tokens — cohérent avec
/// l'écran d'ouverture (landing) pour une continuité visuelle.
class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.alphaBlend(p.primary.withOpacity(0.10), p.background),
            p.background,
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -140,
            left: -90,
            child: _AuthGlow(color: p.primary.withOpacity(0.20), size: 340),
          ),
          Positioned(
            top: -30,
            right: -110,
            child: _AuthGlow(color: p.ember.withOpacity(0.14), size: 300),
          ),
          Positioned(
            bottom: -170,
            left: 0,
            child: _AuthGlow(color: const Color(0xFF8C5CF6).withOpacity(0.14), size: 360),
          ),
        ],
      ),
    );
  }
}

/// Halo radial doux (repris de l'esprit d'`AuroraBackground`).
class _AuthGlow extends StatelessWidget {
  const _AuthGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: <Color>[color, color.withOpacity(0)]),
        ),
      ),
    );
  }
}

/// Bouton retour glass circulaire, ramène à l'écran d'ouverture.
class _AuthBackButton extends StatelessWidget {
  const _AuthBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return Semantics(
      button: true,
      label: 'Retour',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.surface.withOpacity(0.7),
            border: Border.all(color: p.border),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.arrow_back_rounded, color: p.textPrimary, size: 22),
        ),
      ),
    );
  }
}

/// Badge de marque : l'initiale « C » de Certigo (losange dégradé) dans un
/// anneau glass lumineux — même langage visuel que l'ancre de l'écran hero.
class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    const double outer = 88;
    return Center(
      child: Container(
        width: outer,
        height: outer,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.glassFill,
          border: Border.all(color: p.glassStroke, width: 1.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: p.primary.withOpacity(0.32),
              blurRadius: 30,
              offset: const Offset(0, 14),
              spreadRadius: -10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Container(
          width: outer * 0.56,
          height: outer * 0.56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(outer * 0.18),
            gradient: LinearGradient(
              colors: <Color>[p.primaryFill, p.emberFill],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            'C',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}
