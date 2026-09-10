import assert from 'node:assert/strict';
import test from 'node:test';

import {
  WCAG_AA_NON_TEXT,
  WCAG_AA_TEXT,
  alphaBlend,
  contrastRatio,
  evaluate,
  flatten,
  formatHex,
  parseColor,
  relativeLuminance,
  runCli,
} from '../contrast.mjs';

const round = (value) => Number(value.toFixed(2));

test('parse les formes hexadécimales, dont la forme Dart 0xAARRGGBB', () => {
  assert.deepEqual(parseColor('#FFFFFF'), { a: 1, r: 255, g: 255, b: 255 });
  assert.deepEqual(parseColor('#FFF'), { a: 1, r: 255, g: 255, b: 255 });
  // Telle qu'écrite dans packages/prism_ui/lib/src/tokens/prism_colors.dart.
  assert.deepEqual(parseColor('0xFF0078D4'), { a: 1, r: 0, g: 120, b: 212 });
  assert.equal(parseColor('#0078D4@0.3').a, 0.3);
});

test('rejette une couleur ou un alpha invalides', () => {
  assert.throws(() => parseColor('#12345'), /Couleur invalide/);
  assert.throws(() => parseColor('#0078D4@2'), /Alpha invalide/);
});

test('les valeurs de référence WCAG sont exactes', () => {
  assert.equal(round(contrastRatio('#000000', '#FFFFFF')), 21);
  assert.equal(round(contrastRatio('#FFFFFF', '#FFFFFF')), 1);
  assert.equal(round(relativeLuminance('#FFFFFF')), 1);
  assert.equal(round(relativeLuminance('#000000')), 0);
});

test('refuse de mesurer une couleur translucide plutôt que de rendre un chiffre faux', () => {
  // Le cœur du sujet : mesurer #0078D4@0.3 sans son fond ne décrit aucun pixel.
  assert.throws(() => relativeLuminance('#0078D4@0.3'), /couleur opaque/);
});

test('flatten exige un fond opaque', () => {
  assert.throws(() => flatten(['#0078D4@0.3', '#FFFFFF@0.5']), /doit être opaque/);
});

test('alphaBlend reproduit Color.alphaBlend de Flutter', () => {
  // 50 % de noir sur blanc = gris moyen exact.
  assert.equal(formatHex(alphaBlend('#000000@0.5', '#FFFFFF')), '#808080');
  // Un premier plan opaque masque entièrement son fond.
  assert.equal(formatHex(alphaBlend('#0078D4', '#FFFFFF')), '#0078D4');
});

// --- La propriété qui distingue cet outil d'un calculateur naïf --------------
//
// Ces trois assertions décrivent le même bouton secondaire de Prism
// (`prism_button.dart`, variante `secondary`) :
//   fond    = alphaBlend(primary@0.12, surface)
//   bordure = primary@0.30 posée sur ce fond
//
// Un vérificateur générique lit le jeton `#0078D4` et conclut 4.53:1 contre du
// blanc — conforme. L'outil recompose et trouve 1.46:1 contre le fond réel —
// trois fois sous le seuil. C'est la même bordure ; seul le second chiffre
// décrit ce que l'œil voit.
test('recomposer les couches inverse la conclusion sur la bordure secondaire', () => {
  const surface = '#FFFFFF';
  const fill = flatten(['#0078D4@0.12', surface]);
  const border = flatten(['#0078D4@0.30', fill]);

  const naif = contrastRatio('#0078D4', surface);
  const reel = contrastRatio(border, fill);

  assert.equal(round(naif), 4.53, 'lecture naïve du jeton');
  assert.equal(round(reel), 1.46, 'bordure recomposée contre son propre fond');

  assert.ok(naif >= WCAG_AA_TEXT, 'la lecture naïve passe le seuil');
  assert.ok(reel < WCAG_AA_NON_TEXT, 'la mesure réelle échoue au seuil');
});

// --- Les sept rapports validés contre les pixels réels -----------------------
//
// Audit visuel du 2026-09-10 : ces valeurs calculées ont été confrontées à un
// balayage de pixels d'un rendu Flutter réel (Accueil et Profil, 393x852, thème
// clair). Écart maximal constaté : 0,01. Le balayage de l'Accueil donne
//   x=0..39 #F8FAFD (page) | x=40..41 #E2E8F2 (bordure) | x=42.. #FFFFFF (carte)
// soit une carte séparée de la page par un seul pixel logique.
//
// Ces assertions figent donc l'accord entre le calcul et le rendu : si elles
// cassent, c'est l'arithmétique de l'outil qui a dérivé, pas le design system.
test('les sept rapports validés au pixel restent reproduits', () => {
  const page = '#F8FAFD'; // PrismColors.lightBg
  const surface = '#FFFFFF'; // PrismColors.lightSurface
  const border = '#E2E8F2'; // PrismColors.lightBorder
  const primary = '#0078D4'; // PrismColors.primary

  const secondaryFill = flatten([`${primary}@0.12`, surface]);
  const secondaryBorder = flatten([`${primary}@0.30`, secondaryFill]);

  const measured = [
    ['carte vs page', contrastRatio(surface, page), 1.05],
    ['bordure vs page', contrastRatio(border, page), 1.18],
    ['bordure vs carte', contrastRatio(border, surface), 1.23],
    ['fond secondaire vs page', contrastRatio(secondaryFill, page), 1.12],
    ['bordure secondaire vs page', contrastRatio(secondaryBorder, page), 1.64],
    ['bordure secondaire vs son fond', contrastRatio(secondaryBorder, secondaryFill), 1.46],
    ['libellé secondaire vs son fond', contrastRatio(primary, secondaryFill), 3.86],
  ];

  for (const [label, actual, expected] of measured) {
    assert.equal(round(actual), expected, label);
  }
});

test('evaluate rend le verdict et les couleurs composées', () => {
  const result = evaluate({
    foreground: ['#0078D4@0.30', '#0078D4@0.12', '#FFFFFF'],
    background: ['#0078D4@0.12', '#FFFFFF'],
    threshold: WCAG_AA_NON_TEXT,
  });
  assert.equal(round(result.ratio), 1.46);
  assert.equal(result.passes, false);
  assert.match(result.foreground, /^#[0-9A-F]{6}$/);
});

test('la CLI mesure une paire simple et sort en échec sous le seuil', () => {
  const ok = runCli(['#0B1120', '#F8FAFD']);
  assert.equal(ok.code, 0);
  assert.match(ok.text, /18\.01:1/);
  assert.match(ok.text, /CONFORME/);

  const ko = runCli(['#E2E8F2', '#FFFFFF', '--non-text']);
  assert.equal(ko.code, 1);
  assert.match(ko.text, /1\.23:1/);
  assert.match(ko.text, /ÉCHEC/);
});

test('la CLI empile les couches avec --over', () => {
  const result = runCli(['#0078D4@0.30', '--over', '#0078D4@0.12', '#FFFFFF']);
  assert.match(result.text, /1\.46:1/);
});

test('la CLI explique son usage plutôt que de deviner', () => {
  assert.equal(runCli([]).code, 0);
  assert.match(runCli([]).text, /Usage/);
  assert.equal(runCli(['#FFFFFF']).code, 2);
});

test('le seuil AA texte reste la valeur par défaut', () => {
  assert.equal(WCAG_AA_TEXT, 4.5);
  const result = evaluate({ foreground: '#53607A', background: '#FFFFFF' });
  assert.equal(result.threshold, 4.5);
  assert.equal(result.passes, true);
});
