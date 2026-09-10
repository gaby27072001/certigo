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
  bool _focused = false;

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
    final PrismColorScheme p = context.prism;
    final _ProviderBrand brand = _brandFor(context);
    final Duration duration = PrismMotion.resolve(context, PrismMotion.fast);
    final TextStyle labelStyle = Theme.of(
      context,
    ).textTheme.titleMedium!.copyWith(color: brand.foreground, fontWeight: FontWeight.w700);

    return Semantics(
      button: true,
      enabled: _interactive,
      liveRegion: widget.loading,
      label: widget.loading ? '${brand.label}, chargement' : brand.label,
      onTap: _interactive ? _handleTap : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          excludeFromSemantics: true,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          // A neutral state layer derived from each brand's own foreground, so
          // hover and press read correctly on a white Google button and on a
          // black Apple one alike. This was `Colors.transparent`, the third
          // site in the app that switched Material's state layers off.
          overlayColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
            if (!_interactive) return const Color(0x00000000);
            if (states.contains(WidgetState.pressed)) {
              return brand.foreground.withValues(alpha: PrismStateLayer.pressed(p.brightness));
            }
            if (states.contains(WidgetState.hovered)) {
              return brand.foreground.withValues(alpha: PrismStateLayer.hover(p.brightness));
            }
            return const Color(0x00000000);
          }),
          onFocusChange: (bool value) {
            if (_focused != value) setState(() => _focused = value);
          },
          onHighlightChanged: _interactive
              ? (bool value) {
                  if (_down != value) setState(() => _down = value);
                }
              : null,
          onTap: _interactive ? _handleTap : null,
          child: ExcludeSemantics(
            child: AnimatedScale(
              scale: _down ? 0.97 : 1.0,
              duration: duration,
              curve: PrismMotion.standard,
              child: AnimatedOpacity(
                // 0.55 pushed the label under 3:1. A disabled control must read
                // as unavailable, not as a rendering fault.
                opacity: _interactive ? 1 : 0.72,
                duration: duration,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.md),
                  foregroundDecoration: _focused
                      ? BoxDecoration(
                          borderRadius: const BorderRadius.all(Radius.circular(16)),
                          border: Border.all(color: brand.foreground, width: 2),
                        )
                      : null,
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
                      const SizedBox(width: PrismSpacing.sm),
                      Expanded(
                        child: Text(
                          brand.label,
                          // Start-aligned on purpose. Centring each label
                          // inside the leftover width made the four labels
                          // begin at x = 94 / 104 / 109 / 95 — a 15 px jagged
                          // left edge down the stack, because the labels are
                          // different lengths. One shared start x is what makes
                          // a stack of buttons read as a stack.
                          textAlign: TextAlign.start,
                          style: labelStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
