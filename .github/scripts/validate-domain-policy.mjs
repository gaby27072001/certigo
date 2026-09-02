#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const legacyCatalogIdentifier = `certigo${'.app'}-certification-catalog/v2`;
const allowedLegacyPaths = new Set([
  'backend/src/Certigo.Application/Services/CertificationCatalog.cs',
  'docs/ARCHITECTURE.md',
  'packages/data/lib/src/repositories/remote_repositories.dart',
  'packages/data/test/remote_catalog_repository_test.dart',
]);
const domainReferencePattern = /certigo\.app(?![a-z0-9])/gi;

function lineAndColumn(content, index) {
  const prefix = content.slice(0, index);
  const lines = prefix.split('\n');
  return { line: lines.length, column: lines.at(-1).length + 1 };
}

export function findForbiddenDomainReferences(entries) {
  const errors = [];

  for (const { file, content } of entries) {
    domainReferencePattern.lastIndex = 0;
    for (const match of content.matchAll(domainReferencePattern)) {
      const suffix = content.slice(match.index);
      if (allowedLegacyPaths.has(file) && suffix.startsWith(legacyCatalogIdentifier)) {
        continue;
      }

      const { line, column } = lineAndColumn(content, match.index);
      errors.push(
        `${file}:${line}:${column}: unowned domain reference is forbidden; `
          + 'use validated configuration or a neutral URN.',
      );
    }
  }

  return errors;
}

export function validateWorkspace(root) {
  const trackedFiles = execFileSync('git', ['-C', root, 'ls-files', '-z'], {
    encoding: 'utf8',
  })
    .split('\0')
    .filter(Boolean);
  const entries = [];

  for (const file of trackedFiles) {
    const content = readFileSync(path.join(root, file));
    if (!content.includes(0)) {
      entries.push({ file: file.replaceAll('\\', '/'), content: content.toString('utf8') });
    }
  }

  return findForbiddenDomainReferences(entries);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const workspaceIndex = process.argv.indexOf('--workspace');
  const root = workspaceIndex >= 0 ? process.argv[workspaceIndex + 1] : process.cwd();
  if (!root) {
    console.error('::error::--workspace requires a path.');
    process.exitCode = 1;
  } else {
    const errors = validateWorkspace(path.resolve(root));
    for (const error of errors) {
      console.error(`::error::${error}`);
    }
    if (errors.length > 0) {
      process.exitCode = 1;
    }
  }
}
