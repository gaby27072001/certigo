import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../onboarding/presentation/onboarding_common.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import '../application/auth_validators.dart';
import '../application/register_draft.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Troisième écran du flux d'inscription progressif : « Crée un mot de passe »
/// (bascule œil unique appliquée aux deux champs, minimum 8 caractères,
/// **confirmation obligatoire**).
///
/// La confirmation casse la composition mesurée à l'audit :
/// - une seule saisie du mot de passe à l'inscription,
/// - + aucune réinitialisation de mot de passe côté produit,
/// = une faute de frappe au clavier enferme définitivement l'utilisateur dehors
///   (l'adresse est prise côté backend, sans recours). Deux champs suppriment
///   cette composition immédiatement, sans dépendre du chantier « reset »
///   backend.
///
/// Le « CONTINUER » **branche le vrai backend** : il appelle
/// `AuthController.registerWithEmail(...)` avec l'e-mail et le nom accumulés
/// dans le brouillon, affiche le CTA en chargement pendant l'appel, puis :
/// - succès (`Authenticated`) → confirmation de création du profil ;
/// - échec (`Unauthenticated(message)`) → SnackBar et on reste sur l'écran.
class RegisterPasswordScreen extends ConsumerStatefulWidget {
  const RegisterPasswordScreen({super.key});

  @override
  ConsumerState<RegisterPasswordScreen> createState() => _RegisterPasswordScreenState();
}

class _RegisterPasswordScreenState extends ConsumerState<RegisterPasswordScreen> {
  late final TextEditingController _password;
  late final TextEditingController _confirm;

  /// Une seule bascule pilote la visibilité des deux champs : le cas d'usage
  /// « je veux relire ce que j'ai tapé » couvre le mot de passe **et** sa
  /// confirmation en même temps ; deux bascules distinctes doubleraient les
  /// contrôles sans utilité mesurable.
  bool _obscure = true;

  /// Vrai entre le tap sur CONTINUER et la résolution de l'appel backend.
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _password = TextEditingController(text: ref.read(registerDraftProvider).password);
    _confirm = TextEditingController();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _passwordValid => isValidPassword(_password.text);
  bool get _confirmMatches => doPasswordsMatch(_password.text, _confirm.text);
  bool get _canSubmit => _passwordValid && _confirmMatches;

  /// Ne signale la divergence qu'une fois la confirmation « avérée »
  /// (assez longue pour égaler le mot de passe) : évite de crier « ne correspond
  /// pas » pendant que l'utilisateur tape encore ses premiers caractères.
  bool get _confirmMismatchVisible =>
      _confirm.text.isNotEmpty &&
      _confirm.text.length >= _password.text.length &&
      _confirm.text != _password.text;

  void _submit() {
    if (!_canSubmit || _submitting) return;
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
        // Ecran terminal du sous-flux : on remplace la pile pour empecher un
        // retour vers l'ecran de mot de passe (qui viderait les champs, cf.
        // note dans la description de PR sur la persistance du brouillon).
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

    final Widget toggle = IconButton(
      key: const Key('register-password-toggle'),
      onPressed: () => setState(() => _obscure = !_obscure),
      icon: Icon(
        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: p.textSecondary,
      ),
      tooltip: _obscure ? 'Afficher' : 'Masquer',
    );

    return OnboardingScaffold(
      progress: 0.55,
      // Cohérent avec le geste iOS de retour par balayage : on dépile si la pile
      // le permet, sinon on retombe sur la navigation logique (cas deep link).
      onBack: _submitting
          ? null
          : () => context.canPop() ? context.pop() : context.go('/register/email'),
      primaryLabel: 'Continuer',
      primaryLoading: _submitting,
      onPrimary: _canSubmit ? _submit : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          const MascotPrompt(message: 'Crée un mot de passe'),
          const SizedBox(height: 24),
          AppTextField(
            fieldKey: const Key('register-password'),
            controller: _password,
            hint: 'Mot de passe',
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofocus: true,
            autofillHints: const <String>[AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
            suffixIcon: toggle,
          ),
          const SizedBox(height: 10),
          Text(
            'Au moins 8 caractères.',
            style: t.bodySmall?.copyWith(
              color: _passwordValid ? p.primary : p.textSecondary,
              height: 1.4,
              fontWeight: _passwordValid ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            fieldKey: const Key('register-password-confirm'),
            controller: _confirm,
            hint: 'Confirme le mot de passe',
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            autofillHints: const <String>[AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 10),
          _ConfirmHint(
            key: const Key('register-password-confirm-hint'),
            matches: _confirmMatches && _passwordValid,
            mismatchVisible: _confirmMismatchVisible,
          ),
        ],
      ),
    );
  }
}

/// Message d'aide sous le champ de confirmation.
///
/// Trois états :
/// - **neutre** (`Confirme ton mot de passe.`) — champ vide ou l'utilisateur
///   est encore en train de taper (confirmation plus courte que le mot de
///   passe) ;
/// - **erreur** (`Les mots de passe ne correspondent pas.`, couleur `danger`)
///   — divergence avérée, quand la confirmation est au moins aussi longue que
///   le mot de passe et diffère ;
/// - **succès** (`Les mots de passe correspondent.`, couleur `primary`, gras)
///   — mot de passe valide et confirmation identique.
class _ConfirmHint extends StatelessWidget {
  const _ConfirmHint({
    super.key,
    required this.matches,
    required this.mismatchVisible,
  });

  final bool matches;
  final bool mismatchVisible;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextStyle? base = Theme.of(context).textTheme.bodySmall;

    if (matches) {
      return Text(
        'Les mots de passe correspondent.',
        style: base?.copyWith(color: p.primary, height: 1.4, fontWeight: FontWeight.w700),
      );
    }
    if (mismatchVisible) {
      return Text(
        'Les mots de passe ne correspondent pas.',
        style: base?.copyWith(color: p.error, height: 1.4, fontWeight: FontWeight.w700),
      );
    }
    return Text(
      'Confirme ton mot de passe.',
      style: base?.copyWith(color: p.textSecondary, height: 1.4),
    );
  }
}
