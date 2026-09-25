import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { readRegularRepositoryFile } from './workflow-semantic-fingerprint.mjs';

// Approbation « scellée » : Gabriel signe, avec une clé qui ne quitte pas son Mac (Secretive,
// Touch ID) ou une YubiKey, le passage exact d'un fichier protégé de ses octets actuels sur `main`
// à ses nouveaux octets. Les agents utilisent le compte GitHub de Gabriel : aucune approbation
// GitHub native ne distingue un agent de lui ; une signature SSH, si. Ce module ne fait
// qu'authentifier et apparier ces signatures : il ne décide pas quels fichiers sont protégés.
export const approvalNamespace = 'certigo-sealed-approval-v1';
export const approvalHeader = 'certigo-sealed-approval-v1';
export const approvalRepository = 'gchambaud_microsoft/Certigo';
export const allowedSignersPath = '.github/sealed-approvers/allowed_signers';
export const approvalsDirectory = '.github/sealed-approvals';
export const approvalSuffix = '.approval';
export const maxApprovalDays = 30;

const signatureBegin = '-----BEGIN SSH SIGNATURE-----';
const signatureEnd = '-----END SSH SIGNATURE-----';
const digestPattern = /^[0-9a-f]{64}$/;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const pathPattern = /^[A-Za-z0-9._@+-]+(?:\/[A-Za-z0-9._@+-]+)*$/;
const principalPattern = /^[A-Za-z0-9._@+-]+$/;
const base64Pattern = /^[A-Za-z0-9+/]+={0,2}$/;
const dayMilliseconds = 24 * 60 * 60 * 1000;
const hashAlgorithms = new Set(['sha256', 'sha512']);
const keyTypes = new Map([
  ['ecdsa-sha2-nistp256', { curve: 'P-256', sshCurve: 'nistp256', digest: 'sha256', size: 32 }],
  ['ecdsa-sha2-nistp384', { curve: 'P-384', sshCurve: 'nistp384', digest: 'sha384', size: 48 }],
  ['ssh-ed25519', { ed25519: true }],
]);

class WireReader {
  constructor(buffer, label) {
    this.buffer = buffer;
    this.offset = 0;
    this.label = label;
  }

  bytes(length) {
    if (!Number.isSafeInteger(length) || length < 0 || this.offset + length > this.buffer.length) {
      throw new Error(`${this.label}: truncated encoding`);
    }
    const value = this.buffer.subarray(this.offset, this.offset + length);
    this.offset += length;
    return value;
  }

  uint32() {
    return this.bytes(4).readUInt32BE(0);
  }

  string() {
    return this.bytes(this.uint32());
  }

  ascii() {
    const value = this.string();
    if (!/^[\x21-\x7e]*$/u.test(value.toString('latin1'))) {
      throw new Error(`${this.label}: non-printable identifier`);
    }
    return value.toString('latin1');
  }

  end() {
    if (this.offset !== this.buffer.length) {
      throw new Error(`${this.label}: unexpected trailing data`);
    }
  }
}

export function sshString(value) {
  const buffer = Buffer.isBuffer(value) ? value : Buffer.from(value, 'utf8');
  const length = Buffer.alloc(4);
  length.writeUInt32BE(buffer.length, 0);
  return Buffer.concat([length, buffer]);
}

function base64Url(buffer) {
  return buffer.toString('base64').replace(/\+/gu, '-').replace(/\//gu, '_').replace(/=+$/u, '');
}

function decodeBase64(text, label) {
  if (!base64Pattern.test(text) || text.length % 4 !== 0) {
    throw new Error(`${label}: invalid base64`);
  }
  const buffer = Buffer.from(text, 'base64');
  if (buffer.toString('base64') !== text) {
    throw new Error(`${label}: non-canonical base64`);
  }
  return buffer;
}

export function sshFingerprint(publicKeyBlob) {
  const digest = crypto.createHash('sha256').update(publicKeyBlob).digest('base64');
  return `SHA256:${digest.replace(/=+$/u, '')}`;
}

export function parsePublicKeyBlob(blob) {
  const reader = new WireReader(blob, 'public key');
  const type = reader.ascii();
  const spec = keyTypes.get(type);
  if (!spec) {
    throw new Error(
      `public key: unsupported key type ${type}; enroll an ecdsa-sha2-nistp256 key `
      + '(Secretive, Secure Enclave), an ecdsa-sha2-nistp384 key or an ssh-ed25519 key',
    );
  }
  if (spec.ed25519) {
    const raw = reader.string();
    reader.end();
    if (raw.length !== 32) {
      throw new Error('public key: ed25519 keys are 32 bytes');
    }
    return {
      type,
      key: crypto.createPublicKey({
        key: { kty: 'OKP', crv: 'Ed25519', x: base64Url(raw) },
        format: 'jwk',
      }),
    };
  }
  if (reader.ascii() !== spec.sshCurve) {
    throw new Error(`public key: curve does not match ${type}`);
  }
  const point = reader.string();
  reader.end();
  if (point.length !== 1 + 2 * spec.size || point[0] !== 0x04) {
    throw new Error('public key: expected an uncompressed elliptic-curve point');
  }
  return {
    type,
    key: crypto.createPublicKey({
      key: {
        kty: 'EC',
        crv: spec.curve,
        x: base64Url(point.subarray(1, 1 + spec.size)),
        y: base64Url(point.subarray(1 + spec.size)),
      },
      format: 'jwk',
    }),
  };
}

// Sous-ensemble strict du format allowed_signers d'OpenSSH : une ligne par clé,
// `<principal> namespaces="certigo-sealed-approval-v1" <type> <clé> [commentaire]`. Le fichier
// reste lisible par `ssh-keygen -Y verify`, que l'outil du Mac utilise aussi.
export function parseAllowedSigners(text) {
  const signers = [];
  const errors = [];
  if (text.includes('\r')) {
    return { signers, errors: ['allowed_signers: carriage returns are forbidden'] };
  }
  text.split('\n').forEach((line, index) => {
    if (line.trim() === '' || line.startsWith('#')) {
      return;
    }
    const match = /^(\S+) namespaces="([^"]*)" (\S+) (\S+)(?: [^\n]*)?$/u.exec(line);
    const label = `allowed_signers:${index + 1}`;
    if (!match) {
      errors.push(`${label}: expected <principal> namespaces="${approvalNamespace}" <type> <key>`);
      return;
    }
    const [, principal, namespaces, type, encoded] = match;
    if (!principalPattern.test(principal)) {
      errors.push(`${label}: invalid principal`);
      return;
    }
    if (namespaces !== approvalNamespace) {
      errors.push(`${label}: the key must be restricted to namespace ${approvalNamespace}`);
      return;
    }
    try {
      const blob = decodeBase64(encoded, label);
      const parsed = parsePublicKeyBlob(blob);
      if (parsed.type !== type) {
        throw new Error(`${label}: key type ${type} does not match the key`);
      }
      if (signers.some((signer) => signer.blob.equals(blob))) {
        throw new Error(`${label}: duplicate key`);
      }
      signers.push({ principal, type, blob, key: parsed.key, fingerprint: sshFingerprint(blob) });
    } catch (error) {
      errors.push(error.message.startsWith(label) ? error.message : `${label}: ${error.message}`);
    }
  });
  return { signers, errors };
}

export function parseArmoredSignature(text) {
  const lines = text.split('\n');
  if (lines.at(-1) === '') {
    lines.pop();
  }
  if (lines.length < 3 || lines[0] !== signatureBegin || lines.at(-1) !== signatureEnd) {
    throw new Error('SSH signature: expected an armored -----BEGIN SSH SIGNATURE----- block');
  }
  const body = lines.slice(1, -1);
  if (body.some((line) => line.length === 0 || line.length > 76)) {
    throw new Error('SSH signature: malformed armor lines');
  }
  const reader = new WireReader(decodeBase64(body.join(''), 'SSH signature'), 'SSH signature');
  if (reader.bytes(6).toString('latin1') !== 'SSHSIG' || reader.uint32() !== 1) {
    throw new Error('SSH signature: expected an SSHSIG version 1 blob');
  }
  const signature = {
    publicKey: Buffer.from(reader.string()),
    namespace: reader.ascii(),
    reserved: Buffer.from(reader.string()),
    hashAlgorithm: reader.ascii(),
    signature: Buffer.from(reader.string()),
  };
  reader.end();
  return signature;
}

export function signedData(namespace, hashAlgorithm, message) {
  return Buffer.concat([
    Buffer.from('SSHSIG', 'latin1'),
    sshString(namespace),
    sshString(Buffer.alloc(0)),
    sshString(hashAlgorithm),
    sshString(crypto.createHash(hashAlgorithm).update(message).digest()),
  ]);
}

function unsignedInteger(mpint, size) {
  if (mpint.length > 0 && (mpint[0] & 0x80) !== 0) {
    throw new Error('SSH signature: negative ECDSA component');
  }
  let start = 0;
  while (start < mpint.length && mpint[start] === 0) {
    start += 1;
  }
  const value = mpint.subarray(start);
  if (value.length === 0 || value.length > size) {
    throw new Error('SSH signature: ECDSA component out of range');
  }
  return Buffer.concat([Buffer.alloc(size - value.length), value]);
}

function verifyKeySignature(type, key, data, signatureBlob) {
  const reader = new WireReader(signatureBlob, 'SSH signature');
  const algorithm = reader.ascii();
  const payload = reader.string();
  reader.end();
  if (algorithm !== type) {
    throw new Error(`SSH signature: algorithm ${algorithm} does not match key type ${type}`);
  }
  const spec = keyTypes.get(type);
  if (spec.ed25519) {
    return payload.length === 64 && crypto.verify(null, data, key, payload);
  }
  const components = new WireReader(payload, 'SSH signature');
  const r = unsignedInteger(components.string(), spec.size);
  const s = unsignedInteger(components.string(), spec.size);
  components.end();
  return crypto.verify(
    spec.digest,
    data,
    { key, dsaEncoding: 'ieee-p1363' },
    Buffer.concat([r, s]),
  );
}

// Vérifie une signature `ssh-keygen -Y sign -n certigo-sealed-approval-v1` sur `message` avec
// les seules clés de `signers`. Rend le signataire, ou lève une erreur qui dit pourquoi.
export function verifySshSignature({ message, armoredSignature, signers }) {
  const parsed = parseArmoredSignature(armoredSignature);
  if (parsed.namespace !== approvalNamespace) {
    throw new Error(`SSH signature: namespace ${parsed.namespace} is not ${approvalNamespace}`);
  }
  if (parsed.reserved.length !== 0) {
    throw new Error('SSH signature: the reserved field must be empty');
  }
  if (!hashAlgorithms.has(parsed.hashAlgorithm)) {
    throw new Error(`SSH signature: unsupported hash algorithm ${parsed.hashAlgorithm}`);
  }
  const signer = signers.find((candidate) => candidate.blob.equals(parsed.publicKey));
  if (!signer) {
    throw new Error(
      `SSH signature: made with key ${sshFingerprint(parsed.publicKey)}, which is not an enrolled `
      + `approver in ${allowedSignersPath}`,
    );
  }
  const data = signedData(parsed.namespace, parsed.hashAlgorithm, message);
  if (!verifyKeySignature(signer.type, signer.key, data, parsed.signature)) {
    throw new Error('SSH signature: the signature does not match this approval');
  }
  return { principal: signer.principal, fingerprint: signer.fingerprint };
}

export function isCalendarDate(value) {
  return typeof value === 'string'
    && datePattern.test(value)
    && new Date(`${value}T00:00:00Z`).toISOString().slice(0, 10) === value;
}

function utcDate(now) {
  return now.toISOString().slice(0, 10);
}

function addUtcDays(now, days) {
  return utcDate(new Date(Date.parse(`${utcDate(now)}T00:00:00Z`) + days * dayMilliseconds));
}

export function isApprovalPath(value) {
  return typeof value === 'string'
    && pathPattern.test(value)
    && !value.split('/').some((segment) => segment === '.' || segment === '..');
}

function compareCodeUnits(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

export function formatApprovalMessage({ repository = approvalRepository, expires, changes }) {
  const sorted = [...changes].sort((left, right) => compareCodeUnits(left.path, right.path));
  return [
    approvalHeader,
    `repository ${repository}`,
    `expires ${expires}`,
    ...sorted.map((change) => `change ${change.path} ${change.from} ${change.to}`),
    '',
  ].join('\n');
}

function parseApprovalMessage(message) {
  const lines = message.split('\n');
  if (lines.pop() !== '') {
    throw new Error('approval message must end with a newline');
  }
  if (lines[0] !== approvalHeader) {
    throw new Error(`approval message must start with ${approvalHeader}`);
  }
  const repository = /^repository (\S+)$/u.exec(lines[1] ?? '')?.[1];
  const expires = /^expires (\S+)$/u.exec(lines[2] ?? '')?.[1];
  if (repository === undefined || expires === undefined || !isCalendarDate(expires)) {
    throw new Error('approval message must declare `repository <owner/name>` then `expires YYYY-MM-DD`');
  }
  const changes = lines.slice(3).map((line) => {
    const match = /^change (\S+) (\S+) (\S+)$/u.exec(line);
    const valid = (value) => value === 'absent' || digestPattern.test(value);
    if (
      !match
      || !isApprovalPath(match[1])
      || !valid(match[2])
      || !valid(match[3])
      || match[2] === match[3]
    ) {
      throw new Error(`approval message: invalid change line ${JSON.stringify(line)}`);
    }
    return { path: match[1], from: match[2], to: match[3] };
  });
  if (changes.length === 0) {
    throw new Error('approval message must list at least one change');
  }
  for (let index = 1; index < changes.length; index += 1) {
    if (compareCodeUnits(changes[index - 1].path, changes[index].path) >= 0) {
      throw new Error('approval message: change lines must be sorted by path and unique');
    }
  }
  return { repository, expires, changes };
}

// Un fichier d'approbation = le message signé, puis le bloc de signature armé, en LF seulement.
export function parseApprovalFile(text) {
  if (text.includes('\r')) {
    throw new Error('approval file: carriage returns are forbidden');
  }
  const marker = `\n${signatureBegin}\n`;
  const index = text.indexOf(marker);
  if (index < 0 || text.indexOf(marker, index + 1) >= 0) {
    throw new Error('approval file: expected exactly one SSH signature block after the message');
  }
  const message = text.slice(0, index + 1);
  const armoredSignature = text.slice(index + 1);
  if (!armoredSignature.endsWith(`${signatureEnd}\n`)) {
    throw new Error('approval file: must end with the SSH signature block and a single newline');
  }
  return { message, armoredSignature, ...parseApprovalMessage(message) };
}

// Extrait un fichier d'approbation du texte collé par Gabriel (commentaire de PR, bloc de code,
// fins de ligne CRLF) : tout ce qui va de l'en-tête à la fin du bloc de signature.
export function extractApproval(text) {
  const normalized = text.replace(/\r\n?/gu, '\n');
  const start = normalized.indexOf(`${approvalHeader}\n`);
  const end = normalized.indexOf(signatureEnd, start);
  if (start < 0 || end < 0) {
    throw new Error('no certigo-sealed-approval-v1 block found');
  }
  const block = `${normalized.slice(start, end + signatureEnd.length)}\n`;
  parseApprovalFile(block);
  return block;
}

function sha256(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

function fileState(root, relativePath, label, errors) {
  const file = readRegularRepositoryFile(root, relativePath);
  if (file.error) {
    errors.push(`${label}: ${file.error}`);
    return null;
  }
  return file.exists ? sha256(file.bytes) : 'absent';
}

// Liste les approbations d'un arbre. Le répertoire ne contient que des fichiers réguliers
// `*.approval` : c'est un journal d'audit, jamais une configuration.
export function listApprovalFiles(root) {
  const directory = path.join(root, ...approvalsDirectory.split('/'));
  let stat;
  try {
    stat = fs.lstatSync(directory);
  } catch (error) {
    return error.code === 'ENOENT'
      ? { files: [], errors: [] }
      : { files: [], errors: [`${approvalsDirectory}: ${error.message}`] };
  }
  if (!stat.isDirectory() || stat.isSymbolicLink() || fs.realpathSync(directory) !== path.resolve(directory)) {
    return { files: [], errors: [`${approvalsDirectory} must be a real non-symlink directory`] };
  }
  const files = [];
  const errors = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const relativePath = `${approvalsDirectory}/${entry.name}`;
    if (!entry.name.endsWith(approvalSuffix)) {
      errors.push(`${relativePath}: only *${approvalSuffix} files belong here`);
      continue;
    }
    const file = readRegularRepositoryFile(root, relativePath);
    if (file.error) {
      errors.push(file.error);
    } else {
      files.push({ name: entry.name, relativePath, content: file.content });
    }
  }
  files.sort((left, right) => compareCodeUnits(left.name, right.name));
  return { files, errors };
}

// Juge, avec la clé enrôlée dans la BASE, les changements d'une PR sur `protectedPaths`.
// Seules comptent les approbations que la PR ajoute : celles déjà sur `main` sont un journal.
// Une approbation lie chaque fichier à ses octets exacts sur la base et dans la PR ; elle ne vaut
// donc qu'une fois, et seulement jusqu'à son expiration. Les chemins non protégés qu'elle cite
// sont informatifs. Indépendant de l'heure dès que la PR n'apporte aucune approbation.
export function validateSealedApprovals(
  candidateRoot,
  trustedRoot,
  { protectedPaths, now = new Date() },
) {
  const errors = [];
  const changes = new Map();
  for (const relativePath of [...new Set(protectedPaths)].sort(compareCodeUnits)) {
    const from = fileState(trustedRoot, relativePath, 'trusted sealed file', errors);
    const to = fileState(candidateRoot, relativePath, 'candidate sealed file', errors);
    if (from !== null && to !== null && from !== to) {
      changes.set(relativePath, { from, to });
    }
  }

  const trustedApprovals = new Set(listApprovalFiles(trustedRoot).files.map((file) => file.name));
  const candidateApprovals = listApprovalFiles(candidateRoot);
  errors.push(...candidateApprovals.errors);
  const added = candidateApprovals.files.filter((file) => !trustedApprovals.has(file.name));

  const transitions = new Map();
  if (added.length > 0) {
    const signersFile = readRegularRepositoryFile(trustedRoot, allowedSignersPath);
    const enrolled = signersFile.exists && !signersFile.error
      ? parseAllowedSigners(signersFile.content)
      : { signers: [], errors: [signersFile.error ?? `${allowedSignersPath} is missing on main`] };
    errors.push(...enrolled.errors.map((error) => `trusted ${error}`));
    const today = utcDate(now);
    const latest = addUtcDays(now, maxApprovalDays);
    for (const file of added) {
      try {
        const approval = parseApprovalFile(file.content);
        if (approval.repository !== approvalRepository) {
          throw new Error(`approves repository ${approval.repository}, not ${approvalRepository}`);
        }
        if (approval.expires < today || approval.expires > latest) {
          throw new Error(
            `expires on ${approval.expires}; an approval must expire between ${today} and `
            + `${latest} (UTC): sign it again`,
          );
        }
        const signer = verifySshSignature({
          message: Buffer.from(approval.message, 'utf8'),
          armoredSignature: approval.armoredSignature,
          signers: enrolled.signers,
        });
        for (const change of approval.changes) {
          if (transitions.has(change.path)) {
            throw new Error(`approves ${change.path} a second time`);
          }
          transitions.set(change.path, { ...change, file: file.relativePath, signer });
        }
      } catch (error) {
        errors.push(`${file.relativePath}: ${error.message}`);
      }
    }
  }

  const approved = [];
  for (const [relativePath, change] of changes) {
    const transition = transitions.get(relativePath);
    if (!transition) {
      errors.push(
        `${relativePath}: sealed file changed without a signed approval from an enrolled approver `
        + '(see docs/runbooks/APPROBATION_SCELLEE.md)',
      );
    } else if (transition.from !== change.from || transition.to !== change.to) {
      errors.push(
        `${relativePath}: ${transition.file} approves ${transition.from} -> ${transition.to}, but `
        + `this pull request moves it from ${change.from} to ${change.to}: sign the exact change`,
      );
    } else {
      approved.push({ path: relativePath, ...change, principal: transition.signer.principal });
    }
  }
  const protectedSet = new Set(protectedPaths);
  for (const [relativePath, transition] of transitions) {
    if (protectedSet.has(relativePath) && !changes.has(relativePath)) {
      errors.push(
        `${relativePath}: ${transition.file} approves a change that this pull request does not make`,
      );
    }
  }
  return { errors, approved };
}
