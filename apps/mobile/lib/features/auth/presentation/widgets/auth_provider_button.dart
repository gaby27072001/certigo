import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../application/auth_state.dart';

/// Style de marque (couleurs/logo) d'un bouton de connexion, fidèle aux
/// conventions de chaque fournisseur (boutons « Se connecter avec… »).
class _ProviderBrand {
  const _ProviderBrand({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.iconColor,
    this.border,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color iconColor;
  final Color? border;
}

/// Bouton de connexion social plein-largeur, façon Duolingo : pilule haute,
/// logo de marque à gauche, libellé centré, animation d'appui et état de
/// chargement intégré.
class AuthProviderButton extends StatefulWidget {
  const AuthProviderButton({
    super.key,
    required this.provider,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  final AuthProvider provider;
  final VoidCallback onPressed;
  final bool loading;
  final bool enabled;

  @override
  State<AuthProviderButton> createState() => _AuthProviderButtonState();
}

class _AuthProviderButtonState extends State<AuthProviderButton> {
  bool _down = false;

  bool get _interactive => widget.enabled && !widget.loading;

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  _ProviderBrand _brandFor(BuildContext context) {
    final bool isDark = context.prism.brightness == Brightness.dark;
    switch (widget.provider) {
      case AuthProvider.microsoft:
        return _ProviderBrand(
          label: 'Continuer avec Microsoft',
          icon: PrismBrandIcons.microsoft,
          background: isDark ? const Color(0xFF2B2B2B) : Colors.white,
          foreground: isDark ? Colors.white : const Color(0xFF1B1B1F),
          iconColor: const Color(0xFF0067B8),
          border: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFD9D9D9),
        );
      case AuthProvider.google:
        return _ProviderBrand(
          label: 'Continuer avec Google',
          icon: PrismBrandIcons.google,
          background: isDark ? const Color(0xFF2B2B2B) : Colors.white,
          foreground: isDark ? Colors.white : const Color(0xFF1B1B1F),
          iconColor: const Color(0xFFEA4335),
          border: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFD9D9D9),
        );
      case AuthProvider.apple:
        return _ProviderBrand(
          label: 'Continuer avec Apple',
          icon: PrismBrandIcons.apple,
          background: isDark ? Colors.white : Colors.black,
          foreground: isDark ? Colors.black : Colors.white,
          iconColor: isDark ? Colors.black : Colors.white,
        );
      case AuthProvider.email:
        // L'e-mail/mot de passe a sa propre UI (champs + bouton) et n'utilise
        // jamais ce bouton ; ce cas n'existe que pour l'exhaustivité du switch.
        return _ProviderBrand(
          label: 'Continuer avec un e-mail',
          icon: Icons.mail_outline_rounded,
          background: isDark ? const Color(0xFF2B2B2B) : Colors.white,
          foreground: isDark ? Colors.white : const Color(0xFF1B1B1F),
          iconColor: context.prism.primary,
          border: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFD9D9D9),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ProviderBrand brand = _brandFor(context);
    final TextStyle labelStyle = Theme.of(
      context,
    ).textTheme.titleMedium!.copyWith(color: brand.foreground, fontWeight: FontWeight.w700);

    return Semantics(
      button: true,
      enabled: _interactive,
      label: brand.label,
      child: GestureDetector(
        onTapDown: _interactive ? (_) => setState(() => _down = true) : null,
        onTapUp: _interactive ? (_) => setState(() => _down = false) : null,
        onTapCancel: _interactive ? () => setState(() => _down = false) : null,
        onTap: _interactive ? _handleTap : null,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _interactive ? 1 : 0.55,
            duration: const Duration(milliseconds: 160),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.md),
              decoration: BoxDecoration(
                color: brand.background,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                border: brand.border == null ? null : Border.all(color: brand.border!),
                boxShadow: _down
                    ? null
                    : <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                          spreadRadius: -8,
                        ),
                      ],
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: widget.loading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(brand.foreground),
                              ),
                            )
                          : Icon(brand.icon, size: 20, color: brand.iconColor),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      brand.label,
                      textAlign: TextAlign.center,
                      style: labelStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Symétrie visuelle : réserve la largeur du logo à droite pour
                  // que le libellé reste optiquement centré.
                  const SizedBox(width: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
