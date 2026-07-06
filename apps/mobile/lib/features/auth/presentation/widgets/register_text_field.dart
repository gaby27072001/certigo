import 'package:flutter/material.dart';
import 'package:prism_ui/prism_ui.dart';

/// Champ de saisie plein, gris clair et arrondi — la brique de formulaire du
/// flux d'inscription progressif (façon Duolingo : fond `surfaceAlt`, bordure
/// discrète qui s'illumine en `primary` au focus, pas de label flottant).
///
/// Volontairement fin : il s'appuie sur le thème Prism pour les couleurs et
/// n'ajoute qu'un habillage cohérent réutilisé par les écrans nom/e-mail/mot de
/// passe.
class RegisterTextField extends StatelessWidget {
  const RegisterTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.autofillHints,
    this.autocorrect = true,
    this.autofocus = false,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final List<String>? autofillHints;
  final bool autocorrect;
  final bool autofocus;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final PrismColorScheme p = context.prism;
    final TextStyle textStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
          color: p.textPrimary,
          fontWeight: FontWeight.w600,
        );
    final OutlineInputBorder base = OutlineInputBorder(
      borderRadius: PrismRadii.cardLg,
      borderSide: BorderSide(color: p.border, width: 1.5),
    );

    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      autofillHints: autofillHints,
      autocorrect: autocorrect,
      autofocus: autofocus,
      style: textStyle,
      cursorColor: p.primary,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: textStyle.copyWith(color: p.textSecondary.withOpacity(0.7)),
        filled: true,
        fillColor: p.surfaceAlt,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: base,
        enabledBorder: base,
        focusedBorder: OutlineInputBorder(
          borderRadius: PrismRadii.cardLg,
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
      ),
    );
  }
}
