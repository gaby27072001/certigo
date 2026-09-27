// Emits a read-only Azure Logs request. It writes no telemetry or alert rules.
import { readFileSync } from 'node:fs';

const resourceId = '/subscriptions/test/resourceGroups/test/providers/Microsoft.Insights/components/test';
const query = readFileSync(new URL('../queries/critical-failures.kql', import.meta.url), 'utf8')
  .replaceAll('__APP_INSIGHTS_RESOURCE_ID__', resourceId);
const cases = [];
const requests = [];
const exceptions = [];
const quote = JSON.stringify;

function addCase(name, expected) {
  const time = `datetime(2026-01-01T00:00:${String(cases.length).padStart(2, '0')}Z)`;
  cases.push(`${quote(name)}, ${time}, ${expected}`);
  return time;
}

for (const [name, url, code, expected] of [
  ['login', '/api/auth/login', '500', true],
  ['catalog', '/api/catalog', '503', true],
  ['lesson', '/api/lessons/example', '502', true],
  ['quiz', '/api/quiz/submit', '500', true],
  ['exam', '/api/exams/example/submit', '500', true],
  ['profile', '/api/me', '500', true],
  ['future-route', '/api/future-route', '599', true],
  ['missing-url', '', '500', true],
  ['live', '/api/health/live', '500', false],
  ['ready-query', '/api/health/ready?probe=1', '503', false],
  ['health-like', '/api/user/api/health/live', '500', true],
  ['ok', '/api/quiz/submit', '200', false],
  ['unauthorized', '/api/quiz/submit', '401', false],
  ['forbidden', '/api/quiz/submit', '403', false],
  ['validation', '/api/quiz/submit', '400', false],
  ['cancelled', '/api/quiz/submit', '499', false],
  ['empty-code', '/api/quiz/submit', '', false],
  ['invalid-code', '/api/quiz/submit', '5000', false],
  ['foreign-app', '/api/quiz/submit', '500', false],
]) {
  const id = name === 'foreign-app' ? `${resourceId}-other` : resourceId.toUpperCase();
  requests.push([
    addCase(name, expected), quote(id), quote(url ? `https://example.test${url}` : ''), quote(code),
    quote(name), quote(`operation-${name}`), 'dynamic({})',
  ].join(', '));
}

for (const [name, severity, handledAt, expected] of [
  ['middleware-empty-operation', '3', '', true],
  ['critical', '4', '', true],
  ['unhandled-without-severity', 'int(null)', 'Unhandled', true],
  ['warning-probe', '2', '', false],
  ['handled-warning', '2', 'UserCode', false],
  ['foreign-exception', '3', '', false],
]) {
  const id = name === 'foreign-exception' ? `${resourceId}-other` : resourceId;
  exceptions.push([
    addCase(name, expected), quote(id), severity, quote(handledAt), quote('System.Exception'),
    quote(`operation-${name}`), 'dynamic({})',
  ].join(', '));
}

for (const [name, changes, expected] of [
  ['disabled-get', {}, false],
  ['disabled-query-string', { path: '/api/account/deletion?status=1' }, false],
  ['disabled-missing-marker', { marker: false }, true],
  ['disabled-other-503', { type: 'System.TimeoutException' }, true],
  ['disabled-other-code', { code: '500' }, true],
  ['disabled-post', { method: 'POST', function: 'RequestAccountDeletion' }, true],
  ['disabled-wrong-method', { method: 'POST' }, true],
  ['disabled-missing-method', { method: '' }, true],
  ['disabled-other-route', { path: '/api/quiz/submit' }, true],
  ['disabled-other-function', { function: 'SubmitQuiz' }, true],
  ['disabled-other-category', { category: 'Another.Logger' }, true],
  ['disabled-other-template', { template: 'Another warning.' }, true],
  ['disabled-other-marker-function', { markerFunction: 'RequestAccountDeletion' }, true],
  ['disabled-error-marker', { severity: 3 }, true],
  ['disabled-unhandled-marker', { handledAt: 'Unhandled' }, true],
  ['disabled-missing-operation', { operation: '' }, true],
  ['disabled-missing-invocation', { invocation: '' }, true],
  ['disabled-other-operation', { markerOperation: 'another-operation' }, true],
  ['disabled-other-invocation', { markerInvocation: 'another-invocation' }, true],
  ['disabled-foreign-marker', { markerResource: `${resourceId}-other` }, true],
  ['disabled-sibling-request', { sibling: true }, true],
]) {
  const value = {
    path: '/api/account/deletion', code: '503', method: 'GET', function: 'GetAccountDeletion',
    type: 'Certigo.Application.Abstractions.AccountDeletionDisabledException',
    category: 'Certigo.Api.Middleware.ExceptionMiddleware', markerFunction: 'GetAccountDeletion',
    template: 'Account deletion is disabled in function {FunctionName}, invocation {InvocationId}.',
    severity: 2, handledAt: '', operation: `op-${name}`, invocation: `inv-${name}`,
    markerResource: resourceId, marker: true, ...changes,
  };
  const time = addCase(name, expected);
  const request = (invocation) => [
    time, quote(resourceId), quote(`https://example.test${value.path}`), quote(value.code),
    quote(value.function), quote(value.operation),
    `dynamic(${JSON.stringify({ HttpMethod: value.method, InvocationId: invocation })})`,
  ].join(', ');
  requests.push(request(value.invocation));
  if (value.sibling) requests.push(request('another-invocation'));
  if (value.marker) {
    exceptions.push([
      time, quote(value.markerResource), value.severity, quote(value.handledAt), quote(value.type),
      quote(value.markerOperation ?? value.operation),
      `dynamic(${JSON.stringify({
        InvocationId: value.markerInvocation ?? value.invocation,
        CategoryName: value.category, FunctionName: value.markerFunction, OriginalFormat: value.template,
      })})`,
    ].join(', '));
  }
}

console.log(JSON.stringify({
  query: `
let AppRequests=datatable(TimeGenerated:datetime, _ResourceId:string, Url:string, ResultCode:string, Name:string, OperationId:string, Properties:dynamic)[${requests.join(',')}];
let AppExceptions=datatable(TimeGenerated:datetime, _ResourceId:string, SeverityLevel:int, HandledAt:string, ExceptionType:string, OperationId:string, Properties:dynamic)[${exceptions.join(',')}];
let Actual=(${query}) | distinct TimeGenerated | extend Matched=true;
datatable(Case:string, TimeGenerated:datetime, Expected:bool)[${cases.join(',')}]
| join kind=leftouter Actual on TimeGenerated
| extend Passed = Expected == coalesce(Matched, false)
| summarize Cases=count(), FailedCases=countif(not(Passed)), Failures=make_set_if(Case, not(Passed))
`,
}));
