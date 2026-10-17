import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  parseCanonicalWorkflow,
  readVerifiedRegularFileSync,
} from './workflow-semantic-fingerprint.mjs';

// Contrat exact de dart-sast.yml (finding D10, docs/runbooks/DART_SAST.md).
// Le verdict du job agrégé ne vaut que si le workflow est exactement l'une des formes relues de
// `dart-sast-workflow-forms/`, révisions d'actions comprises. Une politique par motifs se
// contournait sans rien casser de visible (relecture indépendante de #560) : `|| true`, second
// `--root`, variables d'environnement échangées, `shell:` ou `defaults`, `working-directory`,
// étape ajoutée avant le scan, gate sans `exit 1`. L'égalité est sémantique, par le parseur durci
// du manifeste (commentaires et ordre des clés ignorés ; ancres, alias, étiquettes, retours chariot
// et doublons refusés). Comme pour le contrat Cosmos, une évolution passe d'abord par une PR de
// code qui ajoute la nouvelle forme à côté de l'ancienne. Le contrat s'applique aussi à la
// proposition d'une pré-approbation (même nom de fichier), dès la PR A.
export const dartSastWorkflowFile = 'dart-sast.yml';
export const dartSastGateJobId = 'gate';
export const dartSastGateName = 'Dart SAST / Security gate';
export const dartSastWorkflowFormsDirectory = 'dart-sast-workflow-forms';

const formName = /^v[1-9][0-9]*\.yml$/u;

function formNumber(name) {
  return Number.parseInt(name.slice(1), 10);
}

export function loadDartSastWorkflowForms(
  directory = path.join(path.dirname(fileURLToPath(import.meta.url)), dartSastWorkflowFormsDirectory),
) {
  const names = fs.readdirSync(directory);
  if (names.length === 0 || names.some((name) => !formName.test(name))) {
    throw new Error(`${directory} must hold only reviewed forms named v<n>.yml, at least one`);
  }
  names.sort((left, right) => formNumber(left) - formNumber(right));
  return Object.freeze(names.map((name) => {
    const file = path.join(directory, name);
    const stat = fs.lstatSync(file);
    if (!stat.isFile() || stat.isSymbolicLink()) {
      throw new Error(`${file} must be a regular file`);
    }
    const text = readVerifiedRegularFileSync(file, stat).toString('utf8');
    const parsed = parseCanonicalWorkflow(text, file);
    if (parsed.errors.length > 0) {
      throw new Error(parsed.errors.join('\n'));
    }
    return Object.freeze({ name, text, serialized: parsed.serialized });
  }));
}

export const acceptedDartSastWorkflowForms = loadDartSastWorkflowForms();

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function firstDifference(expected, actual, at) {
  if (Array.isArray(expected) && Array.isArray(actual)) {
    for (let index = 0; index < Math.max(expected.length, actual.length); index += 1) {
      const next = `${at}[${index}]`;
      if (index >= expected.length || index >= actual.length) {
        return next;
      }
      const found = firstDifference(expected[index], actual[index], next);
      if (found) {
        return found;
      }
    }
    return null;
  }
  if (isPlainObject(expected) && isPlainObject(actual)) {
    const keys = [...new Set([...Object.keys(expected), ...Object.keys(actual)])].sort();
    for (const key of keys) {
      const next = at ? `${at}.${key}` : key;
      if (!Object.hasOwn(expected, key) || !Object.hasOwn(actual, key)) {
        return next;
      }
      const found = firstDifference(expected[key], actual[key], next);
      if (found) {
        return found;
      }
    }
    return null;
  }
  return Object.is(expected, actual) ? null : at || '(document)';
}

export function validateDartSastWorkflow(text, label = dartSastWorkflowFile, forms = acceptedDartSastWorkflowForms) {
  const parsed = parseCanonicalWorkflow(text, label);
  if (parsed.errors.length > 0) {
    return parsed.errors;
  }
  if (forms.some((form) => form.serialized === parsed.serialized)) {
    return [];
  }
  const newest = forms.at(-1);
  const where = firstDifference(JSON.parse(newest.serialized), JSON.parse(parsed.serialized), '');
  return [
    `${label}: the Dart SAST workflow must be exactly a reviewed form of `
      + `.github/scripts/${dartSastWorkflowFormsDirectory}/ (first difference with ${newest.name} `
      + `at ${where}); add the new form there in a code PR first (docs/runbooks/DART_SAST.md)`,
  ];
}
