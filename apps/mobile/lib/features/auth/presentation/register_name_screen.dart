import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../onboarding/presentation/onboarding_common.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import '../application/register_draft.dart';
import 'widgets/auth_provider_button.dart';
import 'widgets/register_text_field.dart';

/// Premier écran du **flux d'inscription progressif** (façon Duo) : « Comment tu
/// t'appelles ? ». Collecte prénom (requis) et nom (facultatif), puis propose,
/// en bas, les fournisseurs sociaux (uniquement si Entra est configuré) et un
/// raccourci vers la connexion pour un compte existant.
///
/// Écran d'ouverture du flux : la barre supérieure porte une **croix (✕)** qui
/// referme le flux vers l'écran d'accueil (`/landing`) ; les écrans suivants ont
/// un chevron de retour.
class RegisterNameScreen extends ConsumerStatefulWidget {
  const RegisterNameScreen({super.key});

  @override
  ConsumerState<RegisterNameScreen> createState() => _RegisterNameScreenState();
}

class _RegisterNameScreenState extends ConsumerState<RegisterNameScreen> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;

  /// Fournisseur social dont la connexion est en cours (spinner du bouton).
  AuthProvider? _pending;

  @override
  void initState() {
    super.initState();
    final RegisterDraft draft = ref.read(registerDraftProvider);
    _firstName = TextEditingController(text: draft.firstName);
    _lastName = TextEditingController(text: draft.lastName);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  bool get _valid => _firstName.text.trim().isNotEmpty;

  void _next() {
    ref
        .read(registerDraftProvider.notifier)
        .setName(firstName: _firstName.text, lastName: _lastName.text);
    context.push('/register/email');
  }

  void _signInSocial(AuthProvider provider) {
    setState(() => _pending = provider);
    ref.read(authControllerProvider.notifier).signIn(provider);
  }

  @override
  Widget build(BuildContext context) {
    final bool socialEnabled = ref.watch(authConfiguredProvider);

    // Une réussite sociale sur cet écran authentifie l'utilisateur : on laisse
    // alors le garde router vers l'onboarding (en visant /home). Un échec réarme
    // les boutons et affiche le message.
    ref.listen<AuthState>(authControllerProvider, (AuthState? prev, AuthState next) {
      if (!mounted) return;
      if (next is Authenticated) {
        context.go('/home');
      } else if (next is Unauthenticated && _pending != null) {
        setState(() => _pending = null);
        final String? message = next.message;
        if (message != null && message.isNotEmpty) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      }
    });

    final AuthState state = ref.watch(authControllerProvider);
    final bool busy = state is AuthLoading || _pending != null;

    return OnboardingScaffold(
      progress: 0.25,
      onClose: () => context.go('/landing'),
      primaryLabel: 'Continuer',
      onPrimary: (_valid && !busy) ? _next : null,
      secondary: TextButton(
        key: const Key('register-have-account'),
        onPressed: busy ? null : () => context.go('/auth?emailOnly=1'),
        child: const Text('J’ai déjà un compte ? Se connecter'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Comment tu t\'appelles ?'),
          const SizedBox(height: 24),
          RegisterTextField(
            fieldKey: const Key('register-first-name'),
            controller: _firstName,
            hint: 'Prénom',
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const <String>[AutofillHints.givenName],
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          RegisterTextField(
            fieldKey: const Key('register-last-name'),
            controller: _lastName,
            hint: 'Nom (facultatif)',
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            autofillHints: const <String>[AutofillHints.familyName],
            onSubmitted: (_) {
              if (_valid && !busy) _next();
            },
          ),
          if (socialEnabled) ...<Widget>[
            const SizedBox(height: 28),
            const _OrDivider(),
            const SizedBox(height: 16),
            AuthProviderButton(
              provider: AuthProvider.microsoft,
              loading: _pending == AuthProvider.microsoft,
              enabled: !busy,
              onPressed: () => _signInSocial(AuthProvider.microsoft),
            ),
            const SizedBox(height: 10),
            AuthProviderButton(
              provider: AuthProvider.google,
              loading: _pending == AuthProvider.google,
              enabled: !busy,
              onPressed: () => _signInSocial(AuthProvider.google),
            ),
            const SizedBox(height: 10),
            AuthProviderButton(
              provider: AuthProvider.apple,
              loading: _pending == AuthProvider.apple,
              enabled: !busy,
              onPressed: () => _signInSocial(AuthProvider.apple),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Séparateur « ou » discret entre le formulaire nom et les boutons sociaux.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return Row(
      children: <Widget>[
        Expanded(child: Divider(color: p.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ou',
            style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Divider(color: p.border, thickness: 1)),
      ],
    );
  }
}
