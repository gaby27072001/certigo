import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Garde de **branchement**.
///
/// Le motif d'échec dominant de ce dépôt est documenté noir sur blanc dans
/// `prism_token_export_test.dart` : *« construire un mécanisme complet et ne
/// pas le brancher »*. Un schéma résolu sur huit combinaisons ne vaut rien si
/// aucun réglage système ne l'atteint jamais.
///
/// Ce fichier vérifie donc la seule chose que les autres gardes ne peuvent pas
/// voir : qu'un réglage posé dans `MediaQuery` **ressort** dans le
/// `PrismColorScheme` que lisent les widgets.
void main() {
  /// Rend le schéma effectivement vu par un widget quelconque sous le scope.
  Future<PrismColorScheme> resolvedUnder(
    WidgetTester tester, {
    required bool highContrast,
    required bool boldText,
    required bool reduceTransparency,
    Brightness brightness = Brightness.light,
  }) async {
    late PrismColorScheme seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: PrismTheme.light(),
        darkTheme: PrismTheme.dark(),
        themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              highContrast: highContrast,
              boldText: boldText,
            ),
            child: PrismAccessibilityScope(
              reduceTransparency: reduceTransparency,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: Builder(
          builder: (BuildContext context) {
            seen = context.prism;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return seen;
  }

  testWidgets('sans aucun réglage, rien n\'est reconstruit', (WidgetTester tester) async {
    final PrismColorScheme p = await resolvedUnder(
      tester,
      highContrast: false,
      boldText: false,
      reduceTransparency: false,
    );
    expect(identical(p, PrismColorScheme.light), isTrue);
  });

  testWidgets('Increase Contrast du système atteint le schéma', (WidgetTester tester) async {
    final PrismColorScheme p = await resolvedUnder(
      tester,
      highContrast: true,
      boldText: false,
      reduceTransparency: false,
    );
    expect(p.highContrast, isTrue);
    expect(p.textSecondary, isNot(PrismColorScheme.light.textSecondary));
  });

  testWidgets('Reduce Transparency de la plateforme atteint le schéma',
      (WidgetTester tester) async {
    final PrismColorScheme p = await resolvedUnder(
      tester,
      highContrast: false,
      boldText: false,
      reduceTransparency: true,
    );
    expect(p.reduceTransparency, isTrue);
    expect(p.glassFill.a, 1.0);
  });

  testWidgets('le mode sombre est traité à égalité', (WidgetTester tester) async {
    // Règle 7 de §10 : « le clair et le sombre sont tenus à égalité — le sombre
    // est un défaut livré ». Une résolution qui prendrait `Brightness.light` en
    // dur passerait toutes les autres gardes.
    final PrismColorScheme p = await resolvedUnder(
      tester,
      highContrast: true,
      boldText: false,
      reduceTransparency: true,
      brightness: Brightness.dark,
    );
    expect(p.brightness, Brightness.dark);
    expect(p.highContrast, isTrue);
    expect(p.reduceTransparency, isTrue);
  });

  testWidgets('Bold Text atteint la typographie', (WidgetTester tester) async {
    late TextTheme seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: PrismTheme.light(),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(boldText: true),
            child: PrismAccessibilityScope(child: child ?? const SizedBox.shrink()),
          );
        },
        home: Builder(
          builder: (BuildContext context) {
            seen = Theme.of(context).textTheme;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    double weightOf(TextStyle? s) =>
        s!.fontVariations!.firstWhere((FontVariation v) => v.axis == 'wght').value;
    expect(weightOf(seen.bodyLarge), greaterThan(400));
    expect(weightOf(seen.displayLarge), greaterThan(800));
  });
}
