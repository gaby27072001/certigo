import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const deploymentParametersSchema =
  'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#';

function requireObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
}

function requireExactFields(value, expected, label) {
  requireObject(value, label);
  const actual = Object.keys(value).sort();
  const required = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(required)) {
    throw new Error(
      `${label} fields must be exactly ${required.join(', ')}; received ${actual.join(', ')}`,
    );
  }
}

function parseJson(raw, label) {
  try {
    return JSON.parse(raw);
  } catch {
    throw new Error(`${label} is not valid JSON`);
  }
}

export function validateDeploymentParametersDocument(document) {
  requireExactFields(
    document,
    ['$schema', 'contentVersion', 'parameters'],
    'deployment parameters document',
  );
  if (document.$schema !== deploymentParametersSchema) {
    throw new Error('deployment parameters document has an unsupported $schema');
  }
  if (document.contentVersion !== '1.0.0.0') {
    throw new Error('deployment parameters document has an unsupported contentVersion');
  }
  requireObject(document.parameters, 'deployment parameters');
  for (const [name, parameter] of Object.entries(document.parameters)) {
    requireExactFields(parameter, ['value'], `deployment parameter ${name}`);
  }
  return document;
}

export function parseBuildParamsOutput(raw) {
  const wrapper = parseJson(raw, 'build-params output');
  requireExactFields(
    wrapper,
    ['parametersJson', 'templateJson', 'templateSpecId'],
    'build-params output',
  );
  if (typeof wrapper.parametersJson !== 'string') {
    throw new Error('build-params output parametersJson must be a JSON string');
  }
  if (wrapper.templateJson !== null && typeof wrapper.templateJson !== 'string') {
    throw new Error('build-params output templateJson must be a JSON string or null');
  }
  if (
    wrapper.templateSpecId !== null &&
    typeof wrapper.templateSpecId !== 'string'
  ) {
    throw new Error('build-params output templateSpecId must be a string or null');
  }
  if (wrapper.templateJson !== null) {
    requireObject(
      parseJson(wrapper.templateJson, 'build-params output templateJson'),
      'build-params output templateJson',
    );
  }
  return validateDeploymentParametersDocument(
    parseJson(wrapper.parametersJson, 'build-params output parametersJson'),
  );
}

function writeDocument(outputPath, document) {
  fs.writeFileSync(
    path.resolve(outputPath),
    `${JSON.stringify(document, null, 2)}\n`,
    { mode: 0o600 },
  );
}

function main() {
  const [command, inputPath, outputPath] = process.argv.slice(2);
  if (command === 'extract') {
    if (!inputPath || !outputPath) {
      throw new Error(
        'Usage: bicep-parameters.mjs extract <build-params-output> <parameters-output>',
      );
    }
    writeDocument(
      outputPath,
      parseBuildParamsOutput(fs.readFileSync(path.resolve(inputPath), 'utf8')),
    );
    return;
  }
  if (command === 'validate') {
    if (!inputPath || outputPath) {
      throw new Error(
        'Usage: bicep-parameters.mjs validate <deployment-parameters>',
      );
    }
    validateDeploymentParametersDocument(
      parseJson(
        fs.readFileSync(path.resolve(inputPath), 'utf8'),
        'deployment parameters document',
      ),
    );
    return;
  }
  throw new Error('command must be extract or validate');
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main();
}
