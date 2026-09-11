import 'package:flutter/widgets.dart';

/// Plancher de zone tactile d'Apple, en points logiques.
///
/// Les *Human Interface Guidelines* fixent 44×44 pt comme la plus petite cible
/// qu'un doigt atteint de façon fiable. Material demande 48×48 dp et Flutter
/// l'applique déjà à ses boutons via `MaterialTapTargetSize.padded` — mais
/// **rien** ne l'applique à un `GestureDetector` nu, qui adopte simplement la
/// taille de ce qu'il entoure. Une icône de 20 pt dans un `GestureDetector`
/// donne donc une cible de 20 pt.
const double kPrismMinTapTarget = 44;

/// Porte la zone tactile d'un contrôle au plancher d'Apple **sans changer ce
/// qui est dessiné**.
///
/// C'est la distinction qui compte : agrandir l'icône corrigerait la cible en
/// abîmant la composition. Ici l'enfant garde sa taille et reste centré ; seule
/// la boîte qui reçoit le toucher grandit.
///
/// À placer **à l'intérieur** du détecteur de gestes, avec
/// `behavior: HitTestBehavior.opaque` — sinon la zone gagnée reste transparente
/// au toucher et la correction ne fait rien :
///
/// ```dart
/// GestureDetector(
///   behavior: HitTestBehavior.opaque,
///   onTap: onTap,
///   child: const PrismTapTarget(child: Icon(Icons.close, size: 26)),
/// )
/// ```
class PrismTapTarget extends StatelessWidget {
  const PrismTapTarget({
    super.key,
    required this.child,
    this.minWidth = kPrismMinTapTarget,
    this.minHeight = kPrismMinTapTarget,
  });

  final Widget child;

  /// Largeur minimale. Un contrôle déjà plus large qu'elle la conserve.
  final double minWidth;

  /// Hauteur minimale. Un contrôle déjà plus haut qu'elle la conserve.
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, minHeight: minHeight),
      // Les facteurs à 1 font que la boîte épouse l'enfant, puis les
      // contraintes ci-dessus la remontent au plancher. L'enfant, lui, reste
      // centré et inchangé.
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}
