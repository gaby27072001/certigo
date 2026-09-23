import assert from 'node:assert/strict';

export const deploymentContext = {
  subscriptionId: 'b8952c8c-8f72-469d-99cd-ac906da4e2fc',
  resourceGroupName: 'rg-certigo-ci',
  location: 'westeurope',
  resourceManager: 'https://management.azure.com/',
};

const missing = Symbol('missing');

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function stableString(value) {
  return JSON.stringify(value);
}

function clone(value) {
  return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
}

function splitArguments(source) {
  const args = [];
  let start = 0;
  let depth = 0;
  let quote = false;
  for (let i = 0; i < source.length; i += 1) {
    const c = source[i];
    if (quote) {
      if (c === "'" && source[i + 1] === "'") {
        i += 1;
      } else if (c === "'") {
        quote = false;
      }
      continue;
    }
    if (c === "'") quote = true;
    else if (c === '(' || c === '[') depth += 1;
    else if (c === ')' || c === ']') depth -= 1;
    else if (c === ',' && depth === 0) {
      args.push(source.slice(start, i).trim());
      start = i + 1;
    }
  }
  if (source.slice(start).trim() !== '') args.push(source.slice(start).trim());
  return args;
}

function decodeStringLiteral(source, index = 0) {
  assert.equal(source[index], "'");
  let value = '';
  let i = index + 1;
  for (; i < source.length; i += 1) {
    if (source[i] === "'" && source[i + 1] === "'") {
      value += "'";
      i += 1;
    } else if (source[i] === "'") {
      return { value, end: i + 1 };
    } else {
      value += source[i];
    }
  }
  throw new Error(`unterminated string literal in ${source}`);
}

function formatComposite(template, args) {
  let result = '';
  for (let i = 0; i < template.length; i += 1) {
    if (template[i] === '{' && template[i + 1] === '{') {
      result += '{';
      i += 1;
    } else if (template[i] === '}' && template[i + 1] === '}') {
      result += '}';
      i += 1;
    } else if (template[i] === '{') {
      const end = template.indexOf('}', i + 1);
      if (end < 0) throw new Error(`invalid format string ${template}`);
      const index = Number(template.slice(i + 1, end));
      if (!Number.isInteger(index) || index >= args.length) {
        throw new Error(`invalid format index {${template.slice(i + 1, end)}}`);
      }
      result += String(args[index]);
      i = end;
    } else {
      result += template[i];
    }
  }
  return result;
}

function uriComponent(value) {
  return encodeURIComponent(String(value)).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);
}

class ArmExpressionEvaluator {
  constructor(template, overrides = {}, context = deploymentContext) {
    this.template = template;
    this.context = context;
    this.parameters = new Map();
    this.variables = new Map();
    this.evaluatingVariables = new Set();
    for (const [name, definition] of Object.entries(template.parameters ?? {})) {
      if (Object.hasOwn(overrides, name)) this.parameters.set(name, overrides[name]);
      else if (Object.hasOwn(definition, 'defaultValue')) this.parameters.set(name, this.evalValue(definition.defaultValue));
      else throw new Error(`missing required ARM parameter ${name}`);
    }
  }

  withParameters(parameters) {
    return new ArmExpressionEvaluator(this.template, parameters, this.context);
  }

  evalValue(value, locals = new Map()) {
    if (typeof value === 'string') {
      if (value.startsWith('[[')) return value.slice(1);
      if (value.startsWith('[') && value.endsWith(']')) return this.evalExpression(value.slice(1, -1), locals);
      return value;
    }
    if (Array.isArray(value)) return value.map((item) => this.evalValue(item, locals));
    if (isObject(value)) {
      const result = {};
      for (const [key, item] of Object.entries(value)) {
        const evaluatedKey = key.startsWith('[') && key.endsWith(']')
          ? this.evalExpression(key.slice(1, -1), locals)
          : key;
        result[evaluatedKey] = this.evalValue(item, locals);
      }
      return result;
    }
    return value;
  }

  evalExpression(source, locals = new Map()) {
    const parser = new ArmParser(source, this, locals);
    const value = parser.parseExpression();
    parser.skipWhitespace();
    if (!parser.eof()) throw new Error(`unsupported ARM syntax near ${source.slice(parser.index)} in ${source}`);
    return value;
  }

  variable(name, locals) {
    if (this.variables.has(name)) return this.variables.get(name);
    if (!Object.hasOwn(this.template.variables ?? {}, name)) throw new Error(`unknown ARM variable ${name}`);
    if (this.evaluatingVariables.has(name)) throw new Error(`cycle while evaluating ARM variable ${name}`);
    this.evaluatingVariables.add(name);
    const value = this.evalValue(this.template.variables[name], locals);
    this.variables.set(name, value);
    this.evaluatingVariables.delete(name);
    return value;
  }

  call(name, args, locals) {
    switch (name) {
      case 'parameters': return this.getParameter(args[0]);
      case 'variables': return this.variable(args[0], locals);
      case 'format': return formatComposite(args[0], args.slice(1));
      case 'replace': return String(args[0]).split(String(args[1])).join(String(args[2]));
      case 'toLower': return String(args[0]).toLowerCase();
      case 'string': return typeof args[0] === 'string' ? args[0] : JSON.stringify(args[0]);
      case 'uriComponent': return uriComponent(args[0]);
      case 'resourceId': return `/subscriptions/${this.context.subscriptionId}/resourceGroups/${this.context.resourceGroupName}/providers/${args[0]}/${args[1]}`;
      case 'subscriptionResourceId': return `/subscriptions/${this.context.subscriptionId}/providers/${args[0]}/${args[1]}`;
      case 'subscription': return { subscriptionId: this.context.subscriptionId, id: `/subscriptions/${this.context.subscriptionId}` };
      case 'resourceGroup': return { name: this.context.resourceGroupName, location: this.context.location, id: `/subscriptions/${this.context.subscriptionId}/resourceGroups/${this.context.resourceGroupName}` };
      case 'environment': return { resourceManager: this.context.resourceManager };
      case 'createObject': {
        if (args.length % 2 !== 0) throw new Error('createObject requires key/value pairs');
        const result = {};
        for (let i = 0; i < args.length; i += 2) result[String(args[i])] = args[i + 1];
        return result;
      }
      case 'createArray': return args;
      case 'map': return args[0].map((item, index) => this.invokeLambda(args[1], item, index));
      case 'toObject': {
        const result = {};
        for (const [index, item] of args[0].entries()) result[this.invokeLambda(args[1], item, index)] = this.invokeLambda(args[2], item, index);
        return result;
      }
      case 'lambda': return { __lambda: true, name: args[0], expression: args[1] };
      case 'lambdaVariables': {
        if (!locals.has(args[0])) throw new Error(`unknown lambda variable ${args[0]}`);
        return locals.get(args[0]);
      }
      case 'union': return unionCollections(args);
      case 'join': return args[0].join(args[1]);
      case 'flatten': return args[0].flat();
      case 'true': return true;
      case 'false': return false;
      case 'if': return args[0] ? args[1] : args[2];
      case 'empty': return args[0] == null || (Array.isArray(args[0]) || typeof args[0] === 'string' ? args[0].length === 0 : Object.keys(args[0]).length === 0);
      case 'guid': return `guid(${args.join(',')})`;
      case 'uniqueString': return `uni${Math.abs(String(args.join('|')).split('').reduce((a, c) => ((a << 5) - a + c.charCodeAt(0)) | 0, 0)).toString(36)}`;
      case 'take': return String(args[0]).slice(0, Number(args[1]));
      default: throw new Error(`unsupported ARM function ${name}`);
    }
  }

  getParameter(name) {
    if (!this.parameters.has(name)) throw new Error(`unknown ARM parameter ${name}`);
    return this.parameters.get(name);
  }

  invokeLambda(lambda, item, index) {
    if (!lambda?.__lambda) throw new Error('expected lambda');
    const locals = new Map([[lambda.name, item], [`${lambda.name}Index`, index]]);
    return this.evalExpression(lambda.expression, locals);
  }
}

class ArmParser {
  constructor(source, evaluator, locals) {
    this.source = source;
    this.evaluator = evaluator;
    this.locals = locals;
    this.index = 0;
  }

  eof() { return this.index >= this.source.length; }
  skipWhitespace() { while (/\s/.test(this.source[this.index] ?? '')) this.index += 1; }
  peek() { this.skipWhitespace(); return this.source[this.index]; }
  consume(expected) {
    this.skipWhitespace();
    if (this.source[this.index] !== expected) throw new Error(`expected ${expected} at ${this.index} in ${this.source}`);
    this.index += 1;
  }

  parseExpression() {
    let value = this.parsePrimary();
    while (true) {
      this.skipWhitespace();
      if (this.source[this.index] === '.') {
        this.index += 1;
        const name = this.parseIdentifier();
        value = value?.[name];
        if (value === undefined) throw new Error(`ARM property .${name} is undefined`);
      } else if (this.source[this.index] === '[') {
        this.index += 1;
        const key = this.parseExpression();
        this.consume(']');
        value = value?.[key];
        if (value === undefined) throw new Error(`ARM index [${key}] is undefined`);
      } else {
        return value;
      }
    }
  }

  parsePrimary() {
    this.skipWhitespace();
    const c = this.source[this.index];
    if (c === "'") {
      const decoded = decodeStringLiteral(this.source, this.index);
      this.index = decoded.end;
      return decoded.value;
    }
    if (c === '-' || /\d/.test(c)) return this.parseNumber();
    const ident = this.parseIdentifier();
    this.skipWhitespace();
    if (this.source[this.index] === '(') {
      this.index += 1;
      const start = this.index;
      let depth = 1;
      let quote = false;
      for (; this.index < this.source.length; this.index += 1) {
        const ch = this.source[this.index];
        if (quote) {
          if (ch === "'" && this.source[this.index + 1] === "'") this.index += 1;
          else if (ch === "'") quote = false;
        } else if (ch === "'") quote = true;
        else if (ch === '(') depth += 1;
        else if (ch === ')') {
          depth -= 1;
          if (depth === 0) break;
        }
      }
      if (depth !== 0) throw new Error(`unterminated function call ${ident}`);
      const body = this.source.slice(start, this.index);
      this.index += 1;
      if (ident === 'lambda') {
        const parts = splitArguments(body);
        return { __lambda: true, name: this.evaluator.evalExpression(parts[0], this.locals), expression: parts[1] };
      }
      const args = splitArguments(body).map((part) => this.evaluator.evalExpression(part, this.locals));
      return this.evaluator.call(ident, args, this.locals);
    }
    throw new Error(`bare ARM identifier ${ident} is unsupported`);
  }

  parseIdentifier() {
    this.skipWhitespace();
    const match = /[A-Za-z_$][A-Za-z0-9_$#]*/.exec(this.source.slice(this.index));
    if (!match) throw new Error(`expected identifier at ${this.index} in ${this.source}`);
    this.index += match[0].length;
    return match[0];
  }

  parseNumber() {
    const match = /-?\d+/.exec(this.source.slice(this.index));
    this.index += match[0].length;
    return Number(match[0]);
  }
}

function unionCollections(collections) {
  if (collections.every(Array.isArray)) {
    const result = [];
    const seen = new Set();
    for (const collection of collections) {
      for (const item of collection) {
        const key = stableString(item);
        if (!seen.has(key)) {
          seen.add(key);
          result.push(item);
        }
      }
    }
    return result;
  }
  if (collections.every(isObject)) return Object.assign({}, ...collections);
  throw new Error('union supports only all arrays or all objects');
}

export function resources(template) {
  return Array.isArray(template.resources) ? template.resources : Object.values(template.resources ?? {});
}

export function expandRecoveryWorkflow(parentTemplate, options = {}) {
  const parentParameters = options.compositionParameters ?? {};
  const parent = new ArmExpressionEvaluator(parentTemplate, parentParameters);
  const nested = resources(parentTemplate).find((resource) => resource.type === 'Microsoft.Resources/deployments' && resource.name === 'certigo-ci-runner-auto-recovery');
  if (!nested) throw new Error('nested deployment certigo-ci-runner-auto-recovery not found');
  if (nested.properties?.expressionEvaluationOptions?.scope !== 'inner') throw new Error('nested deployment must use inner expression evaluation');
  const nestedParameters = {};
  for (const [name, parameter] of Object.entries(nested.properties.parameters ?? {})) nestedParameters[name] = parent.evalValue(parameter.value);
  Object.assign(nestedParameters, options.moduleParameters ?? {});
  const child = new ArmExpressionEvaluator(nested.properties.template, nestedParameters);
  const workflow = resources(nested.properties.template).find((resource) => resource.type === 'Microsoft.Logic/workflows');
  if (!workflow) throw new Error('Microsoft.Logic/workflows resource not found');
  return {
    definition: child.evalValue(workflow.properties.definition),
    moduleTemplate: nested.properties.template,
    nestedParameters,
  };
}

class LogicExpressionEvaluator {
  constructor(parameters, actions, frames = {}) {
    this.parameters = parameters;
    this.actions = actions;
    this.frames = frames;
  }

  evalTemplate(value) {
    if (typeof value !== 'string') return value;
    if (value.startsWith('@@')) return value.slice(1);
    if (value.startsWith('@') && !value.startsWith('@{')) return this.evalExpression(value.slice(1));
    return value.replace(/@\{([^}]*)\}/g, (_match, expression) => String(this.evalExpression(expression)));
  }

  evalExpression(source) {
    const parser = new LogicParser(source, this);
    const value = parser.parseExpression();
    parser.skipWhitespace();
    if (!parser.eof()) throw new Error(`unsupported Logic Apps syntax near ${source.slice(parser.index)} in ${source}`);
    return value;
  }

  call(name, args) {
    switch (name) {
      case 'body': return this.actions.get(args[0])?.body ?? null;
      case 'items': return this.frames.loops?.[args[0]] ?? null;
      case 'item': return this.frames.item ?? null;
      case 'parameters': return this.parameters[args[0]];
      case 'coalesce': return args.find((arg) => arg !== null && arg !== undefined) ?? null;
      // The real engine rejects `createArray()` without arguments (InvalidTemplate, measured
      // on run 08584114192689525938465393788CU124 on 2026-09-23); `json('[]')` is the literal.
      case 'createArray':
        if (args.length === 0) throw new Error("Logic Apps rejects createArray() without arguments; use json('[]')");
        return args;
      case 'json': return JSON.parse(String(args[0]));
      case 'union': return unionCollections(args);
      case 'not': return !args[0];
      case 'and': return args.every(Boolean);
      case 'or': return args.some(Boolean);
      case 'contains': return typeof args[0] === 'string' ? args[0].includes(args[1]) : args[0].some((item) => stableString(item) === stableString(args[1]));
      case 'toLower': return String(args[0]).toLowerCase();
      case 'string': return typeof args[0] === 'string' ? args[0] : JSON.stringify(args[0]);
      case 'length': return args[0]?.length ?? Object.keys(args[0] ?? {}).length;
      case 'empty':
        // empty(null) is not relied upon: its real semantics were not measured.
        if (args[0] == null) throw new Error('empty() of null is unverified against the real engine');
        return Array.isArray(args[0]) || typeof args[0] === 'string' ? args[0].length === 0 : Object.keys(args[0]).length === 0;
      case 'equals': return stableString(args[0]) === stableString(args[1]);
      case 'greaterOrEquals': return args[0] >= args[1];
      case 'greater': return args[0] > args[1];
      case 'less': return args[0] < args[1];
      case 'lessOrEquals': return args[0] <= args[1];
      case 'join': return args[0].join(args[1]);
      case 'concat': return args.map((arg) => String(arg)).join('');
      case 'encodeUriComponent': return uriComponent(args[0]);
      default: throw new Error(`unsupported Logic Apps function ${name}`);
    }
  }
}

class LogicParser {
  constructor(source, evaluator) {
    this.source = source;
    this.evaluator = evaluator;
    this.index = 0;
  }

  eof() { return this.index >= this.source.length; }
  skipWhitespace() { while (/\s/.test(this.source[this.index] ?? '')) this.index += 1; }
  consume(expected) {
    this.skipWhitespace();
    if (this.source[this.index] !== expected) throw new Error(`expected ${expected} at ${this.index} in ${this.source}`);
    this.index += 1;
  }

  parseExpression() {
    let value = this.parsePrimary();
    while (true) {
      this.skipWhitespace();
      if (this.source.startsWith('?[', this.index)) {
        this.index += 2;
        const key = this.parseExpression();
        this.consume(']');
        value = value == null ? null : (value[key] ?? null);
      } else if (this.source[this.index] === '[') {
        this.index += 1;
        const key = this.parseExpression();
        this.consume(']');
        value = value?.[key];
        if (value === undefined) throw new Error(`Logic Apps index [${key}] is undefined`);
      } else {
        return value;
      }
    }
  }

  parsePrimary() {
    this.skipWhitespace();
    const c = this.source[this.index];
    if (c === "'") {
      const decoded = decodeStringLiteral(this.source, this.index);
      this.index = decoded.end;
      return decoded.value;
    }
    if (c === '-' || /\d/.test(c)) return this.parseNumber();
    const ident = this.parseIdentifier();
    if (ident === 'true') return true;
    if (ident === 'false') return false;
    this.consume('(');
    const start = this.index;
    let depth = 1;
    let quote = false;
    for (; this.index < this.source.length; this.index += 1) {
      const ch = this.source[this.index];
      if (quote) {
        if (ch === "'" && this.source[this.index + 1] === "'") this.index += 1;
        else if (ch === "'") quote = false;
      } else if (ch === "'") quote = true;
      else if (ch === '(' || ch === '[') depth += 1;
      else if (ch === ')' || ch === ']') depth -= 1;
      if (depth === 0) break;
    }
    if (depth !== 0) throw new Error(`unterminated Logic Apps call ${ident}`);
    const body = this.source.slice(start, this.index);
    this.index += 1;
    const args = splitArguments(body).map((part) => this.evaluator.evalExpression(part));
    return this.evaluator.call(ident, args);
  }

  parseIdentifier() {
    this.skipWhitespace();
    const match = /[A-Za-z_][A-Za-z0-9_]*/.exec(this.source.slice(this.index));
    if (!match) throw new Error(`expected identifier at ${this.index} in ${this.source}`);
    this.index += match[0].length;
    return match[0];
  }

  parseNumber() {
    const match = /-?\d+/.exec(this.source.slice(this.index));
    this.index += match[0].length;
    return Number(match[0]);
  }
}

function evaluateCondition(condition, evaluator) {
  if (typeof condition === 'string') return Boolean(evaluator.evalTemplate(condition));
  if (typeof condition !== 'object' || condition === null) return Boolean(condition);
  if (Object.hasOwn(condition, 'and')) return condition.and.every((item) => evaluateCondition(item, evaluator));
  if (Object.hasOwn(condition, 'or')) return condition.or.some((item) => evaluateCondition(item, evaluator));
  if (Object.hasOwn(condition, 'not')) return !evaluateCondition(condition.not, evaluator);
  for (const op of ['equals', 'greaterOrEquals', 'greater', 'less', 'lessOrEquals']) {
    if (Object.hasOwn(condition, op)) {
      const [left, right] = condition[op].map((operand) => typeof operand === 'string' ? evaluator.evalTemplate(operand) : operand);
      return evaluator.call(op, [left, right]);
    }
  }
  throw new Error(`unsupported condition ${JSON.stringify(condition)}`);
}

export class MockArm {
  constructor(options = {}) {
    this.vms = (options.vms ?? []).map((vm) => ({ ...vm }));
    this.failListScaleSets = new Set(options.failListScaleSets ?? []);
    this.nextLinkScaleSets = new Set(options.nextLinkScaleSets ?? []);
    this.requests = [];
  }

  startedNames() {
    return this.requests.filter((request) => request.method === 'POST').map((request) => request.name);
  }

  async request(method, uri) {
    this.requests.push({ method, uri });
    const url = new URL(uri);
    const apiVersion = url.searchParams.get('api-version');
    if (!apiVersion) return { status: 400, body: { error: 'missing api-version' } };
    const vmCollection = `/subscriptions/${deploymentContext.subscriptionId}/resourceGroups/${deploymentContext.resourceGroupName}/providers/Microsoft.Compute/virtualMachines`.toLowerCase();
    if (method === 'GET') {
      if (url.pathname.toLowerCase() !== vmCollection) return { status: 404, body: { error: 'unknown list path' } };
      if (url.searchParams.get('$expand') !== 'instanceView') return { status: 400, body: { error: 'missing $expand=instanceView' } };
      const filter = url.searchParams.get('$filter');
      const match = /^'virtualMachineScaleSet\/id' eq '([^']+)'$/.exec(filter ?? '');
      if (!match) return { status: 400, body: { error: `invalid filter ${filter}` } };
      const scaleSetId = match[1];
      const scaleSetName = scaleSetId.split('/').at(-1);
      if (this.failListScaleSets.has(scaleSetName)) return { status: 403, body: { error: 'forbidden' } };
      const body = {
        value: this.vms
          .filter((vm) => vm.scaleSetId.toLowerCase() === scaleSetId.toLowerCase())
          .map((vm) => this.toArmVm(vm)),
      };
      if (this.nextLinkScaleSets.has(scaleSetName)) body.nextLink = `${uri}&skiptoken=next`;
      return { status: 200, body };
    }
    if (method === 'POST') {
      const match = /\/virtualMachines\/([^/]+)\/start$/i.exec(url.pathname);
      if (!match) return { status: 404, body: { error: 'unknown post path' } };
      const name = decodeURIComponent(match[1]);
      this.requests.at(-1).name = name;
      const vm = this.vms.find((candidate) => candidate.name === name);
      if (!vm) return { status: 404, body: { error: 'unknown VM' } };
      // Starts complete synchronously in the simulator; real ARM may return 202 and finish later.
      if (vm.onStart === 'fail') return { status: 500, body: { error: 'start failed' } };
      vm.power = 'running';
      return { status: 200, body: { status: 'started' } };
    }
    return { status: 405, body: { error: 'unsupported method' } };
  }

  toArmVm(vm) {
    const statuses = [
      { code: vm.provisioningState === 'Failed' ? 'ProvisioningState/failed/InternalExecutionError' : 'ProvisioningState/succeeded' },
    ];
    if (vm.power !== 'none') statuses.push({ code: `PowerState/${vm.power}` });
    return {
      name: vm.name,
      id: `/subscriptions/${deploymentContext.subscriptionId}/resourceGroups/${deploymentContext.resourceGroupName}/providers/Microsoft.Compute/virtualMachines/${vm.name}`,
      properties: {
        provisioningState: vm.provisioningState,
        virtualMachineScaleSet: { id: vm.scaleSetId },
        instanceView: { statuses },
      },
    };
  }
}

export async function runWorkflow(definition, arm, options = {}) {
  const parameters = {};
  for (const [name, parameter] of Object.entries(definition.parameters ?? {})) parameters[name] = clone(parameter.defaultValue);
  Object.assign(parameters, options.parameters ?? {});
  const actions = new Map();
  const branches = new Map();
  const termination = await runActions(definition.actions ?? {}, { parameters, arm, actions, branches, loops: {} });
  if (termination) return { status: termination.status, error: termination.error, actions, branches, requests: arm.requests };

  const successors = new Map();
  for (const [name, action] of Object.entries(definition.actions ?? {})) {
    for (const predecessor of Object.keys(action.runAfter ?? {})) {
      if (!successors.has(predecessor)) successors.set(predecessor, []);
      successors.get(predecessor).push(name);
    }
  }
  const leaves = [...Object.keys(definition.actions ?? {})].filter((name) => !successors.has(name));
  const memo = new Map();
  const effectiveStatus = (name) => {
    if (memo.has(name)) return memo.get(name);
    const status = actions.get(name)?.status ?? 'Skipped';
    if (status !== 'Skipped') {
      memo.set(name, status);
      return status;
    }
    const predecessors = Object.keys(definition.actions[name]?.runAfter ?? {});
    const effective = predecessors.some((predecessor) => effectiveStatus(predecessor) === 'Failed') ? 'Failed' : 'Skipped';
    memo.set(name, effective);
    return effective;
  };
  // Logic Apps marks a run failed when any terminal branch effectively ends in failure,
  // including a skipped leaf whose predecessor failed and whose runAfter did not catch it.
  const failed = leaves.some((leaf) => effectiveStatus(leaf) === 'Failed');
  return { status: failed ? 'Failed' : 'Succeeded', actions, branches, requests: arm.requests };
}

async function runActions(actionObject, context) {
  const pending = new Set(Object.keys(actionObject));
  while (pending.size > 0) {
    let progressed = false;
    for (const name of [...pending]) {
      const action = actionObject[name];
      const runAfter = action.runAfter ?? {};
      const predecessors = Object.keys(runAfter);
      if (!predecessors.every((predecessor) => context.actions.has(predecessor))) continue;
      pending.delete(name);
      progressed = true;
      const shouldRun = predecessors.every((predecessor) => runAfter[predecessor].includes(context.actions.get(predecessor).status));
      if (!shouldRun) {
        context.actions.set(name, { status: 'Skipped', body: null });
        continue;
      }
      const result = await runAction(name, action, context);
      if (result?.terminate) return result;
    }
    if (!progressed) throw new Error(`workflow deadlock; pending actions: ${[...pending].join(', ')}`);
  }
  return null;
}

async function runAction(name, action, context) {
  const evaluator = new LogicExpressionEvaluator(context.parameters, context.actions, { loops: context.loops, item: context.item });
  switch (action.type) {
    case 'Http': {
      const response = await context.arm.request(action.inputs.method, evaluator.evalTemplate(action.inputs.uri));
      context.actions.set(name, { status: response.status >= 400 ? 'Failed' : 'Succeeded', body: response.body, statusCode: response.status });
      return null;
    }
    case 'Query': {
      const from = evaluator.evalTemplate(action.inputs.from);
      const body = from.filter((item) => new LogicExpressionEvaluator(context.parameters, context.actions, { ...context, item }).evalTemplate(action.inputs.where));
      context.actions.set(name, { status: 'Succeeded', body });
      return null;
    }
    case 'Select': {
      const from = evaluator.evalTemplate(action.inputs.from);
      const body = from.map((item) => new LogicExpressionEvaluator(context.parameters, context.actions, { ...context, item }).evalTemplate(action.inputs.select));
      context.actions.set(name, { status: 'Succeeded', body });
      return null;
    }
    case 'Foreach': {
      const items = evaluator.evalTemplate(action.foreach);
      const innerNames = Object.keys(action.actions ?? {});
      let failed = false;
      for (const item of items) {
        const iterationActions = new Map(context.actions);
        for (const innerName of innerNames) iterationActions.delete(innerName);
        const termination = await runActions(action.actions ?? {}, { ...context, actions: iterationActions, loops: { ...context.loops, [name]: item }, item });
        for (const [innerName, state] of iterationActions) if (!context.actions.has(innerName) || state !== context.actions.get(innerName)) context.actions.set(innerName, state);
        // Only this loop's own actions decide its status, not failures elsewhere in the run.
        failed ||= innerNames.some((innerName) => iterationActions.get(innerName)?.status === 'Failed');
        if (termination) return termination;
      }
      context.actions.set(name, { status: failed ? 'Failed' : 'Succeeded', body: null });
      return null;
    }
    case 'Wait':
      context.actions.set(name, { status: 'Succeeded', body: null });
      return null;
    case 'If': {
      const condition = evaluateCondition(action.expression, evaluator);
      context.branches.set(name, condition ? 'then' : 'else');
      const branchActions = condition ? (action.actions ?? {}) : (action.else?.actions ?? {});
      const termination = await runActions(branchActions, context);
      context.actions.set(name, { status: termination ? termination.status : 'Succeeded', body: null });
      return termination;
    }
    case 'Terminate': {
      const error = action.inputs.runError
        ? { code: evaluator.evalTemplate(action.inputs.runError.code), message: evaluator.evalTemplate(action.inputs.runError.message) }
        : undefined;
      context.actions.set(name, { status: action.inputs.runStatus, body: null, error });
      return { terminate: true, status: action.inputs.runStatus, error };
    }
    default:
      throw new Error(`unsupported Logic Apps action type ${action.type}`);
  }
}
