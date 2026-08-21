import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const contractPath = 'docs/contracts/b2b-compliance/v1/compliance.contract.json';
const cosmosSchemaPath =
  'docs/contracts/enterprise-learning-metrics/v1/cosmos.schema.json';
const domainPath =
  'backend/src/Certigo.Domain/Organizations/EnterpriseLearningMetricsModels.cs';

const readJson = async (path) => JSON.parse(await readFile(path, 'utf8'));

const dataClass = (contract, id) => {
  const result = contract.dataClasses.find((entry) => entry.id === id);
  assert.ok(result, `missing data class ${id}`);
  return result;
};

const csharpInteger = (source, name) => {
  const match = source.match(
    new RegExp(`public const int ${name} = ([0-9_]+);`),
  );
  assert.ok(match, `missing C# constant ${name}`);
  return Number(match[1].replaceAll('_', ''));
};

test('B2B compliance contract remains feature-off everywhere', async () => {
  const [contract, localSettings, functionApp] = await Promise.all([
    readJson(contractPath),
    readJson('backend/src/Certigo.Api/local.settings.json.example'),
    readFile('infra/modules/functionApp.bicep', 'utf8'),
  ]);

  assert.equal(contract.runtime.default, 'off');
  assert.deepEqual(contract.runtime.implementedValues, ['off']);
  assert.equal(
    localSettings.Values[contract.runtime.setting],
    'off',
    'local settings must stay off',
  );
  assert.match(
    functionApp,
    /ENTERPRISE_LEARNING_METRICS_V1:\s*'off'/,
    'IaC must pin the feature off',
  );
});

test('cohort and retention contract match Domain and Cosmos schema', async () => {
  const [contract, cosmosSchema, domain] = await Promise.all([
    readJson(contractPath),
    readJson(cosmosSchemaPath),
    readFile(domainPath, 'utf8'),
  ]);
  const definitions = cosmosSchema.$defs;

  assert.equal(
    contract.productDecisions.minimumCohortSize,
    csharpInteger(domain, 'MinimumContributors'),
  );
  assert.equal(
    dataClass(contract, 'session-lease').ttlSeconds,
    csharpInteger(domain, 'LeaseTtlSeconds'),
  );
  assert.equal(
    dataClass(contract, 'session-lease').ttlSeconds,
    definitions.lease.properties.ttl.const,
  );
  assert.equal(
    dataClass(contract, 'active-aggregate').ttlSeconds,
    definitions.activeSubjectShard.properties.ttl.const,
  );
  assert.equal(
    dataClass(contract, 'replay-receipt').ttlSeconds,
    csharpInteger(domain, 'ReplayReceiptTtlSeconds'),
  );
  assert.equal(
    dataClass(contract, 'replay-receipt').ttlSeconds,
    definitions.receipt.properties.ttl.const,
  );
  assert.equal(
    dataClass(contract, 'daily-aggregate').retentionDays,
    csharpInteger(domain, 'AggregateRetentionDays'),
  );
  assert.equal(
    dataClass(contract, 'daily-aggregate').maximumTtlSeconds,
    definitions.dailyAggregateShard.properties.ttl.maximum,
  );
  assert.deepEqual(
    definitions.receiptIntent.properties.ttl.enum.toSorted((a, b) => a - b),
    [
      dataClass(contract, 'pending-receipt-intent').ttlSeconds,
      dataClass(contract, 'completed-receipt-intent').ttlSeconds,
    ],
  );
});

test('B2B reporting excludes individual monitoring and export', async () => {
  const contract = await readJson(contractPath);
  const decisions = contract.productDecisions;

  assert.equal(decisions.managerVisibility, 'aggregate-only');
  assert.equal(decisions.arbitraryDateRanges, false);
  assert.equal(decisions.individualManagerExport, false);
  assert.equal(decisions.enterpriseExport, 'thresholded-aggregate-only');
  assert.equal(decisions.auditContainsPii, false);
  assert.equal(decisions.auditContainsStablePseudonym, false);
  assert.ok(decisions.prohibitedPurposes.includes('individual-employee-evaluation'));
  assert.ok(decisions.prohibitedPurposes.includes('disciplinary-action'));
  assert.equal(dataClass(contract, 'personal-learning-record').offboardingAction, 'preserve');
  assert.equal(dataClass(contract, 'personal-learning-record').managerVisible, false);
});

test('legal unknowns and human pilot gates cannot be represented as approved', async () => {
  const contract = await readJson(contractPath);

  assert.equal(contract.status, 'pre-pilot-not-legal-advice');
  assert.ok(contract.legalQuestions.length >= 10);
  assert.ok(contract.pilotRequirements.length >= 10);
  assert.ok(contract.legalQuestions.includes('lawful-basis-by-jurisdiction'));
  assert.ok(contract.legalQuestions.includes('international-transfers-and-data-residency'));
  assert.ok(contract.pilotRequirements.includes('legal-opinion-approved-per-jurisdiction'));
  assert.ok(contract.pilotRequirements.includes('new-activation-adr-approved'));
  assert.equal(
    Object.hasOwn(contract, 'approvals'),
    false,
    'approvals are human evidence and must not be fabricated in this contract',
  );
});
