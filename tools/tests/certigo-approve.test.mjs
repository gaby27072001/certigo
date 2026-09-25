import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { validateSealedApprovals } from '../../.github/scripts/sealed-approval.mjs';

// Essai de bout en bout de tools/certigo-approve.sh, À LANCER EN LOCAL (Linux ou macOS) avant de
// modifier l'outil : faux GitHub (dépôt nu avec refs/pull), faux Mac (clone), ssh-agent à la
// place de Secretive, puis jugement par le vérificateur de la CI. Aucun job CI ne le lance : il
// dépend de bash, git et OpenSSH. Pour tester le bash 3.2 de macOS :
//   CERTIGO_APPROVE_BASH=/chemin/vers/bash-3.2 node --test tools/tests/certigo-approve.test.mjs
const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const bash = process.env.CERTIGO_APPROVE_BASH || 'bash';
const sealed = '.github/workflows/release-android.yml';
const signers = '.github/sealed-approvers/allowed_signers';

function available(command, args) {
  return spawnSync(command, args, { encoding: 'utf8' }).error === undefined;
}

const skip = process.platform === 'win32'
  ? 'uses ssh-agent sockets: run it under Linux or macOS'
  : ['git', 'ssh-keygen', 'ssh-agent', 'ssh-add'].find((command) => !available(command, ['-V']) && !available(command, ['--version']))
    ? 'needs git and OpenSSH'
    : false;

test('certigo-approve signs exactly what main and the pull request contain', { skip }, () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-approve-'));
  const env = {
    ...process.env,
    HOME: path.join(root, 'home'),
    GIT_AUTHOR_NAME: 'sim',
    GIT_AUTHOR_EMAIL: 'sim@example.invalid',
    GIT_COMMITTER_NAME: 'sim',
    GIT_COMMITTER_EMAIL: 'sim@example.invalid',
    GIT_CONFIG_GLOBAL: path.join(root, 'gitconfig'),
    GIT_PAGER: 'cat',
    SSH_AUTH_SOCK: path.join(root, 'agent.sock'),
  };
  fs.mkdirSync(env.HOME);
  fs.writeFileSync(env.GIT_CONFIG_GLOBAL, '[init]\n\tdefaultBranch = main\n');
  const run = (command, args, options = {}) => execFileSync(command, args, { env, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], ...options });
  let agentPid;
  try {
    const bare = path.join(root, 'gh', 'gchambaud_microsoft', 'Certigo.git');
    fs.mkdirSync(bare, { recursive: true });
    run('git', ['init', '-q', '--bare', bare]);
    const key = path.join(root, 'approval-key');
    run('ssh-keygen', ['-q', '-t', 'ecdsa', '-b', '256', '-N', '', '-C', 'mac', '-f', key]);
    agentPid = /SSH_AGENT_PID=(\d+)/u.exec(run('ssh-agent', ['-s', '-a', env.SSH_AUTH_SOCK]))[1];
    run('ssh-add', ['-q', key]);
    fs.rmSync(key);
    const publicKey = fs.readFileSync(`${key}.pub`, 'utf8').split(' ').slice(0, 2).join(' ');

    const seed = path.join(root, 'seed');
    run('git', ['clone', '-q', bare, seed]);
    const write = (relativePath, content) => {
      const destination = path.join(seed, ...relativePath.split('/'));
      fs.mkdirSync(path.dirname(destination), { recursive: true });
      fs.writeFileSync(destination, content);
    };
    write('tools/certigo-approve.sh', fs.readFileSync(path.join(repositoryRoot, 'tools', 'certigo-approve.sh')));
    write(sealed, 'name: release-android\nenv:\n  FLUTTER_VERSION: "3.44.4"\n');
    write(signers, `gabriel@certigo-approval namespaces="certigo-sealed-approval-v1" ${publicKey}\n`);
    write('README.md', 'notes\n');
    const git = (...args) => run('git', ['-C', seed, ...args]);
    git('add', '-A');
    git('commit', '-qm', 'main');
    git('push', '-q', 'origin', 'HEAD:main');
    git('switch', '-q', '-c', 'pr7');
    write(sealed, 'name: release-android\nenv:\n  FLUTTER_VERSION: "3.44.5"\n');
    write('README.md', 'notes v2\n');
    git('commit', '-qam', 'ci : monter FLUTTER_VERSION');
    git('push', '-q', 'origin', 'HEAD:refs/pull/7/head');

    const mac = path.join(root, 'mac');
    run('git', ['clone', '-q', bare, mac]);
    const tool = (args, input = '', extra = {}) => spawnSync(bash, ['tools/certigo-approve.sh', ...args], {
      cwd: mac,
      env: { ...env, CERTIGO_APPROVAL_KEY: `${key}.pub`, CERTIGO_APPROVAL_AGENT: env.SSH_AUTH_SOCK, ...extra },
      input,
      encoding: 'utf8',
    });
    const output = path.join(env.HOME, 'certigo-approval-pr-7.approval');

    assert.equal(tool(['verifier']).status, 0);
    const refused = tool(['7'], 'non\n');
    assert.equal(refused.status, 1);
    assert.match(refused.stderr, /Rien n'a été signé/u);
    assert.equal(fs.existsSync(output), false);

    const signed = tool(['7'], 'oui\n');
    assert.equal(signed.status, 0, signed.stderr);
    assert.match(fs.readFileSync(output, 'utf8'), /^certigo-sealed-approval-v1\nrepository gchambaud_microsoft\/Certigo\nexpires \d{4}-\d{2}-\d{2}\nchange \.github\/workflows\/release-android\.yml [0-9a-f]{64} [0-9a-f]{64}\nchange README\.md [0-9a-f]{64} [0-9a-f]{64}\n-----BEGIN SSH SIGNATURE-----\n/u);

    // Le vérificateur de la CI accepte cette signature sur l'arbre réel de la PR.
    const candidate = path.join(root, 'candidate');
    const base = path.join(root, 'base');
    git('worktree', 'add', '-q', '--detach', candidate, 'pr7');
    git('worktree', 'add', '-q', '--detach', base, 'main');
    fs.mkdirSync(path.join(candidate, '.github', 'sealed-approvals'), { recursive: true });
    fs.copyFileSync(output, path.join(candidate, '.github', 'sealed-approvals', 'pr-7.approval'));
    const judged = validateSealedApprovals(candidate, base, { protectedPaths: [sealed, signers, 'tools/certigo-approve.sh'] });
    assert.deepEqual(judged.errors, []);
    assert.deepEqual(judged.approved.map((entry) => entry.path), [sealed]);

    // Une PR en retard sur main, une copie modifiée de l'outil, ou une autre clé : rien n'est signé.
    git('switch', '-q', 'main');
    write('other.txt', 'x\n');
    git('add', 'other.txt');
    git('commit', '-qm', 'main avance');
    git('push', '-q', 'origin', 'HEAD:main');
    assert.match(tool(['7'], 'oui\n').stderr, /n'est pas à jour avec main/u);
    fs.appendFileSync(path.join(mac, 'tools', 'certigo-approve.sh'), '# modifié\n');
    assert.match(tool(['7'], 'oui\n').stderr, /diffère de celle de main/u);
    run('git', ['-C', mac, 'checkout', '-q', '--', 'tools/certigo-approve.sh']);
    const otherKey = path.join(root, 'other-key');
    run('ssh-keygen', ['-q', '-t', 'ecdsa', '-b', '256', '-N', '', '-C', 'other', '-f', otherKey]);
    const intruder = tool(['verifier'], '', { CERTIGO_APPROVAL_KEY: `${otherKey}.pub` });
    assert.equal(intruder.status, 1);
    assert.match(intruder.stderr, /ALERTE/u);
  } finally {
    if (agentPid) {
      spawnSync('ssh-agent', ['-k'], { env: { ...env, SSH_AGENT_PID: agentPid } });
    }
    fs.rmSync(root, { recursive: true, force: true });
  }
});
