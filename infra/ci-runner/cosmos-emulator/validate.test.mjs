#!/usr/bin/env node

import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const directory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(directory, '..', '..', '..');
const bicep = fs.readFileSync(path.join(directory, 'runner.bicep'), 'utf8');
const bootstrap = fs.readFileSync(path.join(directory, 'bootstrap.sh'), 'utf8');
const gate = fs.readFileSync(path.join(directory, 'run-account-deletion.sh'), 'utf8');
const registration = fs.readFileSync(
  path.join(directory, 'register-runner.ps1'),
  'utf8',
);
const activeWorkflowPath = path.join(
  root,
  '.github',
  'workflows',
  'post-merge-cosmos-account-deletion.yml',
);
const legacyActiveWorkflowPath = path.join(
  root,
  '.github',
  'workflows',
  'test-account-deletion-cosmos.yml',
);
const legacyDisabledWorkflowPath = path.join(
  root,
  '.github',
  'workflows-disabled',
  'test-account-deletion-cosmos.yml',
);
const workflow = fs.readFileSync(activeWorkflowPath, 'utf8');
const runbook = fs.readFileSync(
  path.join(root, 'docs', 'runbooks', 'COSMOS_EMULATOR_RUNNER.md'),
  'utf8',
);

function requireMarkers(content, markers, label) {
  for (const marker of markers) {
    assert.ok(content.includes(marker), `${label} is missing: ${marker}`);
  }
}

test('Bicep isolates the one-shot runner from privileged and application networks', () => {
  requireMarkers(
    bicep,
    [
      "targetScope = 'resourceGroup'",
      "defaultOutboundAccess: false",
      "name: 'DenyAllInbound'",
      "destinationAddressPrefix: 'AzurePlatformIMDS'",
      "name: 'DenyVirtualNetworkOutbound'",
      "name: 'AllowHttpsInternetOutbound'",
      "destinationPortRange: '443'",
      "privateEndpointNetworkPolicies: 'Enabled'",
      "privateLinkServiceNetworkPolicies: 'Enabled'",
      "provisionVMAgent: true",
      "allowExtensionOperations: true",
      "securityType: 'TrustedLaunch'",
      "deleteOption: 'Delete'",
      "managedIdentityEnabled bool = false",
      "runnerLabel string = 'certigo-cosmos-emulator'",
    ],
    'runner.bicep',
  );
  assert.doesNotMatch(bicep, /^\s*identity:\s*/m);
  assert.doesNotMatch(bicep, /snet-runners|certigo-trusted|certigo-pr/);
  assert.doesNotMatch(bicep, /virtualNetworkPeerings|privateEndpoints/);
  assert.doesNotMatch(bicep, /privateEndpointVNetPolicies:\s*'Enabled'/);
  assert.doesNotMatch(bicep, /destinationPortRange: '22'/);
  assert.doesNotMatch(bicep, /param adminSshPublicKey|registrationSourcePrefix/);
  assert.doesNotMatch(
    bicep,
    /networkInterfaces[\s\S]*ipConfigurations[\s\S]*publicIPAddress:/,
  );
});

test('Bicep records the exact bootstrap customData digest', () => {
  const actual = crypto.createHash('sha256').update(bootstrap).digest('hex');
  const declared = bicep.match(/var bootstrapSha256 = '([0-9a-f]{64})'/)?.[1];
  assert.equal(declared, actual);
  assert.match(bicep, /toLower\(imageVersion\) == 'latest'/);
  assert.match(bicep, /loadTextContent\('bootstrap\.sh'\)/);
});

test('bootstrap pins provenance and registers exactly one ephemeral runner', () => {
  requireMarkers(
    bootstrap,
    [
      'RUNNER_VERSION="2.336.0"',
      'RUNNER_SHA256="04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d"',
      'DOCKER_VERSION="29.7.2"',
      'DOCKER_SHA256="803d433f226db4776e1768fd319fc6c6e4935a456acf84fcc0080818b854bc8f"',
      'RUNNER_LABELS="certigo-cosmos-emulator"',
      '"--register" || "$2" != "--token-stdin"',
      "trap 'unset RUNNER_TOKEN' EXIT",
      '--ephemeral',
      '--disableupdate',
      '"bip": "172.31.0.1/24"',
      "docker info --format '{{.ServerVersion}}'",
      'BOOTSTRAP_COMPLETE="${STATE_DIR}/bootstrap-complete"',
      'flock -n 9',
      'Restart=no',
      'RuntimeMaxSec=2700',
      'KillMode=control-group',
      'TimeoutStopSec=120',
      'Environment=HOME=${RUNNER_HOME}',
      'Environment=DOTNET_CLI_HOME=${RUNNER_HOME}/.dotnet',
      'Environment=NUGET_PACKAGES=${RUNNER_HOME}/.nuget/packages',
      'ExecStopPost=+/usr/bin/systemctl poweroff --no-block',
      'certigo-block-imds',
      '169.254.169.254/32',
      'docker pull "${COSMOS_IMAGE}"',
    ],
    'bootstrap.sh',
  );
  assert.doesNotMatch(bootstrap, /azure-cli|az login|managed.identity/i);
  const persistedEnvironment = bootstrap.match(
    /cat > \/etc\/certigo-cosmos-runner\.env <<EOF([\s\S]*?)\nEOF/,
  )?.[1];
  assert.ok(persistedEnvironment);
  assert.doesNotMatch(persistedEnvironment, /RUNNER_TOKEN/);
});

test('registration uses one protected Run Command and removes it', () => {
  requireMarkers(
    registration,
    [
      '[CmdletBinding(SupportsShouldProcess',
      '[switch]$Apply',
      'Invoke-AzRestMethod',
      "name = 'RUNNER_TOKEN'",
      'protectedParameters',
      'Assert-RestSuccess -Response $putResponse',
      'Base bootstrap did not install the registration entry point',
      'certigo-cosmos-runner-bootstrap --register --token-stdin',
      '$registrationToken = $null',
      '-Method DELETE',
      "runnerClass -ne 'certigo-cosmos-emulator'",
      "lifecycle -ne 'one-shot'",
      "trustBoundary -ne 'merged-main-only'",
      "managedIdentity -ne 'none'",
      "registrationChannel -ne 'protected-managed-run-command'",
      "throw 'The one-shot Cosmos runner must not have a managed identity.'",
    ],
    'register-runner.ps1',
  );
  assert.doesNotMatch(registration, /--protected-parameters.+\$registrationToken/);
  assert.doesNotMatch(registration, /Write-(?:Host|Output).+\$registrationToken/);
  assert.ok(
    registration.indexOf('$runCommandRequested = $true')
      < registration.indexOf('-Method PUT'),
    'Run Command cleanup must be armed before the PUT request',
  );
  assert.match(
    registration,
    /finally \{[\s\S]*-Method DELETE[\s\S]*Test-RunCommandAbsent/,
  );
});

test('emulator gate uses only the pinned local image and account-deletion test', () => {
  const bootstrapImage = bootstrap.match(/^COSMOS_IMAGE="([^"]+)"$/m)?.[1];
  const gateImage = gate.match(/^image="([^"]+)"$/m)?.[1];
  assert.equal(gateImage, bootstrapImage);
  assert.match(gateImage, /@sha256:[0-9a-f]{64}$/);
  requireMarkers(
    gate,
    [
      "trap cleanup EXIT",
      '--pull never',
      '--publish 127.0.0.1:8080:8080',
      '--publish 127.0.0.1:8081:8081',
      '--env ENABLE_EXPLORER=false',
      'COSMOS_EMULATOR_CONNECTION_STRING',
      'export NO_PROXY=127.0.0.1,localhost',
      'http://169.254.169.254/metadata/instance',
      'CERTIGO_COSMOS_TESTS=1',
      'COSMOS_EMULATOR_ENDPOINT=https://127.0.0.1:8081',
      'CosmosRepositoriesIntegrationTests.Account_deletion_removes_user_partitions_and_keeps_only_pseudonymous_tombstone',
      "--logger 'trx;LogFileName=account-deletion.trx'",
      'timeout --signal=TERM --kill-after=30s 1200 dotnet test',
      'Expected exactly one account-deletion test result',
      `'outcome="Passed"'`,
      '--cleanup-only',
      'docker rm --force',
    ],
    'run-account-deletion.sh',
  );
  assert.doesNotMatch(gate, /microsoft\.azure\.com|documents\.azure\.com|secrets\./i);
  assert.doesNotMatch(gate, /docker logs/);
});

test('workflow is available, activation-gated, and can consume only merged main', () => {
  assert.ok(fs.existsSync(activeWorkflowPath));
  assert.equal(fs.existsSync(legacyActiveWorkflowPath), false);
  assert.ok(fs.existsSync(legacyDisabledWorkflowPath));
  requireMarkers(
    workflow,
    [
      '# ACTIVATION-GATED:',
      'workflow_dispatch:',
      "github.event_name == 'workflow_dispatch'",
      "github.repository == 'gchambaud_microsoft/Certigo'",
      "github.ref == 'refs/heads/main'",
      "vars.CERTIGO_COSMOS_EMULATOR_ENABLED == 'true'",
      'runs-on: [self-hosted, Linux, X64, certigo-cosmos-emulator]',
      'ref: refs/heads/main',
      'persist-credentials: false',
      'dotnet-version: "8.0.424"',
      'COSMOS_EMULATOR_CONNECTION_STRING: ""',
      'bash infra/ci-runner/cosmos-emulator/run-account-deletion.sh',
      'bash infra/ci-runner/cosmos-emulator/run-account-deletion.sh --cleanup-only',
      '$GITHUB_STEP_SUMMARY',
    ],
    'active workflow',
  );
  assert.doesNotMatch(workflow, /^\s{2}push:/m);
  assert.doesNotMatch(workflow, /pull_request(?:_target)?:/);
  assert.doesNotMatch(workflow, /github\.event\.pull_request|secrets\.|azure\/login@/i);
  assert.doesNotMatch(workflow, /id-token:\s*write|upload-artifact@/i);
});

test('runbook keeps deployment, activation, registration, and rollback explicit', () => {
  requireMarkers(
    runbook,
    [
      'PR #296',
      'PR #302',
      'PR #311',
      'PR #313',
      '6145f357c4cdc3524d04faddf1e2f96e7a1b32d9',
      '978c38e9b64d12144ccc4bbe02ff1fe37c5c0458',
      '8a4f3be99b5d7cf97eb870d85e8481be24ceb1bc',
      '8cd955faa790aa69a2f330a8f57781e8856d624b',
      'what-if',
      'La PR qui déplace uniquement le workflow vers son chemin actif ne provisionne',
      '`gchambaud_microsoft` est un compte utilisateur',
      'certigo-cosmos-emulator',
      'register-runner.ps1',
      '`protectedParameter`',
      'Aucun fichier, clé SSH',
      'exactement un résultat TRX',
      '--ephemeral',
      'RuntimeMaxSec=2700',
      'Microsoft.Compute/virtualMachines/runCommands/read|write|delete',
      ': "${RUNNER_NAME:?set RUNNER_NAME',
      'az vm run-command delete',
      'az vm deallocate',
      'az group delete',
      'aucun déploiement',
      '`.github/workflows/post-merge-cosmos-account-deletion.yml`',
    ],
    'COSMOS_EMULATOR_RUNNER.md',
  );
});
