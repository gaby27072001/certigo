import { pathToFileURL } from 'node:url';

export const phaseBTarget = Object.freeze({
  subscriptionId: 'f434ec55-f342-4948-9298-f99af5216204',
  tenantId: 'e9174162-1033-40c0-b0c9-f31825914fbe',
});

function normalize(value) {
  return String(value ?? '').toLowerCase();
}

export function validatePhaseBTarget(subscriptionId, tenantId) {
  if (
    normalize(subscriptionId) !== phaseBTarget.subscriptionId ||
    normalize(tenantId) !== phaseBTarget.tenantId
  ) {
    throw new Error(
      'Phase B target mismatch: stale professional or unapproved Azure bindings are not executable',
    );
  }
  return phaseBTarget;
}

function main() {
  const [subscriptionId, tenantId, ...extra] = process.argv.slice(2);
  if (!subscriptionId || !tenantId || extra.length !== 0) {
    throw new Error(
      'Usage: phase-b-target.mjs <subscription-id> <tenant-id>',
    );
  }
  validatePhaseBTarget(subscriptionId, tenantId);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main();
}
