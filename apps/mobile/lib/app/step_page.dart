import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:prism_ui/prism_ui.dart';

/// Page Prism pour une étape hors coquille.
///
/// Sur **iOS** on renvoie un [CupertinoPage] : il installe la transition
/// horizontale native ET le détecteur de geste de retour par balayage depuis le
/// bord gauche. Le paramètre [begin] est alors ignoré.
///
/// Sur les **autres plateformes** on garde la transition Prism
/// ([CustomTransitionPage] avec fade + slide) : le mandat produit préserve
/// l'identité visuelle Prism sur Android, quitte à ne pas brancher le
/// « predictive back gesture ».
///
/// Le [BuildContext.canPop] côté appelant reste la condition d'activation du
/// geste : les navigations d'entrée dans un sous-flux (`/register/*`,
/// `/onboarding/*`, explorations) doivent utiliser `context.push(...)` pour
/// empiler, sinon la pile est vidée par `.go(...)` et le geste devient inerte.
///
/// Exposé au niveau du fichier (et non privé de `router.dart`) pour permettre
/// à un test widget de monter un `GoRouter` minimal qui teste réellement le
/// mécanisme de production — sans traîner l'arbre complet des écrans.
Page<void> stepPage({
  required GoRouterState state,
  required Widget child,
  Offset begin = const Offset(0.06, 0),
}) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return CupertinoPage<void>(key: state.pageKey, child: child);
  }
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: PrismMotion.base,
    reverseTransitionDuration: PrismMotion.fast,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final CurvedAnimation curved = CurvedAnimation(
        parent: animation,
        curve: PrismMotion.decelerate,
        reverseCurve: PrismMotion.standard,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
