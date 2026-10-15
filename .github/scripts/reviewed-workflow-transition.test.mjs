import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import YAML from 'yaml';
import {
  backendDeployTrustedFiles,
  isReviewedGenerationJob,
  isReviewedWorkflowTransition,
  validateBackendDeployWorkflow,
  validateBackendDeployWorkspace,
} from './backend-deploy-workflow-policy.mjs';
import {
  fingerprintWorkflow,
  proposalRelativePath,
  renderWorkflowManifest,
} from './workflow-semantic-fingerprint.mjs';
import { validateRunnerLabels } from './workflow-runner-labels.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const fixturesRoot = fs.mkdtempSync(path.join(root, '.post18-policy-tests-'));
test.after(() => fs.rmSync(fixturesRoot, { recursive: true, force: true }));
const manifestPath = '.github/scripts/workflow-semantic-manifest.json';
const workflowPath = (name) => `.github/workflows/${name}`;
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');
const now = new Date('2026-10-15T00:00:00Z');
const options = { now };

function groupedOutputs(old) {
  return `          {\n${old.trimEnd().split('\n').map(
    (line) => `${line.replace(/ +>> "\$GITHUB_OUTPUT"$/u, '').trimEnd().replace(/^ {10}/u, '            ')}`,
  ).join('\n')}\n          } >> "$GITHUB_OUTPUT"\n`;
}

const androidOutputs = [
  '          echo "build_name=$BUILD_NAME"   >> "$GITHUB_OUTPUT"',
  '          echo "build_number=$BUILD_NUMBER" >> "$GITHUB_OUTPUT"',
  '          echo "track=$TRACK"             >> "$GITHUB_OUTPUT"',
  '          echo "dry_run=$DRY_RUN"         >> "$GITHUB_OUTPUT"',
  '',
].join('\n');
const androidSummary = [
  '            echo "### ✅ AAB construit et signé" >> "$GITHUB_STEP_SUMMARY"',
  '            echo "| Champ | Valeur |" >> "$GITHUB_STEP_SUMMARY"',
  '            echo "|---|---|" >> "$GITHUB_STEP_SUMMARY"',
  '            echo "| Version | $BUILD_NAME+$BUILD_NUMBER |" >> "$GITHUB_STEP_SUMMARY"',
  '            echo "| Taille | $SIZE |" >> "$GITHUB_STEP_SUMMARY"',
  '            echo "| Chemin runner | $AAB_PATH |" >> "$GITHUB_STEP_SUMMARY"',
  '            echo "| Publication Play | $PUBLISHED |" >> "$GITHUB_STEP_SUMMARY"',
  '            echo "| Artefact | AAB signé conservé 90 jours |" >> "$GITHUB_STEP_SUMMARY"',
  '',
].join('\n');
const iosOutputs = [
  '          echo "build_name=$BUILD_NAME"     >> "$GITHUB_OUTPUT"',
  '          echo "build_number=$BUILD_NUMBER" >> "$GITHUB_OUTPUT"',
  '          echo "external=$REQUESTED_EXTERNAL" >> "$GITHUB_OUTPUT"',
  '          echo "dry_run=$REQUESTED_DRY_RUN" >> "$GITHUB_OUTPUT"',
  '',
].join('\n');
const oldKeychains = '            security list-keychains -d user -s "$KEYCHAIN" '
  + '$(security list-keychains -d user | sed \'s/[\\"[:space:]]//g\')';
const newKeychains = [
  '            EXISTING_KEYCHAINS=("$KEYCHAIN")',
  '            while IFS= read -r EXISTING_KEYCHAIN || [ -n "$EXISTING_KEYCHAIN" ]; do',
  '              if [ -n "$EXISTING_KEYCHAIN" ]; then',
  '                EXISTING_KEYCHAINS+=("$EXISTING_KEYCHAIN")',
  '              fi',
  '            done < <(security list-keychains -d user | sed -e \'s/^[[:space:]]*"//\' -e \'s/"[[:space:]]*$//\')',
  '            security list-keychains -d user -s "${EXISTING_KEYCHAINS[@]}"',
].join('\n');
const nodeStep = [
  '      - uses: actions/setup-node@249970729cb0ef3589644e2896645e5dc5ba9c38 # v6.5.0',
  '        with:',
  '          node-version: "20.20.2"',
  '',
].join('\n');
const specs = [
  {
    name: 'release-android.yml',
    old: '31817ce82c352a3659fa9cf071a57031edbaed6d33e476b24cd7715680137ed8',
    target: 'f38ef5e57d42f98054e0525b1222386e1966e6fb699f68d0e5698225d956c31a',
    edits: [
      [androidOutputs, groupedOutputs(androidOutputs)],
      [
        androidSummary,
        `            {\n${androidSummary.trimEnd().split('\n').map(
          (line) => `  ${line.replace(/ >> "\$GITHUB_STEP_SUMMARY"$/u, '')}`,
        ).join('\n')}\n            } >> "$GITHUB_STEP_SUMMARY"\n`,
      ],
    ],
  },
  {
    name: 'release-ios.yml',
    old: '849c84a181679db1df83121286b01d5471939d763588dab81ac07b6bcd97de54',
    target: 'a5cbc5a0b824f645a20a32e795ed07c0b53c89366e9de6fe4915550d45a8c44e',
    edits: [[iosOutputs, groupedOutputs(iosOutputs)], [oldKeychains, newKeychains]],
  },
  {
    name: 'ci-infra.yml',
    job: 'bicep-build',
    old: 'dfdd4ba04b743fdf7a92b03b5326c0bf090d0d646ce7acb9bcbcae015cca9326',
    target: 'a96d6a6e131e9c762a861ac763b0cd7ec3a3f284a927e124bd9c3c73d9c35494',
    edits: [
      ['    runs-on: [self-hosted, Linux, X64, certigo-pr]\n', '    runs-on: ubuntu-24.04\n'],
      [
        '      - name: Validate public account-deletion policy\n',
        '      - name: Install public-page test dependencies from lock\n'
          + '        run: npm ci --ignore-scripts\n'
          + '      - name: Test public account-deletion policy\n',
      ],
    ],
  },
  {
    name: 'deploy-privacy-policy.yml',
    job: 'build',
    old: '2e988a44f5c980d82784d1d8086904ed79fa45066f4dcac2bf34e01f62f7a3ce',
    target: '1ac309f8c301aa84d961445027574b7b2c20923b23010458de6cd11ed6dfafef',
    edits: [
      ['    runs-on: [self-hosted, Linux, X64, certigo-trusted]\n', '    runs-on: ubuntu-24.04\n'],
      ['      pages: write\n', '      pages: read\n'],
      [
        '      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0\n',
        '      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0\n'
          + '        with:\n          ref: ${{ github.sha }}\n          persist-credentials: false\n'
          + nodeStep,
      ],
      [
        '      - uses: actions/configure-pages@983d7736d9b0ae728b81ab479565c72886d7745b # v5.0.0\n',
        '      - uses: actions/configure-pages@983d7736d9b0ae728b81ab479565c72886d7745b # v5.0.0\n'
          + '        with:\n          enablement: false\n',
      ],
    ],
  },
  {
    name: 'publish-verified-public-pages.yml',
    job: 'build',
    old: '8461c70580527fbada9c309fbfe1a0c70c7b7b11f7c3dc98d237e493f436964d',
    target: 'd81e70c123dba3d8e89bf7248090937d940857a6b365e835dd66e8a91e2ac171',
    edits: [
      ['    runs-on: [self-hosted, Linux, X64, certigo-trusted]\n', '    runs-on: ubuntu-24.04\n'],
      ['      pages: write\n', '      pages: read\n'],
      [
        '        with:\n          persist-credentials: false\n      - id: pages\n',
        '        with:\n          ref: ${{ github.sha }}\n          persist-credentials: false\n'
          + nodeStep + '      - id: pages\n',
      ],
      [
        '        uses: actions/configure-pages@983d7736d9b0ae728b81ab479565c72886d7745b # v5.0.0\n',
        '        uses: actions/configure-pages@983d7736d9b0ae728b81ab479565c72886d7745b # v5.0.0\n'
          + '        with:\n          enablement: false\n',
      ],
    ],
  },
];
const cdSpec = {
  name: 'cd-backend.yml',
  old: '586addcce22fbbc86d660e601f5e331cd267c334edf4947bc490a5ba3b68a541',
  target: '05287664503833f3c2e6f7daa4c20ff7cb38584de45dccb89f02aff9401fc516',
  edits: [
    [
      '          echo "environment=$TARGET" >> "$GITHUB_OUTPUT"\n'
        + '          echo "operation=$OPERATION" >> "$GITHUB_OUTPUT"\n'
        + '          echo "source-run-id=$SOURCE_RUN_ID" >> "$GITHUB_OUTPUT"\n',
      '          {\n'
        + '            echo "environment=$TARGET"\n'
        + '            echo "operation=$OPERATION"\n'
        + '            echo "source-run-id=$SOURCE_RUN_ID"\n'
        + '          } >> "$GITHUB_OUTPUT"\n',
    ],
  ],
};

function replaceExact(text, from, to) {
  assert.equal(text.includes(from), true, `fixture must contain ${from}`);
  return text.replace(from, to);
}

for (const spec of [...specs, cdSpec]) {
  const current = fs.readFileSync(path.join(root, workflowPath(spec.name)), 'utf8');
  spec.source = digest(current) === spec.target
    ? [...spec.edits].reverse().reduce((text, [from, to]) => replaceExact(text, to, from), current)
    : current;
  assert.equal(digest(spec.source), spec.old, `${spec.name} source fixture`);
  spec.text = spec.edits.reduce((text, [from, to]) => replaceExact(text, from, to), spec.source);
  assert.equal(digest(spec.text), spec.target, `${spec.name} exact target fixture`);
}

function write(directory, relative, text) {
  const file = path.join(directory, ...relative.split('/'));
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text);
}

function workspace() {
  const directory = fs.mkdtempSync(path.join(fixturesRoot, 'workspace-'));
  for (const relative of [...backendDeployTrustedFiles, workflowPath('cd-backend.yml'), manifestPath]) {
    write(directory, relative, fs.readFileSync(path.join(root, relative)));
  }
  for (const spec of specs) {
    write(directory, workflowPath(spec.name), spec.source);
  }
  write(directory, workflowPath(cdSpec.name), cdSpec.source);
  const manifest = JSON.parse(fs.readFileSync(path.join(directory, manifestPath), 'utf8'));
  manifest.preApproved = {};
  for (const spec of [...specs, cdSpec]) {
    manifest.states[workflowPath(spec.name)] = fingerprintWorkflow(
      workflowPath(spec.name), spec.source,
    ).digest;
  }
  write(directory, manifestPath, renderWorkflowManifest(manifest));
  return directory;
}

function approval(directory, spec, expires = '2026-10-16') {
  const manifest = JSON.parse(fs.readFileSync(path.join(directory, manifestPath), 'utf8'));
  manifest.preApproved[workflowPath(spec.name)] = {
    digest: fingerprintWorkflow(workflowPath(spec.name), spec.text).digest,
    expires,
  };
  write(directory, manifestPath, renderWorkflowManifest(manifest));
  write(directory, proposalRelativePath(workflowPath(spec.name)), spec.text);
}

test('exact deltas require prior BASE approval; candidate approval cannot grant or renew it', () => {
  for (const spec of specs) {
    const trusted = workspace();
    const candidate = workspace();
    write(candidate, workflowPath(spec.name), spec.text);
    approval(candidate, spec);
    assert.equal(isReviewedWorkflowTransition(spec.text, workflowPath(spec.name), trusted, options), false);
    assert.match(validateBackendDeployWorkspace(candidate, trusted).join('\n'), /privileged capability/u);
    approval(trusted, spec);
    assert.equal(isReviewedWorkflowTransition(spec.text, workflowPath(spec.name), trusted, options), true);
    // Workspace uses today's date, so the integration proof uses a future approval fixture.
    approval(trusted, spec, '2999-12-31');
    assert.deepEqual(validateBackendDeployWorkspace(candidate, trusted), []);
    approval(trusted, spec, '2026-10-14');
    assert.equal(isReviewedWorkflowTransition(spec.text, workflowPath(spec.name), trusted, options), false);
    assert.match(validateBackendDeployWorkspace(candidate, trusted).join('\n'), /privileged capability/u);
  }
});

test('proposals are reviewable but cannot authorize landing, path substitution or unknown sources', () => {
  for (const spec of specs) {
    const trusted = workspace();
    const proposal = proposalRelativePath(workflowPath(spec.name));
    assert.equal(isReviewedWorkflowTransition(spec.text, proposal, trusted, options), true);
    assert.equal(isReviewedWorkflowTransition(spec.text, workflowPath(spec.name), trusted, options), false);
    approval(trusted, spec);
    assert.equal(isReviewedWorkflowTransition(spec.text, workflowPath('shadow.yml'), trusted, options), false);
    assert.equal(isReviewedWorkflowTransition(
      spec.text, `.github/workflows-disabled/${spec.name}`, trusted, options,
    ), false);
    write(trusted, workflowPath(spec.name), `${spec.source}\n# different trusted source\n`);
    assert.equal(isReviewedWorkflowTransition(spec.text, proposal, trusted, options), false);
    assert.equal(isReviewedWorkflowTransition(spec.text, workflowPath(spec.name), trusted, options), false);
  }
});

test('missing or changed BASE proposals and malformed BASE manifests fail closed', () => {
  const spec = specs[0];
  for (const mutation of [
    (trusted) => fs.rmSync(path.join(trusted, proposalRelativePath(workflowPath(spec.name)))),
    (trusted) => write(trusted, proposalRelativePath(workflowPath(spec.name)), `${spec.text}\n# drift`),
    (trusted) => write(trusted, manifestPath, '{}'),
    (trusted) => write(trusted, manifestPath, '{'),
    (trusted) => fs.rmSync(path.join(trusted, manifestPath)),
  ]) {
    const trusted = workspace();
    approval(trusted, spec);
    mutation(trusted);
    assert.equal(isReviewedWorkflowTransition(spec.text, workflowPath(spec.name), trusted, options), false);
  }
});

test('symlink source, manifest and proposal cannot supply trusted authority', () => {
  const spec = specs[0];
  for (const relative of [
    workflowPath(spec.name),
    manifestPath,
    proposalRelativePath(workflowPath(spec.name)),
  ]) {
    const trusted = workspace();
    approval(trusted, spec);
    const file = path.join(trusted, relative);
    const external = path.join(trusted, 'external');
    fs.mkdirSync(external);
    fs.rmSync(file);
    fs.symlinkSync(external, file, 'junction');
    assert.equal(isReviewedWorkflowTransition(spec.text, workflowPath(spec.name), trusted, options), false);
  }
});

test('inherited target needs a matching BASE state and permits no subsequent byte changes', () => {
  for (const spec of specs) {
    const trusted = workspace();
    write(trusted, workflowPath(spec.name), spec.text);
    assert.equal(isReviewedWorkflowTransition(spec.text, workflowPath(spec.name), trusted, options), false);
    const manifest = JSON.parse(fs.readFileSync(path.join(trusted, manifestPath), 'utf8'));
    for (const state of Object.values(manifest.states)) {
      state[workflowPath(spec.name)] = fingerprintWorkflow(workflowPath(spec.name), spec.text).digest;
    }
    write(trusted, manifestPath, renderWorkflowManifest(manifest));
    assert.equal(isReviewedWorkflowTransition(spec.text, workflowPath(spec.name), trusted, options), true);
    assert.equal(isReviewedWorkflowTransition(`${spec.text}\n`, workflowPath(spec.name), trusted, options), false);
  }
});

test('permissions, secrets, deployment, triggers, runners, jobs and checkout mutations remain forbidden', () => {
  for (const spec of specs) {
    const trusted = workspace();
    const candidate = workspace();
    approval(trusted, spec, '2999-12-31');
    const original = YAML.parse(spec.text);
    const jobId = spec.job ?? Object.keys(original.jobs)[0];
    const mutations = [
      (value) => { value.permissions = 'write-all'; },
      (value) => { value.jobs[jobId].permissions = { 'id-token': 'write' }; },
      (value) => { value.jobs[jobId].env = { TOKEN: '${{ secrets.TOKEN }}' }; },
      (value) => { value.jobs[jobId].steps.push({ run: 'az functionapp deploy' }); },
      (value) => { value.on.push = {}; },
      (value) => { value.jobs[jobId]['runs-on'] = 'ubuntu-latest'; },
      (value) => { value.jobs[jobId].environment = 'other-environment'; },
      (value) => { value.jobs.shadow = { ...value.jobs[jobId] }; },
      (value) => { value.jobs[jobId].steps.push({ uses: 'actions/checkout@main' }); },
    ];
    for (const mutate of mutations) {
      const value = structuredClone(original);
      mutate(value);
      const changed = YAML.stringify(value);
      write(candidate, workflowPath(spec.name), changed);
      assert.equal(isReviewedWorkflowTransition(changed, workflowPath(spec.name), trusted, options), false);
      assert.match(validateBackendDeployWorkspace(candidate, trusted).join('\n'), /privileged capability/u);
    }
  }
});

test('hosted generation is restricted to the exact reviewed job, content and approval', () => {
  for (const spec of specs.filter((entry) => entry.job)) {
    const trusted = workspace();
    const file = workflowPath(spec.name);
    assert.equal(isReviewedGenerationJob(spec.text, file, spec.job, trusted), false);
    assert.notDeepEqual(validateRunnerLabels(spec.text, file, { trustedRoot: trusted }), []);
    approval(trusted, spec, '2999-12-31');
    assert.equal(isReviewedGenerationJob(spec.text, file, spec.job, trusted), true);
    assert.equal(isReviewedGenerationJob(spec.text, file, 'deploy', trusted), false);
    assert.deepEqual(validateRunnerLabels(spec.text, file, { trustedRoot: trusted }), []);
    const changed = spec.text.replace('runs-on: ubuntu-24.04', 'runs-on: ubuntu-latest');
    assert.equal(isReviewedGenerationJob(changed, file, spec.job, trusted), false);
    assert.notDeepEqual(validateRunnerLabels(changed, file, { trustedRoot: trusted }), []);
  }
});

const legacyInputs = [
  'docs/deployment-runbook.md',
  ...[
    'backend-deployment-state.mjs',
    'deploy-flex-onedeploy.sh',
    'public-domain-contract.mjs',
    'update-backend-deployment-state.mjs',
    'verify-backend-deployment-state.mjs',
    'write-secure-bicep-parameters.mjs',
    'backend-release-manifest.mjs',
    'verify-backend-release-transport.sh',
    'backend-release-attestation.mjs',
    'resolve-backend-release-artifact.mjs',
    'resolve-backend-release.mjs',
    'transfer-backend-release.sh',
  ].map((name) => `.github/scripts/${name}`),
];

function withLegacyInputs(directory) {
  for (const relative of legacyInputs) {
    if (fs.existsSync(path.join(root, relative))) {
      write(directory, relative, fs.readFileSync(path.join(root, relative)));
    }
  }
  write(directory, 'infra/main.bicep', fs.readFileSync(path.join(root, 'infra', 'main.bicep')));
  return directory;
}

test('exact lint CD retains only A-hardened semantics and requires prior BASE approval', () => {
  const trusted = withLegacyInputs(workspace());
  const candidate = withLegacyInputs(workspace());
  write(candidate, workflowPath(cdSpec.name), cdSpec.text);
  assert.deepEqual(validateBackendDeployWorkflow(cdSpec.text, cdSpec.source), []);
  assert.match(
    validateBackendDeployWorkspace(candidate, trusted).join('\n'),
    /requires prior trusted BASE approval/u,
  );
  approval(candidate, cdSpec, '2999-12-31');
  assert.match(
    validateBackendDeployWorkspace(candidate, trusted).join('\n'),
    /requires prior trusted BASE approval/u,
  );
  approval(trusted, cdSpec, '2999-12-31');
  assert.deepEqual(validateBackendDeployWorkspace(candidate, trusted), []);
  approval(trusted, cdSpec, '2026-10-14');
  assert.match(
    validateBackendDeployWorkspace(candidate, trusted).join('\n'),
    /requires prior trusted BASE approval/u,
  );
});

test('lint CD cannot extend legacy acceptance to another source, byte, capability or workflow', () => {
  const trusted = withLegacyInputs(workspace());
  const candidate = withLegacyInputs(workspace());
  approval(trusted, cdSpec, '2999-12-31');
  for (const changed of [
    `${cdSpec.text}\n`,
    cdSpec.text.replace('promote-backend', 'other-event'),
    cdSpec.text.replace('contents: read', 'contents: write'),
    cdSpec.text.replace('certigo-trusted', 'ubuntu-24.04'),
    cdSpec.text.replace('id-token: write', 'id-token: read'),
    cdSpec.text.replace('run: |', 'run: echo "${{ secrets.EXTRA }}"'),
  ]) {
    assert.notEqual(changed, cdSpec.text);
    write(candidate, workflowPath(cdSpec.name), changed);
    assert.match(
      validateBackendDeployWorkspace(candidate, trusted).join('\n'),
      /reviewed B object|cannot parse workflow/u,
    );
  }
  write(candidate, workflowPath(cdSpec.name), cdSpec.text);
  write(candidate, workflowPath('shadow.yml'), cdSpec.text);
  assert.match(validateBackendDeployWorkspace(candidate, trusted).join('\n'), /privileged capability/u);
  fs.rmSync(path.join(candidate, workflowPath('shadow.yml')));
  write(trusted, workflowPath(cdSpec.name), `${cdSpec.source}\n# unreviewed source`);
  assert.match(validateBackendDeployWorkspace(candidate, trusted).join('\n'), /reviewed B object/u);
});

test('lint CD seals every runtime, support, capacity and IaC input against drift', () => {
  const trusted = withLegacyInputs(workspace());
  const candidate = withLegacyInputs(workspace());
  approval(trusted, cdSpec, '2999-12-31');
  write(candidate, workflowPath(cdSpec.name), cdSpec.text);
  for (const relative of [...legacyInputs, 'infra/main.bicep']) {
    if (!fs.existsSync(path.join(candidate, relative))) {
      write(candidate, relative, '// newly introduced support control\n');
      assert.match(validateBackendDeployWorkspace(candidate, trusted).join('\n'), /missing/u);
      fs.rmSync(path.join(candidate, relative));
      continue;
    }
    const original = fs.readFileSync(path.join(candidate, relative));
    write(candidate, relative, Buffer.concat([original, Buffer.from('\n// drift\n')]));
    assert.match(validateBackendDeployWorkspace(candidate, trusted).join('\n'), /immutable base revision/u);
    write(candidate, relative, original);
  }
  write(candidate, 'infra/extra.bicep', '// extra input\n');
  assert.match(validateBackendDeployWorkspace(candidate, trusted).join('\n'), /immutable base revision/u);
  fs.rmSync(path.join(candidate, 'infra', 'extra.bicep'));
  fs.rmSync(path.join(candidate, '.github', 'scripts', 'deploy-flex-onedeploy.sh'));
  assert.match(validateBackendDeployWorkspace(candidate, trusted).join('\n'), /missing/u);
  write(candidate, '.github/scripts/deploy-flex-onedeploy.sh', fs.readFileSync(
    path.join(root, '.github', 'scripts', 'deploy-flex-onedeploy.sh'),
  ));
  const infra = fs.readFileSync(path.join(candidate, 'infra', 'main.bicep'));
  fs.rmSync(path.join(candidate, 'infra', 'main.bicep'));
  assert.match(validateBackendDeployWorkspace(candidate, trusted).join('\n'), /immutable base revision/u);
  write(candidate, 'infra/main.bicep', infra);
  const input = path.join(candidate, '.github', 'scripts', 'public-domain-contract.mjs');
  fs.rmSync(input);
  const external = path.join(candidate, 'external-runtime');
  fs.mkdirSync(external);
  fs.symlinkSync(external, input, 'junction');
  assert.match(validateBackendDeployWorkspace(candidate, trusted).join('\n'), /regular non-symlink/u);
});

test('every existing dispatch seal remains enforced', () => {
  const trusted = workspace();
  const candidate = workspace();
  write(candidate, '.github/scripts/validate-backend-deploy-dispatch.mjs', '// altered');
  assert.match(validateBackendDeployWorkspace(candidate, trusted).join('\n'), /immutable base revision/u);
});
