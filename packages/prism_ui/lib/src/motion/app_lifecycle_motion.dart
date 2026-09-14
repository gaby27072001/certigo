import 'package:flutter/widgets.dart';

/// Met une boucle d'animation **au repos quand l'application quitte l'écran**.
///
/// Trois composants Prism entretiennent une boucle infinie
/// (`AnimationController.repeat()`). Hors écran, une boucle ne peut rien
/// informer : elle ne fait plus que consommer de la batterie. DESIGN.md §10,
/// règle 6 — « le mouvement informe ; il ne décore pas ».
///
/// **Ce mixin ne décide pas à la place du composant.** Il expose un seul
/// signal, [motionIsVisible], et redéclenche un `build` quand la réponse
/// change. Chaque composant le compose avec ses propres conditions — au premier
/// chef le mouvement réduit, qui reste maître. C'est un `&&`, jamais un
/// remplacement : les deux conditions doivent pouvoir coexister.
///
/// Dix lignes partagées valent mieux que trois observateurs copiés-collés ; une
/// abstraction plus ambitieuse ne serait pas justifiée par trois sites d'appel.
mixin AppLifecycleMotion<T extends StatefulWidget> on State<T> {
  AppLifecycleListener? _listener;
  bool _visible = true;

  /// Vrai tant que l'application est présente à l'écran.
  ///
  /// À composer avec les conditions propres au composant :
  /// `final bool animate = widget.float && !reduceMotion && motionIsVisible;`
  bool get motionIsVisible => _visible;

  /// `inactive` reste **visible** : l'application est encore à l'écran derrière
  /// un sélecteur d'app ou un centre de contrôle. Y figer le mouvement se
  /// lirait comme une panne. Seuls `hidden`, `paused` et `detached` retirent
  /// réellement la surface au regard.
  static bool _isVisible(AppLifecycleState? state) {
    return switch (state) {
      null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      AppLifecycleState.hidden || AppLifecycleState.paused || AppLifecycleState.detached => false,
    };
  }

  @override
  void initState() {
    super.initState();
    _visible = _isVisible(WidgetsBinding.instance.lifecycleState);
    _listener = AppLifecycleListener(onStateChange: _onLifecycleStateChange);
  }

  @override
  void dispose() {
    _listener?.dispose();
    _listener = null;
    super.dispose();
  }

  void _onLifecycleStateChange(AppLifecycleState state) {
    final bool next = _isVisible(state);
    if (next == _visible || !mounted) return;
    setState(() => _visible = next);
  }
}
