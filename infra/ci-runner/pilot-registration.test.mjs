import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const source = fs.readFileSync(new URL('./pilot-register.sh', import.meta.url), 'utf8');
const preflight = fs.readFileSync(new URL('./pilot-preflight.sh', import.meta.url), 'utf8');
const url = 'https://github.com/gaby27072001/certigo';

function run(t, { expected = url, guest = url, attested = url, service = false,
  configFailure = false, processError = false, unitError = false,
  preflightOnly = false, labels = 'certigo-pr,certigo-pr-pilot' } = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-registration-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const write = (name, content) => {
    const file = path.join(root, name);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, content, { mode: 0o700 });
  };
  write('boot', 'synthetic-boot\n');
  if (!preflightOnly) {
    write('attestation', `BOOT_ID=synthetic-boot\nREPOSITORY_URL=${attested}\n`);
  }
  write('bootstrap', `GITHUB_URL=${guest}\nRUNNER_LABELS=${labels}\nRUNNER_VERSION=2.336.0\n`);
  write('bin/systemctl', `#!/bin/sh\nif [ "$1" = list-unit-files ]; then ${unitError ? 'exit 2' : service ? 'echo actions.runner.old.service' : ':'}; fi\n`);
  write('bin/curl', '#!/bin/sh\ncase "$*" in *169.254.169.254*) exit 1;; *) exit 0;; esac\n');
  write('bin/cloud-init', '#!/bin/sh\nexit 0\n');
  write('bin/az', '#!/bin/sh\nexit 0\n');
  for (const tool of ['git', 'jq', 'tar', 'unzip', 'zip', 'xz']) {
    write(`bin/${tool}`, '#!/bin/sh\nexit 0\n');
  }
  write('bin/pgrep', `#!/bin/sh\nexit ${processError ? 2 : 1}\n`);
  write('bin/stat', '#!/bin/sh\necho root:root:600\n');
  write('bin/chown', '#!/bin/sh\nexit 0\n');
  write('bin/runuser', `#!/bin/sh\ncase "$*" in\n*Runner.Listener*) echo 2.336.0;;\n*config.sh*) printf '%s\\n' "$*" >> "$TRACE"; exit ${configFailure ? 1 : 0};;\n*) exit 99;;\nesac\n`);
  let script = (preflightOnly ? preflight : source).replaceAll('/proc/sys/kernel/random/boot_id', path.join(root, 'boot'))
    .replaceAll('/run/certigo-pr-preflight.ok', path.join(root, 'attestation'))
    .replaceAll('/etc/certigo-runner-bootstrap.env', path.join(root, 'bootstrap'))
    .replaceAll('/opt/actions-runner', path.join(root, 'runner'));
  // Quoted assignment, not shell interpolation of the tested URL.
  script = `expected_repository_url='${expected.replaceAll("'", "'\\''")}'\n${script}`;
  write('register.sh', script);
  fs.mkdirSync(path.join(root, 'runner'));
  const result = spawnSync('bash', [path.join(root, 'register.sh'), 'synthetic-token'], {
    encoding: 'utf8',
    env: { ...process.env, PATH: `${path.join(root, 'bin')}:${process.env.PATH}`,
      TRACE: path.join(root, 'trace') },
  });
  assert.ifError(result.error);
  const trace = fs.existsSync(path.join(root, 'trace'))
    ? fs.readFileSync(path.join(root, 'trace'), 'utf8') : '';
  const attestation = fs.existsSync(path.join(root, 'attestation'))
    ? fs.readFileSync(path.join(root, 'attestation'), 'utf8') : '';
  return { ...result, trace, attestation };
}

test('registration configures exact URL without installing or starting a listener', (t) => {
  const result = run(t);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.trace, new RegExp(`--url ${url}`));
  assert.match(result.stdout, /registered and held offline/);
  assert.doesNotMatch(source, /svc\.sh|systemctl\s+start|run\.sh/);
});

test('legacy guest, stale attestation and malformed URLs fail before configuration', (t) => {
  for (const input of [
    { guest: 'https://github.com/gchambaud_microsoft/Certigo' },
    { attested: 'https://github.com/gchambaud_microsoft/Certigo' },
    { expected: 'https://github.com/gaby27072001/certigo?other=1' },
    { expected: 'https://github.com/gaby27072001/certigo;echo injected' },
    { expected: 'https://github.com/gaby27072001/$(echo injected)' },
  ]) {
    const result = run(t, input);
    assert.notEqual(result.status, 0);
    assert.equal(result.trace, '');
    assert.doesNotMatch(result.stdout + result.stderr, /synthetic-token/);
  }
});

test('stale services and privileged labels prevent configuration', (t) => {
  for (const input of [{ service: true }, { labels: 'certigo-trusted' },
    { processError: true }, { unitError: true }]) {
    const result = run(t, input);
    assert.notEqual(result.status, 0);
    assert.equal(result.trace, '');
  }
});

test('guest preflight attests only exact destination with no existing admission service', (t) => {
  const good = run(t, { preflightOnly: true });
  assert.equal(good.status, 0, good.stderr);
  assert.match(good.attestation, new RegExp(`REPOSITORY_URL=${url}`));
  for (const input of [
    { guest: 'https://github.com/gchambaud_microsoft/Certigo' },
    { service: true }, { processError: true }, { unitError: true },
  ]) {
    const bad = run(t, { ...input, preflightOnly: true });
    assert.notEqual(bad.status, 0);
    assert.equal(bad.attestation, '');
    assert.equal(bad.trace, '');
  }
});

test('configuration failure never reports held registration success', (t) => {
  const result = run(t, { configFailure: true });
  assert.notEqual(result.status, 0);
  assert.doesNotMatch(result.stdout, /registered and held offline/);
});

test('operator requires explicit repository and applies same guard before token request', () => {
  const operator = fs.readFileSync(new URL('./register-pilot.ps1', import.meta.url), 'utf8');
  assert.match(operator, /\[Parameter\(Mandatory\)\]\s+\[ValidatePattern\([^\n]+\)\]\s+\[string\] \$Repository/);
  assert.ok(operator.indexOf('$preflightScript = $repositoryGuard + $preflightScript')
    < operator.indexOf('$registrationToken = Invoke-NativeText'));
  assert.match(operator, /\$registerScript = \$repositoryGuard \+ \$registerScript/);
  assert.match(operator, /\$pilot\[0\]\.status -eq 'offline'/);
});
