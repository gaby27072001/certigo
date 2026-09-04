import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { validateAcaPilotWorkflow } from './validate-workflow-security.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const validator = fs.readFileSync(
  path.join(root, '.github', 'scripts', 'validate-workflow-security.mjs'),
  'utf8',
);
const workflow = fs.readFileSync(
  path.join(root, '.github', 'workflows', 'ci-aca-pilot.yml'),
  'utf8',
);

test('workflow security policy reserves the ACA label for the manual pilot', () => {
  assert.deepEqual(
    validateAcaPilotWorkflow(workflow, 'ci-aca-pilot.yml'),
    [],
  );
  assert.match(validator, /job\.text\.includes\(acaPrLinuxRunner\)/);
  assert.match(validator, /id-token:\\s\*write/);
});

test('workflow security policy rejects ACA trigger and gate broadening', () => {
  const automatic = workflow.replace(
    '  workflow_dispatch:',
    '  push:\n    branches: [main]\n  workflow_dispatch:',
  );
  assert.match(
    validateAcaPilotWorkflow(automatic, 'ci-aca-pilot.yml').join('\n'),
    /restricted to the manual pilot workflow/,
  );

  const ungated = workflow.replace(
    "vars.CERTIGO_ACA_PILOT_ENABLED == 'true'",
    'true',
  );
  assert.match(
    validateAcaPilotWorkflow(ungated, 'ci-aca-pilot.yml').join('\n'),
    /missing fail-closed gate/,
  );

  assert.match(
    validateAcaPilotWorkflow(workflow, 'rogue-pilot.yml').join('\n'),
    /restricted to the manual pilot workflow/,
  );
});

test('manual pilot cannot replace or broaden existing CI routing', () => {
  assert.match(workflow, /^ {2}workflow_dispatch:\s*$/m);
  assert.doesNotMatch(workflow, /^ {2}(?:push|pull_request|pull_request_target|repository_dispatch):/m);
  assert.match(workflow, /github\.repository == 'gchambaud_microsoft\/Certigo'/);
  assert.match(workflow, /github\.ref == 'refs\/heads\/main'/);
  assert.match(workflow, /Fork pull requests are not eligible/);
});
