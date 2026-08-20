import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);

function compileMainTemplate() {
  const bicep = process.env.BICEP_CLI || 'bicep';
  return JSON.parse(
    execFileSync(
      bicep,
      ['build', path.join(repositoryRoot, 'infra', 'main.bicep'), '--stdout'],
      { encoding: 'utf8' },
    ),
  );
}

test('compiled ARM defaults every public-domain input fail-closed', () => {
  const template = compileMainTemplate();

  assert.equal(template.parameters.publicWebOrigin.defaultValue, '');
  assert.equal(template.parameters.publicDomainVerified.defaultValue, false);
  assert.equal(template.parameters.appleCiamDomainReconfigured.defaultValue, false);
  assert.match(
    template.variables.publicDomainActivationReady,
    /publicWebOriginIsCanonicalHttps.*fail\('publicWebOrigin must be a canonical HTTPS origin/,
  );
  assert.match(
    template.variables.publicDomainActivationReady,
    /publicDomainVerified.*fail\('publicDomainVerified must be explicitly true/,
  );
  assert.match(
    template.variables.publicDomainActivationReady,
    /appleCiamDomainReconfigured.*fail\('appleCiamDomainReconfigured must be explicitly true/,
  );
  assert.match(
    template.variables.publicWebOriginIsPlaceholder,
    /\.invalid/,
  );
  assert.match(
    template.variables.publicWebOriginIsCanonicalHttps,
    /endsWith.*publicWebOriginAuthority.*'\.'/,
  );
  assert.match(
    template.variables.publicWebOriginIsCanonicalHttps,
    /trim\(parameters\('publicWebOrigin'\)\)/,
  );
  assert.match(
    template.variables.publicWebOriginIsCanonicalHttps,
    /contains.*publicWebOriginAuthority.*%/,
  );
  assert.match(
    template.variables.unownedLegacyDomain,
    /join\(createArray\('certigo', 'app'\), '\.'\)/,
  );
});

test('compiled ARM exposes URLs only behind the verified activation output', () => {
  const template = compileMainTemplate();

  assert.equal(
    template.outputs.publicDomainActivationReady.value,
    "[variables('publicDomainActivationReady')]",
  );
  for (const output of [
    'privacyPolicyUrl',
    'accountDeletionUrl',
    'appleAppSiteAssociationUrl',
    'assetLinksUrl',
  ]) {
    assert.match(
      template.outputs[output].value,
      /variables\('publicDomainActivationReady'\).*variables\('effectivePublicWebOrigin'\).*''/,
      output,
    );
  }
});

test('hardened parameter files cannot commit public-domain activation values', () => {
  for (const environment of ['staging', 'prod']) {
    const parameters = readFileSync(
      path.join(repositoryRoot, 'infra', 'params', `${environment}.bicepparam`),
      'utf8',
    );
    assert.doesNotMatch(
      parameters,
      /^\s*param\s+(publicWebOrigin|publicDomainVerified|appleCiamDomainReconfigured)\s*=/m,
    );
  }
});
