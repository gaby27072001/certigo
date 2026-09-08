import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import { validatePhaseAProof } from './validate-what-if.mjs';

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function compiledAssignmentKey(description) {
  if (
    typeof description === 'string' &&
    description.includes('Launches the {0} subscription deployment')
  ) {
    return 'subscription-launcher';
  }
  if (description === "[parameters('assignmentDescription')]") {
    return 'shared-network';
  }
  if (description === "[parameters('readerAssignmentDescription')]") {
    return 'content-reader-attach';
  }
  return description;
}

function planAssignmentKey(description) {
  if (/^Launches the (dev|staging|prod) subscription deployment/.test(description)) {
    return 'subscription-launcher';
  }
  if (/^Allows (dev|staging|prod) to reconcile only shared DNS/.test(description)) {
    return 'shared-network';
  }
  if (
    /^Allows (dev|staging|prod) deployment to attach only the immutable content reader identity\.$/.test(
      description,
    )
  ) {
    return 'content-reader-attach';
  }
  return description;
}

function compiledAssignments(template) {
  const assignments = new Map();
  function visit(current) {
    for (const resource of current?.resources ?? []) {
      if (resource.type === 'Microsoft.Authorization/roleAssignments') {
        const key = compiledAssignmentKey(resource.properties?.description);
        if (!key || assignments.has(key)) {
          throw new Error(`compiled assignment declaration is ambiguous: ${key}`);
        }
        assignments.set(key, {
          principalType: resource.properties?.principalType,
          description: resource.properties?.description,
        });
      }
      visit(resource.properties?.template);
    }
  }
  visit(template);
  return assignments;
}

export function normalizePrincipalTypes(plan, compiledTemplate, phaseA) {
  const proof = validatePhaseAProof(phaseA, phaseA.subscriptionId);
  const declarations = compiledAssignments(compiledTemplate);
  const identities = new Map(
    Object.values(proof.identities).map((identity) => [
      identity.principalId.toLowerCase(),
      identity,
    ]),
  );
  const normalizedPlan = structuredClone(plan);
  const provenance = [];
  for (const change of normalizedPlan.changes ?? []) {
    if (change.after?.type !== 'Microsoft.Authorization/roleAssignments') {
      continue;
    }
    const properties = change.after.properties ?? {};
    if (properties.principalType !== null) {
      continue;
    }
    if (!uuidPattern.test(properties.principalId ?? '')) {
      throw new Error(`omitted principalType has non-literal principalId: ${change.resourceId}`);
    }
    const identity = identities.get(properties.principalId.toLowerCase());
    if (!identity) {
      throw new Error(`omitted principalType does not match a Phase A UAMI: ${change.resourceId}`);
    }
    const key = planAssignmentKey(properties.description);
    const declaration = declarations.get(key);
    if (!declaration) {
      throw new Error(
        `compiled assignment declaration is missing (${key}): ${change.resourceId}`,
      );
    }
    if (declaration.principalType !== 'ServicePrincipal') {
      throw new Error(`compiled principalType is not literal ServicePrincipal: ${change.resourceId}`);
    }
    properties.principalType = 'ServicePrincipal';
    provenance.push({
      resourceId: change.resourceId,
      principalId: properties.principalId,
      identityName: identity.name,
      identityResourceId: identity.resourceId,
      observedPrincipalType: null,
      effectivePrincipalType: 'ServicePrincipal',
      provenance: 'compiled-template+live-uami',
      compiledDescription: declaration.description,
    });
  }
  return {
    plan: normalizedPlan,
    provenance: {
      schemaVersion: 1,
      normalizedCount: provenance.length,
      entries: provenance,
    },
  };
}

function main() {
  const [planPath, templatePath, proofPath, outputPath, provenancePath] =
    process.argv.slice(2);
  if (!provenancePath) {
    throw new Error(
      'Usage: normalize-principal-types.mjs <plan> <compiled> <proof> <output> <provenance>',
    );
  }
  const result = normalizePrincipalTypes(
    JSON.parse(fs.readFileSync(path.resolve(planPath), 'utf8')),
    JSON.parse(fs.readFileSync(path.resolve(templatePath), 'utf8')),
    JSON.parse(fs.readFileSync(path.resolve(proofPath), 'utf8')),
  );
  fs.writeFileSync(path.resolve(outputPath), `${JSON.stringify(result.plan)}\n`, {
    mode: 0o600,
  });
  fs.writeFileSync(
    path.resolve(provenancePath),
    `${JSON.stringify(result.provenance, null, 2)}\n`,
    { mode: 0o600 },
  );
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main();
}
