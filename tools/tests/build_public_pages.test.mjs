import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import { chmod, link, mkdir, mkdtemp, readFile, readdir, rm, stat, symlink, writeFile } from 'node:fs/promises';
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
  } finally {
    await rm(output, { recursive: true, force: true });
  }
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
      'account-deletion', 'index.html', 'privacy-policy', 'staticwebapp.config.json',
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
    let writes = 0;
    context.mock.method(fs, 'writeFileSync', (descriptor, ...args) => {
      assert.equal(typeof descriptor, 'number');
      assert.equal(fs.fstatSync(descriptor).mode & 0o777, 0o600 & ~process.umask());
      writes += 1;
      return originalWrite(descriptor, ...args);
    });
    await buildPublicPages(configuration(output));
    assert.equal(writes, generatedFiles.length);
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
      process.umask(0o027);
      await buildPublicPages(config);
      const file = join(output, 'index.html');
      assert.equal((await fs.stat(file)).mode & 0o777, 0o640);
      await fs.chmod(file, 0o604);
      process.umask(0o077);
      await buildPublicPages(config);
      assert.equal((await fs.stat(file)).mode & 0o777, 0o604);
    `, join(output, 'different-umask')], { timeout: 15000, encoding: 'utf8' });
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
