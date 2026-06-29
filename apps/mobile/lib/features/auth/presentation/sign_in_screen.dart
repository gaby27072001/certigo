import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/auth_controller.dart';
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
  const SignInScreen({super.key});

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _signInSocial(AuthProvider provider) {
    setState(() => _pending = provider);
    ref.read(authControllerProvider.notifier).signIn(provider);
  }

  void _submitEmail() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _emailSubmitting = true);

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
    final bool socialEnabled = ref.watch(authConfiguredProvider);

    // Affiche les erreurs et réarme les boutons quand le flux retombe sur un
    // état non authentifié.
    ref.listen<AuthState>(authControllerProvider, (AuthState? prev, AuthState next) {
      if (next is Unauthenticated) {
        if (_pending != null || _emailSubmitting) {
          setState(() {
            _pending = null;
            _emailSubmitting = false;
          });
        }
        final String? message = next.message;
        if (message != null && message.isNotEmpty) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      }
    });

    final AuthState state = ref.watch(authControllerProvider);
    final bool busy = state is AuthLoading || _pending != null || _emailSubmitting;
    final bool registering = _mode == _AuthMode.register;

    return Scaffold(
      body: AuroraBackground(
        animate: true,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: PrismSpacing.lg,
                vertical: PrismSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _Logo(color: p.primary),
                    const SizedBox(height: PrismSpacing.lg),
                    Text(
                      'Certigo',
                      textAlign: TextAlign.center,
                      style: text.displaySmall?.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: PrismSpacing.xs),
                    Text(
                      registering
                          ? 'Crée ton compte pour commencer.'
                          : 'Décroche tes certifications, une leçon à la fois.',
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
                              registering ? AutofillHints.newPassword : AutofillHints.password,
                            ],
                            onFieldSubmitted: (_) => _submitEmail(),
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(_obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
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
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(registering ? 'Créer un compte' : 'Se connecter'),
                            ),
                          ),
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
      ),
    );
  }
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

/// Logo simple et autonome (aucune ressource externe) : un losange lumineux aux
/// couleurs de la marque.
class _Logo extends StatelessWidget {
  const _Logo({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          gradient: LinearGradient(
            colors: <Color>[color, context.prism.ember],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withOpacity(0.40),
              blurRadius: 28,
              offset: const Offset(0, 14),
              spreadRadius: -8,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'M',
            style: TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
