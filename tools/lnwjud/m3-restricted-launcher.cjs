#!/usr/bin/env node
'use strict';

// tunnel-client reaches this only through the adjacent .cmd wrapper. No caller
// argument survives, and the gateway receives only a pinned child environment.
const path = require('node:path');
const { spawn } = require('node:child_process');
const { loadContract, buildRestrictedLaunch, validateLocalReadiness } = require('./m3-remote-contract.cjs');

function restrictedChild({ env = process.env, worktree } = {}) {
  if (process.argv.length > 2) throw new Error('restricted launcher accepts no arguments');
  const contract = loadContract();
  const ready = validateLocalReadiness({ contract, worktree, env });
  const launch = buildRestrictedLaunch({ contract, worktree });
  const childEnv = { ...env };
  for (const name of ['LNWJUD_UNRESTRICTED', 'LNWJUD_SOURCE_ROOT', 'EA_LAB_APPROVED_WORKTREE', 'LNWJUD_DATA_PATH', 'CONTROL_PLANE_API_KEY', contract.credentialEnvironment]) delete childEnv[name];
  childEnv.LNWJUD_SOURCE_ROOT = contract.upstreamSourceRoot;
  childEnv.EA_LAB_APPROVED_WORKTREE = launch.cwd;
  childEnv.LNWJUD_DATA_PATH = contract.runtimeRoot;
  return { ready, command: process.execPath, args: [path.join(launch.cwd, 'tools', 'lnwjud', 'ea-lab-gateway.cjs'), '--policy', launch.policy_path], cwd: launch.cwd, env: childEnv };
}
function main() {
  const child = restrictedChild();
  const processChild = spawn(child.command, child.args, { cwd: child.cwd, env: child.env, stdio: 'inherit', windowsHide: true });
  processChild.once('error', (error) => { process.stderr.write(`M3 restricted launcher failed: ${error.message}\n`); process.exitCode = 1; });
  processChild.once('exit', (code, signal) => { process.exitCode = code === null ? 1 : code; if (signal) process.stderr.write(`M3 restricted launcher child ended with ${signal}\n`); });
}
if (require.main === module) main();
module.exports = { restrictedChild };
