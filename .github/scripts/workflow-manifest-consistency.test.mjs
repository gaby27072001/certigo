import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { parseDocument } from 'yaml';
import { validateAccountDeletionCosmosLayout } from './account-deletion-cosmos-policy.mjs';
import {
  parseGeneratorArguments,
  runManifestGenerator,
} from './generate-workflow-semantic-manifest.mjs';
import {
  extractManifestGoldenDigest,
  validateCandidateWorkflowManifest,
  validatePreApprovalChanges,
  validateWorkflowRemovals,
} from './workflow-manifest-consistency.mjs';
import {
  computeWorkflowStates,
  fingerprintWorkflow,
  lifecycleWorkflowNames,
  readRegularRepositoryFile,
  renderWorkflowManifest,
  validateWorkflowManifest,
} from './workflow-semantic-fingerprint.mjs';

// Ces tests tournent sur l'arbre de `main` à chaque PR : ils ne dépendent ni de la date du jour,
// ni d'un workflow précis du dépôt. Seuls les deux workflows Cosmos de cycle de vie sont repris
// tels quels, à leur emplacement courant, parce que leur contenu est scellé par le validateur.
const repositoryRoot = path.resolve('.');
const now = new Date('2026-09-23T12:00:00Z');
const dayMilliseconds = 24 * 60 * 60 * 1000;
const at = (days) => new Date(now.getTime() + days * dayMilliseconds);
const manifestFile = '.github/scripts/workflow-semantic-manifest.json';
const goldenFile = '.github/scripts/account-deletion-cosmos-policy.test.mjs';
const proposalsDirectory = '.github/workflows-proposed';

function workflow(name, marker) {
  return `name: ${name}
on:
  workflow_dispatch:
permissions:
  contents: read
jobs:
  check:
    runs-on: [self-hosted, Linux, X64, certigo-pr]
    steps:
      - run: echo ${marker}
`;
}

const alphaV1 = workflow('alpha', 'alpha-v1');
const alphaV2 = workflow('alpha', 'alpha-v2');
const alphaV3 = workflow('alpha', 'alpha-v3');
const betaV1 = workflow('beta', 'beta-v1');
const gammaV1 = workflow('gamma', 'gamma-v1');

function resolveIn(root, relativePath) {
  return path.join(root, ...relativePath.split('/'));
}

function read(root, relativePath) {
  return fs.readFileSync(resolveIn(root, relativePath), 'utf8');
}

function write(root, relativePath, content) {
  const destination = resolveIn(root, relativePath);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, content);
}

function digestOf(name, content) {
  return fingerprintWorkflow(`.github/workflows/${name}`, content).digest;
}

function syncGolden(root) {
  const digest = crypto.createHash('sha256').update(read(root, manifestFile)).digest('hex');
  write(root, goldenFile, `const manifestGoldenDigest = '${digest}';\n`);
}

function manifestOf(root) {
  return JSON.parse(read(root, manifestFile));
}

function generate(root, mode, options = {}) {
  const messages = [];
  const code = runManifestGenerator({
    root,
    mode,
    now,
    log: (message) => messages.push(message),
    print: (text) => messages.push(text),
    ...options,
  });
  return { code, messages };
}

// Juge `candidate` comme la CI le ferait avec `base` monté en contrôle trusted.
function judge(base, candidate, when = now) {
  const trustedManifestPath = resolveIn(base, manifestFile);
  return [
    ...validateAccountDeletionCosmosLayout(candidate, { manifestPath: trustedManifestPath, now: when }),
    ...validateCandidateWorkflowManifest(candidate),
    ...validatePreApprovalChanges(candidate, { trustedManifestPath, now: when }),
    ...validateWorkflowRemovals(candidate, { trustedManifestPath }),
  ];
}

function withTrees(callback) {
  const trees = [];
  const track = (root) => {
    trees.push(root);
    return root;
  };
  try {
    callback(track);
  } finally {
    for (const root of trees) {
      fs.rmSync(root, { recursive: true, force: true });
    }
  }
}

function makeRepository(track, workflows) {
  const root = track(fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-manifest-flow-')));
  fs.mkdirSync(resolveIn(root, '.github/workflows'), { recursive: true });
  for (const [name, content] of Object.entries(workflows)) {
    write(root, `.github/workflows/${name}`, content);
  }
  for (const directory of ['workflows', 'workflows-disabled']) {
    for (const name of lifecycleWorkflowNames) {
      const source = path.join(repositoryRoot, '.github', directory, name);
      if (fs.existsSync(source)) {
        write(root, `.github/${directory}/${name}`, fs.readFileSync(source, 'utf8'));
      }
    }
  }
  const tree = computeWorkflowStates(root);
  assert.deepEqual(tree.errors, []);
  write(root, manifestFile, renderWorkflowManifest({ states: tree.states, preApproved: {} }));
  syncGolden(root);
  return root;
}

function clone(track, root) {
  const copy = track(fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-manifest-flow-')));
  fs.cpSync(root, copy, { recursive: true });
  return copy;
}

// PR A : le changement est appliqué, pré-approuvé, puis le workflow est restauré.
function preApprove(track, main, name, content, options) {
  const approval = clone(track, main);
  const original = fs.existsSync(resolveIn(main, `.github/workflows/${name}`))
    ? read(main, `.github/workflows/${name}`)
    : null;
  if (content === null) {
    fs.rmSync(resolveIn(approval, `.github/workflows/${name}`));
  } else {
    write(approval, `.github/workflows/${name}`, content);
  }
  assert.equal(generate(approval, '--pre-approve', options).code, 0);
  if (original === null) {
    fs.rmSync(resolveIn(approval, `.github/workflows/${name}`));
  } else {
    write(approval, `.github/workflows/${name}`, original);
  }
  syncGolden(approval);
  return approval;
}

// PR B : le changement pré-approuvé est fusionné avec la sortie de `--write`.
function land(track, main, name, content) {
  const landing = clone(track, main);
  if (content === null) {
    fs.rmSync(resolveIn(landing, `.github/workflows/${name}`));
  } else {
    write(landing, `.github/workflows/${name}`, content);
  }
  assert.equal(generate(landing, '--write').code, 0);
  syncGolden(landing);
  return landing;
}

function unrelated(track, main) {
  const change = clone(track, main);
  write(change, 'docs/UNRELATED.md', 'A pull request that touches no workflow.\n');
  return change;
}

test('a workflow change lands through a pre-approval without ever leaving main inconsistent', () => {
  withTrees((track) => {
    const main0 = makeRepository(track, { 'alpha.yml': alphaV1, 'beta.yml': betaV1 });
    assert.deepEqual(judge(main0, main0), [], 'positive control: main describes itself');
    assert.deepEqual(judge(main0, unrelated(track, main0)), []);

    // L'ancien remède de #497 — faire tourner `states` sans le workflow — est désormais refusé.
    const rotation = clone(track, main0);
    write(rotation, '.github/workflows/alpha.yml', alphaV2);
    assert.equal(generate(rotation, '--write').code, 0);
    write(rotation, '.github/workflows/alpha.yml', alphaV1);
    syncGolden(rotation);
    const rotationErrors = judge(main0, rotation);
    assert.ok(rotationErrors.some((error) => (
      error.includes('does not describe the workflows of this branch') && error.includes('#497')
    )), rotationErrors.join('\n'));

    // Une PR unique ne peut toujours pas s'auto-approuver.
    const single = land(track, main0, 'alpha.yml', alphaV2);
    assert.ok(judge(main0, single).some((error) => (
      error.includes('.github/workflows/alpha.yml: differs from reviewed semantic manifest')
    )));

    // PR A : la pré-approbation montre le workflow futur en entier et ne change aucun workflow.
    const approval = preApprove(track, main0, 'alpha.yml', alphaV2);
    assert.equal(read(approval, `${proposalsDirectory}/alpha.yml`), alphaV2);
    assert.equal(read(approval, '.github/workflows/alpha.yml'), alphaV1);
    assert.deepEqual(manifestOf(approval).preApproved, {
      '.github/workflows/alpha.yml': {
        digest: digestOf('alpha.yml', alphaV2),
        expires: '2026-10-07',
      },
    });
    assert.deepEqual(judge(main0, approval), []);
    assert.equal(generate(approval, '--check').code, 0);

    const main1 = approval;
    assert.deepEqual(judge(main1, main1), [], 'main + A describes itself');
    assert.deepEqual(judge(main1, unrelated(track, main1)), []);
    const other = land(track, main1, 'alpha.yml', alphaV3);
    assert.ok(judge(main1, other).some((error) => (
      error.includes('alpha.yml: differs from reviewed semantic manifest and from its '
        + 'pre-approved digest')
    )));

    // PR B : le changement approuvé fusionne et consomme sa pré-approbation. Les commentaires
    // n'entrent pas dans l'empreinte sémantique.
    const landing = land(track, main1, 'alpha.yml', `# reviewed in pull request A\n${alphaV2}`);
    assert.deepEqual(judge(main1, landing), []);
    assert.deepEqual(manifestOf(landing).preApproved, {});
    assert.equal(
      manifestOf(landing).states.B['.github/workflows/alpha.yml'],
      digestOf('alpha.yml', alphaV2),
    );
    assert.equal(fs.existsSync(resolveIn(landing, proposalsDirectory)), false);

    const main2 = landing;
    assert.deepEqual(judge(main2, main2), [], 'main + A + B describes itself');
    assert.deepEqual(judge(main2, unrelated(track, main2)), []);
    // Usage unique : ni le retour à l'ancien contenu ni un nouveau changement ne passent sans
    // nouvelle pré-approbation.
    for (const content of [alphaV1, alphaV3]) {
      const change = land(track, main2, 'alpha.yml', content);
      assert.ok(judge(main2, change).some((error) => (
        error.includes('alpha.yml: differs from reviewed semantic manifest')
      )));
    }
  });
});

test('a pre-approval must show the exact future workflow, and nothing else', () => {
  withTrees((track) => {
    const main0 = makeRepository(track, { 'alpha.yml': alphaV1 });
    const approval = preApprove(track, main0, 'alpha.yml', alphaV2);

    const tampered = clone(track, approval);
    write(tampered, `${proposalsDirectory}/alpha.yml`, alphaV3);
    assert.ok(judge(main0, tampered).some((error) => (
      error.includes(`${proposalsDirectory}/alpha.yml: proposal hashes to`)
    )));

    const hidden = clone(track, approval);
    fs.rmSync(resolveIn(hidden, `${proposalsDirectory}/alpha.yml`));
    assert.ok(judge(main0, hidden).some((error) => (
      error.includes('missing proposal for the pre-approval of .github/workflows/alpha.yml')
    )));

    const orphan = clone(track, approval);
    write(orphan, `${proposalsDirectory}/beta.yml`, betaV1);
    assert.ok(judge(main0, orphan).some((error) => (
      error.includes(`${proposalsDirectory}/beta.yml: orphan proposal`)
    )));

    const stray = clone(track, approval);
    write(stray, `${proposalsDirectory}/README.md`, 'not a workflow\n');
    assert.ok(judge(main0, stray).some((error) => error.includes('only workflow proposals')));
  });
});

test('a landing that keeps its pre-approval or its proposal is refused', () => {
  withTrees((track) => {
    const main0 = makeRepository(track, { 'alpha.yml': alphaV1 });
    const main1 = preApprove(track, main0, 'alpha.yml', alphaV2);

    const unconsumed = clone(track, main1);
    write(unconsumed, '.github/workflows/alpha.yml', alphaV2);
    assert.ok(judge(main1, unconsumed).some((error) => (
      error.includes('its pre-approval has landed and must be consumed with --write')
    )));

    const keptProposal = land(track, main1, 'alpha.yml', alphaV2);
    write(keptProposal, `${proposalsDirectory}/alpha.yml`, alphaV2);
    assert.ok(judge(main1, keptProposal).some((error) => error.includes('orphan proposal')));
  });
});

test('an expired pre-approval approves nothing and never blocks an unrelated pull request', () => {
  withTrees((track) => {
    const main0 = makeRepository(track, { 'alpha.yml': alphaV1 });
    const main1 = preApprove(track, main0, 'alpha.yml', alphaV2);
    const expires = manifestOf(main1).preApproved['.github/workflows/alpha.yml'].expires;
    assert.equal(expires, '2026-10-07');

    const landing = land(track, main1, 'alpha.yml', alphaV2);
    assert.deepEqual(judge(main1, landing, new Date('2026-10-07T23:59:59Z')), []);
    assert.ok(judge(main1, landing, new Date('2026-10-08T00:00:00Z')).some((error) => (
      error.includes('its pre-approval expired on 2026-10-07 and must be renewed')
    )));

    // Le passage du temps ne doit jamais rougir `main` ni une PR qui ne touche aucun workflow.
    for (const days of [15, 365, 3650]) {
      assert.deepEqual(judge(main1, main1, at(days)), []);
      assert.deepEqual(judge(main1, unrelated(track, main1), at(days)), []);
    }

    // `--write` retire la pré-approbation expirée et sa proposition.
    const cleanup = clone(track, main1);
    assert.equal(generate(cleanup, '--write', { now: at(15) }).code, 0);
    syncGolden(cleanup);
    assert.deepEqual(manifestOf(cleanup).preApproved, {});
    assert.equal(fs.existsSync(resolveIn(cleanup, proposalsDirectory)), false);
    assert.deepEqual(judge(main1, cleanup, at(15)), []);
  });
});

test('a pre-approval added or changed by a pull request must expire within thirty days', () => {
  withTrees((track) => {
    const main0 = makeRepository(track, { 'alpha.yml': alphaV1 });
    const approval = preApprove(track, main0, 'alpha.yml', alphaV2, { expiresInDays: 30 });
    assert.deepEqual(judge(main0, approval), []);

    for (const expires of ['2026-10-24', '2026-09-22', '2027-09-23']) {
      const outOfWindow = clone(track, approval);
      const manifest = manifestOf(outOfWindow);
      manifest.preApproved['.github/workflows/alpha.yml'].expires = expires;
      write(outOfWindow, manifestFile, renderWorkflowManifest(manifest));
      syncGolden(outOfWindow);
      assert.ok(judge(main0, outOfWindow).some((error) => (
        error.includes('must expire between 2026-09-23 and 2026-10-23 (UTC)')
      )), expires);
    }

    // Une pré-approbation héritée telle quelle n'est jamais rejugée sur la date.
    assert.deepEqual(judge(approval, unrelated(track, approval), at(400)), []);
  });
});

test('additions and removals follow the same two steps', () => {
  withTrees((track) => {
    const main0 = makeRepository(track, { 'alpha.yml': alphaV1, 'beta.yml': betaV1 });

    const unapprovedAddition = land(track, main0, 'gamma.yml', gammaV1);
    assert.ok(judge(main0, unapprovedAddition).some((error) => (
      error.includes('exact reviewed state') && error.includes('unexpected gamma.yml')
    )));
    const addition = preApprove(track, main0, 'gamma.yml', gammaV1);
    assert.equal(read(addition, `${proposalsDirectory}/gamma.yml`), gammaV1);
    assert.deepEqual(judge(main0, addition), []);
    const added = land(track, addition, 'gamma.yml', gammaV1);
    assert.deepEqual(judge(addition, added), []);
    assert.deepEqual(manifestOf(added).preApproved, {});
    assert.deepEqual(judge(added, added), []);

    const unapprovedRemoval = land(track, added, 'beta.yml', null);
    assert.ok(judge(added, unapprovedRemoval).some((error) => error.includes('missing beta.yml')));
    const removal = preApprove(track, added, 'beta.yml', null);
    assert.deepEqual(manifestOf(removal).preApproved['.github/workflows/beta.yml'].digest, null);
    assert.equal(fs.existsSync(resolveIn(removal, `${proposalsDirectory}/beta.yml`)), false);
    assert.deepEqual(judge(added, removal), []);
    const removed = land(track, removal, 'beta.yml', null);
    assert.deepEqual(judge(removal, removed), []);
    assert.deepEqual(manifestOf(removed).preApproved, {});
    assert.deepEqual(judge(removed, removed), []);

    // Un script trusted qui cite encore un workflow retiré ferait échouer `main` après fusion.
    const referenced = clone(track, removal);
    write(referenced, '.github/scripts/example.test.mjs', "const target = 'beta.yml';\n");
    assert.ok(judge(added, referenced).some((error) => (
      error.includes('.github/scripts/example.test.mjs still references beta.yml')
    )));
  });
});

test('lifecycle workflows keep their contract and malformed manifests are refused', () => {
  withTrees((track) => {
    const main0 = makeRepository(track, { 'alpha.yml': alphaV1 });
    const reviewed = manifestOf(main0);
    const alphaPath = '.github/workflows/alpha.yml';
    const oneShotPath = `.github/workflows/${lifecycleWorkflowNames[1]}`;
    const cases = [
      [{ ...reviewed, schemaVersion: 1 }, 'unsupported schema'],
      [
        Object.fromEntries(Object.entries(reviewed).filter(([key]) => key !== 'preApproved')),
        'top-level contract must match exactly',
      ],
      [
        { ...reviewed, preApproved: { [oneShotPath]: { digest: null, expires: '2026-10-01' } } },
        'its removal cannot be pre-approved',
      ],
      [
        { ...reviewed, preApproved: { [oneShotPath]: { digest: reviewed.states.C[oneShotPath], expires: '2026-10-01' } } },
        'already matches the reviewed state',
      ],
      [
        { ...reviewed, preApproved: { [alphaPath]: { digest: reviewed.states.B[alphaPath], expires: '2026-10-01' } } },
        'already matches the reviewed state',
      ],
      [
        { ...reviewed, preApproved: { [alphaPath]: { digest: 'f'.repeat(64), expires: '2026-02-30' } } },
        'YYYY-MM-DD calendar date',
      ],
      [
        { ...reviewed, preApproved: { [alphaPath]: { expires: '2026-10-01', digest: 'f'.repeat(64) } } },
        'must be exactly { "digest", "expires" }',
      ],
      [
        { ...reviewed, preApproved: { [alphaPath]: { digest: 'F'.repeat(64), expires: '2026-10-01' } } },
        'must carry a SHA-256 digest',
      ],
    ];
    for (const [manifest, expected] of cases) {
      assert.ok(
        validateWorkflowManifest(manifest).some((error) => error.includes(expected)),
        expected,
      );
    }
    assert.deepEqual(validateWorkflowManifest({
      ...reviewed,
      preApproved: { [oneShotPath]: { digest: 'f'.repeat(64), expires: '2026-10-01' } },
    }), []);

    // Le contenu d'un workflow de cycle de vie peut être pré-approuvé, où qu'il soit rangé, mais
    // la fusion reste soumise au contrat exact que le code de la base impose à ce workflow.
    const activeOneShot = `.github/workflows/${lifecycleWorkflowNames[1]}`;
    const archivedOneShot = `.github/workflows-disabled/${lifecycleWorkflowNames[1]}`;
    const oneShotFile = fs.existsSync(resolveIn(main0, activeOneShot))
      ? activeOneShot
      : archivedOneShot;
    const oneShotDocument = parseDocument(read(main0, oneShotFile));
    oneShotDocument.set('env', oneShotDocument.createNode({ CHANGED: '1' }));
    const changedOneShot = oneShotDocument.toString();
    assert.notEqual(
      digestOf(lifecycleWorkflowNames[1], changedOneShot),
      digestOf(lifecycleWorkflowNames[1], read(main0, oneShotFile)),
    );
    const approval = clone(track, main0);
    write(approval, oneShotFile, changedOneShot);
    assert.equal(generate(approval, '--pre-approve').code, 0);
    write(approval, oneShotFile, read(main0, oneShotFile));
    syncGolden(approval);
    assert.equal(
      read(approval, `${proposalsDirectory}/${lifecycleWorkflowNames[1]}`),
      changedOneShot,
    );
    assert.deepEqual(judge(main0, approval), []);

    const landing = clone(track, approval);
    write(landing, oneShotFile, changedOneShot);
    assert.equal(generate(landing, '--write').code, 0);
    syncGolden(landing);
    assert.deepEqual(validateCandidateWorkflowManifest(landing), []);
    assert.ok(judge(approval, landing).some((error) => (
      error.includes('top-level workflow contract must match exactly')
    )));
  });
});

test('the guard never reads a symlinked proposal', (context) => {
  withTrees((track) => {
    const main0 = makeRepository(track, { 'alpha.yml': alphaV1 });
    const approval = preApprove(track, main0, 'alpha.yml', alphaV2);
    const outside = path.join(approval, 'outside.yml');
    fs.writeFileSync(outside, alphaV2);
    const link = resolveIn(approval, `${proposalsDirectory}/alpha.yml`);
    fs.rmSync(link);
    try {
      fs.symlinkSync(outside, link, 'file');
    } catch (error) {
      if (error.code === 'EPERM') {
        context.skip('file symlinks require Windows developer mode');
        return;
      }
      throw error;
    }
    assert.ok(judge(main0, approval).some((error) => (
      error.includes('must be a real regular non-symlink file')
    )));
  });
});

test('repository file reads stay bound to the verified regular-file descriptor', {
  timeout: 5000,
}, (context) => {
  withTrees((track) => {
    const root = track(fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-regular-file-')));
    const outside = track(fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-regular-file-outside-')));
    const regularPath = resolveIn(root, 'files/regular.txt');
    write(root, 'files/regular.txt', 'trusted contents');
    write(outside, 'outside.txt', 'outside contents');
    write(outside, 'regular.txt', 'substituted contents');
    assert.equal(readRegularRepositoryFile(root, 'files/regular.txt').content, 'trusted contents');
    assert.deepEqual(readRegularRepositoryFile(root, 'files/missing.txt'), { exists: false });
    assert.deepEqual(readRegularRepositoryFile(root, 'files/regular.txt/missing.txt'), { exists: false });
    assert.match(readRegularRepositoryFile(root, 'files').error, /regular non-symlink file/u);

    const fileLink = resolveIn(root, 'files/final-link.txt');
    try {
      fs.symlinkSync(resolveIn(outside, 'outside.txt'), fileLink, 'file');
    } catch (error) {
      if (error.code !== 'EPERM') throw error;
    }
    if (fs.existsSync(fileLink)) {
      assert.match(readRegularRepositoryFile(root, 'files/final-link.txt').error, /non-symlink/u);
    }

    const directoryLink = resolveIn(root, 'linked-files');
    try {
      fs.symlinkSync(outside, directoryLink, 'junction');
    } catch (error) {
      if (error.code !== 'EPERM') throw error;
    }
    if (fs.existsSync(directoryLink)) {
      assert.match(
        readRegularRepositoryFile(root, 'linked-files/outside.txt').error,
        /exact repository path/u,
      );
    }

    const filesDirectory = resolveIn(root, 'files');
    const filesBackup = resolveIn(root, 'files.verified');
    const originalOpen = fs.openSync;
    fs.openSync = (file, ...args) => {
      if (path.resolve(file) === path.resolve(regularPath)) {
        fs.renameSync(filesDirectory, filesBackup);
        fs.symlinkSync(outside, filesDirectory, 'junction');
      }
      return originalOpen.call(fs, file, ...args);
    };
    try {
      assert.match(
        readRegularRepositoryFile(root, 'files/regular.txt').error,
        /file (?:changed|path changed) while opening/u,
      );
    } finally {
      fs.openSync = originalOpen;
      fs.unlinkSync(filesDirectory);
      fs.renameSync(filesBackup, filesDirectory);
    }

    const backupPath = `${regularPath}.verified`;
    fs.openSync = (file, ...args) => {
      if (path.resolve(file) === path.resolve(regularPath)) {
        fs.renameSync(regularPath, backupPath);
        if (process.platform === 'win32') {
          fs.writeFileSync(regularPath, 'substituted contents');
        } else {
          execFileSync('mkfifo', [regularPath]);
        }
      }
      return originalOpen.call(fs, file, ...args);
    };
    try {
      assert.match(
        readRegularRepositoryFile(root, 'files/regular.txt').error,
        /file changed while opening/u,
      );
    } finally {
      fs.openSync = originalOpen;
      fs.rmSync(regularPath, { force: true });
      fs.renameSync(backupPath, regularPath);
    }
  });
});

test('a pending pre-approval on main cannot silence a base test that expects a rejection', () => {
  withTrees((track) => {
    const main0 = makeRepository(track, { 'alpha.yml': alphaV1 });
    const main1 = preApprove(track, main0, 'alpha.yml', alphaV2);
    // Exactement la mutation qu'un test de base attendrait refusée, déjà pré-approuvée sur main.
    const mutated = clone(track, main1);
    write(mutated, '.github/workflows/alpha.yml', alphaV2);
    assert.deepEqual(
      validateAccountDeletionCosmosLayout(mutated, {
        manifestPath: resolveIn(main1, manifestFile),
        now,
      }),
      [],
      'with the real manifest of main, the pre-approval makes the mutation acceptable',
    );
    // Les tests de base jugent donc leurs fixtures avec les seuls `states` revus.
    const stripped = path.join(track(fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-stripped-'))), 'manifest.json');
    fs.writeFileSync(
      stripped,
      renderWorkflowManifest({ states: manifestOf(main1).states, preApproved: {} }),
    );
    assert.ok(validateAccountDeletionCosmosLayout(mutated, { manifestPath: stripped, now })
      .some((error) => error.includes('alpha.yml: differs from reviewed semantic manifest')));
  });
});

test('the generator rejects ambiguous invocations and the golden reader is strict', () => {
  assert.deepEqual(parseGeneratorArguments([]), { mode: '--print', expiresInDays: 14 });
  assert.deepEqual(
    parseGeneratorArguments(['--pre-approve', '--expires-in-days', '7']),
    { mode: '--pre-approve', expiresInDays: 7 },
  );
  assert.deepEqual(
    parseGeneratorArguments(['--pre-approve', '--expires-in-days=30']),
    { mode: '--pre-approve', expiresInDays: 30 },
  );
  for (const argv of [
    ['--write', '--check'],
    ['--pre-approve', '--expires-in-days', '31'],
    ['--pre-approve', '--expires-in-days', '0'],
    ['--pre-approve', '--expires-in-days', 'soon'],
    ['--write', '--expires-in-days', '7'],
    ['--force'],
  ]) {
    assert.ok(parseGeneratorArguments(argv).error, argv.join(' '));
  }

  const declaration = `const manifestGoldenDigest = '${'a'.repeat(64)}';`;
  assert.equal(extractManifestGoldenDigest(`x\n${declaration}\ny\n`), 'a'.repeat(64));
  assert.equal(extractManifestGoldenDigest(`${declaration}\n${declaration}\n`), null);
  assert.equal(extractManifestGoldenDigest(`// ${declaration}\n`), null);
});
