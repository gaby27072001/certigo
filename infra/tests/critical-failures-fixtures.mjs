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
  const time = `datetime(${new Date(Date.UTC(2026, 0, 1, 0, 0, cases.length)).toISOString()})`;
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

const requestRows = requests.map((row) => `${row}, "", "", bool(null), real(null)`);
const exceptionRows = exceptions.map((row) => `${row}, "", dynamic([])`);
const expectedRowCounts = [];
const taskCancelled = 'System.Threading.Tasks.TaskCanceledException';
const rpcException = 'Microsoft.Azure.WebJobs.Script.Workers.Rpc.RpcException';
const shutdownTemplate = 'Host shutdown cancellation in function {FunctionName}, invocation {InvocationId}; preserving cancellation.';
const workerTemplate = "Function '{functionName}', Invocation id '{invocationId}': An exception was thrown by the invocation.";

for (const [name, changes, expected] of [
  ['shutdown-worker', { host: false }, false],
  ['shutdown-host', {}, false],
  ['shutdown-operation-cancelled', { type: 'System.OperationCanceledException' }, false],
  ['shutdown-missing-marker', { marker: false }, true],
  ['shutdown-no-correlation', { operation: '' }, true],
  ['shutdown-no-invocation', { invocation: '' }, true],
  ['shutdown-no-instance', { instance: '' }, true],
  ['shutdown-other-marker-invocation', { markerInvocation: 'other' }, true],
  ['shutdown-other-marker-operation', { markerOperation: 'other' }, true],
  ['shutdown-other-marker-instance', { markerInstance: 'other' }, true],
  ['shutdown-foreign-marker', { markerResource: `${resourceId}-other` }, true],
  ['shutdown-wrong-marker-category', { markerCategory: 'Other' }, true],
  ['shutdown-wrong-marker-template', { markerTemplate: 'Something else' }, true],
  ['shutdown-wrong-marker-function', { markerFunction: 'Other' }, true],
  ['shutdown-error-marker', { markerSeverity: 3 }, true],
  ['shutdown-unhandled-marker', { markerHandledAt: 'Unhandled' }, true],
  ['shutdown-duplicate-marker', { duplicateMarker: true }, true],
  ['shutdown-duplicate-worker', { duplicateWorker: true }, true],
  ['shutdown-late-wrapper', { late: true }, true],
  ['shutdown-missing-worker', { worker: false }, true],
  ['shutdown-other-worker-invocation', { workerInvocation: 'other' }, true],
  ['shutdown-other-worker-category', { workerCategory: 'Other' }, true],
  ['shutdown-other-worker-template', { workerTemplate: 'Other' }, true],
  ['shutdown-rpc-real-exception', { rpcType: 'System.InvalidOperationException' }, true],
  ['shutdown-rpc-inner-error', { rpcInner: true }, true],
  ['shutdown-rpc-missing-details', { missingDetails: true }, true],
  ['shutdown-rpc-unlinked-details', { unlinkedDetails: true }, true],
  ['shutdown-rpc-unknown-category', { hostCategory: 'Other' }, true],
  ['shutdown-critical', { severity: 4 }, true],
  ['shutdown-unhandled', { handledAt: 'Unhandled' }, true],
  ['shutdown-coexisting-error', { realError: true }, true],
  ['shutdown-coexisting-health-error', { realError: true, functionName: 'Readiness' }, true],
  ['real-exception-health-ready', {
    realError: true, functionName: 'Readiness', code: '499', path: '/api/health/ready',
  }, true],
  ['shutdown-function-timeout', {
    realError: true, realType: 'Microsoft.Azure.WebJobs.Host.FunctionTimeoutException',
  }, true],
  ['shutdown-sibling-error-same-operation', { siblingError: true }, true],
  ['shutdown-500-then-cancel', { code: '500' }, true],
  ['unknown-client-499', { marker: false, code: '499' }, true],
  ['internal-timeout', { marker: false, innerTimeout: true }, true],
  ['shutdown-concurrent-inner-timeout', { innerTimeout: true }, true],
  ...[
    ['pure-499', {}, false],
    ['pure-query-string', { path: '/api/health/ready?probe=1' }, false],
    ['missing-request', { code: '' }, true],
    ['missing-request-id', { requestId: '' }, true],
    ['wrong-path', { path: '/api/quiz/submit' }, true],
    ['wrong-function', { functionName: 'SubmitQuiz' }, true],
    ['200-not-covered', { code: '200' }, true],
    ['503-not-transferred', { code: '503' }, true],
    ['success-conflict', { success: true }, true],
    ['missing-duration', { duration: 'real(null)' }, true],
    ['wrong-request-invocation', { requestInvocation: 'other' }, true],
    ['wrong-request-operation', { requestOperation: 'other' }, true],
    ['wrong-request-instance', { requestInstance: 'other' }, true],
    ['duplicate-request', { duplicateRequest: true }, true],
    ['conflicting-200', { extraSuccess: true }, true],
    ['missing-operation', { operation: '' }, true],
    ['missing-invocation', { invocation: '' }, true],
    ['missing-instance', { instance: '' }, true],
    ['missing-worker', { worker: false }, true],
    ['duplicate-worker', { duplicateWorker: true }, true],
    ['rpc-inner-error', { rpcInner: true }, true],
    ['internal-timeout', { innerTimeout: true }, true],
    ['warning-timeout', { warningType: 'System.TimeoutException' }, true],
    ['warning-cosmos-error', { warningType: 'Microsoft.Azure.Cosmos.CosmosException' }, true],
    ['warning-pure-nested-cancellation', { warningType: taskCancelled, nestedWarning: true }, false],
    ['warning-pure-cosmos-cancellation', { warningType: 'Microsoft.Azure.Cosmos.CosmosOperationCanceledException' }, false],
    ['real-error', { realError: true }, true],
    ['real-error-missing-invocation', { realError: true, errorInvocation: '' }, true],
    ['real-error-missing-instance', { realError: true, errorInstance: '' }, true],
    ['real-error-other-invocation', { siblingError: true }, true],
    ['unknown-client-other-invocation', { siblingCancellation: true }, true],
    ['function-timeout', { realError: true, realType: 'Microsoft.Azure.WebJobs.Host.FunctionTimeoutException' }, true],
    ['last-second-covered', { requestAge: 5 }, false],
    ['outside-completion-window', { requestAge: 6 }, true],
  ].map(([name, changes, expected]) => [
    `readiness-${name}`,
    { marker: false, middleware: true, functionName: 'Readiness', code: '499', readyCoverage: true, ...changes },
    expected,
  ]),
]) {
  const value = {
    operation: `op-${name}`, invocation: `inv-${name}`, instance: 'instance',
    functionName: 'SubmitQuiz', type: taskCancelled, severity: 3, handledAt: '',
    marker: true, markerSeverity: 2, markerHandledAt: '', markerResource: resourceId,
    markerCategory: 'Certigo.Api.Middleware.ExceptionMiddleware', markerTemplate: shutdownTemplate,
    worker: true, workerCategory: 'Microsoft.Azure.Functions.Worker.FunctionsApplication',
    workerTemplate, host: true, ...changes,
  };
  const time = addCase(name, expected);
  if (value.readyCoverage) {
    const retainedRows = !expected ? 0
      : value.siblingError || value.siblingCancellation ? 1
        : Number(value.middleware) + (value.worker ? (value.duplicateWorker ? 2 : 1) : 0)
          + (value.host ? 2 : 0) + Number(Boolean(value.realError));
    expectedRowCounts.push(`${quote(name)}, ${retainedRows}`);
  }
  const markerTime = value.late
    ? `datetime(${new Date(Date.UTC(2026, 0, 1, 0, 0, cases.length - 7)).toISOString()})`
    : time;
  const details = [{
    type: value.type, id: '1', outerId: '0', message: 'A task was canceled.',
  }];
  if (value.innerTimeout) {
    details.push({ type: 'System.TimeoutException', id: '2', outerId: '1', message: 'Internal deadline.' });
  }
  const exception = (rowTime, type, severity, handledAt, properties, detail, row = {}) =>
    [
      rowTime, quote(row.resource ?? resourceId), severity, quote(handledAt), quote(type),
      quote(row.operation ?? value.operation), `dynamic(${quote(properties)})`,
      quote(row.instance ?? value.instance), `dynamic(${quote(detail)})`,
    ].join(', ');
  if (value.marker) {
    const marker = exception(markerTime, value.type, value.markerSeverity, value.markerHandledAt, {
      InvocationId: value.markerInvocation ?? value.invocation,
      FunctionName: value.markerFunction ?? value.functionName,
      CategoryName: value.markerCategory, OriginalFormat: value.markerTemplate,
    }, details, {
      resource: value.markerResource, operation: value.markerOperation, instance: value.markerInstance,
    });
    exceptionRows.push(marker);
    if (value.duplicateMarker) exceptionRows.push(marker);
  }
  if (value.worker) {
    const worker = exception(time, value.type, value.severity, value.handledAt, {
      InvocationId: value.workerInvocation ?? value.invocation,
      invocationId: value.workerInvocation ?? value.invocation,
      functionName: value.functionName,
      CategoryName: value.workerCategory, EventName: 'InvocationError',
      OriginalFormat: value.workerTemplate,
    }, details);
    exceptionRows.push(worker);
    if (value.duplicateWorker) exceptionRows.push(worker);
  }
  if (value.middleware) {
    exceptionRows.push(exception(time, value.type, 3, '', {
      InvocationId: value.invocation, FunctionName: value.functionName,
      CategoryName: 'Certigo.Api.Middleware.ExceptionMiddleware',
      OriginalFormat: 'Unhandled exception in function {FunctionName}.',
    }, details));
  }
  if (value.warningType) {
    const warningDetails = [{ type: value.warningType, id: '1', outerId: '0', message: 'Dependency failure.' }];
    if (value.nestedWarning) {
      warningDetails.push({ type: value.warningType, id: '2', outerId: '1', message: 'Dependency failure.' });
    }
    exceptionRows.push(exception(time, value.warningType, 2, '', {
      InvocationId: value.invocation, CategoryName: 'Certigo.Api.Functions.AzureDependencyHealthProbe',
    }, warningDetails));
  }
  if (value.host) {
    for (const category of [`Function.${value.functionName}`, 'Host.Results']) {
      const rpcDetails = [
        {
          type: 'Microsoft.Azure.WebJobs.Host.FunctionInvocationException', id: '10', outerId: '0',
          message: `Exception while executing function: Functions.${value.functionName}`,
        },
        {
          type: rpcException, id: '11', outerId: value.unlinkedDetails ? '99' : '10',
          message: `Result: Failure\nType: \nException: ${value.rpcType ?? value.type}: A task was canceled.\n   at Example.Run()\n${value.rpcInner ? ' ---> System.InvalidOperationException: real error' : ''}`,
        },
      ];
      exceptionRows.push(exception(time, rpcException, value.severity, value.handledAt, {
        InvocationId: value.invocation, Category: value.hostCategory ?? category,
        EventName: 'FunctionCompleted', prop__functionName: `Functions.${value.functionName}`,
        prop__invocationId: value.invocation, prop__InvocationId: value.invocation,
        prop__Name: value.functionName,
      }, value.missingDetails ? [] : rpcDetails));
    }
  }
  if (value.realError || value.siblingError) {
    const realType = value.realType ?? 'System.InvalidOperationException';
    exceptionRows.push(exception(time, realType, 3, '', {
      InvocationId: value.errorInvocation ?? (value.siblingError ? 'sibling' : value.invocation),
      FunctionName: value.functionName, CategoryName: 'Certigo.Api.Middleware.ExceptionMiddleware',
    }, [{ type: realType, id: '1', outerId: '0', message: 'Real error.' }], {
      instance: value.errorInstance,
    }));
  }
  if (value.siblingCancellation) {
    exceptionRows.push(exception(time, value.type, 3, '', {
      InvocationId: 'sibling', FunctionName: 'SubmitQuiz',
      CategoryName: 'Certigo.Api.Middleware.ExceptionMiddleware',
      OriginalFormat: 'Unhandled exception in function {FunctionName}.',
    }, details));
  }
  if (value.code) {
    const requestTime = value.requestAge
      ? `datetime(${new Date(Date.UTC(2026, 0, 1, 0, 0, cases.length - 1 - value.requestAge)).toISOString()})`
      : markerTime;
    const request = [
      requestTime, quote(resourceId), quote(`https://example.test${value.path ?? (value.readyCoverage ? '/api/health/ready' : '/api/quiz/submit')}`),
      quote(value.code), quote(value.functionName), quote(value.requestOperation ?? value.operation),
      `dynamic(${quote({ InvocationId: value.requestInvocation ?? value.invocation })})`,
      quote(value.requestInstance ?? value.instance), quote(value.requestId ?? (value.readyCoverage ? `id-${name}` : '')),
      value.success ?? false, value.duration ?? 0,
    ].join(', ');
    requestRows.push(request);
    if (value.duplicateRequest) requestRows.push(request);
    if (value.extraSuccess) requestRows.push(request.replace('"499"', '"200"'));
  }
}

console.log(JSON.stringify({
  query: `
// Independent cases: ${cases.length}
let AppRequests=datatable(TimeGenerated:datetime, _ResourceId:string, Url:string, ResultCode:string, Name:string, OperationId:string, Properties:dynamic, AppRoleInstance:string, Id:string, Success:bool, DurationMs:real)[${requestRows.join(',')}];
let AppExceptions=datatable(TimeGenerated:datetime, _ResourceId:string, SeverityLevel:int, HandledAt:string, ExceptionType:string, OperationId:string, Properties:dynamic, AppRoleInstance:string, Details:dynamic)[${exceptionRows.join(',')}];
let Evaluate=(){${query}};
let Actual=Evaluate() | summarize ActualRows=count() by TimeGenerated | extend Matched=true;
let ExpectedCounts=datatable(Case:string, ExpectedRows:long)[${expectedRowCounts.join(',')}];
datatable(Case:string, TimeGenerated:datetime, Expected:bool)[${cases.join(',')}]
| join kind=leftouter Actual on TimeGenerated
| join kind=leftouter ExpectedCounts on Case
| extend Passed = Expected == coalesce(Matched, false)
    and (isnull(ExpectedRows) or ExpectedRows == coalesce(ActualRows, 0))
| summarize Cases=count(), FailedCases=countif(not(Passed)), Failures=make_set_if(Case, not(Passed))
`,
}));
