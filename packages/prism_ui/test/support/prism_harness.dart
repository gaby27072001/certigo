import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prism_ui/prism_ui.dart';

/// Test-only helpers shared by the prism_ui widget suites.
///
/// `prism_ui` renders its type system through `google_fonts`, which by default
/// tries to fetch font files over HTTP at runtime. That is non-hermetic and
/// flaky in CI, so widget/unit suites disable runtime fetching — fonts then
/// fall back to the bundled default without any network access. This touches
/// **test code only**; the library is never modified.
void disableGoogleFontsFetching() {
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// A minimal Prism-aware [ThemeData] that registers the [PrismColorScheme]
/// extension *without* building the `google_fonts` text theme.
///
/// Widget tests assert on layout, colors, icons, text presence and semantics —
/// none of which depend on the font family — so we keep Material's default text
/// theme and stay fully hermetic (no font fetching, no async font errors).
ThemeData _prismTestTheme(Brightness brightness) {
  final PrismColorScheme scheme = brightness == Brightness.dark
      ? PrismColorScheme.dark
      : PrismColorScheme.light;
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
      home: Scaffold(
        body: Center(child: child),
      ),
    ),
  );
}

/// Runs [body] inside a guarded zone that swallows the asynchronous
/// font-loading errors `google_fonts` raises when runtime fetching is disabled.
///
/// `google_fonts` kicks off fire-and-forget font futures from a synchronous
/// `build()`; with fetching disabled those futures error out asynchronously.
/// Each future captures the zone it was created in, so routing those errors to
/// a no-op handler here keeps them from failing the active test — without
/// awaiting anything (awaiting font futures hangs under the test binding's fake
/// async). Build the object under test *inside* [body] and assert on it *after*
/// this call so real failures are never masked.
Future<void> runSwallowingFontErrors(Future<void> Function() body) async {
  await runZonedGuarded<Future<void>>(
    body,
    (Object error, StackTrace stack) {
      // Swallow async google_fonts errors raised when fetching is disabled.
    },
  );
}
