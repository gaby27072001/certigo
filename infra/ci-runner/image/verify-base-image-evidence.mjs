import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const evidenceRoot = new URL('base-image-evidence/', import.meta.url);

export function reconstructBasePackages(inventory, log) {
  const observed = new Map();
  for (const line of inventory.trimEnd().split('\n')) {
    const [name, version, architecture, status, extra] = line.split('\t');
    assert.equal(extra, undefined, 'Unexpected inventory column.');
    assert.equal(status, 'installed', `Unsupported package state: ${name}.`);
    assert.match(name, /^[a-z0-9][a-z0-9+.-]*$/);
    assert.ok(version && !/\s/.test(version), `Missing package version: ${name}.`);
    assert.ok(['amd64', 'all'].includes(architecture), `Unexpected architecture: ${architecture}.`);
    const key = `${name}:${architecture}`;
    assert.ok(!observed.has(key), `Duplicate package: ${key}.`);
    observed.set(key, version);
  }
  const events = [];
  let previousTimestamp = '';
  for (const line of log.trimEnd().split('\n')) {
    const [date, time, action, name, before, after, extra] = line.split(/\s+/);
    const timestamp = `${date}T${time}Z`;
    assert.ok(Number.isFinite(Date.parse(timestamp)), 'Invalid dpkg timestamp.');
    assert.ok(timestamp >= previousTimestamp, 'Unordered dpkg history.');
    previousTimestamp = timestamp;
    if (action === 'install' || action === 'upgrade') {
      assert.equal(extra, undefined, 'Unexpected dpkg transaction field.');
      assert.ok(before && after && after !== '<none>', 'Incomplete dpkg transaction.');
      assert.match(name, /^[a-z0-9][a-z0-9+.-]*:(amd64|all)$/);
      assert.equal(before === '<none>', action === 'install', 'Unsupported dpkg transition.');
      events.push({ timestamp, action, name, before, after });
    } else {
      assert.ok(['status', 'startup', 'configure', 'trigproc'].includes(action),
        `Unsupported dpkg event: ${action}.`);
    }
  }
  assert.ok(events.length > 0, 'Missing dpkg transaction history.');
  const base = new Map(observed);
  for (const { action, name, before, after } of events.toReversed()) {
    assert.equal(base.get(name), after, `Discontinuous dpkg history: ${name}.`);
    if (action === 'install') base.delete(name);
    else base.set(name, before);
  }
  const replay = new Map(base);
  for (const { action, name, before, after } of events) {
    assert.equal(replay.get(name), action === 'install' ? undefined : before,
      `Cannot replay dpkg transaction: ${name}.`);
    replay.set(name, after);
  }
  assert.deepEqual(replay, observed, 'dpkg replay does not match the observed inventory.');
  return { base, observed, events };
}

export function verifyBaseImageEvidence() {
  const evidence = JSON.parse(readFileSync(new URL('base-image-reconstruction.json', evidenceRoot), 'utf8'));
  assert.equal(evidence.status, 'reconstructed-not-independent');
  assert.equal(evidence.baseImageUrn, 'Canonical:ubuntu-24_04-lts:server:24.04.202608070');
  const readEvidence = (name) => {
    const bytes = readFileSync(new URL(name, evidenceRoot));
    assert.equal(createHash('sha256').update(bytes).digest('hex'), evidence.sourceSha256[name], name);
    return bytes.toString('utf8');
  };
  const { base, observed, events } = reconstructBasePackages(
    readEvidence('2026-09-23-pr31-packages.tsv'),
    readEvidence('2026-09-23-pr31-dpkg.txt'),
  );
  readEvidence('2026-09-23-pr31-apt-history.txt');
  assert.equal(readEvidence('2026-09-23-pr31-build.info'), 'build_name: server\nserial: 20260807\n');
  assert.equal(observed.size, evidence.observedPackageCount);
  assert.equal(base.size, evidence.reconstructedBasePackageCount);
  assert.equal(events.length, evidence.versionTransactionCount);
  const serialized = [...base].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)
    .map(([key, version]) => `${key}\t${version}\n`).join('');
  assert.equal(createHash('sha256').update(serialized).digest('hex'), evidence.reconstructedBaseSha256);
  assert.equal(evidence.snapshot, 'https://snapshot.ubuntu.com/ubuntu/20260807T000000Z/');
  assert.equal(evidence.packages.length, base.size);
  const covered = new Set();
  for (const artifact of evidence.packages) {
    assert.ok(!covered.has(artifact.package), `Duplicate snapshot package: ${artifact.package}.`);
    covered.add(artifact.package);
    assert.equal(base.get(artifact.package), artifact.version, artifact.package);
    assert.match(artifact.sha256, /^[a-f0-9]{64}$/);
    assert.ok(artifact.url.startsWith(`${evidence.snapshot}pool/`));
    assert.ok(artifact.url.endsWith('.deb'));
    assert.ok(['noble', 'noble-updates', 'noble-security'].includes(artifact.suite));
    assert.ok(['main', 'restricted', 'universe', 'multiverse'].includes(artifact.component));
  }
  return evidence;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const evidence = verifyBaseImageEvidence();
    console.log(JSON.stringify({
      status: evidence.status,
      observedPackages: evidence.observedPackageCount,
      reconstructedPackages: evidence.reconstructedBasePackageCount,
      snapshotMatches: evidence.packages.length,
    }));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
