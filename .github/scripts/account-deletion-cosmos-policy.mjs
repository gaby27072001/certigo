import fs from 'node:fs';
import path from 'node:path';

const legacyWorkflow = 'test-account-deletion-cosmos.yml';
const oneShotWorkflow = 'post-merge-cosmos-account-deletion.yml';

const legacyMarkers = [
  'refs/heads/main',
  'repository_dispatch:',
  'types: [test-account-deletion-cosmos]',
  'type == "object" and length == 0',
  "github.ref == 'refs/heads/main'",
  'ref: ${{ github.sha }}',
  'runs-on: [self-hosted, Linux, X64, certigo-trusted]',
  'ACTIONS_ID_TOKEN_REQUEST_TOKEN: ""',
  'bash backend/run-account-deletion-cosmos-emulator.sh',
];

const oneShotMarkers = [
  '# FEATURE-OFF:',
  'workflow_dispatch:',
  "github.event_name == 'workflow_dispatch'",
  "github.repository == 'gchambaud_microsoft/Certigo'",
  "github.ref == 'refs/heads/main'",
  "vars.CERTIGO_COSMOS_EMULATOR_ENABLED == 'true'",
  'runs-on: [self-hosted, Linux, X64, certigo-cosmos-emulator]',
  'ref: refs/heads/main',
  'persist-credentials: false',
  'bash infra/ci-runner/cosmos-emulator/run-account-deletion.sh',
];

function requireMarkers(content, markers, label, errors) {
  for (const marker of markers) {
    if (!content.includes(marker)) {
      errors.push(`${label}: missing fail-closed invariant ${marker}`);
    }
  }
}

function validateLegacy(content, archived, errors) {
  const markers = archived ? ['# RETIRED:', ...legacyMarkers] : legacyMarkers;
  requireMarkers(content, markers, legacyWorkflow, errors);
  if (
    content.includes('pull_request')
    || content.includes('push:')
    || content.includes('az role assignment')
    || content.includes('az cosmosdb create')
  ) {
    errors.push(
      `${legacyWorkflow}: the destructive gate must stay manual and must not provision Azure resources or roles`,
    );
  }
}

function validateOneShot(content, errors) {
  requireMarkers(content, oneShotMarkers, oneShotWorkflow, errors);
  if (
    /(?:^|\n)\s*pull_request(?:_target)?:/m.test(content)
    || /(?:^|\n)\s*push:/m.test(content)
    || /secrets\./i.test(content)
    || /azure\/login@/i.test(content)
    || /id-token:\s*write/i.test(content)
    || /getIDToken\s*\(/i.test(content)
  ) {
    errors.push(
      `${oneShotWorkflow}: archived one-shot gate must not accept PR/push events or cloud credentials`,
    );
  }
}

export function validateAccountDeletionCosmosLayout(root) {
  const errors = [];
  const workflows = path.join(root, '.github', 'workflows');
  const disabled = path.join(root, '.github', 'workflows-disabled');
  const paths = {
    activeLegacy: path.join(workflows, legacyWorkflow),
    activeOneShot: path.join(workflows, oneShotWorkflow),
    archivedLegacy: path.join(disabled, legacyWorkflow),
    archivedOneShot: path.join(disabled, oneShotWorkflow),
  };
  const present = Object.fromEntries(
    Object.entries(paths).map(([label, file]) => [label, fs.existsSync(file)]),
  );
  const legacyState = present.activeLegacy
    && !present.activeOneShot
    && !present.archivedLegacy
    && !present.archivedOneShot;
  const archivedState = !present.activeLegacy
    && !present.activeOneShot
    && present.archivedLegacy
    && present.archivedOneShot;

  if (!legacyState && !archivedState) {
    const layout = Object.entries(present)
      .filter(([, exists]) => exists)
      .map(([label]) => label)
      .join(', ') || 'none';
    return [
      'account-deletion Cosmos workflow layout must be exactly legacy-active or fully archived; '
      + `found: ${layout}`,
    ];
  }

  if (legacyState) {
    validateLegacy(fs.readFileSync(paths.activeLegacy, 'utf8'), false, errors);
    return errors;
  }

  validateLegacy(fs.readFileSync(paths.archivedLegacy, 'utf8'), true, errors);
  validateOneShot(fs.readFileSync(paths.archivedOneShot, 'utf8'), errors);
  return errors;
}
