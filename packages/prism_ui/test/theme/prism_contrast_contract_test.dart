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
/// exactement cet angle mort : il interroge `PrismColorScheme.resolve` comme le
/// ferait un site d'appel.
///
/// ## Huit combinaisons, pas quatre
///
/// Le système portait deux apparences ; il en porte **huit** depuis que
/// `highContrast` et `reduceTransparency` sont des axes. §10 de `DESIGN.md`
/// documente la leçon payée deux fois : *« un correctif qui déplace un défaut
/// d'un endroit à un autre n'est pas un correctif tant qu'on n'a pas énuméré
/// les deux côtés »* — le contraste sombre avait été corrigé pour 108 sites de
/// premier plan **en cassant 6 sites d'aplat**.
///
/// Traiter quatre combinaisons en supposant que les quatre autres suivent
/// serait exactement cette faute. Les huit sont donc énumérées ici, une fois,
/// et chaque assertion les parcourt toutes.
double _luminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Une des huit apparences livrées.
@immutable
class Appearance {
  const Appearance(this.brightness, {this.highContrast = false, this.reduceTransparency = false});

  final Brightness brightness;
  final bool highContrast;
  final bool reduceTransparency;

  PrismColorScheme get scheme => PrismColorScheme.resolve(
        brightness: brightness,
        highContrast: highContrast,
        reduceTransparency: reduceTransparency,
      );

  /// Le pixel réellement affiché par le verre.
  ///
  /// Sous Reduce Transparency `glassFill` est déjà opaque, et
  /// `Color.alphaBlend` d'une couche opaque rend cette couche : la même
  /// expression décrit donc les deux cas sans les distinguer.
  Color get glass => Color.alphaBlend(scheme.glassFill, scheme.background);

  /// Plancher du texte sur la carte et la page.
  double get textFloor => highContrast ? 7.0 : 4.5;

  /// Plancher du texte sur la surface alternative et sur le verre.
  ///
  /// Il monte aussi sous Increase Contrast, mais **moins** : 7.0 n'y est pas
  /// atteignable sans vider le chroma. Mesuré, le pire rôle sur le verre
  /// sombre plafonne à 6.48 avec le déplacement retenu ; atteindre 7.00 y
  /// demanderait 0.32, c'est-à-dire faire converger les six bandes du spectre
  /// vers le blanc. La règle 5 de `DESIGN.md` — « la clarté organise ; le
  /// chroma réjouit » — coûte ici un point et demi de rapport, et c'est un
  /// arbitrage nommé, pas un oubli.
  double get textOnAltFloor => highContrast ? 5.5 : 4.5;

  double get fillFloor => highContrast ? 7.0 : 4.5;
  double get disabledFloor => highContrast ? 4.5 : 3.0;

  /// Plancher non textuel des arêtes du verre.
  ///
  /// Il monte dès que la translucidité tombe : le flou était un séparateur, et
  /// il vient de disparaître.
  double get glassEdgeFloor => highContrast || reduceTransparency ? 3.0 : 1.60;

  @override
  String toString() {
    final String base = brightness == Brightness.dark ? 'sombre' : 'clair';
    final List<String> axes = <String>[
      if (highContrast) 'contraste+',
      if (reduceTransparency) 'opaque',
    ];
    return axes.isEmpty ? base : '$base ${axes.join('+')}';
  }
}

/// Les huit, énumérées une fois.
const List<Appearance> kAppearances = <Appearance>[
  Appearance(Brightness.light),
  Appearance(Brightness.light, highContrast: true),
  Appearance(Brightness.light, reduceTransparency: true),
  Appearance(Brightness.light, highContrast: true, reduceTransparency: true),
  Appearance(Brightness.dark),
  Appearance(Brightness.dark, highContrast: true),
  Appearance(Brightness.dark, reduceTransparency: true),
  Appearance(Brightness.dark, highContrast: true, reduceTransparency: true),
];

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
      // Le podium entre ici parce qu'une médaille est un premier plan comme un
      // autre. Le littéral qu'elle remplace, `Color(0xFFB8C2D9)` écrit dans
      // l'écran de ligue, mesurait **1.79:1** sur la carte claire : hors du
      // système de couleurs, il était hors de portée de cette garde.
      'medalGold': p.medalFor(1)!,
      'medalSilver': p.medalFor(2)!,
      'medalBronze': p.medalFor(3)!,
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

void main() {
  test('les huit combinaisons sont bien huit et toutes distinctes', () {
    // Plancher de lecture : une garde qui parcourrait une liste vide passerait
    // au vert sans rien mesurer. §7 de `docs/GOVERNANCE.md` : un instrument qui
    // n'a rien lu doit échouer, pas rendre zéro.
    expect(kAppearances, hasLength(8));
    expect(
      kAppearances.map((Appearance a) => a.toString()).toSet(),
      hasLength(8),
      reason: 'Deux combinaisons portent le même nom : l\'énumération en cache une.',
    );
    expect(foregrounds(PrismColorScheme.light), isNotEmpty);
    expect(fills(PrismColorScheme.light), isNotEmpty);
  });

  for (final Appearance a in kAppearances) {
    group('apparence $a', () {
      final PrismColorScheme p = a.scheme;

      test('chaque rôle de premier plan est lisible sur la carte', () {
        foregrounds(p).forEach((String name, Color c) {
          expect(
            contrast(c, p.surface),
            greaterThanOrEqualTo(a.textFloor),
            reason: '$name sur `surface` en $a',
          );
        });
      });

      test('chaque rôle de premier plan est lisible sur la page', () {
        foregrounds(p).forEach((String name, Color c) {
          expect(
            contrast(c, p.background),
            greaterThanOrEqualTo(a.textFloor),
            reason: '$name sur `background` en $a',
          );
        });
      });

      test('chaque rôle de premier plan est lisible sur la surface alternative', () {
        foregrounds(p).forEach((String name, Color c) {
          expect(
            contrast(c, p.surfaceAlt),
            greaterThanOrEqualTo(a.textOnAltFloor),
            reason: '$name sur `surfaceAlt` en $a',
          );
        });
      });

      test('chaque rôle de premier plan est lisible sur le verre', () {
        // Le verre est la surface de la barre d'onglets et de l'entête ; c'est
        // là que la barre sélectionnée mesurait 2.39:1.
        foregrounds(p).forEach((String name, Color c) {
          expect(
            contrast(c, a.glass),
            greaterThanOrEqualTo(a.textOnAltFloor),
            reason: '$name sur le verre en $a',
          );
        });
      });

      test('chaque aplat porte son texte', () {
        fills(p).forEach((String name, Color c) {
          expect(
            contrast(c, p.onPrimary),
            greaterThanOrEqualTo(a.fillFloor),
            reason: '$name doit porter `onPrimary` en $a',
          );
        });
      });

      test('chaque accent de domaine est lisible comme premier plan', () {
        for (int i = 0; i < 6; i++) {
          expect(
            contrast(p.accentOnSurfaceFor(i), p.surface),
            greaterThanOrEqualTo(a.textFloor),
            reason: 'accent de domaine $i en $a',
          );
        }
      });

      test('chaque aplat de domaine porte son texte', () {
        for (int i = 0; i < 6; i++) {
          expect(
            contrast(p.accentFillFor(i), p.onPrimary),
            greaterThanOrEqualTo(a.fillFloor),
            reason: 'aplat de domaine $i en $a',
          );
        }
      });

      test('chaque couche d\'état se voit sur le verre', () {
        // Une couche d'état qui ne déplace pas la surface n'existe pas. Le fond
        // sélectionné de la barre d'onglets mesurait 1.004:1 en sombre.
        for (final MapEntry<String, Color> e in <String, Color>{
          'hover': p.hoverOn(a.glass),
          'pressed': p.pressedOn(a.glass),
          'selected': p.selectedOn(a.glass),
        }.entries) {
          expect(
            contrast(e.value, a.glass),
            greaterThanOrEqualTo(1.04),
            reason: '${e.key} sur le verre en $a',
          );
        }
      });

      test('le texte désactivé reste du texte', () {
        expect(
          contrast(p.textDisabled, p.surface),
          greaterThanOrEqualTo(a.disabledFloor),
          reason: 'textDisabled sur `surface` en $a',
        );
      });

      test('le verre reste un plan distinct de la page', () {
        // Le piège de §10 : rendre le verre opaque ne doit pas le faire
        // fusionner avec le fond qu'il survole. Le plancher est celui des
        // plans, déjà tenu par la carte.
        expect(
          contrast(a.glass, p.background),
          greaterThanOrEqualTo(1.12),
          reason: 'le verre doit rester un plan en $a',
        );
      });

      test('l\'arête du verre tient son seuil', () {
        final Color stroke = Color.alphaBlend(p.glassStroke, a.glass);
        expect(
          contrast(stroke, a.glass),
          greaterThanOrEqualTo(a.glassEdgeFloor),
          reason: 'le trait du verre en $a',
        );
      });

      test('l\'arête du verre reste directionnelle', () {
        // Règle 1 de §10 : en clair l'arête est plus SOMBRE que son fond, en
        // sombre plus CLAIRE. C'est le *sens* qui est gardé, pas seulement le
        // rapport — sans quoi le défaut d'origine pourrait revenir sous une
        // autre valeur.
        final Color stroke = Color.alphaBlend(p.glassStroke, a.glass);
        final bool isDark = p.brightness == Brightness.dark;
        expect(
          _luminance(stroke) < _luminance(a.glass),
          isDark ? isFalse : isTrue,
          reason: 'le trait du verre doit être ${isDark ? 'plus clair' : 'plus sombre'} '
              'que son fond en $a',
        );
      });

      test('le liseré de lumière reste un mécanisme de chrome sombre', () {
        // Mesuré : blanc à 0.55–0.85 d'alpha sur le fond de verre clair donne
        // 1.00:1. Le mode clair n'en porte donc pas. Un axe qui déplacerait
        // `litEdge` vers le noir lui donnerait un alpha et ferait apparaître un
        // liseré **sombre** en haut du verre clair — le défaut que §4 a
        // supprimé, réintroduit par la porte de service.
        if (p.brightness == Brightness.light) {
          expect(p.litEdge.a, 0, reason: 'litEdge doit rester transparent en $a');
        }
      });

      test('les deux axes sont ceux qui ont été demandés', () {
        expect(
          p.glassFill.a,
          a.reduceTransparency ? 1.0 : lessThan(1.0),
          reason: 'l\'opacité du verre en $a',
        );
        expect(p.reduceTransparency, a.reduceTransparency);
        expect(p.highContrast, a.highContrast);
      });
    });
  }

  group('les axes font vraiment quelque chose', () {
    // Une garde qui ne peut pas échouer est une décoration ; un axe qui ne
    // déplace rien en est une aussi. Ces tests échouent si `resolve` redevient
    // l'identité.
    for (final Brightness b in Brightness.values) {
      final String name = b == Brightness.dark ? 'sombre' : 'clair';

      test('Increase Contrast augmente chaque rôle de premier plan ($name)', () {
        final PrismColorScheme base = PrismColorScheme.resolve(brightness: b);
        final PrismColorScheme hc = PrismColorScheme.resolve(brightness: b, highContrast: true);
        final Map<String, Color> after = foregrounds(hc);
        foregrounds(base).forEach((String role, Color before) {
          expect(
            contrast(after[role]!, hc.surface),
            greaterThan(contrast(before, base.surface)),
            reason: '$role doit gagner du contraste sous Increase Contrast ($name)',
          );
        });
      });

      test('Increase Contrast ne touche ni les plans ni les lavis ($name)', () {
        // Le piège énuméré : pousser un lavis vers le blanc l'aurait rendu
        // identique à `surface` en clair. On garde donc les plans fixes, et on
        // le garde *explicitement*, pour que le choix soit un test et non un
        // souvenir.
        final PrismColorScheme base = PrismColorScheme.resolve(brightness: b);
        final PrismColorScheme hc = PrismColorScheme.resolve(brightness: b, highContrast: true);
        expect(hc.background, base.background);
        expect(hc.surface, base.surface);
        expect(hc.surfaceAlt, base.surfaceAlt);
        expect(hc.primarySoft, base.primarySoft);
        expect(hc.successSoft, base.successSoft);
        expect(hc.errorSoft, base.errorSoft);
      });

      test('Reduce Transparency ne touche que le verre ($name)', () {
        final PrismColorScheme base = PrismColorScheme.resolve(brightness: b);
        final PrismColorScheme rt =
            PrismColorScheme.resolve(brightness: b, reduceTransparency: true);
        expect(rt.glassFill, isNot(base.glassFill));
        expect(rt.glassStroke, isNot(base.glassStroke));
        // Les bordures de cartes ne bougent pas : le réglage n'a pas demandé
        // cela.
        expect(rt.border, base.border);
        expect(rt.borderStrong, base.borderStrong);
        expect(rt.textPrimary, base.textPrimary);
        expect(rt.primary, base.primary);
      });
    }

    test('sans réglage, `resolve` rend exactement les bases exportées', () {
      // L'export neutre vers le natif ne publie que `light` et `dark`. Si
      // `resolve` dérivait déjà sans axe actif, l'artefact décrirait une
      // apparence que l'application n'affiche jamais.
      expect(
        identical(PrismColorScheme.resolve(brightness: Brightness.light), PrismColorScheme.light),
        isTrue,
      );
      expect(
        identical(PrismColorScheme.resolve(brightness: Brightness.dark), PrismColorScheme.dark),
        isTrue,
      );
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
