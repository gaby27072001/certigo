import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { gunzipSync, gzipSync } from 'node:zlib';

const imageRoot = fileURLToPath(new URL('./', import.meta.url));
const repositoryRoot = fileURLToPath(new URL('../../../', import.meta.url));
const contractBytes = readFileSync(join(imageRoot, 'image-build-contract.json'));
const contract = JSON.parse(contractBytes);
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
const staging = '/tmp/certigo-image-staging';
const gzipInputs = new Set(['apt-packages.lock.json', 'toolchain-requirements.lock']);

// Documented limits, with a 10 % margin below each (decimal MB, stricter than MiB):
// - ARM "Template limits": template 4 MB and each resource definition 1 MB, measured on the
//   final state after expansion of variables and parameters.
//   https://learn.microsoft.com/azure/azure-resource-manager/templates/best-practices#template-limits
// - ARM "job size exceeded": deployment job 1 MB after compression, request metadata included.
//   https://learn.microsoft.com/azure/azure-resource-manager/troubleshooting/error-job-size-exceeded
// - Bicep loadFileAsBase64: 96 KB per file (BCP184 at 98304 bytes).
//   https://learn.microsoft.com/azure/azure-resource-manager/bicep/bicep-functions-files#loadfileasbase64
// No Azure VM Image Builder limit on inline customizers is documented; a hidden limit would
// fail the first, separately authorized build closed.
const margin = 0.9;
const limits = {
  templateBytes: 4_000_000,
  resourceBytes: 1_000_000,
  compressedTemplateBytes: 1_000_000,
  embeddedFileBytes: 98_304,
};

const compiledText = execFileSync(process.env.BICEP_CLI || 'bicep',
  ['build', join(imageRoot, 'image-build.bicep'), '--stdout'],
  { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, timeout: 120000 });
const template = JSON.parse(compiledText);

// Minimal evaluator for the ARM expressions this transport is allowed to use.
function evaluate(value) {
  if (typeof value !== 'string' || !value.startsWith('[') || value.startsWith('[[')) {
    return value;
  }
  const text = value.slice(1, -1);
  let index = 0;
  const skip = () => {
    while (/\s/.test(text[index] ?? '')) index += 1;
  };
  const expect = (character) => {
    skip();
    assert.equal(text[index], character, `ARM expression syntax at ${index}: ${value.slice(0, 80)}`);
    index += 1;
  };
  const identifier = () => {
    const match = /^[A-Za-z_][A-Za-z0-9_]*/.exec(text.slice(index));
    assert.ok(match, `ARM identifier expected: ${value.slice(0, 80)}`);
    index += match[0].length;
    return match[0];
  };
  const literal = () => {
    index += 1;
    let result = '';
    for (;;) {
      const character = text[index];
      assert.notEqual(character, undefined, 'Unterminated ARM string');
      index += 1;
      if (character === "'") {
        if (text[index] === "'") {
          result += "'";
          index += 1;
          continue;
        }
        return result;
      }
      result += character;
    }
  };
  const call = (name, args) => {
    if (name === 'variables') {
      assert.ok(Object.hasOwn(template.variables, args[0]), `Unknown variable ${args[0]}`);
      return resolve(template.variables[args[0]]);
    }
    if (name === 'format') {
      assert.doesNotMatch(args[0].replace(/\{\d+\}/g, ''), /[{}]/, 'Unsupported format braces');
      return args[0].replace(/\{(\d+)\}/g, (_, position) => String(args[Number(position) + 1]));
    }
    throw new Error(`Unsupported ARM function in the image transport: ${name}`);
  };
  const expression = () => {
    skip();
    let result;
    if (text[index] === "'") {
      result = literal();
    } else {
      const name = identifier();
      expect('(');
      const args = [];
      skip();
      if (text[index] !== ')') {
        for (;;) {
          args.push(expression());
          skip();
          if (text[index] !== ',') break;
          index += 1;
        }
      }
      expect(')');
      result = call(name, args);
    }
    for (;;) {
      if (text[index] === '.') {
        index += 1;
        result = result[identifier()];
      } else if (text[index] === '[') {
        index += 1;
        const key = expression();
        expect(']');
        result = result[key];
      } else {
        break;
      }
    }
    skip();
    return result;
  };
  const result = expression();
  assert.equal(index, text.length, `Trailing ARM expression text: ${value.slice(0, 80)}`);
  return result;
}

function resolve(value) {
  if (Array.isArray(value)) return value.map(resolve);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, resolve(item)]));
  }
  return evaluate(value);
}

const resources = Array.isArray(template.resources) ? template.resources :
  Object.values(template.resources);
const imageTemplate = resources.find((resource) =>
  resource.type === 'Microsoft.VirtualMachineImages/imageTemplates');
const customize = resolve(imageTemplate.properties.customize);
const customizer = (name) => {
  const found = customize.filter((item) => item.name === name);
  assert.equal(found.length, 1, name);
  return found[0];
};

function embeddedPayloads() {
  const payloads = new Map();
  for (const line of customizer('stage-embedded-inputs').inline.slice(2)) {
    const match = /^printf '%s' '([A-Za-z0-9+/=]+)' > \/tmp\/certigo-image-staging\/([A-Za-z0-9._-]+)\.b64 \|\| exit 1$/.exec(line);
    assert.ok(match, `Unexpected staging line: ${line.slice(0, 100)}`);
    assert.ok(!payloads.has(match[2]), `Duplicate embedded input: ${match[2]}`);
    payloads.set(match[2], Buffer.from(match[1], 'base64'));
  }
  return payloads;
}

test('the template embeds exactly the contract inputs, byte for byte', () => {
  const payloads = embeddedPayloads();
  const expected = ['image-build-contract.json', ...contract.inputs.map((input) =>
    gzipInputs.has(input.destination) ? `${input.destination}.gz` : input.destination)];
  assert.deepEqual([...payloads.keys()].sort(), expected.sort());
  const contractSha256 = template.variables.contractSha256;
  assert.equal(sha256(payloads.get('image-build-contract.json')), contractSha256);
  assert.equal(sha256(contractBytes), contractSha256);
  for (const input of contract.inputs) {
    const name = gzipInputs.has(input.destination) ? `${input.destination}.gz` : input.destination;
    const bytes = name.endsWith('.gz') ? gunzipSync(payloads.get(name)) : payloads.get(name);
    assert.equal(sha256(bytes), input.sha256, input.destination);
    assert.deepEqual(bytes, readFileSync(join(repositoryRoot, input.path)), input.path);
  }
});

test('gzip derivatives decompress to the exact lock bytes and carry no name or date', () => {
  const directory = join(imageRoot, 'transport');
  const files = readdirSync(directory).filter((name) => name.endsWith('.gz')).sort();
  assert.deepEqual(files, [...gzipInputs].map((name) => `${name}.gz`).sort());
  for (const file of files) {
    const gz = readFileSync(join(directory, file));
    const input = contract.inputs.find((item) => `${item.destination}.gz` === file);
    const expanded = gunzipSync(gz);
    assert.deepEqual(expanded, readFileSync(join(repositoryRoot, input.path)), file);
    assert.equal(sha256(expanded), input.sha256, file);
    // RFC 1952 header produced by `gzip -n`: no FNAME flag and a zero MTIME.
    assert.deepEqual([gz[0], gz[1], gz[2]], [0x1f, 0x8b, 8], file);
    assert.equal(gz[3] & 0x08, 0, `${file} must not store a file name`);
    assert.equal(gz.readUInt32LE(4), 0, `${file} must not store a timestamp`);
    // Bytes, not the compressor, are the contract: recompression may legitimately differ.
    assert.deepEqual(gunzipSync(gzipSync(expanded, { level: 9 })), expanded);
  }
});

test('compiled sizes stay at least 10 % below every documented limit', (t) => {
  const templateBytes = Buffer.byteLength(compiledText);
  // Upper bound of the expanded resource: customizers fully resolved, plus every other
  // variable and parameter default in case the remaining expressions expand to them.
  const transportVariables = new Set(['stageEmbeddedInputs', 'verifyEmbeddedInputs',
    'acquireClosedArtifactSet']);
  const otherVariables = Object.fromEntries(Object.entries(template.variables)
    .filter(([name]) => !name.startsWith('$fxv#') && !transportVariables.has(name)));
  const resourceBytes = Buffer.byteLength(JSON.stringify({
    ...imageTemplate,
    properties: { ...imageTemplate.properties, customize },
  })) + Buffer.byteLength(JSON.stringify(otherVariables)) +
    Buffer.byteLength(JSON.stringify(template.parameters));
  const compressedTemplateBytes = gzipSync(Buffer.from(compiledText), { level: 9 }).length;
  const measured = { templateBytes, resourceBytes, compressedTemplateBytes };
  t.diagnostic(`measured ${JSON.stringify(measured)}`);
  for (const [name, value] of Object.entries(measured)) {
    assert.ok(value <= Math.floor(limits[name] * margin),
      `${name} ${value} exceeds ${margin * 100} % of the documented ${limits[name]}`);
  }
  for (const [name, bytes] of embeddedPayloads()) {
    assert.ok(bytes.length <= Math.floor(limits.embeddedFileBytes * margin),
      `${name} ${bytes.length} bytes exceeds ${margin * 100} % of loadFileAsBase64 limit`);
  }
});

test('customizers stay ordered and the installation stays blocked', () => {
  assert.deepEqual(customize.map((item) => item.name), [
    'block-imds-before-network',
    'stage-embedded-inputs',
    'verify-embedded-inputs',
    'acquire-closed-artifact-set',
    'install-offline-toolchain',
  ]);
  assert.ok(customize.every((item) => item.type === 'Shell'), 'No File customizer may remain');
  assert.doesNotMatch(compiledText, /raw\.githubusercontent\.com|sourceUri|pipefail/);
  const install = customizer('install-offline-toolchain').inline;
  assert.equal(install[0], 'set -eu');
  assert.match(install[1], /^echo "Image installation blocked: .*\(#341\)\." >&2; exit 1$/);
  assert.ok(install.includes('sudo unshare --net -- python3 -E -s -B ' +
    '/var/tmp/certigo-image-input/install_offline.py install --inputs /var/tmp/certigo-image-input ' +
    `--store /var/tmp/certigo-image-store --contract-sha256 ${template.variables.contractSha256} || exit 1`));
  const acquire = customizer('acquire-closed-artifact-set').inline;
  assert.match(acquire[1], /^rm -rf \/tmp\/certigo-image-store && python3 -E -s -B /);
  assert.doesNotMatch(acquire[1], /sudo/, 'Downloads run as the unprivileged build user');
  for (const item of customize) {
    for (const line of item.inline.slice(1)) {
      assert.ok(/(\|\| exit 1|\|\| exit 1; done|exit 1; fi|>&2; exit 1)$/.test(line),
        `${item.name}: ${line.slice(0, 90)}`);
    }
  }
});

test('the decode and verification lines run under POSIX sh and refuse tampering',
  { skip: process.platform !== 'linux' && 'requires /bin/sh, base64, gzip, jq and sha256sum' }, (t) => {
    const directory = mkdtempSync(join(tmpdir(), 'certigo-transport-'));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    const relocated = (line) => line.replaceAll(staging, join(directory, 'staging'));
    const stageLines = customizer('stage-embedded-inputs').inline.map(relocated);
    const verifyLines = customizer('verify-embedded-inputs').inline.map(relocated);
    const checkLines = verifyLines.slice(3, -1);
    // Each line in its own shell: AIB does not document whether lines share a session.
    const runLine = (line) => spawnSync('/bin/sh', ['-c', `set -eu; ${line}`],
      { cwd: directory, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
    const runAll = (lines) => lines.map(runLine).find((result) => result.status !== 0);
    assert.equal(runAll([...stageLines.slice(1), ...verifyLines.slice(1, 3)]), undefined);
    assert.equal(runAll(checkLines), undefined);
    for (const input of contract.inputs) {
      assert.deepEqual(readFileSync(join(directory, 'staging', input.destination)),
        readFileSync(join(repositoryRoot, input.path)), input.destination);
    }
    const victim = join(directory, 'staging', 'install_offline.py');
    const original = readFileSync(victim);
    writeFileSync(victim, Buffer.concat([original, Buffer.from('\n# tampered\n')]));
    const altered = runAll(checkLines);
    assert.ok(altered && /install_offline\.py: FAILED/.test(altered.stdout + altered.stderr));
    writeFileSync(victim, original);
    writeFileSync(join(directory, 'staging', 'unexpected.sh'), 'exit 0\n');
    assert.ok(runAll(checkLines), 'An unexpected staged file must be refused');
    rmSync(join(directory, 'staging', 'unexpected.sh'));
    rmSync(victim);
    const omitted = runAll(checkLines);
    assert.ok(omitted && /install_offline\.py/.test(omitted.stdout + omitted.stderr));
    writeFileSync(victim, original);
    const contractPath = join(directory, 'staging', 'image-build-contract.json');
    const forged = JSON.parse(readFileSync(contractPath));
    forged.inputs.find((input) => input.destination === 'install_offline.py').sha256 = sha256(
      Buffer.concat([original, Buffer.from('\n')]));
    writeFileSync(contractPath, `${JSON.stringify(forged, null, 2)}\n`);
    const substituted = runAll(checkLines);
    assert.ok(substituted && /image-build-contract\.json: FAILED/.test(
      substituted.stdout + substituted.stderr), 'A substituted contract must be refused first');
  });
