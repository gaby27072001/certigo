import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  parseBuildParamsOutput,
  validateDeploymentParametersDocument,
} from '../governance/bicep-parameters.mjs';
import {
  collectScheduleInstances,
  collectScheduleInstancesForPrincipals,
  initialScheduleUrls,
} from '../governance/collect-role-assignment-schedules.mjs';
import { collectTransitiveGroupIds } from '../governance/collect-transitive-groups.mjs';
import {
  normalizeEvidencePath,
  validateEvidenceEntries,
  verifyManifestSeal,
  writeManifestSeal,
} from '../governance/evidence-files.mjs';
import {
  validateIndependentAdminLiveSchedule,
  validateLegacyLiveAssignments,
  validateLegacyTransition,
} from '../governance/legacy-transition-contract.mjs';
import {
  phaseBTarget,
  validatePhaseBTarget,
} from '../governance/phase-b-target.mjs';
import { verifyManifestFiles } from '../governance/validate-evidence.mjs';
import {
  armGuid,
  runtimeWriterCondition,
} from '../governance/validate-what-if.mjs';
import { createManifest } from '../governance/write-what-if-manifest.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const subscription = 'a0000000-0000-0000-0000-000000000001';
const tenant = 'b0000000-0000-0000-0000-000000000002';
const malformedArtifactUuids = [
  null,
  {},
  '00000000-0000-0000-0000-000000000000',
  '30000000-0000-0000-0000-00000000000A',
];
const parameterSchema =
  'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#';

function parameterDocument(parameters = { location: { value: 'westeurope' } }) {
  return {
    $schema: parameterSchema,
    contentVersion: '1.0.0.0',
    parameters,
  };
}

function phaseAProof() {
  const identity = (name, suffix) => ({
    clientId: `10000000-0000-0000-0000-0000000000${suffix}`,
    name,
    principalId: `20000000-0000-0000-0000-0000000000${suffix}`,
    resourceId:
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-identities/` +
      `providers/Microsoft.ManagedIdentity/userAssignedIdentities/${name}`,
  });
  const role = (seed) =>
    `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
    `roleDefinitions/${armGuid(`/subscriptions/${subscription}`, seed)}`;
  return {
    schemaVersion: 2,
    subscriptionId: subscription,
    tenantId: tenant,
    contentResourceGroupId:
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-content`,
    identityResourceGroupId:
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-identities`,
    identities: {
      contentAnswerKey: identity('id-certigo-content-answer-key', '01'),
      contentInfrastructurePlan: {
        ...identity('id-certigo-content-infra-plan', '02'),
        federatedSubject:
          'repo:gchambaud_microsoft/Certigo:environment:azure-content-infra-plan',
      },
      contentPublic: identity('id-certigo-content-public', '03'),
      contentReader: identity('id-certigo-content-reader', '04'),
      contentRelease: identity('id-certigo-content-release', '05'),
      deployDev: identity('id-certigo-deploy-dev', '06'),
      deployProd: identity('id-certigo-deploy-prod', '07'),
      deployStaging: identity('id-certigo-deploy-staging', '08'),
    },
    policyDefinitionId: role('certigo-privileged-ci-role-assignments').replace(
      '/roleDefinitions/',
      '/policyDefinitions/',
    ),
    roleDefinitionIds: {
      contentInfrastructurePlanExecutor: role(
        'certigo-content-infrastructure-plan-executor',
      ),
      contentInfrastructurePlanExternalJoin: role(
        'certigo-content-infrastructure-plan-external-join',
      ),
      contentPublisher:
        `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
        'roleDefinitions/c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de',
      runtimeRoleAssignmentWriter: role(
        'certigo-runtime-role-assignment-writer',
      ),
      sharedNetworkDeployment: role('certigo-shared-network-deployment'),
      subscriptionDeploymentLauncher: role(
        'certigo-subscription-deployment-launcher',
      ),
    },
  };
}

function temporaryAssignments(proof, principalId) {
  const subscriptionScope = `/subscriptions/${subscription}`;
  const role = (id) =>
    `${subscriptionScope}/providers/Microsoft.Authorization/roleDefinitions/${id}`;
  const createdAt = '2026-09-01T10:00:00Z';
  const expiresAt = '2026-09-08T10:00:00Z';
  let scheduleIndex = 0;
  const assignment = (
    purpose,
    scope,
    roleDefinitionId,
    condition = null,
  ) => {
    scheduleIndex += 1;
    return {
      purpose,
      scope,
      principalId,
      principalType: 'ServicePrincipal',
      roleDefinitionId,
      condition,
      conditionVersion: condition ? '2.0' : null,
      createdAt,
      expiresAt,
      owner: 'cloud-governance',
      rollbackProcedure: `Remove ${purpose} by schedule instance ID`,
      scheduleInstanceId:
        `${scope}/providers/Microsoft.Authorization/roleAssignmentScheduleInstances/` +
        `50000000-0000-0000-0000-${String(scheduleIndex).padStart(12, '0')}`,
    };
  };
  const result = [
    assignment(
      'rollback-subscription-deployment',
      subscriptionScope,
      proof.roleDefinitionIds.subscriptionDeploymentLauncher,
    ),
    assignment(
      'rollback-shared-network',
      `${subscriptionScope}/resourceGroups/rg-certigo-ci`,
      proof.roleDefinitionIds.sharedNetworkDeployment,
    ),
  ];
  for (const environment of ['dev', 'staging', 'prod']) {
    const scope = `${subscriptionScope}/resourceGroups/rg-certigo-${environment}`;
    result.push(
      assignment(
        `rollback-${environment}-deployment`,
        scope,
        role('b24988ac-6180-42a0-ab88-20f7382dd24c'),
      ),
      assignment(
        `rollback-${environment}-runtime-rbac`,
        scope,
        proof.roleDefinitionIds.runtimeRoleAssignmentWriter,
        runtimeWriterCondition(),
      ),
    );
  }
  return result;
}

function validTransition() {
  const proof = phaseAProof();
  const legacyPrincipalId = '30000000-0000-0000-0000-000000000001';
  const contributorAssignmentId = '40000000-0000-0000-0000-000000000001';
  const userAccessAdministratorAssignmentId =
    '40000000-0000-0000-0000-000000000002';
  return {
    proof,
    transition: {
      schemaVersion: 1,
      subscriptionId: subscription,
      legacyPrincipalId,
      inventory: {
        capturedAt: '2026-09-01T08:00:00Z',
        evidenceSha256: 'a'.repeat(64),
        assignmentIds: [
          contributorAssignmentId,
          userAccessAdministratorAssignmentId,
        ],
      },
      replacementJit: {
        eligibilityCreatedAt: '2026-09-01T09:00:00Z',
        activationTests: [
          {
            testedAt: '2026-09-01T09:15:00Z',
            expiresAt: '2026-09-01T09:25:00Z',
            evidenceSha256: 'b'.repeat(64),
            nonLockoutVerified: true,
          },
          {
            testedAt: '2026-09-01T09:30:00Z',
            expiresAt: '2026-09-01T12:00:00Z',
            evidenceSha256: 'c'.repeat(64),
            nonLockoutVerified: true,
          },
        ],
      },
      rollback: {
        testedAt: '2026-09-01T09:45:00Z',
        evidenceSha256: 'd'.repeat(64),
      },
      temporaryAssignments: temporaryAssignments(proof, legacyPrincipalId),
      broadRemoval: {
        contributorAssignmentId,
        userAccessAdministratorAssignmentId,
        uaaRemovedAt: '2026-09-01T10:15:00Z',
        contributorRemovedAt: '2026-09-01T10:30:00Z',
        evidenceSha256: 'e'.repeat(64),
      },
      changeControl: {
        administrationMode: 'independent-third-party',
        assignmentChangesSerialized: true,
        safetyAdminPrincipalId:
          '30000000-0000-0000-0000-000000000002',
        operatorOwner: 'certigo-sole-owner',
        independentAdminOwner: 'temporary-governance-msp',
        independentAdminTenantId: tenant,
        independentAdminScope: `/subscriptions/${subscription}`,
        independentAdminPrincipalId:
          '30000000-0000-0000-0000-000000000002',
        independentAdminRoleDefinitionId:
          `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
          'roleDefinitions/18d7d88d-d35e-4fb5-a5c3-7773c20a72d9',
        independentAdminScheduleInstanceId:
          `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
          'roleAssignmentScheduleInstances/50000000-0000-0000-0000-000000000099',
        independentAdminExpiresAt: '2026-09-08T10:00:00Z',
        soloModeControls: null,
        emergencyPrincipalIds: [
          '30000000-0000-0000-0000-000000000003',
          '30000000-0000-0000-0000-000000000004',
        ],
        evidenceSha256: 'f'.repeat(64),
      },
      soakEndsAt: '2026-09-08T10:00:00Z',
    },
  };
}

function independentAdminSchedule(transition) {
  return {
    id: transition.changeControl.independentAdminScheduleInstanceId,
    properties: {
      scope: transition.changeControl.independentAdminScope,
      principalId: transition.changeControl.independentAdminPrincipalId,
      principalType: 'ServicePrincipal',
      roleDefinitionId:
        transition.changeControl.independentAdminRoleDefinitionId,
      roleAssignmentScheduleId:
        `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
        'roleAssignmentSchedules/50000000-0000-0000-0000-000000000099',
      originRoleAssignmentId:
        `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
        'roleAssignments/50000000-0000-0000-0000-000000000099',
      startDateTime: '2026-09-01T10:00:00Z',
      endDateTime: transition.changeControl.independentAdminExpiresAt,
      assignmentType: 'Assigned',
      memberType: 'Direct',
      status: 'Provisioned',
      condition: null,
      conditionVersion: null,
    },
  };
}

function scheduleFixture(id, scope, roleSuffix = '01') {
  return {
    id:
      `${scope}/providers/Microsoft.Authorization/` +
      `roleAssignmentScheduleInstances/${id}`,
    properties: {
      scope,
      principalId: '30000000-0000-0000-0000-000000000001',
      principalType: 'ServicePrincipal',
      roleDefinitionId:
        `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
        `roleDefinitions/70000000-0000-0000-0000-0000000000${roleSuffix}`,
      roleAssignmentScheduleId:
        `${scope}/providers/Microsoft.Authorization/roleAssignmentSchedules/${id}`,
      originRoleAssignmentId:
        `${scope}/providers/Microsoft.Authorization/roleAssignments/${id}`,
      startDateTime: '2026-09-01T10:00:00Z',
      endDateTime: '2026-09-08T10:00:00Z',
      assignmentType: 'Assigned',
      memberType: 'Direct',
      status: 'Provisioned',
      condition: null,
      conditionVersion: null,
    },
  };
}

test('schedule scopes match literal subscriptions and exactly four resource groups', () => {
  const principalId = '30000000-0000-0000-0000-000000000001';
  for (const id of [subscription, 'sub.name', 'sub(alt)', 'sub+name', 'sub[name]', 'sub|name']) {
    const base = `/subscriptions/${id}`;
    const groups = ['ci', 'dev', 'staging', 'prod'].map(
      (environment) => `${base}/resourceGroups/rg-certigo-${environment}`,
    );
    const scopes = [base, ...groups, '/providers/Microsoft.Management/managementGroups/parent'];
    assert.equal(initialScheduleUrls(id, principalId, undefined, scopes).length, 6);
    assert.equal(
      initialScheduleUrls(id.toUpperCase(), principalId, undefined,
        scopes.map((scope) => scope.toUpperCase())).length,
      6,
    );
    for (const hostile of [
      `${base}/resourceGroups/rg-certigo-development`,
      `${base}/resourceGroups/rg-certigo-prod/extra`,
      `${base}/resourceGroups/rg-certigo-prod\n`,
      `/subscriptions/${id.replace('.', 'X')}-other/resourceGroups/rg-certigo-dev`,
      `/subscriptions/${id.replace('.', 'X')}/resourceGroups/rg-certigo-dev`,
    ].filter((scope) => !groups.includes(scope))) {
      assert.throws(
        () => initialScheduleUrls(id, principalId, undefined, [base, hostile]),
        /approved hierarchy/,
      );
    }
    for (const invalid of [[], groups, [base, base.toUpperCase()], [base, '']]) {
      assert.throws(
        () => initialScheduleUrls(id, principalId, undefined, invalid),
        /non-empty|approved hierarchy/,
      );
    }
  }
});

test('schedule pagination follows pages and deduplicates identical scope overlap', async () => {
  const principalId = '30000000-0000-0000-0000-000000000001';
  const urls = initialScheduleUrls(subscription, principalId);
  const first = scheduleFixture(
    '80000000-0000-0000-0000-000000000001',
    `/subscriptions/${subscription}`,
  );
  const second = scheduleFixture(
    '80000000-0000-0000-0000-000000000002',
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-dev`,
    '02',
  );
  let calls = 0;
  const result = await collectScheduleInstances({
    subscriptionId: subscription,
    principalId,
    fetchPage: async (url) => {
      calls += 1;
      const parsed = new URL(url);
      if (
        !parsed.searchParams.get('$skiptoken') &&
        parsed.pathname.toLowerCase() ===
          new URL(urls[0]).pathname.toLowerCase()
      ) {
        parsed.searchParams.set('$skiptoken', 'page-2');
        return { value: [first], nextLink: parsed.href };
      }
      if (parsed.searchParams.get('$skiptoken') === 'page-2') {
        return { value: [second] };
      }
      if (
        parsed.pathname.toLowerCase() ===
        new URL(urls[1]).pathname.toLowerCase()
      ) {
        return { value: [first, second] };
      }
      return { value: [] };
    },
  });
  assert.equal(calls, 6);
  assert.deepEqual(result, [first, second]);
});

test('schedule pagination rejects duplicate conflicts, cycles, and hostile nextLink', async () => {
  const principalId = '30000000-0000-0000-0000-000000000001';
  const urls = initialScheduleUrls(subscription, principalId);
  const first = scheduleFixture(
    '80000000-0000-0000-0000-000000000001',
    `/subscriptions/${subscription}`,
  );
  const conflicting = structuredClone(first);
  conflicting.properties.endDateTime = '2026-09-09T10:00:00Z';
  await assert.rejects(
    collectScheduleInstances({
      subscriptionId: subscription,
      principalId,
      fetchPage: async (url) => {
        const isFirst =
          new URL(url).pathname.toLowerCase() ===
          new URL(urls[0]).pathname.toLowerCase();
        return { value: isFirst ? [first] : [conflicting] };
      },
    }),
    /conflicting duplicate contract/,
  );

  const cycleUrl = new URL(urls[0]);
  cycleUrl.searchParams.set('$skiptoken', 'cycle');
  await assert.rejects(
    collectScheduleInstances({
      subscriptionId: subscription,
      principalId,
      fetchPage: async (url) => ({
        value: [],
        nextLink: cycleUrl.href,
      }),
    }),
    /nextLink cycle/,
  );

  for (const hostile of [
    `https://attacker.example/schedules?api-version=2020-10-01` +
      `&%24filter=${encodeURIComponent(`principalId eq '${principalId}'`)}` +
      '&%24skiptoken=x',
    `${urls[0]}&%24skiptoken=x&redirect=https://attacker.example`,
    urls[0].replace(principalId, '30000000-0000-0000-0000-000000000099') +
      '&%24skiptoken=x',
    `${urls[1]}&%24skiptoken=cross-scope`,
  ]) {
    await assert.rejects(
      collectScheduleInstances({
        subscriptionId: subscription,
        principalId,
        fetchPage: async () => ({ value: [], nextLink: hostile }),
      }),
      /escapes the approved Azure endpoint|unexpected query field|changes the approved query/,
    );
  }
});

test('legacy access collection covers transitive groups and both PIM schedule types', async () => {
  const principalId = '30000000-0000-0000-0000-000000000001';
  const secondPrincipalId = '30000000-0000-0000-0000-000000000002';
  const groupIds = await collectTransitiveGroupIds({
    principalId,
    fetchPage: async (url) => {
      const parsed = new URL(url);
      if (parsed.searchParams.has('$skiptoken')) {
        return {
          value: [
            {
              '@odata.type': '#microsoft.graph.group',
              id: secondPrincipalId,
            },
          ],
        };
      }
      return {
        value: [
          {
            '@odata.type': '#microsoft.graph.group',
            id: '30000000-0000-0000-0000-000000000003',
          },
          {
            '@odata.type': '#microsoft.graph.administrativeUnit',
            id: '30000000-0000-0000-0000-000000000004',
          },
        ],
        '@odata.nextLink': `${url}&$skiptoken=page-2`,
      };
    },
  });
  assert.deepEqual(groupIds, [
    secondPrincipalId,
    '30000000-0000-0000-0000-000000000003',
  ]);
  await assert.rejects(
    () =>
      collectTransitiveGroupIds({
        principalId,
        fetchPage: async () => ({
          value: [],
          '@odata.nextLink':
            'https://evil.example/v1.0/servicePrincipals/' +
            `${principalId}/transitiveMemberOf` +
            '?$select=id&$top=999&$skiptoken=stolen',
        }),
      }),
    /escapes the approved Graph query/,
  );
  await assert.rejects(
    () =>
      collectTransitiveGroupIds({
        principalId,
        fetchPage: async (url) => ({
          value: [],
          '@odata.nextLink': `${url}&$select=id&$skiptoken=page-2`,
        }),
      }),
    /escapes the approved Graph query/,
  );
  for (const directoryObject of [
    { id: secondPrincipalId },
    {
      '@odata.type': '#microsoft.graph.group',
      id: 'not-a-uuid',
    },
    {
      '@odata.type': 'UNKNOWN',
      id: secondPrincipalId,
    },
  ]) {
    await assert.rejects(
      () =>
        collectTransitiveGroupIds({
          principalId,
          fetchPage: async () => ({ value: [directoryObject] }),
        }),
      /missing or extra fields|must be a UUID/,
    );
  }
  await assert.rejects(
    () =>
      collectTransitiveGroupIds({
        principalId,
        fetchPage: async () => {
          throw new Error('Graph visibility is unavailable');
        },
      }),
    /Graph visibility is unavailable/,
  );

  const seenUrls = [];
  const schedules = await collectScheduleInstancesForPrincipals({
    subscriptionId: subscription,
    principalIds: [principalId, secondPrincipalId],
    resourceType: 'roleEligibilityScheduleInstances',
    scopes: [
      `/subscriptions/${subscription}`,
      '/providers/Microsoft.Management/managementGroups/root',
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-ci`,
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-dev`,
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-staging`,
      `/subscriptions/${subscription}/resourceGroups/rg-certigo-prod`,
    ],
    fetchPage: async (url) => {
      seenUrls.push(url);
      return { value: [] };
    },
  });
  assert.deepEqual(schedules, []);
  assert.equal(seenUrls.length, 12);
  assert.ok(
    seenUrls.every((url) =>
      url.includes('/roleeligibilityscheduleinstances?'),
    ),
  );
  await assert.rejects(
    () =>
      collectScheduleInstances({
        subscriptionId: subscription,
        principalId,
        resourceType: 'roleEligibilityScheduleInstances',
        fetchPage: async (url) => ({
          value: [],
          nextLink: `${url}&api-version=2020-10-01&$skiptoken=page-2`,
        }),
      }),
    /changes the approved query/,
  );
});

test('Phase B target rejects stale professional bindings', () => {
  assert.deepEqual(
    validatePhaseBTarget(
      phaseBTarget.subscriptionId.toUpperCase(),
      phaseBTarget.tenantId.toUpperCase(),
    ),
    phaseBTarget,
  );
  assert.throws(
    () =>
      validatePhaseBTarget(
        'b8952c8c-8f72-469d-99cd-ac906da4e2fc',
        '16b3c013-d300-468d-ac64-7eda0820b6d3',
      ),
    /stale professional or unapproved Azure bindings/,
  );
});

test('build-params wrapper extracts only a strict deployment parameters document', () => {
  const parameters = parameterDocument();
  const wrapper = {
    parametersJson: JSON.stringify(parameters),
    templateJson: JSON.stringify({ resources: [] }),
    templateSpecId: null,
  };
  assert.deepEqual(parseBuildParamsOutput(JSON.stringify(wrapper)), parameters);
  for (const key of Object.keys(wrapper)) {
    const invalid = structuredClone(wrapper);
    delete invalid[key];
    assert.throws(
      () => parseBuildParamsOutput(JSON.stringify(invalid)),
      /fields must be exactly/,
    );
  }
  assert.throws(
    () =>
      parseBuildParamsOutput(
        JSON.stringify({ ...wrapper, unexpected: 'not-allowed' }),
      ),
    /fields must be exactly/,
  );
  assert.throws(
    () =>
      validateDeploymentParametersDocument({
        ...parameters,
        unexpected: true,
      }),
    /fields must be exactly/,
  );
  assert.throws(
    () =>
      validateDeploymentParametersDocument(
        parameterDocument({ location: { value: 'westeurope', extra: true } }),
      ),
    /fields must be exactly/,
  );
});

test('all governance what-if phases normalize or validate parameters before use', () => {
  for (const script of [
    'what-if-phase-a.sh',
    'what-if-governance-planner.sh',
  ]) {
    const source = fs.readFileSync(
      path.join(root, 'infra/governance', script),
      'utf8',
    );
    assert.match(source, /build-params-output\.json/);
    assert.match(source, /bicep-parameters\.mjs" extract/);
    assert.doesNotMatch(source, /--stdout > "\$\{evidence_dir\}\/parameters\.json"/);
  }
  for (const script of [
    'what-if-phase-b1.sh',
    'what-if-phase-b1b.sh',
    'what-if-phase-b2.sh',
  ]) {
    assert.match(
      fs.readFileSync(path.join(root, 'infra/governance', script), 'utf8'),
      /bicep-parameters\.mjs" validate/,
    );
  }
});

test('evidence paths normalize Windows and Unix separators and reject unsafe forms', () => {
  assert.equal(normalizeEvidencePath('fixtures\\windows\\plan.json'), 'fixtures/windows/plan.json');
  assert.equal(normalizeEvidencePath('fixtures/linux/plan.json'), 'fixtures/linux/plan.json');
  for (const unsafe of [
    '../plan.json',
    '..\\plan.json',
    'folder/../plan.json',
    'C:\\evidence\\plan.json',
    '\\\\server\\share\\plan.json',
    '/tmp/plan.json',
    'folder//plan.json',
  ]) {
    assert.throws(() => normalizeEvidencePath(unsafe), /relative|traversal/);
  }
  assert.throws(
    () =>
      validateEvidenceEntries(
        [
          { path: 'Plan.json', sha256: 'a'.repeat(64) },
          { path: 'plan.json', sha256: 'b'.repeat(64) },
        ],
        'fixtures',
      ),
    /case-insensitive path collision/,
  );
});

test('manifest seal overwrites a regular file without changing its existing mode', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'manifest-overwrite-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const manifest = path.join(directory, 'manifest.json');
  const seal = path.join(directory, 'manifest.sha256');
  fs.writeFileSync(manifest, '{}\n');
  writeManifestSeal(manifest, seal);
  const descriptor = fs.openSync(seal, 'r+');
  try {
    assert.equal(fs.fstatSync(descriptor).mode & 0o777, 0o600);
    fs.fchmodSync(descriptor, 0o640);
    fs.writeSync(descriptor, 'old seal with extra bytes'.repeat(10), 0, 'utf8');
    writeManifestSeal(manifest, seal);
    assert.doesNotThrow(() => verifyManifestSeal(manifest, seal));
    assert.equal(fs.fstatSync(descriptor).mode & 0o777, 0o640);
    assert.match(fs.readFileSync(descriptor, 'utf8'), /^[0-9a-f]{64}  manifest\.json\n$/);
  } finally {
    fs.closeSync(descriptor);
  }
});

test('manifest seal rejects symlinks, parent symlinks and nonregular outputs without changing targets', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'manifest-hostile-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const manifest = path.join(directory, 'manifest.json');
  const outside = path.join(directory, 'target');
  const seal = path.join(directory, 'manifest.sha256');
  fs.writeFileSync(manifest, '{}\n');
  fs.writeFileSync(outside, 'untouched');
  fs.symlinkSync(outside, seal);
  assert.throws(() => writeManifestSeal(manifest, seal), /symbolic link/);
  assert.equal(fs.readFileSync(outside, 'utf8'), 'untouched');
  fs.rmSync(seal);
  fs.mkdirSync(seal);
  assert.throws(() => writeManifestSeal(manifest, seal), /regular file/);
  const parent = path.join(directory, 'parent');
  fs.symlinkSync(directory, parent, 'dir');
  assert.throws(() => writeManifestSeal(manifest, path.join(parent, 'new.sha256')), /symbolic link/);
  assert.equal(fs.existsSync(path.join(directory, 'new.sha256')), false);
});

test('manifest seal rejects hard links and foreign ownership before truncating', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'manifest-ownership-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const manifest = path.join(directory, 'manifest.json');
  const seal = path.join(directory, 'manifest.sha256');
  const target = path.join(directory, 'target');
  fs.writeFileSync(manifest, '{}\n');
  fs.writeFileSync(target, 'untouched');
  fs.linkSync(target, seal);
  assert.throws(() => writeManifestSeal(manifest, seal), /owned regular/);
  assert.equal(fs.readFileSync(target, 'utf8'), 'untouched');
  fs.unlinkSync(seal);
  fs.writeFileSync(seal, 'original');
  if (typeof process.geteuid === 'function') {
    const inspect = fs.fstatSync;
    t.mock.method(fs, 'fstatSync', (descriptor) => {
      const stats = inspect(descriptor);
      stats.uid = process.geteuid() + 1;
      return stats;
    });
    assert.throws(() => writeManifestSeal(manifest, seal), /owned regular/);
    assert.equal(fs.readFileSync(seal, 'utf8'), 'original');
  }
});

test('manifest seal detects object substitution before truncation and closes the rejected object', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'manifest-swap-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const manifest = path.join(directory, 'manifest.json');
  const seal = path.join(directory, 'manifest.sha256');
  fs.writeFileSync(manifest, '{}\n');
  fs.writeFileSync(seal, 'original');
  const open = fs.openSync;
  let descriptor;
  t.mock.method(fs, 'openSync', (file, ...args) => {
    if (file === seal && descriptor === undefined) {
      fs.renameSync(seal, `${seal}.original`);
      fs.writeFileSync(seal, 'replacement must remain intact');
      descriptor = open(file, ...args);
      return descriptor;
    }
    return open(file, ...args);
  });
  assert.throws(() => writeManifestSeal(manifest, seal), /changed before writing/);
  assert.equal(fs.readFileSync(seal, 'utf8'), 'replacement must remain intact');
  assert.equal(fs.readFileSync(`${seal}.original`, 'utf8'), 'original');
  assert.throws(() => fs.fstatSync(descriptor), { code: 'EBADF' });
});

test('manifest seal closes descriptors on validation and write errors', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'manifest-io-error-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const manifest = path.join(directory, 'manifest.json');
  const seal = path.join(directory, 'manifest.sha256');
  fs.writeFileSync(manifest, '{}\n');
  fs.writeFileSync(seal, 'original');
  const open = fs.openSync;
  let descriptor;
  t.mock.method(fs, 'openSync', (file, ...args) => {
    const fd = open(file, ...args);
    if (file === seal) {
      descriptor = fd;
    }
    return fd;
  });
  const denied = Object.assign(new Error('write denied'), { code: 'EACCES' });
  const truncateMock = t.mock.method(fs, 'ftruncateSync', () => { throw denied; });
  assert.throws(() => writeManifestSeal(manifest, seal), denied);
  assert.equal(fs.readFileSync(seal, 'utf8'), 'original');
  assert.throws(() => fs.fstatSync(descriptor), { code: 'EBADF' });
  truncateMock.mock.restore();
  const inspect = fs.fstatSync;
  t.mock.method(fs, 'fstatSync', () => { throw denied; });
  assert.throws(() => writeManifestSeal(manifest, seal), denied);
  assert.throws(() => inspect(descriptor), { code: 'EBADF' });
});

test('manifest seal rejects a symlink swap before truncating its outside target', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'manifest-link-swap-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const manifest = path.join(directory, 'manifest.json');
  const seal = path.join(directory, 'manifest.sha256');
  const outside = path.join(directory, 'outside');
  fs.writeFileSync(manifest, '{}\n');
  fs.writeFileSync(seal, 'original');
  fs.writeFileSync(outside, 'untouched');
  const open = fs.openSync;
  let swapped = false;
  t.mock.method(fs, 'openSync', (file, ...args) => {
    if (file === seal && !swapped) {
      swapped = true;
      fs.renameSync(seal, `${seal}.original`);
      fs.symlinkSync(outside, seal);
    }
    return open(file, ...args);
  });
  assert.throws(() => writeManifestSeal(manifest, seal), /ELOOP|changed before writing/);
  assert.equal(fs.readFileSync(outside, 'utf8'), 'untouched');
  assert.equal(fs.readFileSync(`${seal}.original`, 'utf8'), 'original');
});

test('manifest seal rejects FIFOs before writing or waiting for a reader', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'manifest-fifo-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const manifest = path.join(directory, 'manifest.json');
  const seal = path.join(directory, 'manifest.sha256');
  fs.writeFileSync(manifest, '{}\n');
  execFileSync('mkfifo', [seal]);
  assert.throws(() => writeManifestSeal(manifest, seal), /regular file/);
  fs.rmSync(seal);
  fs.writeFileSync(seal, 'original');
  const script = `
    import fs from 'node:fs';
    import { execFileSync } from 'node:child_process';
    import { writeManifestSeal } from ${JSON.stringify(new URL('../governance/evidence-files.mjs', import.meta.url).href)};
    const open = fs.openSync;
    const seal = ${JSON.stringify(seal)};
    fs.openSync = (file, ...args) => {
      if (file === seal) {
        fs.unlinkSync(seal);
        execFileSync('mkfifo', [seal]);
      }
      return open(file, ...args);
    };
    try {
      writeManifestSeal(${JSON.stringify(manifest)}, seal);
      process.exitCode = 2;
    } catch (error) {
      if (!/ENXIO|changed before writing/.test(error.message)) throw error;
    }
  `;
  const result = spawnSync(process.execPath, ['--input-type=module', '--eval', script], {
    encoding: 'utf8',
    timeout: 10000,
  });
  assert.equal(result.error, undefined);
  assert.equal(result.status, 0, result.stderr);
});

test('manifest seal is path-independent and detects tampering', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'manifest-seal-'));
  const manifestPath = path.join(directory, 'manifest.json');
  const sealPath = path.join(directory, 'manifest.sha256');
  fs.writeFileSync(manifestPath, '{"schemaVersion":2}\n');
  writeManifestSeal(manifestPath, sealPath);
  assert.match(
    fs.readFileSync(sealPath, 'utf8'),
    /^[0-9a-f]{64}  manifest\.json\n$/,
  );
  assert.doesNotMatch(fs.readFileSync(sealPath, 'utf8'), /manifest-seal-/);
  assert.doesNotThrow(() => verifyManifestSeal(manifestPath, sealPath));
  fs.appendFileSync(manifestPath, ' ');
  assert.throws(
    () => verifyManifestSeal(manifestPath, sealPath),
    /seal is invalid/,
  );
  fs.rmSync(directory, { recursive: true, force: true });
});

function manifestFixture() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'manifest-fixture-'));
  const planPath = path.join(directory, 'plan.json');
  const parametersPath = path.join(directory, 'parameters.json');
  const compiledTemplatePath = path.join(directory, 'compiled-template.json');
  const manifestPath = path.join(directory, 'manifest.json');
  fs.writeFileSync(
    planPath,
    JSON.stringify({
      changes: [],
      diagnostics: null,
      error: null,
      potentialChanges: null,
      status: 'Succeeded',
    }),
  );
  fs.writeFileSync(parametersPath, JSON.stringify(parameterDocument()));
  fs.writeFileSync(
    compiledTemplatePath,
    JSON.stringify({ metadata: { _generator: { templateHash: '123' } } }),
  );
  const templatePath = path.join(
    root,
    'infra/governance/bootstrap-planning-identity.bicep',
  );
  const sourceCommit = execFileSync('git', ['rev-parse', 'HEAD'], {
    cwd: root,
    encoding: 'utf8',
  }).trim();
  const manifest = createManifest({
    phase: 'A0-B1a-Planner',
    planPath,
    outputPath: manifestPath,
    templatePath,
    compiledTemplatePath,
    parametersPath,
    sourceRoot: root,
    sourceCommit,
    subscriptionId: subscription,
    tenantId: tenant,
    sourceFiles: [templatePath],
    artifactDirectory: directory,
  });
  return {
    directory,
    planPath,
    parametersPath,
    compiledTemplatePath,
    manifestPath,
    manifest,
  };
}

function manifestOptions(fixture) {
  return {
    manifestPath: fixture.manifestPath,
    planPath: fixture.planPath,
    parametersPath: fixture.parametersPath,
    compiledTemplatePath: fixture.compiledTemplatePath,
    sourceRoot: root,
    requireHead: true,
  };
}

test('manifest schema rejects extra fields, traversal, and case collisions', () => {
  const extra = manifestFixture();
  extra.manifest.unexpected = true;
  assert.throws(
    () => verifyManifestFiles(extra.manifest, manifestOptions(extra)),
    /missing or extra fields/,
  );
  fs.rmSync(extra.directory, { recursive: true, force: true });

  const traversal = manifestFixture();
  traversal.manifest.artifacts[0].path = '../outside.json';
  assert.throws(
    () => verifyManifestFiles(traversal.manifest, manifestOptions(traversal)),
    /traversal/,
  );
  fs.rmSync(traversal.directory, { recursive: true, force: true });

  const collision = manifestFixture();
  collision.manifest.artifacts.push({
    ...collision.manifest.artifacts[0],
    path: collision.manifest.artifacts[0].path.toUpperCase(),
  });
  assert.throws(
    () => verifyManifestFiles(collision.manifest, manifestOptions(collision)),
    /case-insensitive path collision/,
  );
  fs.rmSync(collision.directory, { recursive: true, force: true });
});

test('artifact inventory rejects symbolic links', (t) => {
  const fixture = manifestFixture();
  const linkPath = path.join(fixture.directory, 'linked-plan.json');
  try {
    fs.symlinkSync(fixture.planPath, linkPath, 'file');
  } catch (error) {
    fs.rmSync(fixture.directory, { recursive: true, force: true });
    if (error.code === 'EPERM' || error.code === 'EACCES') {
      t.skip('symbolic links are unavailable on this Windows host');
      return;
    }
    throw error;
  }
  assert.throws(
    () => verifyManifestFiles(fixture.manifest, manifestOptions(fixture)),
    /symbolic link/,
  );
  fs.rmSync(fixture.directory, { recursive: true, force: true });
});

test('legacy transition prevents lockout and removes broad roles before Phase B', () => {
  const { proof, transition } = validTransition();
  const now = Date.parse('2026-09-01T15:00:00Z');
  const validate = (candidate) =>
    validateLegacyTransition(candidate, proof, now);
  assert.deepEqual(validate(transition), {
    broadAccessRemoved: true,
    jitActivationTestCount: 2,
    nonLockoutVerified: true,
    temporaryAssignmentCount: 8,
  });
  const principalMutations = [
    [
      'legacy principal',
      (candidate, invalid) => {
        candidate.legacyPrincipalId = invalid;
      },
    ],
    [
      'temporary assignment principal',
      (candidate, invalid) => {
        candidate.temporaryAssignments[0].principalId = invalid;
      },
    ],
    [
      'safety principal',
      (candidate, invalid) => {
        candidate.changeControl.safetyAdminPrincipalId = invalid;
      },
    ],
    [
      'emergency principal',
      (candidate, invalid) => {
        candidate.changeControl.emergencyPrincipalIds[0] = invalid;
      },
    ],
  ];
  for (const [label, mutate] of principalMutations) {
    for (const invalid of malformedArtifactUuids) {
      const candidate = structuredClone(transition);
      mutate(candidate, invalid);
      assert.throws(
        () => validate(candidate),
        /non-nil canonical lowercase UUID string/,
        label,
      );
    }
  }

  const staleProfessionalProof = structuredClone(transition);
  staleProfessionalProof.subscriptionId =
    'f434ec55-f342-4948-9298-f99af5216204';
  assert.throws(
    () => validateLegacyTransition(staleProfessionalProof, proof, now),
    /subscriptionId does not match the target subscription/,
  );
  const liveAssignments = transition.temporaryAssignments.map(
    ({
      createdAt,
      expiresAt,
      owner,
      purpose,
      rollbackProcedure,
      scheduleInstanceId,
      ...assignment
    }) => ({
      ...assignment,
      id: scheduleInstanceId.replace(
        '/roleAssignmentScheduleInstances/',
        '/roleAssignments/',
      ),
    }),
  );
  const liveScheduleInstances = transition.temporaryAssignments.map(
    ({
      scheduleInstanceId,
      scope,
      principalId,
      principalType,
      roleDefinitionId,
      condition,
      conditionVersion,
      createdAt,
      expiresAt,
    }) => ({
      id: scheduleInstanceId,
      properties: {
        scope,
        principalId,
        principalType,
        roleDefinitionId,
        condition,
        conditionVersion,
        startDateTime: createdAt,
        endDateTime: expiresAt,
        originRoleAssignmentId: scheduleInstanceId.replace(
          '/roleAssignmentScheduleInstances/',
          '/roleAssignments/',
        ),
        assignmentType: 'Assigned',
        memberType: 'Direct',
        status: 'Provisioned',
      },
    }),
  );
  const liveIndependentAdminSchedules = [independentAdminSchedule(transition)];
  assert.doesNotThrow(() =>
    validateLegacyLiveAssignments(
      liveAssignments,
      liveScheduleInstances,
      transition,
      proof,
      Date.parse('2026-09-02T10:00:00Z'),
      [],
      [],
      liveIndependentAdminSchedules,
    ),
  );
  const equivalentAzureSchedules = structuredClone(liveScheduleInstances);
  equivalentAzureSchedules[0].properties.startDateTime =
    '2026-09-01T12:00:00.0000000+02:00';
  equivalentAzureSchedules[0].properties.endDateTime =
    '2026-09-08T11:00:00.000+01:00';
  assert.doesNotThrow(() =>
    validateLegacyLiveAssignments(
      liveAssignments,
      equivalentAzureSchedules,
      transition,
      proof,
      Date.parse('2026-09-02T10:00:00Z'),
      [],
      [],
      liveIndependentAdminSchedules,
    ),
  );
  for (const [label, timestampValue, pattern] of [
    ['impossible date', '2026-09-31T10:00:00Z', /schedule start .* is invalid/],
    [
      'sub-millisecond mismatch',
      '2026-09-01T10:00:00.0000001Z',
      /does not match the approved transition/,
    ],
  ]) {
    const invalidSchedules = structuredClone(liveScheduleInstances);
    invalidSchedules[0].properties.startDateTime = timestampValue;
    assert.throws(
      () =>
        validateLegacyLiveAssignments(
          liveAssignments,
          invalidSchedules,
          transition,
          proof,
          Date.parse('2026-09-02T10:00:00Z'),
          [],
          [],
          liveIndependentAdminSchedules,
        ),
      pattern,
      label,
    );
  }

  const premature = structuredClone(transition);
  premature.replacementJit.activationTests[1].testedAt =
    '2026-09-01T11:00:00Z';
  assert.throws(
    () => validate(premature),
    /cannot be removed before two JIT activations/,
  );

  const oneActivation = structuredClone(transition);
  oneActivation.replacementJit.activationTests.pop();
  assert.throws(
    () => validate(oneActivation),
    /exactly two JIT activation tests/,
  );

  const reusedActivationProof = structuredClone(transition);
  reusedActivationProof.replacementJit.activationTests[1].evidenceSha256 =
    reusedActivationProof.replacementJit.activationTests[0].evidenceSha256;
  assert.throws(
    () => validate(reusedActivationProof),
    /independently evidenced/,
  );

  const parallelChanges = structuredClone(transition);
  parallelChanges.changeControl.assignmentChangesSerialized = false;
  assert.throws(
    () => validate(parallelChanges),
    /one at a time/,
  );

  const sameOwnerAdmin = structuredClone(transition);
  sameOwnerAdmin.changeControl.independentAdminOwner =
    sameOwnerAdmin.changeControl.operatorOwner;
  assert.throws(
    () => validate(sameOwnerAdmin),
    /real third-party or MSP/,
  );

  const approvedSolo = structuredClone(transition);
  approvedSolo.changeControl.administrationMode =
    'approved-solo-compensating-controls';
  approvedSolo.changeControl.independentAdminOwner = null;
  approvedSolo.changeControl.independentAdminTenantId = null;
  approvedSolo.changeControl.independentAdminScope = null;
  approvedSolo.changeControl.independentAdminPrincipalId = null;
  approvedSolo.changeControl.independentAdminRoleDefinitionId = null;
  approvedSolo.changeControl.independentAdminScheduleInstanceId = null;
  approvedSolo.changeControl.independentAdminExpiresAt = null;
  approvedSolo.changeControl.soloModeControls = {
    riskAcceptance: {
      approvedAt: '2026-09-01T07:00:00Z',
      expiresAt: '2026-09-08T10:00:00Z',
      scope: `/subscriptions/${subscription}/governance-phase-b`,
      evidenceSha256: '7'.repeat(64),
    },
    dailyAndAdminAccountsSeparated: true,
    sameHumanControlAcknowledged: true,
    managementTenantId: tenant,
    tenantIssuerDomain: 'fdpo.onmicrosoft.com',
    breakGlassAccounts: [
      {
        userPrincipalName: 'certigo-emergency-1@certigoapp.onmicrosoft.com',
        userType: 'Member',
        accountEnabled: true,
        tenantId: tenant,
        objectId: '30000000-0000-0000-0000-000000000003',
        managementAccessVerified: true,
        authenticationMethodCount: 1,
        authenticationMethodsTested: true,
        creationType: null,
        onPremisesSyncEnabled: false,
        issuer: 'fdpo.onmicrosoft.com',
      },
      {
        userPrincipalName: 'certigo-emergency-2@fdpo.onmicrosoft.com',
        userType: 'Member',
        accountEnabled: true,
        tenantId: tenant,
        objectId: '30000000-0000-0000-0000-000000000004',
        managementAccessVerified: true,
        authenticationMethodCount: 1,
        authenticationMethodsTested: true,
        creationType: null,
        onPremisesSyncEnabled: null,
        issuer: 'fdpo.onmicrosoft.com',
      },
    ],
    breakGlassAccountsCloudOnly: true,
    breakGlassGlobalAdministratorActivePermanent: true,
    breakGlassEvidenceSha256: '8'.repeat(64),
    credentialMode: 'authenticator-device-bound-passkeys',
    credentialCount: 2,
    credentialsDistinctAndTested: true,
    credentialDevicesDistinct: true,
    credentialAttestationAaguids: [
      '10000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000002',
    ],
    credentialEvidenceSha256: '9'.repeat(64),
    whfbPolicyEligibleAndTested: null,
    guestPasskeyPathRejected: true,
    personalDeviceDependencyAbsent: true,
    phishingResistantCredentialsDistinct: true,
    credentialsStoredSeparately: true,
    conditionalAccessExclusionsVerified: true,
    conditionalAccessEvidenceSha256: 'a'.repeat(64),
    alertingEnabled: true,
    periodicTestCadenceDays: 30,
    recoveryDrillTestedAt: '2026-09-01T13:00:00Z',
    nonLockoutEvidenceSha256: 'b'.repeat(64),
    rollbackEvidenceSha256: 'c'.repeat(64),
  };
  assert.doesNotThrow(() => validate(approvedSolo));
  const soloIdentifierMutations = [
    [
      'management tenant',
      (candidate, invalid) => {
        candidate.changeControl.soloModeControls.managementTenantId = invalid;
      },
    ],
    [
      'break-glass tenant',
      (candidate, invalid) => {
        candidate.changeControl.soloModeControls.breakGlassAccounts[0].tenantId =
          invalid;
      },
    ],
    [
      'break-glass principal',
      (candidate, invalid) => {
        candidate.changeControl.soloModeControls.breakGlassAccounts[0].objectId =
          invalid;
      },
    ],
  ];
  for (const [label, mutate] of soloIdentifierMutations) {
    for (const invalid of malformedArtifactUuids) {
      const candidate = structuredClone(approvedSolo);
      mutate(candidate, invalid);
      assert.throws(
        () => validate(candidate),
        /non-nil canonical lowercase UUID string/,
        label,
      );
    }
  }
  for (const invalidAaguid of [
    null,
    [],
    {},
    'UNKNOWN',
    '00000000-0000-0000-0000-000000000000',
    '10000000000000000000000000000001',
    '10000000-0000-0000-0000-00000000000A',
  ]) {
    const malformedCredential = structuredClone(approvedSolo);
    malformedCredential.changeControl.soloModeControls
      .credentialAttestationAaguids[0] = invalidAaguid;
    assert.throws(
      () => validate(malformedCredential),
      /canonical lowercase UUID string/,
    );
  }
  const unrelatedEmergencyEvidence = structuredClone(approvedSolo);
  unrelatedEmergencyEvidence.changeControl.soloModeControls
    .breakGlassAccounts[0].objectId =
    '6503a9b1-1e64-4c39-9ec7-c15a1c911c80';
  assert.throws(
    () => validate(unrelatedEmergencyEvidence),
    /must exactly match both emergency principal IDs/,
  );
  const duplicateEmergencyEvidence = structuredClone(approvedSolo);
  duplicateEmergencyEvidence.changeControl.soloModeControls
    .breakGlassAccounts[1].objectId =
    duplicateEmergencyEvidence.changeControl.soloModeControls
      .breakGlassAccounts[0].objectId;
  assert.throws(
    () => validate(duplicateEmergencyEvidence),
    /must exactly match both emergency principal IDs/,
  );
  const noManagementEmergencyAccounts = structuredClone(approvedSolo);
  noManagementEmergencyAccounts.changeControl.soloModeControls
    .breakGlassAccounts = [];
  assert.throws(
    () => validate(noManagementEmergencyAccounts),
    /NO-GO: exactly two qualified emergency accounts.*management tenant/,
  );
  approvedSolo.changeControl.soloModeControls.riskAcceptance.evidenceSha256 =
    null;
  assert.throws(
    () => validate(approvedSolo),
    /solo-mode risk acceptance/,
  );
  approvedSolo.changeControl.soloModeControls.riskAcceptance.evidenceSha256 =
    '7'.repeat(64);
  approvedSolo.changeControl.soloModeControls.credentialsDistinctAndTested =
    false;
  assert.throws(
    () => validate(approvedSolo),
    /two tested active cloud-only native Member accounts/,
  );
  approvedSolo.changeControl.soloModeControls.credentialsDistinctAndTested =
    true;
  approvedSolo.changeControl.soloModeControls.breakGlassAccounts[0]
    .userPrincipalName = 'guest_example.com#EXT#@fdpo.onmicrosoft.com';
  assert.throws(
    () => validate(approvedSolo),
    /active cloud-only native Member accounts/,
  );

  const oneDevicePasskeys = structuredClone(approvedSolo);
  oneDevicePasskeys.changeControl.soloModeControls.breakGlassAccounts[0]
    .userPrincipalName =
    'certigo-emergency-1@certigoapp.onmicrosoft.com';
  oneDevicePasskeys.changeControl.soloModeControls.credentialAttestationAaguids[1] =
    oneDevicePasskeys.changeControl.soloModeControls
      .credentialAttestationAaguids[0];
  assert.throws(
    () => validate(oneDevicePasskeys),
    /two admissible distinct credentials/,
  );

  const untestedWhfb = structuredClone(oneDevicePasskeys);
  untestedWhfb.changeControl.soloModeControls.credentialMode = 'whfb-tested';
  untestedWhfb.changeControl.soloModeControls.credentialDevicesDistinct = null;
  untestedWhfb.changeControl.soloModeControls.credentialAttestationAaguids =
    null;
  untestedWhfb.changeControl.soloModeControls.whfbPolicyEligibleAndTested =
    false;
  assert.throws(
    () => validate(untestedWhfb),
    /two admissible distinct credentials/,
  );

  const retrospectiveAcceptance = structuredClone(approvedSolo);
  retrospectiveAcceptance.changeControl.soloModeControls.breakGlassAccounts[0]
    .userPrincipalName =
    'certigo-emergency-1@certigoapp.onmicrosoft.com';
  retrospectiveAcceptance.changeControl.soloModeControls.riskAcceptance.approvedAt =
    retrospectiveAcceptance.broadRemoval.uaaRemovedAt;
  assert.throws(
    () => validate(retrospectiveAcceptance),
    /cannot be removed before two JIT activations/,
  );

  const invitedMember = structuredClone(approvedSolo);
  invitedMember.changeControl.soloModeControls.breakGlassAccounts[0]
    .userPrincipalName =
    'certigo-emergency-1@certigoapp.onmicrosoft.com';
  invitedMember.changeControl.soloModeControls.breakGlassAccounts[0]
    .creationType = 'Invitation';
  assert.throws(
    () => validate(invitedMember),
    /active cloud-only native Member accounts/,
  );

  const wrongIssuer = structuredClone(invitedMember);
  wrongIssuer.changeControl.soloModeControls.breakGlassAccounts[0]
    .creationType = null;
  wrongIssuer.changeControl.soloModeControls.breakGlassAccounts[0].issuer =
    'other.onmicrosoft.com';
  assert.throws(
    () => validate(wrongIssuer),
    /tenant issuer/,
  );

  const crossTenantAccount = structuredClone(wrongIssuer);
  crossTenantAccount.changeControl.soloModeControls.breakGlassAccounts[0]
    .issuer = 'fdpo.onmicrosoft.com';
  crossTenantAccount.changeControl.soloModeControls.breakGlassAccounts[0]
    .tenantId = 'af721be8-5901-422a-b299-b9c57847b968';
  assert.throws(
    () => validate(crossTenantAccount),
    /subscription management tenant/,
  );

  const missingAuthenticationEvidence = structuredClone(crossTenantAccount);
  missingAuthenticationEvidence.changeControl.soloModeControls
    .breakGlassAccounts[0].tenantId = tenant;
  missingAuthenticationEvidence.changeControl.soloModeControls
    .breakGlassAccounts[0].authenticationMethodCount = 0;
  missingAuthenticationEvidence.changeControl.soloModeControls
    .breakGlassAccounts[0].authenticationMethodsTested = false;
  assert.throws(
    () => validate(missingAuthenticationEvidence),
    /authentication methods/,
  );

  const equalBoundary = structuredClone(transition);
  equalBoundary.rollback.testedAt =
    equalBoundary.broadRemoval.uaaRemovedAt;
  assert.throws(
    () => validate(equalBoundary),
    /cannot be removed before two JIT activations/,
  );

  const simultaneousRemoval = structuredClone(transition);
  simultaneousRemoval.broadRemoval.uaaRemovedAt =
    simultaneousRemoval.broadRemoval.contributorRemovedAt;
  assert.throws(
    () => validate(simultaneousRemoval),
    /cannot be removed before two JIT activations/,
  );

  const lateTemporaryAssignment = structuredClone(transition);
  lateTemporaryAssignment.temporaryAssignments[0].createdAt =
    lateTemporaryAssignment.broadRemoval.uaaRemovedAt;
  assert.throws(
    () => validate(lateTemporaryAssignment),
    /predate UAA removal/,
  );

  assert.throws(
    () =>
      validateLegacyTransition(
        transition,
        proof,
        Date.parse('2026-09-01T10:29:59Z'),
      ),
    /cannot be removed before two JIT activations/,
  );

  const unbounded = structuredClone(transition);
  unbounded.temporaryAssignments[0].expiresAt = '2026-09-09T10:00:00Z';
  assert.throws(
    () => validate(unbounded),
    /expire by the approved soak end/,
  );

  const missing = structuredClone(transition);
  missing.temporaryAssignments.pop();
  assert.throws(
    () => validate(missing),
    /exact canary contract/,
  );

  liveAssignments.push({
    id:
      `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
      'roleAssignments/60000000-0000-0000-0000-000000000001',
    scope: `/subscriptions/${subscription}`,
    principalId: transition.legacyPrincipalId,
    principalType: 'ServicePrincipal',
    roleDefinitionId:
      `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
      'roleDefinitions/18d7d88d-d35e-4fb5-a5c3-7773c20a72d9',
  });
  assert.throws(
    () =>
      validateLegacyLiveAssignments(
        liveAssignments,
        liveScheduleInstances,
        transition,
        proof,
        Date.parse('2026-09-02T10:00:00Z'),
        [],
        [],
        liveIndependentAdminSchedules,
      ),
    /Owner, Contributor, or UAA access remains live/,
  );

  const transitiveGroupId = '30000000-0000-0000-0000-000000000099';
  const groupAssignment = {
    ...liveAssignments[0],
    id:
      `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
      'roleAssignments/60000000-0000-0000-0000-000000000099',
    principalId: transitiveGroupId,
  };
  assert.throws(
    () =>
      validateLegacyLiveAssignments(
        [...liveAssignments.slice(0, -1), groupAssignment],
        liveScheduleInstances,
        transition,
        proof,
        Date.parse('2026-09-02T10:00:00Z'),
        [transitiveGroupId],
        [],
        liveIndependentAdminSchedules,
      ),
    /transitive group assignment remains live/,
  );
  assert.throws(
    () =>
      validateLegacyLiveAssignments(
        liveAssignments.slice(0, -1),
        liveScheduleInstances,
        transition,
        proof,
        Date.parse('2026-09-02T10:00:00Z'),
        [],
        [
          {
            id:
              `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
              'roleEligibilityScheduleInstances/60000000-0000-0000-0000-000000000098',
            properties: {
              principalId: transition.legacyPrincipalId,
            },
          },
        ],
        liveIndependentAdminSchedules,
      ),
    /retains a PIM eligibility schedule/,
  );

  const permanentSchedule = structuredClone(liveScheduleInstances);
  permanentSchedule[0].properties.endDateTime = null;
  assert.throws(
    () =>
      validateLegacyLiveAssignments(
        liveAssignments.slice(0, -1),
        permanentSchedule,
        transition,
        proof,
        Date.parse('2026-09-02T10:00:00Z'),
        [],
        [],
        liveIndependentAdminSchedules,
      ),
    /schedule expiry/,
  );
});

test('independent admin evidence exactly matches one live active UAA schedule', () => {
  const { proof, transition } = validTransition();
  const now = Date.parse('2026-09-02T10:00:00Z');
  const live = independentAdminSchedule(transition);
  const validate = (candidateTransition, candidateLive = live) =>
    validateIndependentAdminLiveSchedule(
      candidateLive === null ? [] : [candidateLive],
      candidateTransition,
      proof,
      now,
    );
  assert.doesNotThrow(() => validate(transition));
  for (const [label, field] of [
    ['tenant', 'independentAdminTenantId'],
    ['principal', 'independentAdminPrincipalId'],
    ['safety principal', 'safetyAdminPrincipalId'],
  ]) {
    for (const invalid of malformedArtifactUuids) {
      const candidate = structuredClone(transition);
      candidate.changeControl[field] = invalid;
      assert.throws(
        () => validate(candidate, independentAdminSchedule(candidate)),
        /non-nil canonical lowercase UUID string/,
        label,
      );
    }
  }
  for (const field of ['tenantId', 'subscriptionId']) {
    const candidateProof = structuredClone(proof);
    candidateProof[field] = candidateProof[field].toUpperCase();
    assert.throws(
      () =>
        validateIndependentAdminLiveSchedule(
          [independentAdminSchedule(transition)],
          transition,
          candidateProof,
          now,
        ),
      /non-nil canonical lowercase UUID string/,
      `Phase A ${field}`,
    );
  }
  const azureResponseShape = independentAdminSchedule(transition);
  azureResponseShape.properties.startDateTime = '2026-09-01T12:00:00.91+02:00';
  azureResponseShape.properties.endDateTime =
    '2026-09-08T12:00:00.0000000+02:00';
  delete azureResponseShape.properties.condition;
  delete azureResponseShape.properties.conditionVersion;
  assert.doesNotThrow(() => validate(transition, azureResponseShape));
  const leapDay = structuredClone(transition);
  leapDay.changeControl.independentAdminExpiresAt = '2028-02-29T10:00:00Z';
  assert.doesNotThrow(() =>
    validate(leapDay, independentAdminSchedule(leapDay)),
  );

  const cases = [
    [
      'tenant',
      (candidate) => {
        candidate.changeControl.independentAdminTenantId =
          '00000000-0000-0000-0000-000000000099';
      },
      /target tenant/,
    ],
    [
      'scope',
      (candidate) => {
        candidate.changeControl.independentAdminScope += '/';
      },
      /canonical subscription scope/,
    ],
    [
      'live scope',
      (_candidate, candidateLive) => {
        candidateLive.properties.scope += '/resourceGroups/rg-certigo-ci';
      },
      /does not match approved evidence/,
    ],
    [
      'principal',
      (_candidate, candidateLive) => {
        candidateLive.properties.principalId =
          '30000000-0000-0000-0000-000000000099';
      },
      /does not match approved evidence/,
    ],
    [
      'schedule',
      (_candidate, candidateLive) => {
        candidateLive.id =
          `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
          'roleAssignmentScheduleInstances/50000000-0000-0000-0000-000000000098';
      },
      /does not match approved evidence/,
    ],
    [
      'role',
      (_candidate, candidateLive) => {
        candidateLive.properties.roleDefinitionId =
          `/subscriptions/${subscription}/providers/Microsoft.Authorization/` +
          'roleDefinitions/70000000-0000-0000-0000-000000000001';
      },
      /does not match approved evidence/,
    ],
    [
      'window',
      (_candidate, candidateLive) => {
        candidateLive.properties.startDateTime = '2026-09-03T10:00:00Z';
      },
      /outside its active window/,
    ],
    [
      'expiry',
      (_candidate, candidateLive) => {
        candidateLive.properties.endDateTime = '2026-09-07T10:00:00Z';
      },
      /does not match approved evidence/,
    ],
    [
      'condition',
      (_candidate, candidateLive) => {
        candidateLive.properties.condition =
          "@Resource[Microsoft.Storage/storageAccounts:name] StringEquals 'restricted'";
      },
      /does not match approved evidence/,
    ],
    [
      'condition version',
      (_candidate, candidateLive) => {
        candidateLive.properties.conditionVersion = '2.0';
      },
      /does not match approved evidence/,
    ],
    [
      'empty condition',
      (_candidate, candidateLive) => {
        candidateLive.properties.condition = '';
      },
      /does not match approved evidence/,
    ],
    [
      'empty condition version',
      (_candidate, candidateLive) => {
        candidateLive.properties.conditionVersion = '';
      },
      /does not match approved evidence/,
    ],
    [
      'malformed live timestamp',
      (_candidate, candidateLive) => {
        candidateLive.properties.startDateTime = '2026-09-01T10:00:00.12345678Z';
      },
      /explicit UTC timestamp/,
    ],
    [
      'impossible live date',
      (_candidate, candidateLive) => {
        candidateLive.properties.startDateTime = '2026-09-31T10:00:00Z';
      },
      /schedule start is invalid/,
    ],
    [
      'unknown zero offset',
      (_candidate, candidateLive) => {
        candidateLive.properties.startDateTime = '2026-09-01T10:00:00-00:00';
      },
      /schedule start is invalid/,
    ],
    [
      'out-of-range offset',
      (_candidate, candidateLive) => {
        candidateLive.properties.startDateTime = '2026-09-01T10:00:00+14:01';
      },
      /schedule start is invalid/,
    ],
    [
      'sub-millisecond expiry mismatch',
      (_candidate, candidateLive) => {
        candidateLive.properties.endDateTime = '2026-09-08T10:00:00.0000001Z';
      },
      /does not match approved evidence/,
    ],
  ];
  for (const [label, mutate, pattern] of cases) {
    const candidate = structuredClone(transition);
    const candidateLive = independentAdminSchedule(candidate);
    mutate(candidate, candidateLive);
    assert.throws(() => validate(candidate, candidateLive), pattern, label);
  }
  assert.throws(() => validate(transition, null), /exactly one schedule instance/);
  const missingExpiry = structuredClone(transition);
  delete missingExpiry.changeControl.independentAdminExpiresAt;
  assert.throws(
    () => validate(missingExpiry, independentAdminSchedule(missingExpiry)),
    /expiresAt must be an explicit UTC timestamp/,
  );
  const expired = structuredClone(transition);
  expired.changeControl.independentAdminExpiresAt = '2026-09-02T10:00:00Z';
  const expiredLive = independentAdminSchedule(expired);
  assert.throws(
    () => validate(expired, expiredLive),
    /expiry must be strictly later than now/,
  );
  const fractionalApprovedExpiry = structuredClone(transition);
  fractionalApprovedExpiry.changeControl.independentAdminExpiresAt =
    '2026-09-08T10:00:00.000Z';
  assert.throws(
    () =>
      validate(
        fractionalApprovedExpiry,
        independentAdminSchedule(fractionalApprovedExpiry),
      ),
    /expiresAt must be an explicit UTC timestamp/,
  );
  for (const invalidExpiry of [
    '2026-09-31T10:00:00Z',
    '2025-02-29T10:00:00Z',
  ]) {
    const invalidCalendar = structuredClone(transition);
    invalidCalendar.changeControl.independentAdminExpiresAt = invalidExpiry;
    assert.throws(
      () =>
        validate(
          invalidCalendar,
          independentAdminSchedule(invalidCalendar),
        ),
      /independent admin expiresAt is invalid/,
    );
  }
});

test('assignment IDs require canonical UUID strings before comparison', () => {
  const invalidIdentifiers = [
    null,
    [],
    {},
    'UNKNOWN',
    '00000000-0000-0000-0000-000000000000',
    '40000000000000000000000000000001',
    '40000000-0000-0000-0000-00000000000A',
  ];
  for (const invalid of invalidIdentifiers) {
    const { proof, transition } = validTransition();
    transition.inventory.assignmentIds[0] = invalid;
    assert.throws(
      () => validateLegacyTransition(transition, proof),
      /canonical lowercase UUID string/,
    );
  }
  {
    const { proof, transition } = validTransition();
    transition.inventory.assignmentIds[1] =
      transition.inventory.assignmentIds[0];
    assert.throws(
      () => validateLegacyTransition(transition, proof),
      /inventory assignment IDs are invalid/,
    );
  }
  for (const invalid of invalidIdentifiers) {
    const { proof, transition } = validTransition();
    transition.broadRemoval.contributorAssignmentId = invalid;
    assert.throws(
      () => validateLegacyTransition(transition, proof),
      /canonical lowercase UUID string/,
    );
  }
});
test('runbook fixes planner count, transition ordering, and Phase A repair proof', () => {
  const runbook = fs.readFileSync(
    path.join(root, 'docs/runbooks/CLOUD_LEAST_PRIVILEGE.md'),
    'utf8',
  );
  assert.match(runbook, /cinq attributions PIM décrites/);
  assert.doesNotMatch(runbook, /six attributions PIM décrites/);
  assert.ok(
    runbook.indexOf('Créer le remplacement humain JIT') <
      runbook.indexOf('Retirer les rôles larges avant Phase B') &&
      runbook.indexOf('Retirer les rôles larges avant Phase B') <
        runbook.indexOf('Prévol B1a'),
  );
  assert.match(runbook, /exactement huit attributions\s+temporaires/);
  assert.match(runbook, /Never reconstruct it locally|reconstruit ne constituent jamais/);
  assert.match(runbook, /changement de réparation séparé/);
  assert.match(runbook, /LEGACY_TRANSITION_FILE/);
  assert.match(runbook, /domaines UPN secondaires `\*\.onmicrosoft\.com`/);
  assert.match(runbook, /B2B `#EXT#`/);
  assert.match(runbook, /deux passkeys\s+Authenticator device-bound/);
  assert.match(runbook, /WHfB ne compte qu'après preuve/);
  assert.match(runbook, /téléphone unique est refusé/);
  assert.match(
    runbook,
    /f434ec55-f342-4948-9298-f99af5216204/,
  );
  assert.match(
    runbook,
    /e9174162-1033-40c0-b0c9-f31825914fbe/,
  );
  assert.match(runbook, /ancienne paire est stale et refusé/);
  const prepare = fs.readFileSync(
    path.join(root, 'infra/governance/prepare-phase-b.sh'),
    'utf8',
  );
  const phaseBWorkflow = fs.readFileSync(
    path.join(
      root,
      '.github/workflows/governance-bootstrap-phase-b-what-if.yml',
    ),
    'utf8',
  );
  assert.match(prepare, /legacy-transition-contract\.mjs/);
  assert.match(prepare, /broad access.*JIT activation|Never reconstruct it locally/s);
  assert.match(prepare, /collect-role-assignment-schedules\.mjs/);
  assert.match(prepare, /collect-transitive-groups\.mjs/);
  assert.match(prepare, /roleEligibilityScheduleInstances/);
  assert.match(prepare, /LEGACY_TRANSITION_SHA256/);
  assert.match(phaseBWorkflow, /legacy_transition_json/);
  assert.match(phaseBWorkflow, /legacy_transition_sha256/);
  assert.match(phaseBWorkflow, /LEGACY_TRANSITION_SHA256/);
  assert.match(phaseBWorkflow, /phase-b-target\.mjs/);
  for (const script of [
    'prepare-phase-b.sh',
    'what-if-phase-b1.sh',
    'what-if-phase-b1b.sh',
    'what-if-phase-b2.sh',
    'deploy-phase-b1.sh',
    'deploy-phase-b1b.sh',
    'deploy-phase-b2.sh',
  ]) {
    assert.match(
      fs.readFileSync(path.join(root, 'infra/governance', script), 'utf8'),
      /phase-b-target\.mjs/,
    );
  }
});
