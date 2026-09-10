import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../onboarding/presentation/onboarding_common.dart';
import '../application/auth_validators.dart';
import '../application/register_draft.dart';
import 'widgets/register_text_field.dart';

/// Deuxième écran du flux d'inscription progressif : « Ton adresse e-mail,
/// {prénom} ? ». Valide l'e-mail (même règle que `SignInScreen`) et propose,
/// quand le domaine ressemble à une faute de frappe connue, une correction
/// tappable (« Vouliez-vous dire … ? »).
class RegisterEmailScreen extends ConsumerStatefulWidget {
  const RegisterEmailScreen({super.key});

  @override
  ConsumerState<RegisterEmailScreen> createState() => _RegisterEmailScreenState();
}

class _RegisterEmailScreenState extends ConsumerState<RegisterEmailScreen> {
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: ref.read(registerDraftProvider).email);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _valid => isValidEmail(_email.text);

  void _applySuggestion(String suggestion) {
    _email.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    setState(() {});
  }

  void _next() {
    ref.read(registerDraftProvider.notifier).setEmail(_email.text);
    context.push('/register/password');
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    final String firstName = ref.watch(registerDraftProvider).firstName;
    final String greeting =
        firstName.isEmpty ? 'Ton adresse e-mail ?' : 'Ton adresse e-mail, $firstName ?';
    final String? suggestion = suggestEmailCorrection(_email.text);

    return OnboardingScaffold(
      progress: 0.4,
      // Cohérent avec le geste iOS de retour par balayage : on dépile si la pile
      // le permet, sinon on retombe sur la navigation logique (cas deep link).
      onBack: () => context.canPop() ? context.pop() : context.go('/register/name'),
      primaryLabel: 'Continuer',
      onPrimary: _valid ? _next : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          MascotPrompt(message: greeting),
          const SizedBox(height: 24),
          RegisterTextField(
            fieldKey: const Key('register-email'),
            controller: _email,
            hint: 'exemple@domaine.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofocus: true,
            autofillHints: const <String>[AutofillHints.email],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_valid) _next();
            },
          ),
          const SizedBox(height: 10),
          if (suggestion != null)
            GestureDetector(
              key: const Key('register-email-suggestion'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _applySuggestion(suggestion),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text.rich(
                  TextSpan(
                    style: t.bodyMedium?.copyWith(color: p.textSecondary),
                    children: <InlineSpan>[
                      const TextSpan(text: 'Vouliez-vous dire '),
                      TextSpan(
                        text: suggestion,
                        style: TextStyle(color: p.primary, fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: ' ?'),
                    ],
                  ),
                ),
              ),
            )
          else
            Text(
              'On t\'enverra un lien de confirmation à cette adresse.',
              style: t.bodySmall?.copyWith(color: p.textSecondary, height: 1.4),
            ),
        ],
      ),
    );
  }
}
