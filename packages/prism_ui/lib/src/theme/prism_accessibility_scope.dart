import 'package:flutter/material.dart';

import 'prism_theme.dart';

/// Branche les réglages système d'accessibilité sur le thème Prism.
///
/// ## Pourquoi ce widget existe
///
/// Certigo est **entièrement en couleurs personnalisées**. Les couleurs
/// système d'Apple s'adaptent seules à *Increase Contrast* ; une couleur
/// personnalisée doit fournir ses variantes, sinon le réglage ne fait
/// strictement rien. Mesuré avant ce changement : `highContrast`,
/// `reduceTransparency`, `boldText` et `accessibleNavigation` n'apparaissaient
/// **nulle part** dans `apps/mobile/lib` ni dans `packages/prism_ui/lib`.
///
/// À placer dans `MaterialApp.builder`, c'est-à-dire sous le `MediaQuery` que
/// `MaterialApp` installe et au-dessus de toutes les routes. Le thème est
/// alors reconstruit à chaque changement de réglage, sans qu'aucun site
/// d'appel n'ait à le savoir.
///
/// ## Ce que Flutter ne donne pas
///
/// `MediaQueryData` expose `highContrast` et `boldText`, et ils sont lus ici.
/// Il n'expose **pas** `reduceTransparency` : le symbole est absent de tout
/// `packages/flutter/lib/src` en 3.44.9, et absent de `AccessibilityFeatures`
/// dans `dart:ui`. Le réglage doit donc arriver par un canal de plateforme
/// écrit à la main, et il est passé ici par [reduceTransparency].
///
/// C'est le même constat que celui déjà consigné au §7 de `DESIGN.md` pour les
/// charnières : quand Flutter ne relaie pas une information de plateforme, ce
/// n'est pas une impasse, c'est un canal à écrire.
class PrismAccessibilityScope extends StatelessWidget {
  const PrismAccessibilityScope({
    super.key,
    required this.child,
    this.reduceTransparency = false,
  });

  final Widget child;

  /// *Reduce Transparency*, fourni par la plateforme faute d'être exposé par
  /// `MediaQuery`.
  final bool reduceTransparency;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final bool highContrast = media.highContrast;
    final bool boldText = media.boldText;

    // Aucun réglage actif : on ne reconstruit rien. Le chemin par défaut reste
    // exactement celui d'avant, y compris son coût.
    if (!highContrast && !reduceTransparency && !boldText) return child;

    return Theme(
      data: PrismTheme.resolve(
        brightness: Theme.of(context).brightness,
        highContrast: highContrast,
        reduceTransparency: reduceTransparency,
        boldText: boldText,
      ),
      child: child,
    );
  }
}
