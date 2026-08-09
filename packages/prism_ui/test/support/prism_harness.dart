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
ThemeData _prismTestTheme(Brightness brightness) {
  final PrismColorScheme scheme =
      brightness == Brightness.dark ? PrismColorScheme.dark : PrismColorScheme.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: scheme.background,
    extensions: <ThemeExtension<dynamic>>[scheme],
  );
}

/// Pumps [child] inside a Prism-themed [MaterialApp] so that `context.prism`
/// and `Theme.of(context).textTheme` resolve just like in the app.
Future<void> pumpPrism(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) {
  return tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _prismTestTheme(brightness),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}
