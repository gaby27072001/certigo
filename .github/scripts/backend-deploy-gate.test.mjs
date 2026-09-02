import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import YAML from 'yaml';
import { validateBackendDeployWorkflow } from './backend-deploy-workflow-policy.mjs';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);
const dispatchValidator = path.join(
  repositoryRoot,
  '.github',
  'scripts',
  'validate-backend-deploy-dispatch.mjs',
);
const workflowPath = path.join(
  repositoryRoot,
  '.github',
  'workflows',
  'cd-backend.yml',
);
const workflowText = readFileSync(workflowPath, 'utf8');

function validateDispatch(payload, overrides = {}) {
  const env = {
    ...process.env,
    EVENT_NAME: 'repository_dispatch',
    EVENT_ACTION: 'promote-backend',
    GITHUB_REF: 'refs/heads/main',
    GITHUB_RUN_ID: '9001',
    ...overrides,
  };
  if (payload !== undefined) {
    env.CLIENT_PAYLOAD_JSON =
      typeof payload === 'string' ? payload : JSON.stringify(payload);
  } else {
    delete env.CLIENT_PAYLOAD_JSON;
  }
  return spawnSync(process.execPath, [dispatchValidator], {
    encoding: 'utf8',
    env,
  });
}

function mutateWorkflow(mutator) {
  const workflow = YAML.parse(workflowText);
  mutator(workflow);
  return YAML.stringify(workflow);
}

test('explicit backend dispatch accepts only the supported operation and environment pairs', () => {
  for (const [operation, environment] of [
    ['release', 'dev'],
    ['promotion', 'staging'],
    ['promotion', 'prod'],
    ['rollback', 'dev'],
    ['rollback', 'staging'],
    ['rollback', 'prod'],
  ]) {
    const result = validateDispatch({
      environment,
      operation,
      source_run_id: '1234',
    });
    assert.equal(result.status, 0, `${operation}:${environment}: ${result.stderr}`);
    assert.match(result.stdout, new RegExp(`environment=${environment}`));
    assert.match(result.stdout, new RegExp(`operation=${operation}`));
    assert.match(result.stdout, /requested-source-run-id=1234/);
    assert.match(
      result.stdout,
      new RegExp(`source-run-id=${operation === 'release' ? '9001' : '1234'}`),
    );
  }
});

test('explicit backend dispatch rejects absent, malformed and non-exact payloads', () => {
  const invalidPayloads = [
    undefined,
    '{',
    'null',
    '[]',
    {},
    { environment: 'dev', operation: 'release' },
    {
      environment: 'dev',
      operation: 'release',
      source_run_id: '1234',
      unexpected: true,
    },
    { environment: 1, operation: 'release', source_run_id: '1234' },
    { environment: 'dev', operation: [], source_run_id: '1234' },
    { environment: 'dev', operation: 'release', source_run_id: 1234 },
    { environment: 'dev', operation: 'release', source_run_id: false },
    { environment: 'qa', operation: 'release', source_run_id: '1234' },
    { environment: 'prod', operation: 'release', source_run_id: '1234' },
    { environment: 'dev', operation: 'promotion', source_run_id: '1234' },
    { environment: 'dev', operation: 'deploy', source_run_id: '1234' },
  ];
  for (const payload of invalidPayloads) {
    const result = validateDispatch(payload);
    assert.notEqual(result.status, 0, `unexpectedly accepted ${JSON.stringify(payload)}`);
  }
});

test('explicit backend dispatch rejects malformed source run ids', () => {
  for (const sourceRunId of ['', '0', '01', '-1', '1e3', '123456789012345678901']) {
    const result = validateDispatch({
      environment: 'dev',
      operation: 'release',
      source_run_id: sourceRunId,
    });
    assert.notEqual(result.status, 0, `unexpectedly accepted ${sourceRunId}`);
    assert.match(result.stderr, /source_run_id/i);
  }
});

test('explicit backend dispatch rejects every non-authorized trigger context', () => {
  const payload = {
    environment: 'dev',
    operation: 'release',
    source_run_id: '1234',
  };
  for (const overrides of [
    { EVENT_NAME: 'push' },
    { EVENT_ACTION: 'deploy-backend' },
    { EVENT_ACTION: '' },
    { GITHUB_REF: 'refs/heads/feature' },
    { GITHUB_RUN_ID: '0' },
  ]) {
    const result = validateDispatch(payload, overrides);
    assert.notEqual(result.status, 0, `unexpectedly accepted ${JSON.stringify(overrides)}`);
  }
});

test('backend deployment workflow is dispatch-only and all Azure jobs are gated', () => {
  assert.deepEqual(validateBackendDeployWorkflow(workflowText), []);
});

test('backend deployment workflow policy rejects push and alternate manual triggers', () => {
  const pushEnabled = mutateWorkflow((workflow) => {
    workflow.on.push = { branches: ['main'] };
  });
  assert.match(
    validateBackendDeployWorkflow(pushEnabled).join('\n'),
    /must only use repository_dispatch/,
  );

  const workflowDispatchEnabled = mutateWorkflow((workflow) => {
    workflow.on.workflow_dispatch = {};
  });
  assert.match(
    validateBackendDeployWorkflow(workflowDispatchEnabled).join('\n'),
    /must only use repository_dispatch/,
  );
});

test('backend deployment workflow policy rejects Azure jobs outside the gate graph', () => {
  const rogueAzureJob = mutateWorkflow((workflow) => {
    workflow.jobs.rogue = {
      'runs-on': ['self-hosted', 'Linux', 'X64', 'certigo-trusted'],
      permissions: { 'id-token': 'write' },
      steps: [{ uses: 'azure/login@0123456789012345678901234567890123456789' }],
    };
  });
  const errors = validateBackendDeployWorkflow(rogueAzureJob).join('\n');
  assert.match(errors, /Azure-capable jobs must be exactly/);
  assert.match(errors, /rogue must use an Environment/);
  assert.match(errors, /rogue must transitively need validate-target/);
  assert.match(errors, /rogue must transitively need validate-public-domain/);
});

test('backend deployment workflow policy rejects Environment and needs bypasses', () => {
  const noEnvironment = mutateWorkflow((workflow) => {
    delete workflow.jobs['deploy-infra'].environment;
  });
  assert.match(
    validateBackendDeployWorkflow(noEnvironment).join('\n'),
    /deploy-infra must use an Environment/,
  );

  const disconnected = mutateWorkflow((workflow) => {
    workflow.jobs['build-release'].needs = [];
  });
  const disconnectedErrors = validateBackendDeployWorkflow(disconnected).join('\n');
  assert.match(disconnectedErrors, /build-release must keep its exact fail-closed needs/);
  assert.match(disconnectedErrors, /build-release must transitively need validate-target/);
  assert.match(disconnectedErrors, /build-release must transitively need validate-public-domain/);
});

test('backend deployment workflow policy rejects always bypasses', () => {
  const bypassedResolve = mutateWorkflow((workflow) => {
    workflow.jobs['resolve-release'].if = '${{ always() }}';
  });
  const resolveErrors = validateBackendDeployWorkflow(bypassedResolve).join('\n');
  assert.match(resolveErrors, /resolve-release condition must exactly match/);

  const hiddenResolveBypass = mutateWorkflow((workflow) => {
    workflow.jobs['resolve-release'].if = workflow.jobs['resolve-release'].if.replace(
      "needs.validate-target.result == 'success'",
      "true || needs.validate-target.result == 'success'",
    );
  });
  assert.match(
    validateBackendDeployWorkflow(hiddenResolveBypass).join('\n'),
    /resolve-release condition must exactly match/,
  );

  const bypassedBuild = mutateWorkflow((workflow) => {
    workflow.jobs['build-release'].if = '${{ always() }}';
  });
  const buildErrors = validateBackendDeployWorkflow(bypassedBuild).join('\n');
  assert.match(buildErrors, /build-release condition must exactly require release/);

  const bypassedDeploy = mutateWorkflow((workflow) => {
    workflow.jobs['deploy-infra'].if = '${{ always() }}';
  });
  assert.match(
    validateBackendDeployWorkflow(bypassedDeploy).join('\n'),
    /deploy-infra must rely on the default success gate/,
  );
});

test('backend deployment workflow policy rejects gate identity and secret bypasses', () => {
  const wrongRef = mutateWorkflow((workflow) => {
    workflow.jobs['validate-target'].if = '${{ true }}';
  });
  assert.match(
    validateBackendDeployWorkflow(wrongRef).join('\n'),
    /validate-target condition must be exactly refs\/heads\/main/,
  );

  const earlyIdentity = mutateWorkflow((workflow) => {
    workflow.jobs['validate-release-source'].permissions['id-token'] = 'write';
  });
  assert.match(
    validateBackendDeployWorkflow(earlyIdentity).join('\n'),
    /validate-release-source must be local, secret-free and without Azure identity/,
  );

  const earlySecret = mutateWorkflow((workflow) => {
    workflow.jobs['validate-public-domain'].env.UNSAFE = '${{ secrets.AZURE_CLIENT_ID }}';
  });
  assert.match(
    validateBackendDeployWorkflow(earlySecret).join('\n'),
    /validate-public-domain must run without secrets or Azure identity/,
  );
});
