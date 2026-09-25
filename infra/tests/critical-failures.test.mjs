import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const query = readFileSync(path.join(root, 'infra/queries/critical-failures.kql'), 'utf8');
const template = JSON.parse(execFileSync(
  process.env.BICEP_CLI || 'bicep',
  ['build', path.join(root, 'infra/modules/diagnostics.bicep'), '--stdout'],
  { encoding: 'utf8', timeout: 120_000 },
));

test('live KQL fixtures use the deployed query and assert 46 independent scenarios', () => {
  const fixture = JSON.parse(execFileSync(process.execPath, [
    path.join(root, 'infra/tests/critical-failures-fixtures.mjs'),
  ], { encoding: 'utf8', timeout: 10_000 }));
  assert.ok(fixture.query.includes(query.replaceAll(
    '__APP_INSIGHTS_RESOURCE_ID__',
    '/subscriptions/test/resourceGroups/test/providers/Microsoft.Insights/components/test',
  )));
  assert.match(fixture.query, /FailedCases=countif\(not\(Passed\)\)/);
  // Each case has one expectation; marker cases also emit correlated exceptions.
  assert.equal(fixture.query.match(/datetime\(2026-01-01T00:00:\d\dZ\), (true|false)/g)?.length, 46);
});

test('only the proven disabled GET is excluded and unhandled exceptions stay independent', () => {
  assert.match(query, /AppRequests/);
  assert.match(query, /AppExceptions/);
  assert.equal(query.match(/_ResourceId =~ "__APP_INSIGHTS_RESOURCE_ID__"/g)?.length, 3);
  assert.match(query, /ResultCode matches regex "\^5\[0-9\]\[0-9\]\$"/);
  assert.match(query, /SeverityLevel >= 3 or HandledAt =~ "Unhandled"/);
  assert.match(query, /parse_url\(Url\)\.Path/);
  assert.match(query, /RequestPath !in~ \("\/api\/health\/live", "\/api\/health\/ready"\)/);
  const executable = query.replace(/\/\/.*$/gm, '');
  assert.doesNotMatch(executable, /OperationName|AppRoleName|SyntheticSource/);
  assert.match(executable, /Name == "GetAccountDeletion" and ResultCode == "503"/);
  assert.match(executable, /RequestPath == "\/api\/account\/deletion" and tostring\(Properties.HttpMethod\) == "GET"/);
  assert.match(executable, /join kind=leftanti/);
  assert.match(executable, /on OperationId, DisabledInvocationId/);
  assert.match(executable, /isnotempty\(OperationId\) and isnotempty\(DisabledInvocationId\)/);
  const exceptionBranch = executable.slice(executable.lastIndexOf('(AppExceptions'));
  assert.doesNotMatch(exceptionBranch, /join|FunctionName|OperationId|ExceptionType/);
  assert.equal(executable.match(/project TimeGenerated/g)?.length, 2);
  assert.doesNotMatch(executable, /summarize|bin\(|ago\(|take |limit /);
});

test('one event fires one existing stateful incident with no high-cardinality dimensions', () => {
  const definitions = template.variables.logAlerts;
  assert.equal(definitions.length, 5);
  const critical = definitions.find((alert) => alert.name === 'http5xx-spike');
  assert.equal(critical.threshold, 0);
  assert.equal(critical.severity, 1);
  assert.match(critical.query, /^\[replace\(/);
  assert.match(critical.query, /Microsoft\.Insights\/components/);
  assert.match(critical.desc, /no traffic is not proof of recovery/);
  const rules = template.resources.filter((resource) =>
    resource.type === 'Microsoft.Insights/scheduledQueryRules');
  assert.equal(rules.length, 1);
  const rule = rules[0];
  assert.equal(rule.name, "[format('alert-certigo-{0}', variables('logAlerts')[copyIndex()].name)]");
  assert.equal(rule.properties.enabled, true);
  assert.equal(rule.properties.autoMitigate, true);
  assert.equal(rule.properties.evaluationFrequency, 'PT5M');
  assert.equal(rule.properties.windowSize, 'PT15M');
  assert.equal(rule.properties.muteActionsDuration, undefined);
  const [condition] = rule.properties.criteria.allOf;
  assert.equal(condition.timeAggregation, 'Count');
  assert.equal(condition.operator, 'GreaterThan');
  assert.equal(condition.threshold, "[variables('logAlerts')[copyIndex()].threshold]");
  assert.deepEqual(condition.failingPeriods, {
    numberOfEvaluationPeriods: 1,
    minFailingPeriodsToAlert: 1,
  });
  assert.equal(condition.dimensions, undefined);
  assert.deepEqual(rule.properties.actions.actionGroups, [
    "[resourceId('Microsoft.Insights/actionGroups', 'ag-certigo-security')]",
  ]);
});

test('notification receiver and least-privilege rule identities remain enabled', () => {
  const group = template.resources.find((r) => r.type === 'Microsoft.Insights/actionGroups');
  assert.equal(group.properties.enabled, true);
  assert.deepEqual(group.properties.emailReceivers, [{
    name: 'secops',
    emailAddress: "[parameters('alertEmail')]",
    useCommonAlertSchema: true,
  }]);
  const grants = template.resources.find((r) => r.type === 'Microsoft.Authorization/roleAssignments');
  assert.equal(grants.condition, "[parameters('grantAlertReaderRole')]");
  assert.match(grants.properties.principalId, /SystemAssigned|identity\.principalId/);
  for (const environment of ['staging', 'prod']) {
    const parameters = readFileSync(path.join(root, `infra/params/${environment}.bicepparam`), 'utf8');
    assert.match(parameters, /param grantAlertReaderRole = true/);
  }
});
