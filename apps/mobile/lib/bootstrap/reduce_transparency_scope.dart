import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// Relaie le réglage système **Reduce Transparency** jusqu'au thème Prism.
///
/// ## Pourquoi un canal écrit à la main
///
/// Flutter n'expose pas ce réglage. Mesuré sur le SDK 3.44.9 installé :
/// `reduceTransparency` n'apparaît dans **aucun** fichier de
/// `packages/flutter/lib/src`, et `AccessibilityFeatures` de `dart:ui` ne
/// déclare que `accessibleNavigation`, `invertColors`, `disableAnimations`,
/// `boldText`, `reduceMotion`, `highContrast` et `onOffSwitchLabels`. Le
/// témoin de la même recherche sur `highContrast` rend 236 occurrences, et sur
/// un motif inexistant 0 : l'absence est réelle, pas un instrument muet.
///
/// `DESIGN.md` §7 a déjà tranché ce cas de figure pour les charnières :
/// « *Le jour où cela vaudra le coup, ce sera un canal de plateforme écrit à
/// la main, pas une attente de Flutter.* » C'est ce canal.
///
/// ## Le défaut est sûr
///
/// Toute plateforme qui ne répond pas — Android, le web, les tests, un
/// simulateur sans le canal enregistré — vaut `false`, c'est-à-dire le
/// comportement d'aujourd'hui : le verre reste du verre. Un canal absent ne
/// doit pas pouvoir aplatir le matériau par accident.
///
/// Android n'a pas de réglage système équivalent ; `false` y est le bon
/// verdict, pas un repli par dépit.
class ReduceTransparencyScope extends StatefulWidget {
  const ReduceTransparencyScope({super.key, required this.child});

  final Widget child;

  /// Le canal, partagé avec `AppDelegate.swift`.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('com.certigo.mobileapp/accessibility');

  /// Méthode appelée par Dart pour l'état courant.
  @visibleForTesting
  static const String getMethod = 'isReduceTransparencyEnabled';

  /// Méthode poussée par la plateforme quand l'utilisateur change le réglage
  /// pendant que l'application tourne.
  @visibleForTesting
  static const String changedMethod = 'reduceTransparencyChanged';

  @override
  State<ReduceTransparencyScope> createState() => _ReduceTransparencyScopeState();
}

class _ReduceTransparencyScopeState extends State<ReduceTransparencyScope> {
  bool _reduceTransparency = false;

  @override
  void initState() {
    super.initState();
    ReduceTransparencyScope.channel.setMethodCallHandler(_onPlatformCall);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    ReduceTransparencyScope.channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<Object?> _onPlatformCall(MethodCall call) async {
    if (call.method == ReduceTransparencyScope.changedMethod) {
      _apply(call.arguments == true);
    }
    return null;
  }

  Future<void> _refresh() async {
    bool enabled = false;
    try {
      enabled = await ReduceTransparencyScope.channel.invokeMethod<bool>(
            ReduceTransparencyScope.getMethod,
          ) ??
          false;
    } on MissingPluginException {
      // Plateforme sans canal : le verre reste du verre.
      enabled = false;
    } on PlatformException {
      enabled = false;
    }
    _apply(enabled);
  }

  void _apply(bool enabled) {
    if (!mounted || enabled == _reduceTransparency) return;
    setState(() => _reduceTransparency = enabled);
  }

  @override
  Widget build(BuildContext context) {
    return PrismAccessibilityScope(
      reduceTransparency: _reduceTransparency,
      child: widget.child,
    );
  }
}
