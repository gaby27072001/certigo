#!/usr/bin/env node
// Calcul de contraste WCAG 2.1 sur les couleurs réellement composées.
//
// Invariant que cet outil existe pour couvrir : les couleurs de Prism ne sont
// presque jamais opaques au point d'usage. Une bordure s'écrit
// `Border.all(color: tone.withOpacity(0.30))`, un fond
// `Color.alphaBlend(tone.withOpacity(0.12), p.surface)`. Un vérificateur de
// contraste générique — extension de navigateur, service en ligne, linter — ne
// sait pas ce qu'il y a DERRIÈRE ces couches : il lit `#0078D4` et annonce
// 4.53:1 contre du blanc, alors que le pixel affiché est `#9CCBEF` et que le
// rapport réel contre son propre fond est 1.46:1.
//
// L'écart n'est pas marginal, il inverse la conclusion : le premier chiffre
// passe le seuil AA, le second est trois fois en dessous. C'est exactement le
// défaut « les boutons sont mal détourés » signalé sur l'app, et il est
// invisible pour tout outil qui ne recompose pas les couches.
//
// Cet outil recompose donc la pile avant de mesurer, avec la même arithmétique
// que `Color.alphaBlend` de Flutter, de sorte que le nombre rendu décrit le
// pixel affiché et non le jeton d'origine.
//
// Validation contre des pixels réels (audit visuel du 2026-09-10). Sept
// rapports calculés ont été confrontés à un balayage de captures d'un rendu
// Flutter (Accueil et Profil, 393x852, thème clair) :
//
//   carte vs page                    1.05   mesuré 1.05
//   bordure vs page                  1.18   mesuré 1.18
//   bordure vs carte                 1.23   mesuré 1.23
//   fond secondaire vs page          1.12   mesuré 1.12
//   bordure secondaire vs page       1.64   mesuré 1.65
//   bordure secondaire vs son fond   1.46   mesuré 1.47
//   libellé secondaire vs son fond   3.86   mesuré 3.86
//
// Écart maximal : 0,01. La composition prédit même la couleur exacte du pixel :
// le fond du bouton secondaire est calculé `#E0EFFA` et rendu `#E0EFFA` ; sa
// bordure est calculée `#9DCBEE` et rendue `#9CCBEF`, soit 1/255 d'écart
// imputable à l'arrondi du moteur de rendu.
//
// Ces sept valeurs sont figées dans `tools/tests/contrast.test.mjs` : si elles
// cassent, c'est l'arithmétique de cet outil qui a dérivé, pas le design system.
//
// Usage :
//   node tools/contrast.mjs '#0B1120' '#F8FAFD'
//   node tools/contrast.mjs '#0078D4@0.30' --over '#0078D4@0.12' '#FFFFFF'
//   node tools/contrast.mjs --large '#53607A' '#FFFFFF'
//
// La syntaxe `COULEUR@ALPHA` déclare une couche translucide ; `--over` empile
// les couches de la plus haute à la plus basse, la dernière devant être opaque.
// Le code de sortie vaut 0 si le seuil est atteint, 1 sinon — utilisable tel
// quel dans un script de vérification.

/** Seuils WCAG 2.1 niveau AA. */
export const WCAG_AA_TEXT = 4.5;
export const WCAG_AA_LARGE = 3.0;
/** Éléments non textuels : bordures, contours de focus, indicateurs d'état. */
export const WCAG_AA_NON_TEXT = 3.0;

/**
 * Accepte `#RGB`, `#RRGGBB`, `#AARRGGBB` et la forme Dart `0xAARRGGBB` — c'est
 * ainsi que les jetons sont écrits dans `packages/prism_ui/lib/src/tokens/`,
 * ce qui permet de copier une constante sans la retranscrire.
 */
export function parseColor(input) {
  if (input && typeof input === 'object') {
    const { r, g, b, a = 1 } = input;
    return { r, g, b, a };
  }
  let text = String(input).trim();
  let alpha = null;

  const at = text.indexOf('@');
  if (at !== -1) {
    alpha = Number(text.slice(at + 1));
    if (!Number.isFinite(alpha) || alpha < 0 || alpha > 1) {
      throw new Error(`Alpha invalide dans « ${input} » : attendu entre 0 et 1.`);
    }
    text = text.slice(0, at);
  }

  text = text.replace(/^0x/i, '').replace(/^#/, '');
  if (text.length === 3) {
    text = text
      .split('')
      .map((c) => c + c)
      .join('');
  }
  if (text.length === 6) text = `ff${text}`;
  if (text.length !== 8 || !/^[0-9a-f]{8}$/i.test(text)) {
    throw new Error(`Couleur invalide : « ${input} ».`);
  }

  const value = Number.parseInt(text, 16);
  const color = {
    a: ((value >>> 24) & 0xff) / 255,
    r: (value >>> 16) & 0xff,
    g: (value >>> 8) & 0xff,
    b: value & 0xff,
  };
  return alpha === null ? color : { ...color, a: alpha };
}

export function withAlpha(color, alpha) {
  return { ...parseColor(color), a: alpha };
}

/**
 * Compose `foreground` sur `background`, équivalent de `Color.alphaBlend`.
 * `background` doit être opaque : c'est ce que garantit [flatten].
 */
export function alphaBlend(foreground, background) {
  const f = parseColor(foreground);
  const b = parseColor(background);
  return {
    a: 1,
    r: f.r * f.a + b.r * (1 - f.a),
    g: f.g * f.a + b.g * (1 - f.a),
    b: f.b * f.a + b.b * (1 - f.a),
  };
}

/**
 * Aplatit une pile de couches en une seule couleur opaque.
 *
 * L'ordre suit la lecture visuelle : `layers[0]` est la couche du dessus,
 * la dernière est le fond et doit être opaque. C'est cette fonction qui
 * distingue l'outil d'un calculateur naïf.
 */
export function flatten(layers) {
  if (!Array.isArray(layers) || layers.length === 0) {
    throw new Error('flatten attend au moins une couche.');
  }
  const stack = layers.map(parseColor);
  const base = stack[stack.length - 1];
  if (base.a !== 1) {
    throw new Error(
      `La couche la plus basse doit être opaque (alpha 1), reçue ${base.a}. ` +
        'Sans fond opaque, le pixel affiché est indéterminé.',
    );
  }
  let result = base;
  for (let i = stack.length - 2; i >= 0; i -= 1) {
    result = alphaBlend(stack[i], result);
  }
  return result;
}

/** Luminance relative WCAG 2.1. La couleur doit être opaque. */
export function relativeLuminance(color) {
  const c = parseColor(color);
  if (c.a !== 1) {
    throw new Error(
      'relativeLuminance exige une couleur opaque : aplatis la pile avec flatten() ' +
        'avant de mesurer, sinon le chiffre ne décrit aucun pixel réel.',
    );
  }
  const channel = (v) => {
    const s = v / 255;
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/** Rapport de contraste WCAG 2.1, entre 1 et 21. Les deux couleurs sont opaques. */
export function contrastRatio(a, b) {
  const [high, low] = [relativeLuminance(a), relativeLuminance(b)].sort((x, y) => y - x);
  return (high + 0.05) / (low + 0.05);
}

export function formatHex(color) {
  const c = parseColor(color);
  const hex = (v) => Math.round(v).toString(16).padStart(2, '0');
  return `#${hex(c.r)}${hex(c.g)}${hex(c.b)}`.toUpperCase();
}

/**
 * Mesure un couple premier-plan / arrière-plan, chacun pouvant être une pile.
 * Retourne le rapport, le seuil retenu et le verdict.
 */
export function evaluate({ foreground, background, threshold = WCAG_AA_TEXT }) {
  const fg = Array.isArray(foreground) ? flatten(foreground) : parseColor(foreground);
  const bg = Array.isArray(background) ? flatten(background) : parseColor(background);
  const ratio = contrastRatio(fg, bg);
  return {
    ratio,
    threshold,
    passes: ratio >= threshold,
    foreground: formatHex(fg),
    background: formatHex(bg),
  };
}

function usage() {
  return [
    'Calcul de contraste WCAG 2.1 sur les couleurs réellement composées.',
    '',
    'Usage :',
    "  node tools/contrast.mjs <premier-plan> <arrière-plan> [--large|--non-text]",
    "  node tools/contrast.mjs <premier-plan> --over <couche…> <fond-opaque>",
    '',
    'Couleurs : #RGB, #RRGGBB, #AARRGGBB, 0xAARRGGBB (forme Dart).',
    'Suffixe @ALPHA pour une couche translucide, ex. « #0078D4@0.30 ».',
    '',
    'Exemples :',
    "  node tools/contrast.mjs '#0B1120' '#F8FAFD'",
    "  node tools/contrast.mjs '#0078D4@0.30' --over '#0078D4@0.12' '#FFFFFF'",
  ].join('\n');
}

export function runCli(argv) {
  const args = argv.slice();
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    return { text: usage(), code: 0 };
  }

  let threshold = WCAG_AA_TEXT;
  let thresholdLabel = 'AA texte';
  const flags = new Set();
  for (const flag of ['--large', '--non-text']) {
    const index = args.indexOf(flag);
    if (index !== -1) {
      flags.add(flag);
      args.splice(index, 1);
    }
  }
  if (flags.has('--large')) {
    threshold = WCAG_AA_LARGE;
    thresholdLabel = 'AA texte large';
  }
  if (flags.has('--non-text')) {
    threshold = WCAG_AA_NON_TEXT;
    thresholdLabel = 'AA non textuel';
  }

  const overIndex = args.indexOf('--over');
  let foreground;
  let background;
  if (overIndex === -1) {
    if (args.length !== 2) {
      return { text: `Deux couleurs attendues.\n\n${usage()}`, code: 2 };
    }
    [foreground, background] = args;
  } else {
    const head = args.slice(0, overIndex);
    const tail = args.slice(overIndex + 1);
    if (head.length !== 1 || tail.length === 0) {
      return { text: `Forme attendue : <couleur> --over <couches…>.\n\n${usage()}`, code: 2 };
    }
    // Le premier plan est la couche du dessus, posée sur la pile fournie.
    foreground = [head[0], ...tail];
    background = tail;
  }

  const result = evaluate({ foreground, background, threshold });
  const lines = [
    `premier-plan composé : ${result.foreground}`,
    `arrière-plan composé : ${result.background}`,
    `rapport              : ${result.ratio.toFixed(2)}:1`,
    `seuil (${thresholdLabel})  : ${threshold.toFixed(1)}:1`,
    `verdict              : ${result.passes ? 'CONFORME' : 'ÉCHEC'}`,
  ];
  return { text: lines.join('\n'), code: result.passes ? 0 : 1 };
}

const isMain = process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href;
if (isMain) {
  try {
    const { text, code } = runCli(process.argv.slice(2));
    console.log(text);
    process.exitCode = code;
  } catch (error) {
    console.error(String(error.message ?? error));
    process.exitCode = 2;
  }
}
