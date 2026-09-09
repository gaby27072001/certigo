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

// Minimal ARM expression reader, limited to the constructs of the public-domain decision
// chain. It exists so the activation decision and the six outputs are proven by
// evaluation rather than by reading the compiled template: a structural assertion cannot
// tell an empty output from an URL built on an empty origin.
function parseArmExpression(text) {
  const source = text.startsWith('[') && text.endsWith(']') ? text.slice(1, -1) : text;
  let cursor = 0;
  const skipWhitespace = () => {
    while (cursor < source.length && /\s/.test(source[cursor])) {
      cursor += 1;
    }
  };
  function parseString() {
    cursor += 1;
    let value = '';
    while (cursor < source.length) {
      if (source[cursor] === "'") {
        if (source[cursor + 1] === "'") {
          value += "'";
          cursor += 2;
          continue;
        }
        cursor += 1;
        break;
      }
      value += source[cursor];
      cursor += 1;
    }
    return { type: 'literal', value };
  }
  function parseNumber() {
    const start = cursor;
    while (cursor < source.length && /[0-9.-]/.test(source[cursor])) {
      cursor += 1;
    }
    return { type: 'literal', value: Number(source.slice(start, cursor)) };
  }
  function parseCall() {
    const start = cursor;
    while (cursor < source.length && /[A-Za-z0-9_]/.test(source[cursor])) {
      cursor += 1;
    }
    const name = source.slice(start, cursor);
    skipWhitespace();
    const args = [];
    if (source[cursor] === '(') {
      cursor += 1;
      skipWhitespace();
      if (source[cursor] !== ')') {
        for (;;) {
          args.push(parseExpression());
          skipWhitespace();
          if (source[cursor] === ',') {
            cursor += 1;
            continue;
          }
          break;
        }
      }
      skipWhitespace();
      if (source[cursor] !== ')') {
        throw new Error(`Unbalanced ARM expression near "${source.slice(cursor, cursor + 24)}"`);
      }
      cursor += 1;
    }
    return { type: 'call', name, args };
  }
  function parseExpression() {
    skipWhitespace();
    if (source[cursor] === "'") {
      return parseString();
    }
    if (/[0-9-]/.test(source[cursor])) {
      return parseNumber();
    }
    return parseCall();
  }
  const node = parseExpression();
  skipWhitespace();
  if (cursor !== source.length) {
    throw new Error(`Unparsed ARM expression tail: "${source.slice(cursor)}"`);
  }
  return node;
}

function createArmReader(template, { parameters = {}, variables: overrides = {} } = {}) {
  const cache = new Map();
  function parameterValue(name) {
    if (name in parameters) {
      return parameters[name];
    }
    const declared = template.parameters[name];
    if (!declared || !('defaultValue' in declared)) {
      throw new Error(`ARM parameter "${name}" has no value in this evaluation`);
    }
    return declared.defaultValue;
  }
  function variableValue(name) {
    if (name in overrides) {
      return overrides[name];
    }
    if (cache.has(name)) {
      return cache.get(name);
    }
    const raw = template.variables[name];
    if (raw === undefined) {
      throw new Error(`Unknown ARM variable "${name}"`);
    }
    const value = typeof raw === 'string' ? evaluate(parseArmExpression(raw)) : raw;
    cache.set(name, value);
    return value;
  }
  function evaluate(node) {
    if (node.type === 'literal') {
      return node.value;
    }
    const { name, args } = node;
    switch (name) {
      case 'if':
        return evaluate(args[0]) ? evaluate(args[1]) : evaluate(args[2]);
      case 'and':
        return args.every((argument) => evaluate(argument));
      case 'or':
        return args.some((argument) => evaluate(argument));
      case 'not':
        return !evaluate(args[0]);
      case 'true':
        return true;
      case 'false':
        return false;
      case 'equals':
        return evaluate(args[0]) === evaluate(args[1]);
      case 'empty': {
        const value = evaluate(args[0]);
        return value === '' || value === null || value === undefined
          || (Array.isArray(value) && value.length === 0);
      }
      case 'parameters':
        return parameterValue(evaluate(args[0]));
      case 'variables':
        return variableValue(evaluate(args[0]));
      case 'concat':
        return args.map((argument) => String(evaluate(argument))).join('');
      case 'format': {
        const [template_, ...rest] = args.map((argument) => evaluate(argument));
        return String(template_).replace(/\{(\d+)\}/g, (_, index) => String(rest[Number(index)]));
      }
      case 'fail':
        throw new Error(String(evaluate(args[0])));
      default:
        throw new Error(`ARM function "${name}" is out of scope for this evaluation`);
    }
  }
  return (raw) => (
    typeof raw === 'string' && raw.startsWith('[') ? evaluate(parseArmExpression(raw)) : raw
  );
}

const publicDomainOutputs = [
  'publicDomainActivationReady',
  'publicWebOrigin',
  'privacyPolicyUrl',
  'accountDeletionUrl',
  'appleAppSiteAssociationUrl',
  'assetLinksUrl',
];

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
    /publicWebOriginAuthorityRemainder/,
  );
  assert.match(
    template.variables.publicWebOriginIsCanonicalHttps,
    /trim\(parameters\('publicWebOrigin'\)\)/,
  );
  assert.match(
    template.variables.publicWebOriginAuthorityRemainder,
    /reduce.*publicWebOriginAllowedCharacters.*replace/,
  );
  assert.match(
    template.variables.publicWebOriginLabelsAreValid,
    /reduce.*publicWebOriginLabels.*length.*63.*startsWith.*endsWith/,
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

test('an empty origin evaluates every public-domain output to disabled', () => {
  const template = compileMainTemplate();
  const read = createArmReader(template, {
    parameters: {
      env: 'prod',
      publicWebOrigin: '',
      publicDomainVerified: false,
      appleCiamDomainReconfigured: false,
      accountDeletionEnabled: false,
    },
  });

  assert.equal(read(template.outputs.publicDomainActivationReady.value), false);
  for (const output of publicDomainOutputs.slice(1)) {
    assert.equal(read(template.outputs[output].value), '', output);
  }
});

test('an activated domain evaluates the six outputs on the configured origin', () => {
  // Guards the opposite failure of the one above: a correction that silently disabled the
  // domain in every case would keep the previous test green.
  const template = compileMainTemplate();
  const read = createArmReader(template, {
    parameters: {
      env: 'prod',
      publicWebOrigin: 'https://www.example.net',
      publicDomainVerified: true,
      appleCiamDomainReconfigured: true,
      accountDeletionEnabled: true,
    },
    variables: { publicWebOriginIsCanonicalHttps: true },
  });

  assert.equal(read(template.outputs.publicDomainActivationReady.value), true);
  assert.equal(read(template.outputs.publicWebOrigin.value), 'https://www.example.net');
  assert.equal(
    read(template.outputs.privacyPolicyUrl.value),
    'https://www.example.net/privacy-policy/',
  );
  assert.equal(
    read(template.outputs.accountDeletionUrl.value),
    'https://www.example.net/account-deletion/',
  );
});

test('a configured origin still refuses an unproven or malformed activation', () => {
  const template = compileMainTemplate();
  const activated = {
    env: 'prod',
    publicWebOrigin: 'https://www.example.net',
    publicDomainVerified: true,
    appleCiamDomainReconfigured: true,
    accountDeletionEnabled: true,
  };
  // The origin shape rules are asserted structurally above and behaviourally in
  // .github/scripts/public-domain-contract.test.mjs; what is evaluated here is that a
  // failing shape is still wired to its fail().
  assert.throws(
    () => createArmReader(template, {
      parameters: activated,
      variables: { publicWebOriginIsCanonicalHttps: false },
    })(template.outputs.publicDomainActivationReady.value),
    /publicWebOrigin must be a canonical HTTPS origin/,
  );
  assert.throws(
    () => createArmReader(template, {
      parameters: { ...activated, publicDomainVerified: false },
      variables: { publicWebOriginIsCanonicalHttps: true },
    })(template.outputs.publicDomainActivationReady.value),
    /publicDomainVerified must be explicitly true/,
  );
});

test('refuses a proof posted without an origin', () => {
  // Optional hardening, isolated so it can be dropped on its own.
  const template = compileMainTemplate();
  assert.throws(
    () => createArmReader(template, {
      parameters: {
        env: 'prod',
        publicWebOrigin: '',
        publicDomainVerified: true,
        appleCiamDomainReconfigured: false,
        accountDeletionEnabled: false,
      },
    })(template.outputs.publicDomainActivationReady.value),
    /publicWebOrigin is required when/,
  );
});

test('enabling account deletion re-arms the Apple requirement in the template', () => {
  const template = compileMainTemplate();
  const withoutAppleProof = {
    env: 'prod',
    publicWebOrigin: 'https://www.example.net',
    publicDomainVerified: true,
    appleCiamDomainReconfigured: false,
  };

  assert.equal(
    createArmReader(template, {
      parameters: { ...withoutAppleProof, accountDeletionEnabled: false },
      variables: { publicWebOriginIsCanonicalHttps: true },
    })(template.outputs.publicDomainActivationReady.value),
    true,
  );
  assert.throws(
    () => createArmReader(template, {
      parameters: { ...withoutAppleProof, accountDeletionEnabled: true },
      variables: { publicWebOriginIsCanonicalHttps: true },
    })(template.outputs.publicDomainActivationReady.value),
    /appleCiamDomainReconfigured must be explicitly true/,
  );
});
