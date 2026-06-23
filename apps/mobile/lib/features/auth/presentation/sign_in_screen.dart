import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import 'widgets/auth_provider_button.dart';

/// Premier écran à l'ouverture de l'app (tant qu'aucun compte n'est mémorisé) :
/// présente les **trois** moyens de connexion — Microsoft, Google, Apple —
/// derrière Microsoft Entra External ID.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  /// Fournisseur dont la connexion est en cours (pour le spinner du bouton).
  AuthProvider? _pending;

  void _signIn(AuthProvider provider) {
    setState(() => _pending = provider);
    ref.read(authControllerProvider.notifier).signIn(provider);
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme text = Theme.of(context).textTheme;

    // Affiche les erreurs de connexion et réarme les boutons quand le flux
    // retombe sur un état non authentifié.
    ref.listen<AuthState>(authControllerProvider, (AuthState? prev, AuthState next) {
      if (next is Unauthenticated) {
        if (_pending != null) setState(() => _pending = null);
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
                      'Microlingo',
                      textAlign: TextAlign.center,
                      style: text.displaySmall?.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: PrismSpacing.xs),
                    Text(
                      'Décroche tes certifications, une leçon à la fois.',
                      textAlign: TextAlign.center,
                      style: text.titleMedium?.copyWith(color: p.textSecondary),
                    ),
                    const SizedBox(height: PrismSpacing.xxl),
                    AuthProviderButton(
                      provider: AuthProvider.microsoft,
                      loading: _pending == AuthProvider.microsoft,
                      enabled: !busy,
                      onPressed: () => _signIn(AuthProvider.microsoft),
                    ),
                    const SizedBox(height: PrismSpacing.sm),
                    AuthProviderButton(
                      provider: AuthProvider.google,
                      loading: _pending == AuthProvider.google,
                      enabled: !busy,
                      onPressed: () => _signIn(AuthProvider.google),
                    ),
                    const SizedBox(height: PrismSpacing.sm),
                    AuthProviderButton(
                      provider: AuthProvider.apple,
                      loading: _pending == AuthProvider.apple,
                      enabled: !busy,
                      onPressed: () => _signIn(AuthProvider.apple),
                    ),
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
