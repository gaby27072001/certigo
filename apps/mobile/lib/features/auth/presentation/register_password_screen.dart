import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../onboarding/presentation/onboarding_common.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import '../application/auth_validators.dart';
import '../application/register_draft.dart';
import 'widgets/register_text_field.dart';

/// Troisième écran du flux d'inscription progressif : « Crée un mot de passe »
/// (bascule œil, minimum 8 caractères). Le « CONTINUER » **branche le vrai
/// backend** : il appelle `AuthController.registerWithEmail(...)` avec l'e-mail
/// et le nom accumulés dans le brouillon, affiche le CTA en chargement pendant
/// l'appel, puis :
/// - succès (`Authenticated`) → confirmation de création du profil ;
/// - échec (`Unauthenticated(message)`) → SnackBar et on reste sur l'écran.
class RegisterPasswordScreen extends ConsumerStatefulWidget {
  const RegisterPasswordScreen({super.key});

  @override
  ConsumerState<RegisterPasswordScreen> createState() => _RegisterPasswordScreenState();
}

class _RegisterPasswordScreenState extends ConsumerState<RegisterPasswordScreen> {
  late final TextEditingController _password;
  bool _obscure = true;

  /// Vrai entre le tap sur CONTINUER et la résolution de l'appel backend.
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _password = TextEditingController(text: ref.read(registerDraftProvider).password);
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _valid => isValidPassword(_password.text);

  void _submit() {
    if (!_valid || _submitting) return;
    FocusScope.of(context).unfocus();
    final RegisterDraftController draftCtrl = ref.read(registerDraftProvider.notifier);
    draftCtrl.setPassword(_password.text);
    final RegisterDraft draft = ref.read(registerDraftProvider);
    setState(() => _submitting = true);
    ref.read(authControllerProvider.notifier).registerWithEmail(
          email: draft.email,
          password: draft.password,
          displayName: draft.displayName.isEmpty ? null : draft.displayName,
        );
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    // Réagit à la réussite/échec de la création de compte réelle.
    ref.listen<AuthState>(authControllerProvider, (AuthState? prev, AuthState next) {
      if (!mounted || !_submitting) return;
      if (next is Authenticated) {
        context.go('/register/profile-created');
      } else if (next is Unauthenticated) {
        setState(() => _submitting = false);
        final String message = (next.message != null && next.message!.isNotEmpty)
            ? next.message!
            : 'La création du compte a échoué. Réessayez.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return OnboardingScaffold(
      progress: 0.55,
      onBack: _submitting ? null : () => context.go('/register/email'),
      primaryLabel: 'CONTINUER',
      primaryLoading: _submitting,
      onPrimary: _valid ? _submit : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Crée un mot de passe'),
          const SizedBox(height: 24),
          RegisterTextField(
            fieldKey: const Key('register-password'),
            controller: _password,
            hint: 'Mot de passe',
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            autofocus: true,
            autofillHints: const <String>[AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            suffixIcon: IconButton(
              key: const Key('register-password-toggle'),
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: p.textSecondary,
              ),
              tooltip: _obscure ? 'Afficher' : 'Masquer',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Au moins 8 caractères.',
            style: t.bodySmall?.copyWith(
              color: _valid ? p.primary : p.textSecondary,
              height: 1.4,
              fontWeight: _valid ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
