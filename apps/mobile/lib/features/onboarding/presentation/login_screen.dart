import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

import '../application/onboarding_controller.dart';
import 'onboarding_common.dart';

/// Sign-in screen reached from "J'ai déjà un compte". Email + password with a
/// reveal toggle, a forgotten-password link, social options and the legal line.
///
/// Authentication is not wired yet (dev builds use a dev token), so any of the
/// actions simply marks onboarding complete and enters the app — the screen is
/// here to complete the visual flow and is ready to host real auth later.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _enter() {
    ref.read(onboardingControllerProvider).complete();
    context.go('/path');
  }

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(OnboardingRoutes.welcome),
        ),
        title: Text('Connexion', style: t.titleLarge),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: <Widget>[
            _Field(
              controller: _email,
              hint: 'E-mail ou nom d\'utilisateur',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _password,
              hint: 'Mot de passe',
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              trailing: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                color: p.textSecondary,
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _enter,
                child: Text('Mot de passe oublié ?', style: t.labelLarge?.copyWith(color: p.primary)),
              ),
            ),
            const SizedBox(height: 8),
            PrismButton(label: 'SE CONNECTER', onPressed: _enter),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(child: Divider(color: p.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OU', style: t.labelMedium?.copyWith(color: p.textSecondary)),
                ),
                Expanded(child: Divider(color: p.border)),
              ],
            ),
            const SizedBox(height: 20),
            _SocialButton(
              label: 'CONTINUER AVEC GOOGLE',
              icon: Icons.g_mobiledata_rounded,
              onTap: _enter,
            ),
            const SizedBox(height: 12),
            _SocialButton(
              label: 'CONTINUER AVEC MICROSOFT',
              icon: Icons.window_rounded,
              onTap: _enter,
            ),
            const SizedBox(height: 24),
            Text(
              'En te connectant à Microlingo, tu acceptes nos Conditions d\'utilisation '
              'et notre Politique de confidentialité.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: p.textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: p.textSecondary),
        suffixIcon: trailing,
        filled: true,
        fillColor: p.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: PrismRadii.cardLg,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PrismRadii.cardLg,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: PrismRadii.cardLg,
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextTheme t = Theme.of(context).textTheme;
    return Material(
      color: p.surface,
      borderRadius: PrismRadii.buttonAll,
      child: InkWell(
        borderRadius: PrismRadii.buttonAll,
        onTap: onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: PrismRadii.buttonAll,
            border: Border.all(color: p.border, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: p.textPrimary, size: 24),
              const SizedBox(width: 10),
              Text(
                label,
                style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: p.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
