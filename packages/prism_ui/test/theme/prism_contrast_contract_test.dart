import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

/// Contrat de contraste sur les **rôles sémantiques résolus**.
///
/// Pourquoi ce test existe — la régression qu'il ferme :
///
/// La refonte visuelle a construit trois rôles par accent (`ink`, `vivid`,
/// `glow`) puis a fait pointer les tokens sémantiques sur `ink` **dans les deux
/// thèmes**. C'est correct pour un aplat, qui se pose par-dessus le chrome.
/// C'est faux pour un premier plan, et le premier plan est le cas courant :
/// mesuré sur l'arbre, **108 usages en couleur de premier plan contre 6 aplats
/// pleins**.
///
/// Résultat : six accents sur sept sont tombés entre 2.6:1 et 3.1:1 en mode
/// sombre — sous le seuil des icônes, a fortiori sous celui du texte — alors
/// que le mode sombre est le défaut livré (`ThemeMode.system`).
///
/// Les tests existants ne l'ont pas vu parce qu'ils vérifiaient les
/// **primitives** (`PrismColors.spectrumGlow` contre le fond sombre) et jamais
/// les **rôles résolus** que lisent réellement les widgets. Ce fichier comble
/// exactement cet angle mort : il interroge `PrismColorScheme.light` et
/// `.dark` comme le ferait un site d'appel.
double _luminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const Map<String, PrismColorScheme> schemes = <String, PrismColorScheme>{
    'clair': PrismColorScheme.light,
    'sombre': PrismColorScheme.dark,
  };

  /// Les accents tels qu'un site d'appel naïf les écrit : `color: p.error`.
  Map<String, Color> foregrounds(PrismColorScheme p) => <String, Color>{
        'primary': p.primary,
        'ember': p.ember,
        'xpGold': p.xpGold,
        'success': p.success,
        'warning': p.warning,
        'error': p.error,
        'info': p.info,
        'primaryOnSurface': p.primaryOnSurface,
        'emberOnSurface': p.emberOnSurface,
        'xpGoldOnSurface': p.xpGoldOnSurface,
        'successOnSurface': p.successOnSurface,
        'warningOnSurface': p.warningOnSurface,
        'errorOnSurface': p.errorOnSurface,
        'infoOnSurface': p.infoOnSurface,
        'textPrimary': p.textPrimary,
        'textSecondary': p.textSecondary,
      };

  Map<String, Color> fills(PrismColorScheme p) => <String, Color>{
        'primaryFill': p.primaryFill,
        'emberFill': p.emberFill,
        'xpGoldFill': p.xpGoldFill,
        'successFill': p.successFill,
        'warningFill': p.warningFill,
        'errorFill': p.errorFill,
        'infoFill': p.infoFill,
      };

  schemes.forEach((String themeName, PrismColorScheme p) {
    group('thème $themeName', () {
      test('chaque rôle de premier plan est lisible sur la carte', () {
        foregrounds(p).forEach((String name, Color c) {
          expect(
            contrast(c, p.surface),
            greaterThanOrEqualTo(4.5),
            reason: '$name sur `surface` en $themeName',
          );
        });
      });

      test('chaque rôle de premier plan est lisible sur la page', () {
        foregrounds(p).forEach((String name, Color c) {
          expect(
            contrast(c, p.background),
            greaterThanOrEqualTo(4.5),
            reason: '$name sur `background` en $themeName',
          );
        });
      });

      test('chaque rôle de premier plan est lisible sur la surface alternative', () {
        foregrounds(p).forEach((String name, Color c) {
          expect(
            contrast(c, p.surfaceAlt),
            greaterThanOrEqualTo(4.5),
            reason: '$name sur `surfaceAlt` en $themeName',
          );
        });
      });

      test('chaque rôle de premier plan est lisible sur le verre', () {
        // Le verre est la surface de la barre d'onglets et des cartes
        // flottantes ; c'est là que la barre sélectionnée mesurait 2.39:1.
        final Color glass = Color.alphaBlend(p.glassFill, p.background);
        foregrounds(p).forEach((String name, Color c) {
          expect(
            contrast(c, glass),
            greaterThanOrEqualTo(4.5),
            reason: '$name sur le verre en $themeName',
          );
        });
      });

      test('chaque aplat porte son texte', () {
        fills(p).forEach((String name, Color c) {
          expect(
            contrast(c, p.onPrimary),
            greaterThanOrEqualTo(4.5),
            reason: '$name doit porter `onPrimary` en $themeName',
          );
        });
      });

      test('chaque accent de domaine est lisible comme premier plan', () {
        for (int i = 0; i < 6; i++) {
          expect(
            contrast(p.accentOnSurfaceFor(i), p.surface),
            greaterThanOrEqualTo(4.5),
            reason: 'accent de domaine $i en $themeName',
          );
        }
      });

      test('chaque couche d\'état se voit sur le verre', () {
        // Une couche d'état qui ne déplace pas la surface n'existe pas. Le fond
        // sélectionné de la barre d'onglets mesurait 1.004:1 en sombre.
        final Color glass = Color.alphaBlend(p.glassFill, p.background);
        for (final MapEntry<String, Color> e in <String, Color>{
          'hover': p.hoverOn(glass),
          'pressed': p.pressedOn(glass),
          'selected': p.selectedOn(glass),
        }.entries) {
          expect(
            contrast(e.value, glass),
            greaterThanOrEqualTo(1.04),
            reason: '${e.key} sur le verre en $themeName',
          );
        }
      });

      test('le texte désactivé reste du texte', () {
        expect(contrast(p.textDisabled, p.surface), greaterThanOrEqualTo(3.0));
      });
    });
  });

  test('une teinte interactive s\'adapte entre les apparences', () {
    // L'assertion inverse — « light et dark partagent le primaire de marque » —
    // encodait le bug. Une teinte interactive doit changer d'apparence, comme
    // `systemBlue` chez Apple ; c'est l'aplat qui reste stable.
    expect(PrismColorScheme.light.primary, isNot(PrismColorScheme.dark.primary));
    expect(PrismColorScheme.light.error, isNot(PrismColorScheme.dark.error));
    expect(PrismColorScheme.light.primaryFill, PrismColorScheme.dark.primaryFill);
    expect(PrismColorScheme.light.errorFill, PrismColorScheme.dark.errorFill);
  });
}
