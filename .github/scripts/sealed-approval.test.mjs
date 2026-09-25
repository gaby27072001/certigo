import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  allowedSignersPath,
  approvalNamespace,
  approvalsDirectory,
  extractApproval,
  formatApprovalMessage,
  parseAllowedSigners,
  parseApprovalFile,
  signedData,
  sshFingerprint,
  sshString,
  validateSealedApprovals,
  verifySshSignature,
} from './sealed-approval.mjs';

// Ces tests tournent sur l'arbre de `main` à chaque PR : ils n'utilisent ni la clé enrôlée sur
// `main`, ni la date du jour. Les vecteurs de fixtures/sealed-approval/ ont été produits par le vrai
// `ssh-keygen -Y sign` (OpenSSH 10.2) avec des clés jetables dont seule la partie publique est
// versionnée : ils prouvent que ce vérificateur lit exactement le format d'OpenSSH.
const fixtures = path.join(path.dirname(fileURLToPath(import.meta.url)), 'fixtures', 'sealed-approval');
const now = new Date('2026-09-25T09:00:00Z');
const other = crypto.createHash('sha256').update('other').digest('hex');

function wireKey(type, keyObject) {
  const jwk = keyObject.export({ format: 'jwk' });
  const raw = (value) => Buffer.from(value, 'base64url');
  if (type === 'ssh-ed25519') {
    return Buffer.concat([sshString(type), sshString(raw(jwk.x))]);
  }
  return Buffer.concat([
    sshString(type),
    sshString('nistp256'),
    sshString(Buffer.concat([Buffer.from([4]), raw(jwk.x), raw(jwk.y)])),
  ]);
}

function mpint(bytes) {
  let start = 0;
  while (start < bytes.length - 1 && bytes[start] === 0) {
    start += 1;
  }
  const value = bytes.subarray(start);
  return sshString((value[0] & 0x80) !== 0 ? Buffer.concat([Buffer.from([0]), value]) : value);
}

function makeKey(type = 'ecdsa-sha2-nistp256') {
  const { publicKey, privateKey } = type === 'ssh-ed25519'
    ? crypto.generateKeyPairSync('ed25519')
    : crypto.generateKeyPairSync('ec', { namedCurve: 'P-256' });
  const blob = wireKey(type, publicKey);
  return { type, blob, privateKey, line: (principal) => `${principal} namespaces="${approvalNamespace}" ${type} ${blob.toString('base64')}` };
}

// Signataire de test : l'inverse exact du vérificateur, au format SSHSIG d'OpenSSH.
function sign(key, message, { namespace = approvalNamespace, hash = 'sha512' } = {}) {
  const data = signedData(namespace, hash, Buffer.from(message));
  let payload;
  if (key.type === 'ssh-ed25519') {
    payload = crypto.sign(null, data, key.privateKey);
  } else {
    const rs = crypto.sign('sha256', data, { key: key.privateKey, dsaEncoding: 'ieee-p1363' });
    payload = Buffer.concat([mpint(rs.subarray(0, 32)), mpint(rs.subarray(32))]);
  }
  const blob = Buffer.concat([
    Buffer.from('SSHSIG'),
    Buffer.from([0, 0, 0, 1]),
    sshString(key.blob),
    sshString(namespace),
    sshString(Buffer.alloc(0)),
    sshString(hash),
    sshString(Buffer.concat([sshString(key.type), sshString(payload)])),
  ]).toString('base64');
  return `-----BEGIN SSH SIGNATURE-----\n${blob.match(/.{1,70}/gu).join('\n')}\n-----END SSH SIGNATURE-----\n`;
}

function approval(key, changes, { expires = '2026-10-02', repository, namespace } = {}) {
  const message = formatApprovalMessage({ expires, changes, ...(repository ? { repository } : {}) });
  return `${message}${sign(key, message, { namespace })}`;
}

function digest(text) {
  return crypto.createHash('sha256').update(text).digest('hex');
}

function withTrees(callback) {
  const container = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-sealed-'));
  const base = path.join(container, 'base');
  const candidate = path.join(container, 'candidate');
  const write = (root, relativePath, content) => {
    const destination = path.join(root, ...relativePath.split('/'));
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.writeFileSync(destination, content);
  };
  try {
    callback({ base, candidate, write, container });
  } finally {
    fs.rmSync(container, { recursive: true, force: true });
  }
}

const sealed = '.github/workflows/release-android.yml';

function setup({ write, base, candidate }, key, { enrolled = true } = {}) {
  for (const root of [base, candidate]) {
    write(root, sealed, 'version: 1\n');
    write(root, 'docs/notes.md', 'notes\n');
    if (enrolled) {
      write(root, allowedSignersPath, `# Clé d'approbation\n${key.line('gabriel@certigo-approval')}\n`);
    }
  }
}

function judge({ base, candidate }, when = now) {
  return validateSealedApprovals(candidate, base, { protectedPaths: [sealed, allowedSignersPath], now: when });
}

test('verifies the real ssh-keygen vectors with the fingerprints ssh-keygen prints', () => {
  const { signers, errors } = parseAllowedSigners(fs.readFileSync(path.join(fixtures, 'allowed_signers'), 'utf8'));
  assert.deepEqual(errors, []);
  assert.deepEqual(signers.map((signer) => signer.fingerprint), [
    'SHA256:pX01febupCAoWi7BDGcFsuw0YigED+plKFTv0uBQ07I',
    'SHA256:o2Od5pl2WOXESJN542o1v8gOt2GY4j0fmcOawlubBXk',
  ]);
  for (const [type, principal] of [['ecdsa', 'fixture-ecdsa@certigo'], ['ed25519', 'fixture-ed25519@certigo']]) {
    const parsed = parseApprovalFile(fs.readFileSync(path.join(fixtures, `ssh-keygen-${type}.approval`), 'utf8'));
    const signer = verifySshSignature({ message: Buffer.from(parsed.message), armoredSignature: parsed.armoredSignature, signers });
    assert.equal(signer.principal, principal);
    assert.throws(
      () => verifySshSignature({ message: Buffer.from(`${parsed.message} `), armoredSignature: parsed.armoredSignature, signers }),
      /does not match this approval/,
    );
    assert.throws(
      () => verifySshSignature({ message: Buffer.from(parsed.message), armoredSignature: parsed.armoredSignature, signers: signers.filter((candidate) => candidate.principal !== principal) }),
      /not an enrolled approver/,
    );
  }
});

test('rejects signatures made for another namespace, altered, or by an unenrolled key', () => {
  const key = makeKey();
  const stranger = makeKey();
  const message = formatApprovalMessage({ expires: '2026-10-02', changes: [{ path: sealed, from: other, to: digest('x') }] });
  const { signers } = parseAllowedSigners(`${key.line('gabriel@certigo-approval')}\n`);
  assert.equal(verifySshSignature({ message: Buffer.from(message), armoredSignature: sign(key, message), signers }).principal, 'gabriel@certigo-approval');
  assert.throws(() => verifySshSignature({ message: Buffer.from(message), armoredSignature: sign(key, message, { namespace: 'git' }), signers }), /namespace git/);
  assert.throws(() => verifySshSignature({ message: Buffer.from(message), armoredSignature: sign(stranger, message), signers }), /not an enrolled approver/);
  const flipped = sign(key, message).replace(/^([A-Za-z0-9+/]{20})[A-Za-z0-9+/]/mu, (all, head) => `${head}${all.at(-1) === 'A' ? 'B' : 'A'}`);
  assert.throws(() => verifySshSignature({ message: Buffer.from(message), armoredSignature: flipped, signers }));
  const ed = makeKey('ssh-ed25519');
  const edSigners = parseAllowedSigners(`${ed.line('gabriel@certigo-approval')}\n`).signers;
  assert.equal(verifySshSignature({ message: Buffer.from(message), armoredSignature: sign(ed, message, { hash: 'sha256' }), signers: edSigners }).fingerprint, sshFingerprint(ed.blob));
});

test('reads only the strict allowed_signers subset', () => {
  const key = makeKey();
  const encoded = key.blob.toString('base64');
  for (const [text, expected] of [
    [`${key.line('a@b')}\r\n`, /carriage returns/],
    [`a@b ecdsa-sha2-nistp256 ${encoded}\n`, /expected <principal> namespaces=/],
    [`a@b namespaces="git" ecdsa-sha2-nistp256 ${encoded}\n`, /restricted to namespace/],
    [`a@b cert-authority,namespaces="${approvalNamespace}" ecdsa-sha2-nistp256 ${encoded}\n`, /expected <principal>/],
    [`a@b namespaces="${approvalNamespace}" ssh-ed25519 ${encoded}\n`, /does not match the key/],
    [`a@b namespaces="${approvalNamespace}" ecdsa-sha2-nistp256 ${encoded.slice(1)}\n`, /base64|truncated|curve|point/],
    [`${key.line('a@b')}\n${key.line('c@d')}\n`, /duplicate key/],
    [`a b namespaces="${approvalNamespace}" ecdsa-sha2-nistp256 ${encoded}\n`, /expected <principal>/],
  ]) {
    const { errors } = parseAllowedSigners(text);
    assert.ok(errors.some((error) => expected.test(error)), `${text}: ${errors.join(' | ')}`);
  }
  assert.deepEqual(parseAllowedSigners(`# commentaire\n\n${key.line('a@b')} Mac de Gabriel\n`).errors, []);
});

test('reads only canonical approval messages', () => {
  const key = makeKey();
  const good = { path: sealed, from: other, to: digest('x') };
  assert.equal(parseApprovalFile(approval(key, [good])).changes.length, 1);
  const signature = sign(key, 'x\n');
  for (const [message, expected] of [
    ['certigo-sealed-approval-v2\nrepository gchambaud_microsoft/Certigo\nexpires 2026-10-02\nchange a b c\n', /must start with/],
    [`certigo-sealed-approval-v1\nrepository gchambaud_microsoft/Certigo\nexpires 2026-02-30\nchange ${sealed} ${other} absent\n`, /expires YYYY-MM-DD/],
    ['certigo-sealed-approval-v1\nrepository gchambaud_microsoft/Certigo\nexpires 2026-10-02\n', /at least one change/],
    [`certigo-sealed-approval-v1\nrepository gchambaud_microsoft/Certigo\nexpires 2026-10-02\nchange ../x ${other} absent\n`, /invalid change line/],
    [`certigo-sealed-approval-v1\nrepository gchambaud_microsoft/Certigo\nexpires 2026-10-02\nchange a/b absent absent\n`, /invalid change line/],
    [`certigo-sealed-approval-v1\nrepository gchambaud_microsoft/Certigo\nexpires 2026-10-02\nchange b ${other} absent\nchange a ${other} absent\n`, /sorted by path and unique/],
    [`certigo-sealed-approval-v1\nrepository gchambaud_microsoft/Certigo\nexpires 2026-10-02\nchange a ${other} absent\nchange a ${other} absent\n`, /sorted by path and unique/],
    [`certigo-sealed-approval-v1\nrepository gchambaud_microsoft/Certigo\nexpires 2026-10-02\nchange a%20b ${other} absent\n`, /invalid change line/],
  ]) {
    assert.throws(() => parseApprovalFile(`${message}${signature}`), expected, message);
  }
  assert.throws(() => parseApprovalFile(approval(key, [good]).replace(/\n/gu, '\r\n')), /carriage returns/);
  assert.throws(() => parseApprovalFile(`${approval(key, [good])}trailing\n`), /must end with the SSH signature block/);
  assert.throws(() => parseApprovalFile(`${approval(key, [good])}${signature}`), /exactly one SSH signature block/);
});

test('extracts a pasted approval from a pull request comment', () => {
  const key = makeKey();
  const text = approval(key, [{ path: sealed, from: other, to: digest('x') }]);
  const comment = `Approuvé depuis mon Mac :\r\n\r\n\`\`\`\r\n${text.replace(/\n/gu, '\r\n')}\`\`\`\r\n`;
  assert.equal(extractApproval(comment), text);
  assert.throws(() => extractApproval('rien ici'), /no certigo-sealed-approval-v1 block/);
});

test('a pull request that changes no sealed file never depends on approvals or on the date', () => {
  withTrees((trees) => {
    const key = makeKey();
    setup(trees, key);
    trees.write(trees.candidate, 'docs/notes.md', 'changed\n');
    for (const days of [0, 400, 4000]) {
      assert.deepEqual(judge(trees, new Date(now.getTime() + days * 86400000)).errors, []);
    }
  });
});

test('a sealed change needs a new approval signed by the key enrolled on main', () => {
  withTrees((trees) => {
    const key = makeKey();
    setup(trees, key);
    trees.write(trees.candidate, sealed, 'version: 2\n');
    const change = { path: sealed, from: digest('version: 1\n'), to: digest('version: 2\n') };
    assert.match(judge(trees).errors.join('\n'), /sealed file changed without a signed approval/);

    trees.write(trees.candidate, `${approvalsDirectory}/pr-1.approval`, approval(key, [change]));
    const accepted = judge(trees);
    assert.deepEqual(accepted.errors, []);
    assert.deepEqual(accepted.approved.map((entry) => entry.path), [sealed]);
    assert.equal(accepted.approved[0].principal, 'gabriel@certigo-approval');
  });
});

test('an approval only authorises its exact bytes, once, before it expires', () => {
  withTrees((trees) => {
    const key = makeKey();
    setup(trees, key);
    const change = { path: sealed, from: digest('version: 1\n'), to: digest('version: 2\n') };
    trees.write(trees.candidate, `${approvalsDirectory}/pr-1.approval`, approval(key, [change]));

    trees.write(trees.candidate, sealed, 'version: 3\n');
    assert.match(judge(trees).errors.join('\n'), /approves .* but this pull request moves it/);

    trees.write(trees.candidate, sealed, 'version: 2\n');
    assert.deepEqual(judge(trees).errors, []);
    assert.match(judge(trees, new Date('2026-10-03T00:00:00Z')).errors.join('\n'), /expires on 2026-10-02/);

    // Déjà sur main, la même approbation n'est plus qu'un journal : elle ne vaut plus rien.
    trees.write(trees.base, `${approvalsDirectory}/pr-1.approval`, approval(key, [change]));
    assert.match(judge(trees).errors.join('\n'), /sealed file changed without a signed approval/);

    // Recopiée sous un autre nom après sa fusion, elle ne correspond plus aux octets de main.
    trees.write(trees.base, sealed, 'version: 2\n');
    trees.write(trees.candidate, sealed, 'version: 1\n');
    trees.write(trees.candidate, `${approvalsDirectory}/replay.approval`, approval(key, [change]));
    assert.match(judge(trees).errors.join('\n'), /approves .* but this pull request moves it/);
  });
});

test('refuses approvals that expire too late, name another repository, or come from an unenrolled key', () => {
  withTrees((trees) => {
    const key = makeKey();
    setup(trees, key);
    trees.write(trees.candidate, sealed, 'version: 2\n');
    const change = { path: sealed, from: digest('version: 1\n'), to: digest('version: 2\n') };
    const file = `${approvalsDirectory}/pr-1.approval`;
    for (const [text, expected] of [
      [approval(key, [change], { expires: '2026-10-26' }), /must expire between 2026-09-25 and 2026-10-25/],
      [approval(key, [change], { expires: '2026-09-24' }), /must expire between/],
      [approval(key, [change], { repository: 'someone/else' }), /approves repository someone\/else/],
      [approval(makeKey(), [change]), /not an enrolled approver/],
    ]) {
      trees.write(trees.candidate, file, text);
      assert.match(judge(trees).errors.join('\n'), expected);
    }
  });
});

test('a pull request cannot enrol its own key to sign its own change', () => {
  withTrees((trees) => {
    const key = makeKey();
    const intruder = makeKey();
    setup(trees, key);
    trees.write(trees.candidate, allowedSignersPath, `${intruder.line('intruder@nowhere')}\n`);
    trees.write(trees.candidate, sealed, 'version: 2\n');
    const changes = [
      { path: allowedSignersPath, from: digest(`# Clé d'approbation\n${key.line('gabriel@certigo-approval')}\n`), to: digest(`${intruder.line('intruder@nowhere')}\n`) },
      { path: sealed, from: digest('version: 1\n'), to: digest('version: 2\n') },
    ];
    trees.write(trees.candidate, `${approvalsDirectory}/pr-1.approval`, approval(intruder, changes));
    assert.match(judge(trees).errors.join('\n'), /not an enrolled approver/);

    // Remplacer la clé reste possible, signé par la clé en place.
    trees.write(trees.candidate, `${approvalsDirectory}/pr-1.approval`, approval(key, changes));
    assert.deepEqual(judge(trees).errors, []);
  });
});

test('nothing can be approved before a key is enrolled on main', () => {
  withTrees((trees) => {
    const key = makeKey();
    setup(trees, key, { enrolled: false });
    trees.write(trees.candidate, allowedSignersPath, `${key.line('gabriel@certigo-approval')}\n`);
    trees.write(trees.candidate, sealed, 'version: 2\n');
    trees.write(trees.candidate, `${approvalsDirectory}/pr-1.approval`, approval(key, [{ path: sealed, from: digest('version: 1\n'), to: digest('version: 2\n') }]));
    assert.match(judge(trees).errors.join('\n'), /allowed_signers is missing on main/);
  });
});

test('every approved protected path must be changed exactly as approved, and each only once', () => {
  withTrees((trees) => {
    const key = makeKey();
    setup(trees, key);
    const change = { path: sealed, from: digest('version: 1\n'), to: digest('version: 2\n') };
    trees.write(trees.candidate, `${approvalsDirectory}/pr-1.approval`, approval(key, [change]));
    assert.match(judge(trees).errors.join('\n'), /approves a change that this pull request does not make/);

    trees.write(trees.candidate, sealed, 'version: 2\n');
    trees.write(trees.candidate, `${approvalsDirectory}/pr-2.approval`, approval(key, [change]));
    assert.match(judge(trees).errors.join('\n'), /approves .* a second time/);

    // Les chemins non protégés qu'une approbation cite sont seulement informatifs.
    fs.rmSync(path.join(trees.candidate, ...`${approvalsDirectory}/pr-2.approval`.split('/')));
    trees.write(trees.candidate, `${approvalsDirectory}/pr-1.approval`, approval(key, [
      { path: 'docs/notes.md', from: digest('notes\n'), to: digest('anything\n') },
      change,
    ]));
    assert.deepEqual(judge(trees).errors, []);
  });
});

test('the approvals directory holds only regular approval files', (context) => {
  withTrees((trees) => {
    const key = makeKey();
    setup(trees, key);
    trees.write(trees.candidate, `${approvalsDirectory}/README.md`, 'x\n');
    assert.match(judge(trees).errors.join('\n'), /only \*\.approval files belong here/);
    fs.rmSync(path.join(trees.candidate, ...`${approvalsDirectory}/README.md`.split('/')));

    const target = path.join(trees.container, 'elsewhere.yml');
    fs.writeFileSync(target, 'version: 2\n');
    const link = path.join(trees.candidate, ...sealed.split('/'));
    fs.rmSync(link);
    try {
      fs.symlinkSync(target, link, 'file');
    } catch (error) {
      if (error.code === 'EPERM') {
        context.skip('file symlinks require Windows developer mode');
        return;
      }
      throw error;
    }
    assert.match(judge(trees).errors.join('\n'), /must be a real regular non-symlink file/);
  });
});
