// Emits only a read-only Logs query; the datatable does not ingest telemetry.
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export const resourceId = '/subscriptions/test/resourceGroups/test/providers/Microsoft.Insights/components/test';
export const query = readFileSync(new URL('../queries/readiness-failures.kql', import.meta.url), 'utf8')
  .replaceAll('__APP_INSIGHTS_RESOURCE_ID__', resourceId);
export const epoch = Date.parse('2026-01-01T00:00:00Z');
export const minute = 60_000;
export const request = (seconds, changes = {}) => ({
  TimeGenerated: epoch + seconds * 1000,
  _ResourceId: resourceId,
  Url: 'https://example.test/api/health/ready',
  ResultCode: '503',
  Id: `request-${seconds}`,
  OperationId: 'shared-probe-operation',
  AppRoleInstance: 'host-a',
  ItemCount: 1,
  ...changes,
});

export const cases = [
  { name: 'empty', rows: [], at: 60, count: 0 },
  { name: 'single-before-retry', rows: [request(0)], at: 20, count: 1 },
  { name: 'staging-retry-recovered', rows: [request(0), request(25.064, { ResultCode: '200' })], at: 26, count: 1 },
  { name: 'prod-retry-recovered', rows: [request(0), request(25.411, { ResultCode: '200' })], at: 26, count: 1 },
  { name: 'failed-retry-same-operation-host', rows: [request(0), request(25)], at: 26, count: 2 },
  { name: 'next-five-minute-probe', rows: [request(0), request(300)], at: 301, count: 2 },
  { name: 'success-interleaving', rows: [request(0), request(10, { ResultCode: '200' }), request(25)], at: 26, count: 2 },
  { name: 'different-hosts', rows: [request(0), request(25, { AppRoleInstance: 'host-b' })], at: 26, count: 2 },
  { name: 'empty-hosts', rows: [request(0, { AppRoleInstance: '' }), request(25, { AppRoleInstance: '' })], at: 26, count: 2 },
  { name: 'duplicate-id', rows: [request(0), request(0)], at: 26, count: 1 },
  { name: 'duplicate-id-different-time', rows: [request(0), request(25, { Id: 'request-0' })], at: 26, count: 1 },
  { name: 'missing-id-distinct-events', rows: [request(0, { Id: '' }), request(25, { Id: '' })], at: 26, count: 2 },
  { name: 'missing-id-and-host', rows: [request(0, { Id: '', AppRoleInstance: '' }), request(25, { Id: '', AppRoleInstance: '' })], at: 26, count: 2 },
  { name: 'missing-id-duplicate-event', rows: [request(0, { Id: '', AppRoleInstance: '' }), request(0, { Id: '', AppRoleInstance: '' })], at: 26, count: 1 },
  { name: 'missing-id-different-hosts', rows: [request(0, { Id: '' }), request(0, { Id: '', AppRoleInstance: 'host-b' })], at: 26, count: 2 },
  { name: 'sample-weight-is-not-events', rows: [request(0, { ItemCount: 20 })], at: 26, count: 1 },
  { name: 'foreign-app', rows: [request(0), request(25, { _ResourceId: `${resourceId}-other` })], at: 26, count: 1 },
  { name: 'case-insensitive-scope', rows: [request(0), request(25, { _ResourceId: resourceId.toUpperCase() })], at: 26, count: 2 },
  { name: 'query-string', rows: [request(0), request(25, { Url: 'https://example.test/api/health/ready?probe=1' })], at: 26, count: 2 },
  { name: 'not-readiness', rows: [request(0), request(25, { Url: 'https://example.test/other/api/health/ready' })], at: 26, count: 1 },
  { name: 'liveness-not-counted', rows: [request(0), request(25, { Url: 'https://example.test/api/health/live' })], at: 26, count: 1 },
  { name: 'empty-url-not-counted', rows: [request(0), request(25, { Url: '' })], at: 26, count: 1 },
  { name: 'non-200-retained', rows: [request(0, { ResultCode: '429' }), request(25, { ResultCode: '' })], at: 26, count: 2 },
  { name: 'outside-window', rows: [request(0), request(601)], at: 602, count: 1 },
  { name: 'inside-window', rows: [request(0), request(599)], at: 599, count: 2 },
  { name: 'future-not-counted', rows: [request(0), request(25)], at: 24, count: 1 },
  { name: 'outage-worst-phase-before-retry', rows: [request(300), request(325)], at: 324, count: 1 },
  { name: 'outage-worst-phase-signals-384s', rows: [request(300), request(325)], at: 384, count: 2 },
  { name: 'outage-two-regions-signals-359s', rows: [request(300), request(300, { Id: 'second-region' }), request(325)], at: 359, count: 3 },
  { name: 'outage-no-retry-signals-359s-after-first', rows: [request(0), request(300)], at: 359, count: 2 },
];

const schema = 'TimeGenerated:datetime, _ResourceId:string, Url:string, ResultCode:string, Id:string, OperationId:string, AppRoleInstance:string, ItemCount:long';
const date = (ms) => `datetime(${new Date(ms).toISOString()})`;
const fields = ['_ResourceId', 'Url', 'ResultCode', 'Id', 'OperationId', 'AppRoleInstance', 'ItemCount'];

export function fixtureQuery() {
  const tables = cases.map((item, index) =>
    `let Case${index}=datatable(${schema})[\n${item.rows.map((row) =>
      [date(row.TimeGenerated), ...fields.map((key) => JSON.stringify(row[key]))].join(', ')
    ).join(',\n')}\n];`);
  const assertions = cases.map((item, index) =>
    `(evaluateReadiness(Case${index}, ${date(epoch + item.at * 1000)})`
    + ` | summarize Actual=count() | extend Case=${JSON.stringify(item.name)}, Expected=long(${item.count})`
    + ' | extend Passed=Actual == Expected)');
  return `let evaluateReadiness=(Requests:(${schema}), EvaluationTime:datetime) {
let AppRequests=Requests | where TimeGenerated > EvaluationTime - 10m and TimeGenerated <= EvaluationTime;
${query}
};
${tables.join('\n')}
union ${assertions.join(',\n')}
| summarize Cases=count(), FailedCases=countif(not(Passed)), Failures=make_list_if(Case, not(Passed))
`;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  console.log(JSON.stringify({ query: fixtureQuery() }));
}
