import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import {
  runtimeWriterCondition,
  validatePhaseAProof,
} from './validate-what-if.mjs';

const contributorRoleDefinitionId = 'b24988ac-6180-42a0-ab88-20f7382dd24c';
const userAccessAdministratorRoleDefinitionId =
  '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9';
const ownerRoleDefinitionId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635';

function requireExactFields(value, expected, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
  if (
    JSON.stringify(Object.keys(value).sort()) !==
    JSON.stringify([...expected].sort())
  ) {
    throw new Error(`${label} has missing or extra fields`);
  }
}

function requireSha256(value, label) {
  if (typeof value !== 'string' || !/^[0-9a-f]{64}$/.test(value)) {
    throw new Error(`${label} must be a lowercase SHA-256`);
  }
}

function requireUuid(value, label) {
  if (
    typeof value !== 'string' ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      value,
    )
  ) {
    throw new Error(`${label} must be a UUID`);
  }
  return normalize(value);
}

function requireNonEmptyString(value, label) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`${label} must be a non-empty string`);
  }
}

function timestamp(value, label) {
  if (
    typeof value !== 'string' ||
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(value)
  ) {
    throw new Error(`${label} must be an explicit UTC timestamp`);
  }
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed)) {
    throw new Error(`${label} is invalid`);
  }
  return parsed;
}

function normalize(value) {
  return String(value ?? '').toLowerCase();
}

function expectedTemporaryAssignments(proof, legacyPrincipalId) {
  const subscriptionScope = `/subscriptions/${proof.subscriptionId}`;
  const role = (roleDefinitionId) =>
    `${subscriptionScope}/providers/Microsoft.Authorization/roleDefinitions/` +
    roleDefinitionId;
  const assignment = (
    purpose,
    scope,
    roleDefinitionId,
    condition = null,
  ) => ({
    purpose,
    scope,
    principalId: legacyPrincipalId,
    principalType: 'ServicePrincipal',
    roleDefinitionId,
    condition,
    conditionVersion: condition ? '2.0' : null,
  });
  const assignments = [
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
    assignments.push(
      assignment(
        `rollback-${environment}-deployment`,
        scope,
        role(contributorRoleDefinitionId),
      ),
      assignment(
        `rollback-${environment}-runtime-rbac`,
        scope,
        proof.roleDefinitionIds.runtimeRoleAssignmentWriter,
        runtimeWriterCondition(),
      ),
    );
  }
  return assignments;
}

function comparableAssignment(assignment) {
  return {
    purpose: assignment.purpose,
    scope: normalize(assignment.scope),
    principalId: normalize(assignment.principalId),
    principalType: assignment.principalType,
    roleDefinitionId: normalize(assignment.roleDefinitionId),
    condition: assignment.condition,
    conditionVersion: assignment.conditionVersion,
  };
}

function comparableLiveAssignment(assignment) {
  return {
    scope: normalize(assignment.scope),
    principalId: normalize(assignment.principalId),
    principalType: assignment.principalType,
    roleDefinitionId: normalize(assignment.roleDefinitionId),
    condition: assignment.condition ?? null,
    conditionVersion: assignment.conditionVersion ?? null,
  };
}

function requireResourceId(value, resourceType, label) {
  if (
    typeof value !== 'string' ||
    !normalize(value).includes(`/providers/microsoft.authorization/${resourceType}/`)
  ) {
    throw new Error(`${label} is invalid`);
  }
  return normalize(value);
}

function requireSameTimestamp(actual, expected, label) {
  if (Date.parse(actual) !== Date.parse(expected)) {
    throw new Error(`${label} does not match the approved transition`);
  }
}

export function validateLegacyLiveAssignments(
  assignments,
  scheduleInstances,
  transition,
  phaseA,
  now = Date.now(),
) {
  if (!Array.isArray(assignments)) {
    throw new Error('live legacy assignment inventory must be an array');
  }
  if (!Array.isArray(scheduleInstances)) {
    throw new Error('live legacy schedule inventory must be an array');
  }
  const proof = validatePhaseAProof(phaseA, transition.subscriptionId);
  const subscriptionScope = normalize(`/subscriptions/${proof.subscriptionId}`);
  const broadRoleIds = new Set([
    contributorRoleDefinitionId,
    userAccessAdministratorRoleDefinitionId,
    ownerRoleDefinitionId,
  ]);
  for (const assignment of assignments) {
    const roleId = normalize(assignment.roleDefinitionId).split('/').at(-1);
    if (
      normalize(assignment.scope) === subscriptionScope &&
      broadRoleIds.has(roleId)
    ) {
      throw new Error('broad subscription Owner, Contributor, or UAA access remains live');
    }
  }
  const expectedContracts = expectedTemporaryAssignments(
    proof,
    transition.legacyPrincipalId,
  ).map(comparableAssignment);
  const liveContracts = assignments.map(comparableLiveAssignment);
  const liveAssignmentsById = new Map();
  for (const assignment of assignments) {
    const assignmentId = requireResourceId(
      assignment.id,
      'roleassignments',
      'live legacy role assignment ID',
    );
    if (liveAssignmentsById.has(assignmentId)) {
      throw new Error('live legacy role assignment IDs must be unique');
    }
    liveAssignmentsById.set(assignmentId, assignment);
  }
  if (liveContracts.length !== expectedContracts.length) {
    throw new Error('unexpected legacy role assignment remains live');
  }
  for (const expected of expectedContracts) {
    if (
      !liveContracts.some(
        (actual) =>
          JSON.stringify(actual) ===
          JSON.stringify({
            scope: expected.scope,
            principalId: expected.principalId,
            principalType: expected.principalType,
            roleDefinitionId: expected.roleDefinitionId,
            condition: expected.condition,
            conditionVersion: expected.conditionVersion,
          }),
      )
    ) {
      throw new Error(`temporary legacy assignment is not live: ${expected.purpose}`);
    }
  }
  if (scheduleInstances.length !== transition.temporaryAssignments.length) {
    throw new Error('unexpected legacy assignment schedule remains live');
  }
  const observedScheduleIds = new Set();
  const scheduledRoleAssignmentIds = new Set();
  for (const declared of transition.temporaryAssignments) {
    const scheduleId = normalize(declared.scheduleInstanceId);
    const live = scheduleInstances.find(
      (candidate) => normalize(candidate.id) === scheduleId,
    );
    if (!live || observedScheduleIds.has(scheduleId)) {
      throw new Error(`approved schedule instance is not live: ${declared.purpose}`);
    }
    observedScheduleIds.add(scheduleId);
    const properties = live.properties ?? {};
    const originRoleAssignmentId = requireResourceId(
      properties.originRoleAssignmentId,
      'roleassignments',
      `schedule backing assignment for ${declared.purpose}`,
    );
    if (
      !liveAssignmentsById.has(originRoleAssignmentId) ||
      scheduledRoleAssignmentIds.has(originRoleAssignmentId)
    ) {
      throw new Error(
        `schedule backing assignment is missing or reused: ${declared.purpose}`,
      );
    }
    scheduledRoleAssignmentIds.add(originRoleAssignmentId);
    const expected = comparableAssignment(declared);
    const actual = comparableLiveAssignment(properties);
    if (
      JSON.stringify(actual) !==
      JSON.stringify({
        scope: expected.scope,
        principalId: expected.principalId,
        principalType: expected.principalType,
        roleDefinitionId: expected.roleDefinitionId,
        condition: expected.condition,
        conditionVersion: expected.conditionVersion,
      })
    ) {
      throw new Error(`schedule instance contract mismatch: ${declared.purpose}`);
    }
    requireSameTimestamp(
      properties.startDateTime,
      declared.createdAt,
      `schedule start for ${declared.purpose}`,
    );
    requireSameTimestamp(
      properties.endDateTime,
      declared.expiresAt,
      `schedule expiry for ${declared.purpose}`,
    );
    if (
      properties.assignmentType !== 'Assigned' ||
      properties.memberType !== 'Direct' ||
      !['Accepted', 'Granted', 'Provisioned', 'ScheduleCreated'].includes(
        properties.status,
      )
    ) {
      throw new Error(`schedule instance is not active and direct: ${declared.purpose}`);
    }
    if (
      Date.parse(properties.startDateTime) > now ||
      Date.parse(properties.endDateTime) <= now
    ) {
      throw new Error(`schedule instance is outside its active window: ${declared.purpose}`);
    }
  }
  if (scheduledRoleAssignmentIds.size !== liveAssignmentsById.size) {
    throw new Error('an unbounded legacy role assignment remains live');
  }
}

export function validateLegacyTransition(
  transition,
  phaseA,
  now = Date.now(),
) {
  requireExactFields(
    transition,
    [
      'broadRemoval',
      'changeControl',
      'inventory',
      'legacyPrincipalId',
      'replacementJit',
      'rollback',
      'schemaVersion',
      'soakEndsAt',
      'subscriptionId',
      'temporaryAssignments',
    ],
    'legacy transition',
  );
  if (transition.schemaVersion !== 1) {
    throw new Error('legacy transition schemaVersion must be 1');
  }
  const proof = validatePhaseAProof(phaseA, transition.subscriptionId);
  if (normalize(transition.legacyPrincipalId) === '') {
    throw new Error('legacy principal ID is required');
  }
  requireExactFields(
    transition.inventory,
    ['assignmentIds', 'capturedAt', 'evidenceSha256'],
    'legacy transition inventory',
  );
  requireExactFields(
    transition.replacementJit,
    ['activationTests', 'eligibilityCreatedAt'],
    'legacy transition JIT replacement',
  );
  requireExactFields(
    transition.broadRemoval,
    [
      'contributorAssignmentId',
      'contributorRemovedAt',
      'evidenceSha256',
      'uaaRemovedAt',
      'userAccessAdministratorAssignmentId',
    ],
    'legacy transition broad removal',
  );
  requireExactFields(
    transition.rollback,
    ['evidenceSha256', 'testedAt'],
    'legacy transition rollback',
  );
  requireExactFields(
    transition.changeControl,
    [
      'administrationMode',
      'assignmentChangesSerialized',
      'emergencyPrincipalIds',
      'evidenceSha256',
      'independentAdminExpiresAt',
      'independentAdminOwner',
      'independentAdminRoleDefinitionId',
      'operatorOwner',
      'safetyAdminPrincipalId',
      'soloModeControls',
    ],
    'legacy transition change control',
  );
  for (const [label, value] of [
    ['inventory evidence', transition.inventory.evidenceSha256],
    ['broad removal evidence', transition.broadRemoval.evidenceSha256],
    ['change control evidence', transition.changeControl.evidenceSha256],
    ['rollback evidence', transition.rollback.evidenceSha256],
  ]) {
    requireSha256(value, label);
  }
  if (
    !Array.isArray(transition.inventory.assignmentIds) ||
    transition.inventory.assignmentIds.length === 0 ||
    new Set(transition.inventory.assignmentIds.map(normalize)).size !==
      transition.inventory.assignmentIds.length
  ) {
    throw new Error('legacy transition inventory assignment IDs are invalid');
  }
  const broadAssignmentIds = [
    transition.broadRemoval.contributorAssignmentId,
    transition.broadRemoval.userAccessAdministratorAssignmentId,
  ];
  if (
    new Set(broadAssignmentIds.map(normalize)).size !== 2 ||
    broadAssignmentIds.some(
      (assignmentId) =>
        !transition.inventory.assignmentIds.map(normalize).includes(
          normalize(assignmentId),
        ),
    )
  ) {
    throw new Error('broad role removals must identify two inventoried assignments'    );
  }
  if (transition.changeControl.assignmentChangesSerialized !== true) {
    throw new Error('legacy assignment changes must be performed one at a time');
  }
  const operatorOwner = transition.changeControl.operatorOwner;
  requireNonEmptyString(operatorOwner, 'transition operator owner');
  let independentAdminExpiresAt = null;
  let soloRiskApprovedAt = null;
  if (transition.changeControl.administrationMode === 'independent-third-party') {
    const independentAdminOwner = transition.changeControl.independentAdminOwner;
    requireNonEmptyString(independentAdminOwner, 'independent admin owner');
    if (
      normalize(independentAdminOwner) === normalize(operatorOwner) ||
      transition.changeControl.soloModeControls !== null ||
      normalize(transition.changeControl.independentAdminRoleDefinitionId)
        .split('/')
        .at(-1) !== userAccessAdministratorRoleDefinitionId
    ) {
      throw new Error(
        'independent administration requires a bounded UAA eligibility for a real third-party or MSP owner distinct from the operator',
      );
    }
    independentAdminExpiresAt = timestamp(
      transition.changeControl.independentAdminExpiresAt,
      'independent admin expiresAt',
    );
  } else if (
    transition.changeControl.administrationMode ===
    'approved-solo-compensating-controls'
  ) {
    if (
      transition.changeControl.independentAdminOwner !== null ||
      transition.changeControl.independentAdminExpiresAt !== null ||
      transition.changeControl.independentAdminRoleDefinitionId !== null
    ) {
      throw new Error('solo mode cannot claim an independent admin contract');
    }
    requireExactFields(
      transition.changeControl.soloModeControls,
      [
        'alertingEnabled',
        'breakGlassAccounts',
        'breakGlassAccountsCloudOnly',
        'breakGlassEvidenceSha256',
        'breakGlassGlobalAdministratorActivePermanent',
        'conditionalAccessEvidenceSha256',
        'conditionalAccessExclusionsVerified',
        'credentialAttestationAaguids',
        'credentialCount',
        'credentialDevicesDistinct',
        'credentialEvidenceSha256',
        'credentialMode',
        'credentialsDistinctAndTested',
        'credentialsStoredSeparately',
        'dailyAndAdminAccountsSeparated',
        'guestPasskeyPathRejected',
        'nonLockoutEvidenceSha256',
        'personalDeviceDependencyAbsent',
        'periodicTestCadenceDays',
        'phishingResistantCredentialsDistinct',
        'recoveryDrillTestedAt',
        'riskAcceptance',
        'rollbackEvidenceSha256',
        'sameHumanControlAcknowledged',
        'managementTenantId',
        'tenantIssuerDomain',
        'whfbPolicyEligibleAndTested',
      ],
      'solo-mode compensating controls',
    );
    requireExactFields(
      transition.changeControl.soloModeControls.riskAcceptance,
      ['approvedAt', 'evidenceSha256', 'expiresAt', 'scope'],
      'solo-mode risk acceptance',
    );
    for (const [label, value] of [
      [
        'solo-mode risk acceptance',
        transition.changeControl.soloModeControls.riskAcceptance.evidenceSha256,
      ],
      [
        'solo-mode break-glass evidence',
        transition.changeControl.soloModeControls.breakGlassEvidenceSha256,
      ],
      [
        'solo-mode credential evidence',
        transition.changeControl.soloModeControls.credentialEvidenceSha256,
      ],
      [
        'solo-mode Conditional Access evidence',
        transition.changeControl.soloModeControls
          .conditionalAccessEvidenceSha256,
      ],
      [
        'solo-mode non-lockout evidence',
        transition.changeControl.soloModeControls.nonLockoutEvidenceSha256,
      ],
      [
        'solo-mode rollback evidence',
        transition.changeControl.soloModeControls.rollbackEvidenceSha256,
      ],
    ]) {
      requireSha256(value, label);
    }
    soloRiskApprovedAt = timestamp(
      transition.changeControl.soloModeControls.riskAcceptance.approvedAt,
      'solo-mode risk acceptance approvedAt',
    );
    const riskExpiresAt = timestamp(
      transition.changeControl.soloModeControls.riskAcceptance.expiresAt,
      'solo-mode risk acceptance expiresAt',
    );
    const recoveryDrillTestedAt = timestamp(
      transition.changeControl.soloModeControls.recoveryDrillTestedAt,
      'solo-mode recovery drill testedAt',
    );
    const expectedRiskScope =
      `/subscriptions/${transition.subscriptionId}/governance-phase-b`;
    const tenantIssuerDomain = normalize(
      transition.changeControl.soloModeControls.tenantIssuerDomain,
    );
    const managementTenantId = requireUuid(
      transition.changeControl.soloModeControls.managementTenantId,
      'solo-mode management tenant ID',
    );
    const breakGlassAccounts =
      transition.changeControl.soloModeControls.breakGlassAccounts;
    if (!Array.isArray(breakGlassAccounts) || breakGlassAccounts.length !== 2) {
      throw new Error(
        'NO-GO: exactly two qualified emergency accounts are required in the subscription management tenant',
      );
    }
    const credentialMode =
      transition.changeControl.soloModeControls.credentialMode;
    const attestationAaguids =
      transition.changeControl.soloModeControls.credentialAttestationAaguids;
    const validCredentialMode =
      credentialMode === 'fido2-or-cba' ||
      credentialMode === 'authenticator-device-bound-passkeys' ||
      credentialMode === 'whfb-tested';
    if (
      normalize(transition.changeControl.soloModeControls.riskAcceptance.scope) !==
        normalize(expectedRiskScope) ||
      soloRiskApprovedAt > now ||
      riskExpiresAt <= now ||
      recoveryDrillTestedAt > now ||
      !/^[a-z0-9][a-z0-9.-]*\.onmicrosoft\.com$/.test(tenantIssuerDomain) ||
      breakGlassAccounts.some((account) => {
        requireExactFields(
          account,
          [
            'accountEnabled',
            'authenticationMethodCount',
            'authenticationMethodsTested',
            'creationType',
            'issuer',
            'managementAccessVerified',
            'objectId',
            'onPremisesSyncEnabled',
            'tenantId',
            'userPrincipalName',
            'userType',
          ],
          'solo-mode break-glass account',
        );
        return (
          account.accountEnabled !== true ||
          account.userType !== 'Member' ||
          requireUuid(account.tenantId, 'break-glass account tenant ID') !==
            normalize(proof.tenantId) ||
          requireUuid(account.objectId, 'break-glass account object ID') ===
            managementTenantId ||
          account.managementAccessVerified !== true ||
          !Number.isInteger(account.authenticationMethodCount) ||
          account.authenticationMethodCount < 1 ||
          account.authenticationMethodsTested !== true ||
          typeof account.userPrincipalName !== 'string' ||
          !/^[^@]+@[^@]+\.onmicrosoft\.com$/i.test(
            account.userPrincipalName,
          ) ||
          normalize(account.userPrincipalName).includes('#ext#') ||
          normalize(account.issuer) !== tenantIssuerDomain ||
          normalize(account.creationType) === 'invitation' ||
          account.onPremisesSyncEnabled === true
        );
      }) ||
      new Set(
        breakGlassAccounts.map((account) =>
          normalize(account.userPrincipalName),
        ),
      ).size !== 2 ||
      managementTenantId !== normalize(proof.tenantId) ||
      breakGlassAccounts.some(
        (account) =>
          typeof account.creationType !== 'string' &&
          account.creationType !== null,
      ) ||
      transition.changeControl.soloModeControls
        .dailyAndAdminAccountsSeparated !== true ||
      transition.changeControl.soloModeControls.sameHumanControlAcknowledged !==
        true ||
      transition.changeControl.soloModeControls.breakGlassAccountsCloudOnly !== true ||
      transition.changeControl.soloModeControls
        .breakGlassGlobalAdministratorActivePermanent !== true ||
      !validCredentialMode ||
      transition.changeControl.soloModeControls.credentialCount !== 2 ||
      transition.changeControl.soloModeControls.credentialsDistinctAndTested !==
        true ||
      (credentialMode === 'authenticator-device-bound-passkeys' &&
        (transition.changeControl.soloModeControls
          .credentialDevicesDistinct !== true ||
          !Array.isArray(attestationAaguids) ||
          attestationAaguids.length !== 2 ||
          new Set(attestationAaguids.map(normalize)).size !== 2)) ||
      (credentialMode !== 'authenticator-device-bound-passkeys' &&
        (transition.changeControl.soloModeControls.credentialDevicesDistinct !==
          null ||
          transition.changeControl.soloModeControls
            .credentialAttestationAaguids !== null)) ||
      (credentialMode === 'whfb-tested'
        ? transition.changeControl.soloModeControls
            .whfbPolicyEligibleAndTested !== true
        : transition.changeControl.soloModeControls
            .whfbPolicyEligibleAndTested !== null) ||
      transition.changeControl.soloModeControls.guestPasskeyPathRejected !==
        true ||
      transition.changeControl.soloModeControls.personalDeviceDependencyAbsent !==
        true ||
      transition.changeControl.soloModeControls.credentialsStoredSeparately !==
        true ||
      transition.changeControl.soloModeControls
        .conditionalAccessExclusionsVerified !== true ||
      transition.changeControl.soloModeControls
        .phishingResistantCredentialsDistinct !== true ||
      transition.changeControl.soloModeControls.alertingEnabled !== true ||
      !Number.isInteger(
        transition.changeControl.soloModeControls.periodicTestCadenceDays,
      ) ||
      transition.changeControl.soloModeControls.periodicTestCadenceDays < 1 ||
      transition.changeControl.soloModeControls.periodicTestCadenceDays > 90 ||
      now - recoveryDrillTestedAt >
        transition.changeControl.soloModeControls.periodicTestCadenceDays *
          24 *
          60 *
          60 *
          1000
    ) {
      throw new Error(
        'solo mode requires current scoped risk acceptance, separated daily/admin accounts, two tested active cloud-only native Member accounts bound to the subscription management tenant with verified management access, authentication methods, tenant issuer, and permanent Global Admin, two admissible distinct credentials, no guest passkey path, separate recovery, Conditional Access exclusions, alerting, and a current recovery drill',
      );
    }
  } else {
    throw new Error(
      'administrationMode must be independent-third-party or approved-solo-compensating-controls',
    );
  }
  const safetyPrincipals = [
    requireUuid(
      transition.changeControl.safetyAdminPrincipalId,
      'safety admin principal ID',
    ),
    requireUuid(transition.legacyPrincipalId, 'legacy principal ID'),
  ];
  if (
    !Array.isArray(transition.changeControl.emergencyPrincipalIds) ||
    transition.changeControl.emergencyPrincipalIds.length !== 2
  ) {
    throw new Error('exactly two emergency principal IDs are required');
  }
  safetyPrincipals.push(
    ...transition.changeControl.emergencyPrincipalIds.map(
      (principalId, index) =>
        requireUuid(principalId, `emergency principal IDs[${index}]`),
    ),
  );
  if (new Set(safetyPrincipals).size !== safetyPrincipals.length) {
    throw new Error(
      'legacy, safety admin, and both emergency principals must be distinct',
    );
  }
  const inventoryAt = timestamp(
    transition.inventory.capturedAt,
    'inventory capturedAt',
  );
  const eligibilityAt = timestamp(
    transition.replacementJit.eligibilityCreatedAt,
    'JIT eligibilityCreatedAt',
  );
  if (
    !Array.isArray(transition.replacementJit.activationTests) ||
    transition.replacementJit.activationTests.length !== 2
  ) {
    throw new Error('exactly two JIT activation tests are required');
  }
  const activationTests = transition.replacementJit.activationTests.map(
    (activation, index) => {
      requireExactFields(
        activation,
        ['evidenceSha256', 'expiresAt', 'nonLockoutVerified', 'testedAt'],
        `JIT activationTests[${index}]`,
      );
      requireSha256(
        activation.evidenceSha256,
        `JIT activationTests[${index}] evidence`,
      );
      if (activation.nonLockoutVerified !== true) {
        throw new Error('each JIT activation must prove non-lockout');
      }
      const testedAt = timestamp(
        activation.testedAt,
        `JIT activationTests[${index}].testedAt`,
      );
      const expiresAt = timestamp(
        activation.expiresAt,
        `JIT activationTests[${index}].expiresAt`,
      );
      if (expiresAt <= testedAt) {
        throw new Error('JIT activation must expire after its test');
      }
      return { testedAt, expiresAt };
    },
  );
  if (
    activationTests[0].testedAt >= activationTests[1].testedAt ||
    activationTests[0].expiresAt > activationTests[1].testedAt ||
    new Set(
      transition.replacementJit.activationTests.map(
        ({ evidenceSha256 }) => evidenceSha256,
      ),
    ).size !== 2
  ) {
    throw new Error(
      'JIT activation tests must be separate, ordered, and independently evidenced',
    );
  }
  const rollbackAt = timestamp(
    transition.rollback.testedAt,
    'rollback testedAt',
  );
  const uaaRemovalAt = timestamp(
    transition.broadRemoval.uaaRemovedAt,
    'broad removal uaaRemovedAt',
  );
  const contributorRemovalAt = timestamp(
    transition.broadRemoval.contributorRemovedAt,
    'broad removal contributorRemovedAt',
  );
  const removalAt = contributorRemovalAt;
  const soakEndsAt = timestamp(transition.soakEndsAt, 'soakEndsAt');
  if (
    inventoryAt >= eligibilityAt ||
    eligibilityAt >= activationTests[0].testedAt ||
    activationTests[1].testedAt >= rollbackAt ||
    rollbackAt >= uaaRemovalAt ||
    uaaRemovalAt >= contributorRemovalAt ||
    contributorRemovalAt >= activationTests[1].expiresAt ||
    contributorRemovalAt > now ||
    (soloRiskApprovedAt !== null && soloRiskApprovedAt >= uaaRemovalAt)
  ) {
    throw new Error(
      'broad access cannot be removed before two JIT activations, non-lockout, and rollback are proved',
    );
  }
  if (soakEndsAt <= removalAt) {
    throw new Error('the approved soak must end after broad access removal');
  }
  if (
    independentAdminExpiresAt !== null &&
    (independentAdminExpiresAt <= contributorRemovalAt ||
      independentAdminExpiresAt > soakEndsAt)
  ) {
    throw new Error(
      'independent third-party UAA eligibility must cover removal and expire by soak end',
    );
  }
  if (!Array.isArray(transition.temporaryAssignments)) {
    throw new Error('temporaryAssignments must be an array');
  }
  const actualAssignments = transition.temporaryAssignments.map(
    (assignment, index) => {
      requireExactFields(
        assignment,
        [
          'condition',
          'conditionVersion',
          'createdAt',
          'expiresAt',
          'owner',
          'principalId',
          'principalType',
          'purpose',
          'roleDefinitionId',
          'rollbackProcedure',
          'scheduleInstanceId',
          'scope',
        ],
        `temporaryAssignments[${index}]`,
      );
      const createdAt = timestamp(
        assignment.createdAt,
        `temporaryAssignments[${index}].createdAt`,
      );
      const expiresAt = timestamp(
        assignment.expiresAt,
        `temporaryAssignments[${index}].expiresAt`,
      );
      if (
        createdAt >= uaaRemovalAt ||
        expiresAt <= removalAt ||
        expiresAt > soakEndsAt
      ) {
        throw new Error(
          'temporary assignments must predate UAA removal and expire by the approved soak end',
        );
      }
      requireNonEmptyString(
        assignment.owner,
        `temporaryAssignments[${index}].owner`,
      );
      requireNonEmptyString(
        assignment.rollbackProcedure,
        `temporaryAssignments[${index}].rollbackProcedure`,
      );
      if (
        typeof assignment.scheduleInstanceId !== 'string' ||
        !normalize(assignment.scheduleInstanceId).includes(
          '/providers/microsoft.authorization/roleassignmentscheduleinstances/',
        )
      ) {
        throw new Error(
          `temporaryAssignments[${index}].scheduleInstanceId is invalid`,
        );
      }
      return comparableAssignment(assignment);
    },
  );
  if (
    new Set(
      transition.temporaryAssignments.map(({ scheduleInstanceId }) =>
        normalize(scheduleInstanceId),
      ),
    ).size !== transition.temporaryAssignments.length
  ) {
    throw new Error('temporary assignment schedule instance IDs must be unique');
  }
  const expectedAssignments = expectedTemporaryAssignments(
    proof,
    transition.legacyPrincipalId,
  ).map(comparableAssignment);
  const byPurpose = (left, right) =>
    left.purpose < right.purpose ? -1 : left.purpose > right.purpose ? 1 : 0;
  if (
    JSON.stringify(actualAssignments.sort(byPurpose)) !==
    JSON.stringify(expectedAssignments.sort(byPurpose))
  ) {
    throw new Error('temporary legacy assignments violate the exact canary contract');
  }
  const forbiddenRoleIds = new Set([
    contributorRoleDefinitionId,
    userAccessAdministratorRoleDefinitionId,
  ]);
  for (const assignment of actualAssignments) {
    const roleId = assignment.roleDefinitionId.split('/').at(-1);
    if (
      assignment.scope === normalize(`/subscriptions/${proof.subscriptionId}`) &&
      forbiddenRoleIds.has(roleId)
    ) {
      throw new Error('broad subscription Contributor or UAA access remains');
    }
  }
  return {
    broadAccessRemoved: true,
    jitActivationTestCount: activationTests.length,
    nonLockoutVerified: true,
    temporaryAssignmentCount: expectedAssignments.length,
  };
}

function main() {
  const [
    transitionPath,
    phaseAPath,
    liveAssignmentsPath,
    liveScheduleInstancesPath,
  ] = process.argv.slice(2);
  if (!transitionPath || !phaseAPath) {
    throw new Error(
      'Usage: legacy-transition-contract.mjs <transition.json> <phase-a.json> ' +
        '[live-assignments.json live-schedule-instances.json]',
    );
  }
  const transition = JSON.parse(
    fs.readFileSync(path.resolve(transitionPath), 'utf8'),
  );
  const phaseA = JSON.parse(fs.readFileSync(path.resolve(phaseAPath), 'utf8'));
  validateLegacyTransition(transition, phaseA);
  if (liveAssignmentsPath) {
    if (!liveScheduleInstancesPath) {
      throw new Error('live schedule instances are required with live assignments');
    }
    validateLegacyLiveAssignments(
      JSON.parse(fs.readFileSync(path.resolve(liveAssignmentsPath), 'utf8')),
      JSON.parse(
        fs.readFileSync(path.resolve(liveScheduleInstancesPath), 'utf8'),
      ),
      transition,
      phaseA,
    );
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main();
}
