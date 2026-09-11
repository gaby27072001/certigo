import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

void main() {
  group('PrismTheme', () {
    test('light theme is Material 3 with the light scaffold background', () {
      final ThemeData theme = PrismTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, PrismColors.lightBg);
    });

    test('dark theme is Material 3 with the dark scaffold background', () {
      final ThemeData theme = PrismTheme.dark();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, PrismColors.darkBg);
    });

    test('themes register the matching PrismColorScheme extension', () {
      final ThemeData light = PrismTheme.light();
      final ThemeData dark = PrismTheme.dark();
      expect(identical(light.extension<PrismColorScheme>(), PrismColorScheme.light), isTrue);
      expect(identical(dark.extension<PrismColorScheme>(), PrismColorScheme.dark), isTrue);
    });

    test('les huit combinaisons construisent un thème qui porte ses propres axes', () {
      // Le thème est ce que lisent les widgets Material (bordures de champs,
      // couleur de curseur, piste de progression…). Si `PrismTheme` oubliait un
      // axe, `context.prism` serait juste et le reste du thème faux.
      int built = 0;
      for (final Brightness b in Brightness.values) {
        for (final bool hc in <bool>[false, true]) {
          for (final bool rt in <bool>[false, true]) {
            final ThemeData theme =
                PrismTheme.resolve(brightness: b, highContrast: hc, reduceTransparency: rt);
            final PrismColorScheme? p = theme.extension<PrismColorScheme>();
            expect(p, isNotNull);
            expect(p!.brightness, b);
            expect(p.highContrast, hc);
            expect(p.reduceTransparency, rt);
            expect(theme.brightness, b);
            built++;
          }
        }
      }
      expect(built, 8, reason: 'huit combinaisons, pas quatre');
    });

    test('Increase Contrast déplace aussi le thème Material, pas seulement le schéma', () {
      final ThemeData base = PrismTheme.light();
      final ThemeData hc = PrismTheme.light(highContrast: true);
      expect(hc.dividerTheme.color, isNot(base.dividerTheme.color));
      expect(hc.iconTheme.color, isNot(base.iconTheme.color));
      expect(hc.colorScheme.primary, isNot(base.colorScheme.primary));
    });

    group('Bold Text', () {
      /// Lit l'axe variable `wght` réellement demandé au moteur.
      double weightOf(TextStyle? style) =>
          style!.fontVariations!.firstWhere((FontVariation v) => v.axis == 'wght').value;

      List<TextStyle?> slots(TextTheme t) => <TextStyle?>[
            t.displayLarge,
            t.displayMedium,
            t.displaySmall,
            t.headlineLarge,
            t.headlineMedium,
            t.headlineSmall,
            t.titleLarge,
            t.titleMedium,
            t.titleSmall,
            t.bodyLarge,
            t.bodyMedium,
            t.bodySmall,
            t.labelLarge,
            t.labelMedium,
            t.labelSmall,
          ];

      test('aucun créneau n\'est jamais aminci', () {
        // Le piège : `Text.build` fusionne `FontWeight.bold`, c'est-à-dire
        // w700 en dur, alors que Display est à 800 et Headline à 750–780. Un
        // correctif qui se contenterait d'aligner tout le monde sur w700
        // **amincirait** les six créneaux hauts. C'est exactement le motif
        // « déplacer un défaut » de §10.
        final List<TextStyle?> before = slots(PrismTypography.build(
          const Color(0xFF000000),
          const Color(0xFF444444),
        ));
        final List<TextStyle?> after = slots(PrismTypography.build(
          const Color(0xFF000000),
          const Color(0xFF444444),
          boldText: true,
        ));
        expect(before, hasLength(15));
        for (int i = 0; i < before.length; i++) {
          expect(
            weightOf(after[i]),
            greaterThan(weightOf(before[i])),
            reason: 'le créneau $i doit s\'alourdir, jamais s\'alléger',
          );
          expect(weightOf(after[i]), lessThanOrEqualTo(900));
        }
      });

      test('la hiérarchie des graisses survit', () {
        // Un w700 uniforme aplatirait Display, Headline et Title sur une seule
        // valeur : la hiérarchie que §6 fait porter par le poids disparaîtrait
        // au moment précis où l'utilisateur demande plus de lisibilité.
        final TextTheme bold = PrismTypography.build(
          const Color(0xFF000000),
          const Color(0xFF444444),
          boldText: true,
        );
        expect(weightOf(bold.displayLarge), greaterThan(weightOf(bold.headlineMedium)));
        expect(weightOf(bold.headlineMedium), greaterThan(weightOf(bold.titleLarge)));
        expect(weightOf(bold.titleLarge), greaterThan(weightOf(bold.bodyLarge)));
      });

      test('le corps atteint exactement la graisse que Flutter visait', () {
        // `Text.build` applique `FontWeight.bold` = w700. Le corps y arrive
        // donc par le même chemin, sans que les créneaux lourds y soient
        // écrasés.
        final TextTheme bold = PrismTypography.build(
          const Color(0xFF000000),
          const Color(0xFF444444),
          boldText: true,
        );
        expect(weightOf(bold.bodyLarge), 700);
      });
    });
  });
}
