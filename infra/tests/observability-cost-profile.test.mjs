import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

// Non-production observability cost profile (docs/runbooks/OBSERVABILITY.md, "Profil de cout
// hors production"). Production must compile to exactly the values it had before the profile.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const templates = new Map();
function compile(relativePath) {
  if (!templates.has(relativePath)) {
    templates.set(relativePath, JSON.parse(execFileSync(
      process.env.BICEP_CLI || 'bicep',
      ['build', path.join(root, relativePath), '--stdout'],
      { encoding: 'utf8', timeout: 120_000 },
    )));
  }
  return templates.get(relativePath);
}

// Resolves the only profile switch the module uses, `if(variables('nonProduction'), A, B)`, so
// that each profile can be compared with literal values. Anything else stays unresolved.
function profileBranches(expression) {
  const prefix = "[if(variables('nonProduction'), ";
  assert.ok(expression.startsWith(prefix) && expression.endsWith(')]'), expression);
  const body = expression.slice(prefix.length, -2);
  let depth = 0;
  let quoted = false;
  for (let index = 0; index < body.length; index++) {
    const character = body[index];
    if (character === "'") quoted = !quoted;
    if (quoted) continue;
    if (character === '(') depth++;
    if (character === ')') depth--;
    if (character === ',' && depth === 0) {
      return { nonProduction: body.slice(0, index).trim(), production: body.slice(index + 1).trim() };
    }
  }
  throw new Error(`no top-level branch in ${expression}`);
}

const diagnostics = () => compile('infra/modules/diagnostics.bicep');
const ofType = (template, type) => template.resources.filter((resource) => resource.type === type);

test('the cost profile defaults to production and accepts only the two documented values', () => {
  const parameter = diagnostics().parameters.costProfile;
  assert.equal(parameter.defaultValue, 'production');
  assert.deepEqual(parameter.allowedValues, ['production', 'nonProduction']);
  assert.equal(diagnostics().variables.nonProduction, "[equals(parameters('costProfile'), 'nonProduction')]");
});

test('main.bicep selects production for prod, nonProduction for staging, and nothing for dev', () => {
  const main = compile('infra/main.bicep');
  const module = main.resources.diagnostics;
  assert.equal(module.condition, "[not(equals(parameters('env'), 'dev'))]");
  assert.equal(
    module.properties.parameters.costProfile,
    "[if(equals(parameters('env'), 'prod'), createObject('value', 'production'), createObject('value', 'nonProduction'))]",
  );
  for (const [environment, value] of [['prod', 'prod'], ['staging', 'staging'], ['dev', 'dev']]) {
    const parameters = readFileSync(path.join(root, 'infra', 'params', `${environment}.bicepparam`), 'utf8');
    assert.match(parameters, new RegExp(`^param env = '${value}'$`, 'm'));
  }
});

test('production keeps every log-search alert cadence, window and description of before', () => {
  const [rule] = ofType(diagnostics(), 'Microsoft.Insights/scheduledQueryRules');
  const frequency = profileBranches(rule.properties.evaluationFrequency);
  const window = profileBranches(rule.properties.windowSize);
  assert.equal(frequency.production,
    "if(equals(variables('logAlerts')[copyIndex()].name, 'readiness-failure'), 'PT1M', 'PT5M')");
  assert.equal(window.production,
    "if(equals(variables('logAlerts')[copyIndex()].name, 'readiness-failure'), 'PT10M', 'PT15M')");
  assert.equal(frequency.nonProduction, "'PT15M'");
  assert.equal(window.nonProduction, "'PT15M'");
  const readiness = diagnostics().variables.logAlerts.find((alert) => alert.name === 'readiness-failure');
  assert.match(readiness.desc, /^\[format\('At least two readiness requests failed within \{0\} minutes\. /);
  assert.match(readiness.desc, /, if\(variables\('nonProduction'\), 15, 10\)\)\]$/);
  // Thresholds, severity, routing and the number of rules do not depend on the profile.
  assert.deepEqual(diagnostics().variables.logAlerts.map((alert) => [alert.name, alert.threshold, alert.severity]), [
    ['http401-spike', 25, 2], ['readiness-failure', 1, 1], ['http403-spike', 25, 2],
    ['http5xx-spike', 0, 1], ['telemetry-absent', 0, 1],
  ]);
  assert.equal(rule.properties.criteria.allOf[0].threshold, "[variables('logAlerts')[copyIndex()].threshold]");
  assert.deepEqual(rule.properties.actions.actionGroups, [
    "[resourceId('Microsoft.Insights/actionGroups', 'ag-certigo-security')]",
  ]);
});

test('production keeps every storage data-plane category; non-production keeps deletions only', () => {
  const branches = profileBranches(diagnostics().variables.storageServiceLogs);
  assert.equal(branches.production, "createArray(createObject('categoryGroup', 'allLogs', 'enabled', true()))");
  assert.equal(branches.nonProduction, "createArray(createObject('category', 'StorageDelete', 'enabled', true()))");
  const settings = ofType(diagnostics(), 'Microsoft.Insights/diagnosticSettings');
  // Function App, Cosmos DB and Key Vault, then storage account, Blob, Queue, Table.
  assert.equal(settings.length, 7);
  for (const setting of settings.slice(0, 3)) {
    assert.deepEqual(setting.properties.logs, [{ categoryGroup: 'allLogs', enabled: true }]);
  }
  assert.equal(settings[3].properties.logs, undefined);
  for (const setting of settings.slice(4)) {
    assert.equal(setting.properties.logs, "[variables('storageServiceLogs')]");
    assert.deepEqual(setting.properties.metrics, [{ category: 'Transaction', enabled: true }]);
  }
});

test('outside production only the readiness availability test remains, at the production cadence', () => {
  const template = diagnostics();
  assert.deepEqual(template.variables.availabilityTests.map((probe) => [probe.name, probe.keptOutsideProduction]), [
    ['ready', true], ['live', false],
  ]);
  assert.equal(
    template.variables.deployedAvailabilityTests,
    "[filter(variables('availabilityTests'), lambda('test', or(not(variables('nonProduction')), lambdaVariables('test').keptOutsideProduction)))]",
  );
  // The filter above, applied to each profile: production keeps both tests.
  for (const [nonProduction, expected] of [[false, ['ready', 'live']], [true, ['ready']]]) {
    assert.deepEqual(template.variables.availabilityTests
      .filter((probe) => !nonProduction || probe.keptOutsideProduction)
      .map((probe) => probe.name), expected);
  }
  const [webTests] = ofType(template, 'Microsoft.Insights/webtests');
  const [alerts] = ofType(template, 'Microsoft.Insights/metricAlerts');
  for (const resource of [webTests, alerts]) {
    assert.equal(resource.condition, undefined);
    assert.equal(resource.copy.count, "[length(variables('deployedAvailabilityTests'))]");
  }
  // Cadence and locations never depend on the profile (promotion monitor contract, #577).
  assert.equal(webTests.properties.Frequency, 300);
  assert.deepEqual(webTests.properties.Locations, [{ Id: 'emea-nl-ams-azr' }, { Id: 'us-va-ash-azr' }]);
  assert.equal(alerts.properties.criteria.failedLocationCount, 2);
  const source = readFileSync(path.join(root, 'infra', 'modules', 'diagnostics.bicep'), 'utf8');
  const probes = source.slice(source.indexOf('resource availabilityWebTests'), source.indexOf('// Activity Log alerts'));
  assert.doesNotMatch(probes, /nonProduction|costProfile/);
});
test('dev adopts its three manual HTTP alerts at a 15-minute cadence, unchanged otherwise', () => {
  const main = compile('infra/main.bicep');
  assert.equal(main.resources.devObservability.condition, "[equals(parameters('env'), 'dev')]");
  const dev = compile('infra/modules/devObservability.bicep');
  assert.deepEqual([...new Set(dev.resources.map((resource) => resource.type))].sort(), [
    'Microsoft.Insights/diagnosticSettings',
    'Microsoft.Insights/scheduledQueryRules',
  ]);
  // Exactly the definitions deployed by hand on 2026-08-15 (read back from Azure on 2026-10-04).
  assert.deepEqual(dev.variables.logAlerts, [
    {
      name: 'http401-spike',
      query: 'AppRequests | where ResultCode == "401"',
      desc: 'Spike of 401 authentication failures - possible auth issue or credential probing.',
    },
    {
      name: 'http403-spike',
      query: 'AppRequests | where ResultCode == "403"',
      desc: 'Spike of 403 authorization failures - possible permission issue or access probing.',
    },
    {
      name: 'http5xx-spike',
      query: 'AppRequests | where ResultCode matches regex "^5[0-9][0-9]$"',
      desc: 'Spike of 5xx server errors - API instability or active attack.',
    },
  ]);
  const [rule] = ofType(dev, 'Microsoft.Insights/scheduledQueryRules');
  assert.equal(rule.name, "[format('alert-certigo-{0}', variables('logAlerts')[copyIndex()].name)]");
  assert.equal(rule.kind, 'LogAlert');
  assert.equal(rule.identity, undefined);
  assert.equal(rule.properties.severity, 2);
  assert.equal(rule.properties.enabled, true);
  assert.equal(rule.properties.evaluationFrequency, 'PT15M');
  assert.equal(rule.properties.windowSize, 'PT15M');
  assert.equal(rule.properties.autoMitigate, true);
  assert.deepEqual(rule.properties.scopes, ["[parameters('workspaceId')]"]);
  // As before: no action group, the rules are read in the portal.
  assert.equal(rule.properties.actions, undefined);
  assert.deepEqual(rule.properties.criteria.allOf, [{
    query: "[variables('logAlerts')[copyIndex()].query]",
    timeAggregation: 'Count',
    operator: 'GreaterThan',
    threshold: 25,
    failingPeriods: { numberOfEvaluationPeriods: 1, minFailingPeriodsToAlert: 1 },
  }]);
});

test('dev storage services keep deletions only under their adopted setting name', () => {
  const dev = compile('infra/modules/devObservability.bicep');
  const settings = ofType(dev, 'Microsoft.Insights/diagnosticSettings');
  assert.equal(settings.length, 3);
  assert.deepEqual(dev.variables.storageServiceLogs, [{ category: 'StorageDelete', enabled: true }]);
  assert.deepEqual(dev.variables.storageServiceMetrics, [
    { category: 'Capacity', enabled: true },
    { category: 'Transaction', enabled: true },
  ]);
  for (const setting of settings) {
    assert.equal(setting.name, "[variables('diagnosticSettingName')]");
    assert.equal(setting.properties.workspaceId, "[parameters('workspaceId')]");
    assert.equal(setting.properties.logs, "[variables('storageServiceLogs')]");
    assert.equal(setting.properties.metrics, "[variables('storageServiceMetrics')]");
  }
  assert.equal(dev.variables.diagnosticSettingName, 'diag-to-log-analytics');
  assert.deepEqual(settings.map((setting) => setting.scope), [
    "[resourceId('Microsoft.Storage/storageAccounts/blobServices', parameters('storageAccountName'), 'default')]",
    "[resourceId('Microsoft.Storage/storageAccounts/queueServices', parameters('storageAccountName'), 'default')]",
    "[resourceId('Microsoft.Storage/storageAccounts/tableServices', parameters('storageAccountName'), 'default')]",
  ]);
});
