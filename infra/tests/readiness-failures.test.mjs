import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { cases, epoch, fixtureQuery, minute, query, request, resourceId } from './readiness-failures-fixtures.mjs';

// Local timing model, complemented by the same fixtures executed by Azure KQL.
function failures(rows, at) {
  const identities = new Set();
  for (const row of rows) {
    if (row.TimeGenerated <= at - 10 * minute || row.TimeGenerated > at) continue;
    if (row._ResourceId.toLowerCase() !== resourceId.toLowerCase()) continue;
    if (!row.Url || new URL(row.Url).pathname.toLowerCase() !== '/api/health/ready') continue;
    if (row.ResultCode === '200') continue;
    identities.add(row.Id ? `id:${row.Id}`
      : `event:${row.TimeGenerated}|${row.OperationId}|${row.AppRoleInstance}`);
  }
  return identities.size;
}

test('read-only KQL fixtures embed the complete production query', () => {
  assert.ok(fixtureQuery().includes(query));
  assert.match(fixtureQuery(), /FailedCases=countif\(not\(Passed\)\)/);
  assert.equal(cases.length, 30);
  for (const item of cases) {
    assert.equal(failures(item.rows, epoch + item.at * 1000), item.count, item.name);
  }
});

test('neither recorded single-failure incident alerts at any evaluation point', () => {
  for (const [failureUtc, successUtc] of [
    ['2026-09-26T17:27:40.1427924Z', '2026-09-26T17:28:05.2067095Z'],
    ['2026-09-27T13:03:23.8271765Z', '2026-09-27T13:03:49.2380492Z'],
  ]) {
    const first = Date.parse(failureUtc);
    const recovered = Date.parse(successUtc);
    const rows = [
      request(0, { TimeGenerated: first }),
      request(25, { TimeGenerated: recovered, ResultCode: '200' }),
    ];
    // Every second covers all 60 phases of the 1-minute evaluation cadence.
    for (let at = first - minute; at <= first + 20 * minute; at += 1000) {
      assert.ok(failures(rows, at) < 2, `${failureUtc} at ${at}`);
    }
    for (const at of [first - 0.001, first, recovered - 0.001, recovered, first + 10 * minute]) {
      assert.ok(failures(rows, at) < 2);
    }
  }
});

test('continuous 503 with two regions and 25-second retries signals under 10 minutes from onset', () => {
  let worstMs = 0;
  // Include the full initial wait and every evaluation phase. Align the two
  // regions in the worst-case profile; no beneficial regional staggering assumed.
  for (let initialWait = 0; initialWait <= 300; initialWait++) {
    const rows = ['amsterdam', 'ashburn'].flatMap((region) =>
      [initialWait, initialWait + 25, initialWait + 300, initialWait + 325]
        .map((seconds, index) => request(seconds, {
          Id: `${region}-${index}`,
          OperationId: `${region}-probe-${Math.floor(index / 2)}`,
        })));
    for (let phase = 0; phase < 60; phase++) {
      // Also test the conservative case where only one region's telemetry arrives.
      for (const observed of [rows, rows.filter((row) => row.Id.startsWith('amsterdam'))]) {
        let firedAt;
        for (let seconds = phase; seconds < 600; seconds += 60) {
          if (failures(observed, epoch + seconds * 1000) > 1) {
            firedAt = seconds * 1000;
            break;
          }
        }
        assert.notEqual(firedAt, undefined, `wait=${initialWait}, phase=${phase}`);
        assert.ok(firedAt < 600_000);
        worstMs = Math.max(worstMs, firedAt);
      }
    }
  }
  assert.equal(worstMs, 384_000); // < 5 min + 25 s + 1 min at 1-second resolution.
});

test('without visible retries detection is under 6 minutes from the first observed failure', () => {
  const rows = [request(0), request(300), request(600)];
  for (let phase = 0; phase < 60; phase++) {
    const firstEvaluation = phase === 0 ? 300 : 300 + phase;
    assert.ok(failures(rows, epoch + firstEvaluation * 1000) > 1);
    assert.ok(firstEvaluation < 360);
  }
});

test('ARM changes only readiness query/threshold/cadence/window, preserving routing and probes', () => {
  const template = JSON.parse(execFileSync(process.env.BICEP_CLI || 'bicep',
    ['build', fileURLToPath(new URL('../modules/diagnostics.bicep', import.meta.url)), '--stdout'],
    { encoding: 'utf8', timeout: 120_000 }));
  const definitions = template.variables.logAlerts;
  const ready = definitions.find((a) => a.name === 'readiness-failure');
  assert.equal(ready.threshold, 1);
  assert.equal(ready.severity, 1);
  assert.match(ready.query, /^\[replace\(/);
  assert.match(ready.query, /Microsoft\.Insights\/components/);
  const rule = template.resources.find((r) => r.type === 'Microsoft.Insights/scheduledQueryRules');
  assert.equal(rule.properties.evaluationFrequency,
    "[if(variables('nonProduction'), 'PT15M', if(equals(variables('logAlerts')[copyIndex()].name, 'readiness-failure'), 'PT1M', 'PT5M'))]");
  assert.equal(rule.properties.windowSize,
    "[if(variables('nonProduction'), 'PT15M', if(equals(variables('logAlerts')[copyIndex()].name, 'readiness-failure'), 'PT10M', 'PT15M'))]");
  assert.equal(rule.properties.autoMitigate, true);
  assert.equal(rule.properties.criteria.allOf[0].timeAggregation, 'Count');
  assert.equal(rule.properties.criteria.allOf[0].operator, 'GreaterThan');
  assert.deepEqual(definitions.filter((a) => a.name !== 'readiness-failure').map((a) => [a.name, a.threshold]),
    [['http401-spike', 25], ['http403-spike', 25], ['http5xx-spike', 0], ['telemetry-absent', 0]]);
  const probes = template.resources.find((r) => r.type === 'Microsoft.Insights/webtests');
  assert.equal(probes.properties.Frequency, 300);
  assert.equal(probes.properties.Locations.length, 2);
  assert.equal(template.variables.availabilityTests.find((p) => p.name === 'ready').retryEnabled, true);
});
