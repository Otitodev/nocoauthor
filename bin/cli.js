#!/usr/bin/env node
'use strict';

// Thin launcher. All the real logic lives in the shell scripts, so that the
// git-clone and curl|sh install paths stay identical to the npm one.
//
// This exists rather than pointing `bin` straight at install.sh because npm's
// generated Windows shims do not reliably launch shell scripts.

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const SCRIPTS = { install: 'install.sh', uninstall: 'uninstall.sh' };

const USAGE = `
  nocoauthor — strip AI co-author trailers from git commit messages

  Usage
    npx git-nocoauthor install [--repo] [--force]
    npx git-nocoauthor uninstall [--repo]

  Options
    --repo    act on the current repository only, instead of globally
    --force   replace an existing commit-msg hook (backs it up first)

  Configuration, once installed
    git config --global nocoauthor.pattern 'claude|anthropic|copilot|cursor'
    git config --global nocoauthor.enabled false
    NOCOAUTHOR=0 git commit ...        bypass for a single commit
`;

// Locate a POSIX shell. Present as `sh` on macOS/Linux; on Windows it ships
// inside Git for Windows, which we find by walking up from git's exec-path.
function findSh() {
  const probe = spawnSync('sh', ['-c', 'exit 0'], { stdio: 'ignore' });
  if (!probe.error && probe.status === 0) return 'sh';

  if (process.platform === 'win32') {
    const execPath = spawnSync('git', ['--exec-path'], { encoding: 'utf8' });
    if (!execPath.error && execPath.stdout) {
      let dir = execPath.stdout.trim().replace(/\//g, path.sep);
      for (let i = 0; i < 6 && dir; i++) {
        for (const rel of [['usr', 'bin', 'sh.exe'], ['bin', 'sh.exe']]) {
          const candidate = path.join(dir, ...rel);
          if (fs.existsSync(candidate)) return candidate;
        }
        const parent = path.dirname(dir);
        if (parent === dir) break;
        dir = parent;
      }
    }
  }
  return null;
}

const args = process.argv.slice(2);
const command = args[0];

if (!command || command === '-h' || command === '--help' || command === 'help') {
  process.stdout.write(USAGE);
  process.exit(command ? 0 : 1);
}

if (!Object.prototype.hasOwnProperty.call(SCRIPTS, command)) {
  process.stderr.write(`nocoauthor: unknown command '${command}'\n${USAGE}`);
  process.exit(2);
}

const sh = findSh();
if (!sh) {
  process.stderr.write(
    'nocoauthor: no POSIX shell found.\n' +
    (process.platform === 'win32'
      ? 'Install Git for Windows (which bundles sh), or run ./install.sh from Git Bash.\n'
      : 'Could not execute `sh`.\n')
  );
  process.exit(1);
}

const script = path.join(ROOT, SCRIPTS[command]);
if (!fs.existsSync(script)) {
  process.stderr.write(`nocoauthor: missing ${script}\n`);
  process.exit(1);
}

const result = spawnSync(sh, [script].concat(args.slice(1)), { stdio: 'inherit' });
if (result.error) {
  process.stderr.write(`nocoauthor: ${result.error.message}\n`);
  process.exit(1);
}
process.exit(result.status === null ? 1 : result.status);
