import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import { chmod, link, mkdir, mkdtemp, open, readFile, readdir, rm, stat, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import test from 'node:test';
import { parseDocument } from 'yaml';

import { buildPublicPages } from '../build_public_pages.mjs';

const generatedFiles = [
  'staticwebapp.config.json',
  'index.html',
  'privacy-policy/index.html',
  'account-deletion/index.html',
  'learn/responsible-ai-assistants/index.html',
  'learn/responsible-ai-assistants/verify-claims/index.html',
  'learn/responsible-ai-assistants/retrieval-not-training/index.html',
  'learn/responsible-ai-assistants/stop-and-escalate/index.html',
];

function configuration(output) {
  return {
    root: resolve('.'), output, publicWebOrigin: 'https://github.com',
    publicDomainVerified: true, appleCiamDomainReconfigured: false,
  };
}

test('builds public privacy and account-deletion routes without a data form', async () => {
  const output = await mkdtemp(join(tmpdir(), 'certigo-public-pages-'));
  try {
    await buildPublicPages({
      root: resolve('.'),
      output,
      publicWebOrigin: 'https://github.com',
      publicDomainVerified: true,
      appleCiamDomainReconfigured: false,
    });

    const deletion = await readFile(join(output, 'account-deletion/index.html'), 'utf8');
    const privacy = await readFile(join(output, 'privacy-policy/index.html'), 'utf8');
    const lesson = await readFile(
      join(output, 'learn/responsible-ai-assistants/verify-claims/index.html'),
      'utf8',
    );
    const config = JSON.parse(await readFile(join(output, 'staticwebapp.config.json'), 'utf8'));

    assert.match(deletion, /Demander la suppression d’un compte Certigo/);
    assert.match(deletion, /mailto:gabriel\.chambaud@icloud\.com/);
    assert.match(deletion, /données actives sont supprimées immédiatement/);
    assert.match(deletion, /reçu pseudonymisé expire après 30 jours/);
    assert.match(deletion, /sauvegardes résiduelles expirent au plus tard après 30 jours/);
    assert.match(deletion, /journaux techniques sans identité sont conservés 90 jours/);
    assert.match(deletion, /N’envoyez jamais .* pièce d’identité/);
    assert.match(deletion, /<html lang="fr">/);
    assert.match(deletion, /aria-labelledby="request-title"/);
    assert.match(
      deletion,
      /<link rel="canonical" href="https:\/\/github\.com\/account-deletion\/">/,
    );
    assert.match(deletion, /\.button:focus-visible/);
    assert.doesNotMatch(deletion, /<form\b/i);
    assert.doesNotMatch(deletion, /password|mot de passe" type=/i);
    assert.match(privacy, /Politique de confidentialité/);
    assert.match(privacy, /gabriel\.chambaud@icloud\.com/);
    assert.match(privacy, /immédiatement après la vérification/);
    assert.match(privacy, /récupération maximale de 30 jours/);
    assert.match(privacy, /conservés pendant 90 jours/);
    assert.match(privacy, /ne demande pas de pièce d’identité/);
    assert.match(
      privacy,
      /<link rel="canonical" href="https:\/\/github\.com\/privacy-policy\/">/,
    );
    assert.match(lesson, /Une réponse convaincante n&#39;est pas une preuve/);
    assert.match(lesson, /Apprentissage, pas certification/);
    assert.match(lesson, /La lecture web ne crée pas de compte/);
    assert.ok(
      lesson.includes(
        '<link rel="canonical" href="https://github.com/learn/responsible-ai-assistants/verify-claims/">',
      ),
    );
    assert.ok(lesson.includes('href="https://docs.aws.amazon.com/'));
    assert.deepEqual(config.routes, []);
    await assert.rejects(
      readFile(join(output, '.well-known/apple-app-site-association.json')),
      /ENOENT/,
    );
  } finally {
    await rm(output, { recursive: true, force: true });
  }
});

test('only emits the production AASA after an explicitly verified compatible build', async () => {
  const output = await mkdtemp(join(tmpdir(), 'certigo-universal-links-enabled-'));
  try {
    await buildPublicPages({
      root: resolve('.'),
      output,
      publicWebOrigin: 'https://www.certigo-app.com',
      publicDomainVerified: true,
      appleCiamDomainReconfigured: false,
      iosUniversalLinksBuildVerified: true,
    });

    const aasa = JSON.parse(
      await readFile(join(output, '.well-known/apple-app-site-association.json'), 'utf8'),
    );
    const config = JSON.parse(await readFile(join(output, 'staticwebapp.config.json'), 'utf8'));
    assert.deepEqual(aasa, {
      applinks: {
        apps: [],
        details: [{
          appID: 'FFQPC7NC68.com.certigo.mobileapp',
          paths: [
            '/learn/responsible-ai-assistants/verify-claims',
            '/learn/responsible-ai-assistants/verify-claims/',
            '/learn/responsible-ai-assistants/retrieval-not-training',
            '/learn/responsible-ai-assistants/retrieval-not-training/',
            '/learn/responsible-ai-assistants/stop-and-escalate',
            '/learn/responsible-ai-assistants/stop-and-escalate/',
          ],
        }],
      },
    });
    assert.deepEqual(config.routes, [{
      route: '/.well-known/apple-app-site-association',
      rewrite: '/.well-known/apple-app-site-association.json',
    }]);
  } finally {
    await rm(output, { recursive: true, force: true });
  }
});

test('URL receipt only stages a link; access and read operations stay at their V1 boundary', async () => {
  const nativeApp = await readFile(
    resolve('apps/apple/CertigoNative/Sources/NativeEntryViews.swift'),
    'utf8',
  );
  const handlerStart = nativeApp.indexOf('private func handleIncomingURL');
  assert.ok(handlerStart >= 0);
  const handlerEnd = nativeApp.indexOf('\n        }\n    }', handlerStart);
  assert.ok(handlerEnd > handlerStart);
  const handler = nativeApp.slice(handlerStart, handlerEnd);
  assert.doesNotMatch(
    handler,
    /connect\(|loadEditorialPilot\(|accessEditorialPilotLesson\(|markEditorialPilotLessonRead\(/,
  );
  assert.match(nativeApp, /Button\(copy\.native\(\.openLinkedLesson\)/);
  const rootView = await readFile(
    resolve('apps/apple/CertigoNative/Sources/NativeRootView.swift'), 'utf8',
  );
  assert.match(rootView, /Button\(\s*copy\.native\(\.openLinkedLesson\)/);

  const pilotView = await readFile(
    resolve('apps/apple/CertigoNative/Sources/NativeEditorialPilotView.swift'),
    'utf8',
  );
  assert.match(pilotView, /\.task \{ await recordAccess\(\) \}/);
  assert.doesNotMatch(pilotView, /\.task \{[^}]*markRead\(\)/s);
  assert.match(
    pilotView,
    /NativePrimaryButton\(title: copy\.native\(\.markRead\), symbol: "checkmark"\)\s*\{\s*Task \{ await markRead\(\) \}\s*\}/s,
  );
});

test('refuses to enable the production AASA for any other origin', async () => {
  const output = join(tmpdir(), `certigo-universal-links-closed-${process.pid}-${Date.now()}`);
  await assert.rejects(
    buildPublicPages({
      ...configuration(output),
      iosUniversalLinksBuildVerified: true,
    }),
    /Universal Links can only be enabled for https:\/\/www\.certigo-app\.com/,
  );
  await assert.rejects(readFile(join(output, 'index.html')), /ENOENT/);
});

test('fails before creating output when the public domain is not verified', async () => {
  const output = join(tmpdir(), `certigo-public-pages-closed-${process.pid}-${Date.now()}`);
  await assert.rejects(
    buildPublicPages({
      root: resolve('.'),
      output,
      publicWebOrigin: '',
      publicDomainVerified: false,
      appleCiamDomainReconfigured: false,
    }),
    /PUBLIC_WEB_ORIGIN is required/,
  );
  await assert.rejects(readFile(join(output, 'privacy-policy/index.html')), /ENOENT/);
});

test('reruns preserve output bytes and existing modes; new files match ordinary creation modes', async () => {
  const output = await mkdtemp(join(tmpdir(), 'certigo-public-repeat-'));
  try {
    const reference = join(output, 'reference');
    await writeFile(reference, 'creation-mode reference');
    const mode = (await stat(reference)).mode & 0o777;
    await rm(reference);
    await buildPublicPages(configuration(output));
    const first = await Promise.all(generatedFiles.map((file) => readFile(join(output, file))));
    if (process.platform !== 'win32') {
      for (const file of generatedFiles) {
        assert.equal((await stat(join(output, file))).mode & 0o777, mode);
      }
      await chmod(join(output, 'index.html'), 0o640);
    }
    await buildPublicPages(configuration(output));
    assert.deepEqual(await Promise.all(generatedFiles.map((file) => readFile(join(output, file)))), first);
    if (process.platform !== 'win32') {
      assert.equal((await stat(join(output, 'index.html'))).mode & 0o777, 0o640);
    }
    assert.deepEqual((await readdir(output)).sort(), [
      'account-deletion', 'index.html', 'learn', 'privacy-policy', 'staticwebapp.config.json',
    ]);
  } finally {
    await rm(output, { recursive: true, force: true });
  }
});

test('each generated destination refuses symlinks, hardlinks and directories without touching victims', async (context) => {
  for (const file of generatedFiles) {
    for (const kind of ['symlink', 'hardlink', 'directory']) {
      await context.test(`${file}: ${kind}`, async (fixture) => {
        const output = await mkdtemp(join(tmpdir(), 'certigo-public-hostile-'));
        try {
          const destination = join(output, file);
          const victim = join(output, 'victim');
          await mkdir(dirname(destination), { recursive: true });
          await writeFile(victim, 'untouched');
          if (kind === 'symlink') {
            try {
              await symlink(victim, destination, 'file');
            } catch (error) {
              if (process.platform !== 'win32' || error.code !== 'EPERM') throw error;
              fixture.skip('Windows does not permit file symlink creation in this test context');
              return;
            }
          } else if (kind === 'hardlink') {
            await link(victim, destination);
          } else {
            await mkdir(destination);
          }
          await assert.rejects(buildPublicPages(configuration(output)), /regular non-symlink single-link file/);
          assert.equal(await readFile(victim, 'utf8'), 'untouched');
        } finally {
          await rm(output, { recursive: true, force: true });
        }
      });
    }
  }
});

test('a pre-existing parent link is rejected before any output directories or files are created outside', async () => {
  const root = await mkdtemp(join(tmpdir(), 'certigo-public-parent-'));
  try {
    const outside = join(root, 'outside');
    await mkdir(outside);
    const parent = join(root, 'linked');
    await symlink(outside, parent, 'junction');
    await assert.rejects(
      buildPublicPages(configuration(join(parent, 'new-output'))),
      /output ancestors must be real non-symlink directories/,
    );
    assert.deepEqual(await readdir(outside), []);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test('substitution of an existing destination is rejected before truncate or write', async (context) => {
  const output = await mkdtemp(join(tmpdir(), 'certigo-public-substitute-'));
  try {
    await buildPublicPages(configuration(output));
    const destination = join(output, 'staticwebapp.config.json');
    const backup = join(output, 'original-config');
    const victim = join(output, 'victim');
    await writeFile(victim, 'untouched');
    const originalOpen = fs.openSync;
    context.mock.method(fs, 'openSync', (file, ...args) => {
      if (file === destination) {
        fs.renameSync(destination, backup);
        fs.linkSync(victim, destination);
      }
      return originalOpen(file, ...args);
    });
    await assert.rejects(buildPublicPages(configuration(output)), /output file changed while opening/);
    assert.equal(await readFile(victim, 'utf8'), 'untouched');
  } finally {
    context.mock.restoreAll();
    await rm(output, { recursive: true, force: true });
  }
});

test('new outputs use exclusive creation; a competing final file is never overwritten', async (context) => {
  const output = await mkdtemp(join(tmpdir(), 'certigo-public-exclusive-'));
  try {
    const destination = join(output, 'staticwebapp.config.json');
    const originalOpen = fs.openSync;
    context.mock.method(fs, 'openSync', (file, flags, ...args) => {
      if (file === destination) {
        assert.ok(flags & fs.constants.O_EXCL);
        fs.writeFileSync(file, 'competing file');
      }
      return originalOpen(file, flags, ...args);
    });
    await assert.rejects(buildPublicPages(configuration(output)), { code: 'EEXIST' });
    assert.equal(await readFile(destination, 'utf8'), 'competing file');
  } finally {
    context.mock.restoreAll();
    await rm(output, { recursive: true, force: true });
  }
});

test('new POSIX output stays private during writing and follows non-default umask on completion', {
  skip: process.platform === 'win32' && 'POSIX mode and umask are not Windows permissions',
}, async (context) => {
  const output = await mkdtemp(join(tmpdir(), 'certigo-public-modes-'));
  try {
    const originalWrite = fs.writeFileSync;
    const descriptorTypes = [];
    const modes = [];
    context.mock.method(fs, 'writeFileSync', (descriptor, ...args) => {
      descriptorTypes.push(typeof descriptor);
      const result = originalWrite(descriptor, ...args);
      modes.push(fs.fstatSync(descriptor).mode & 0o777);
      return result;
    });
    const originalTruncate = fs.ftruncateSync;
    const originalChmod = fs.fchmodSync;
    let truncations = 0;
    let publications = 0;
    context.mock.method(fs, 'ftruncateSync', (descriptor, ...args) => {
      assert.equal(typeof descriptor, 'number');
      assert.equal(fs.fstatSync(descriptor).mode & 0o777, 0o600 & ~process.umask());
      truncations += 1;
      return originalTruncate(descriptor, ...args);
    });
    context.mock.method(fs, 'fchmodSync', (descriptor, ...args) => {
      assert.equal(fs.fstatSync(descriptor).mode & 0o777, 0o600 & ~process.umask());
      assert.ok(fs.fstatSync(descriptor).size > 0);
      publications += 1;
      return originalChmod(descriptor, ...args);
    });
    await buildPublicPages(configuration(output));
    assert.equal(descriptorTypes.length, generatedFiles.length);
    assert.ok(descriptorTypes.every((type) => type === 'number'));
    assert.deepEqual(modes, modes.map(() => 0o600 & ~process.umask()));
    assert.equal(truncations, generatedFiles.length);
    assert.equal(publications, generatedFiles.length);
    context.mock.restoreAll();
    execFileSync(process.execPath, ['--input-type=module', '-e', `
      import assert from 'node:assert/strict';
      import fs from 'node:fs/promises';
      import { join } from 'node:path';
      import { buildPublicPages } from ${JSON.stringify(new URL('../build_public_pages.mjs', import.meta.url).href)};
      const output = process.argv[1];
      const config = {
        root: process.cwd(), output, publicWebOrigin: 'https://github.com',
        publicDomainVerified: true, appleCiamDomainReconfigured: false,
      };
      async function assertModeAndChmod(file, expected, mode) {
        const handle = await fs.open(file, 'r');
        try {
          assert.equal((await handle.stat()).mode & 0o777, expected);
          await handle.chmod(mode);
        } finally {
          await handle.close();
        }
      }
      process.umask(0o027);
      await buildPublicPages(config);
      const file = join(output, 'index.html');
      await assertModeAndChmod(file, 0o640, 0o604);
      process.umask(0o077);
      await buildPublicPages(config);
      assert.equal((await fs.stat(file)).mode & 0o777, 0o604);

      const originalOpen = fs.open;
      const original = join(output, 'original-index.html');
      const victim = join(output, 'victim');
      await fs.writeFile(victim, 'untouched', { mode: 0o600 });
      let substituted = false;
      let closed = false;
      fs.open = async (...args) => {
        const handle = await originalOpen(...args);
        const originalStat = handle.stat.bind(handle);
        const originalClose = handle.close.bind(handle);
        handle.stat = async () => {
          const stats = await originalStat();
          await fs.rename(file, original);
          await fs.symlink(victim, file);
          substituted = true;
          return stats;
        };
        handle.close = async () => {
          closed = true;
          return originalClose();
        };
        return handle;
      };
      try {
        await assertModeAndChmod(file, 0o604, 0o640);
      } finally {
        fs.open = originalOpen;
      }
      assert.equal(substituted, true);
      assert.equal(closed, true);
      assert.equal((await fs.stat(original)).mode & 0o777, 0o640);
      assert.equal((await fs.stat(victim)).mode & 0o777, 0o600);
      assert.equal(await fs.readFile(victim, 'utf8'), 'untouched');
    `, join(output, 'different-umask')], { timeout: 15000, encoding: 'utf8' });
  } finally {
    context.mock.restoreAll();
    await rm(output, { recursive: true, force: true });
  }
});

test('replacement after descriptor validation cannot redirect truncation, writing or mode changes', {
  skip: process.platform === 'win32' && 'POSIX mode and symlink substitution fixture',
}, async (context) => {
  const output = await mkdtemp(join(tmpdir(), 'certigo-public-write-substitute-'));
  try {
    const destination = join(output, 'staticwebapp.config.json');
    const original = join(output, 'original-config');
    const victim = join(output, 'victim');
    await writeFile(victim, 'untouched', { mode: 0o600 });
    const originalOpen = fs.openSync;
    const originalTruncate = fs.ftruncateSync;
    let descriptor;
    let substituted = false;
    context.mock.method(fs, 'openSync', (file, ...args) => {
      const opened = originalOpen(file, ...args);
      if (file === destination) descriptor = opened;
      return opened;
    });
    context.mock.method(fs, 'ftruncateSync', (opened, ...args) => {
      if (opened === descriptor && !substituted) {
        fs.renameSync(destination, original);
        fs.symlinkSync(victim, destination);
        substituted = true;
      }
      return originalTruncate(opened, ...args);
    });
    await buildPublicPages(configuration(output));
    assert.equal(substituted, true);
    assert.throws(() => fs.fstatSync(descriptor), { code: 'EBADF' });
    assert.equal(await readFile(victim, 'utf8'), 'untouched');
    assert.equal((await stat(victim)).mode & 0o777, 0o600 & ~process.umask());
    const handle = await open(original, 'r');
    try {
      assert.equal((await handle.stat()).mode & 0o777, 0o666 & ~process.umask());
      const generated = JSON.parse(await handle.readFile('utf8'));
      assert.deepEqual(generated.mimeTypes, { '.json': 'application/json' });
      assert.deepEqual(generated.routes, []);
    } finally {
      await handle.close();
    }
  } finally {
    context.mock.restoreAll();
    await rm(output, { recursive: true, force: true });
  }
});

test('a substituted FIFO cannot block generation or receive bytes', {
  skip: process.platform === 'win32' && 'mkfifo is a POSIX fixture',
}, async (context) => {
  const output = await mkdtemp(join(tmpdir(), 'certigo-public-fifo-'));
  try {
    await buildPublicPages(configuration(output));
    const destination = join(output, 'staticwebapp.config.json');
    const originalOpen = fs.openSync;
    context.mock.method(fs, 'openSync', (file, ...args) => {
      if (file === destination) {
        fs.renameSync(file, join(output, 'verified-config'));
        execFileSync('mkfifo', [file], { timeout: 5000 });
      }
      return originalOpen(file, ...args);
    });
    await assert.rejects(
      buildPublicPages(configuration(output)),
      /output file changed while opening|ENXIO/,
    );
    assert.equal((await stat(destination)).isFIFO(), true);
  } finally {
    context.mock.restoreAll();
    await rm(output, { recursive: true, force: true });
  }
});

test('public publishing isolates read-only generation from privileged deployment', async () => {
  for (const name of ['publish-verified-public-pages', 'deploy-privacy-policy']) {
    const text = await readFile(resolve(`.github/workflows/${name}.yml`), 'utf8');
    const document = parseDocument(text, { uniqueKeys: true });
    assert.deepEqual(document.errors, []);
    const workflow = document.toJS();
    const { build, deploy } = workflow.jobs;
    assert.deepEqual(workflow.permissions, {});
    assert.deepEqual(workflow.on, { repository_dispatch: { types: [name] } });
    assert.equal(build.if, "${{ github.ref == 'refs/heads/main' }}");
    assert.equal(build['runs-on'], 'ubuntu-24.04');
    assert.deepEqual(build.permissions, { contents: 'read', pages: 'read' });
    assert.doesNotMatch(JSON.stringify(build), /secrets\.|id-token|continue-on-error/);
    const checkout = build.steps.find((step) => step.uses?.startsWith('actions/checkout@'));
    assert.deepEqual(checkout.with, {
      ref: '${{ github.sha }}', 'persist-credentials': false,
    });
    const pages = build.steps.find((step) => step.uses?.startsWith('actions/configure-pages@'));
    assert.deepEqual(pages.with, { enablement: false });
    for (const step of build.steps.filter((step) => step.uses)) {
      assert.match(step.uses, /@[0-9a-f]{40}$/);
    }
    assert.equal(deploy.needs, 'build');
    assert.equal(deploy.if, "${{ github.ref == 'refs/heads/main' }}");
    assert.deepEqual(deploy.permissions, { pages: 'write', 'id-token': 'write' });
    assert.doesNotMatch(JSON.stringify(deploy), /checkout@|build_public_pages/);
  }
  const document = parseDocument(
    await readFile(resolve('.github/workflows/ci-infra.yml'), 'utf8'),
    { uniqueKeys: true },
  );
  assert.deepEqual(document.errors, []);
  const infra = document.toJS().jobs['bicep-build'];
  assert.equal(infra['runs-on'], 'ubuntu-24.04');
  assert.deepEqual(infra.permissions, { contents: 'read', 'pull-requests': 'read' });
  assert.doesNotMatch(JSON.stringify(infra), /secrets\.|id-token|continue-on-error/);
  const checkout = infra.steps.find((step) => step.uses?.startsWith('actions/checkout@'));
  assert.equal(checkout.with['persist-credentials'], false);
  assert.equal(checkout.with.ref,
    "${{ github.event_name == 'pull_request_target' && github.event.pull_request.head.sha || github.sha }}");
  const install = infra.steps.findIndex((step) => step.run === 'npm ci --ignore-scripts');
  const run = infra.steps.findIndex((step) => (
    step.run === 'node --test tools/tests/build_public_pages.test.mjs'
  ));
  assert.ok(install >= 0 && run > install);
});
