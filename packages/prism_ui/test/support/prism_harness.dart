import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Test-only helpers shared by the prism_ui widget suites.

/// A minimal Prism-aware [ThemeData] that registers the [PrismColorScheme]
/// extension without building the complete application theme.
///
/// Widget tests assert on layout, colors, icons, text presence and semantics —
/// none of which depend on the font family — so we keep Material's default text
/// theme and stay fully hermetic.
ThemeData _prismTestTheme(
  Brightness brightness, {
  bool highContrast = false,
  bool reduceTransparency = false,
}) {
  final PrismColorScheme scheme = PrismColorScheme.resolve(
    brightness: brightness,
    highContrast: highContrast,
    reduceTransparency: reduceTransparency,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: scheme.background,
    extensions: <ThemeExtension<dynamic>>[scheme],
  );
}

/// Pumps [child] inside a Prism-themed [MaterialApp] so that `context.prism`
/// and `Theme.of(context).textTheme` resolve just like in the app.
///
/// [highContrast] et [reduceTransparency] sont les deux axes d'accessibilité :
/// le premier est posé **aussi** dans `MediaQuery`, parce que c'est là que
/// `PrismAccessibilityScope` le lit dans l'application réelle ; le second n'y
/// existe pas — Flutter ne l'expose pas — et n'arrive que par le schéma.
Future<void> pumpPrism(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  bool highContrast = false,
  bool reduceTransparency = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _prismTestTheme(
        brightness,
        highContrast: highContrast,
        reduceTransparency: reduceTransparency,
      ),
      builder: (BuildContext context, Widget? appChild) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
            highContrast: highContrast,
          ),
          child: appChild!,
        );
      },
      home: Scaffold(body: Center(child: child)),
    ),
  );
}
