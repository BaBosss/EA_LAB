#!/usr/bin/env node
'use strict';

// Launch only byte-identical output of a successful preflight.  The generated
// copy prevents a mutable owner profile from participating in the run path.
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { loadContract, buildRestrictedLaunch, validateLocalReadiness } = require('./m3-remote-contract.cjs');
const { tunnelEnv } = require('./m3-owner-preflight.cjs');
function fail(message) { throw new Error(`M3 owner run refused: ${message}`); }
function sha(file) { return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'); }
function parseArgs(argv) { if (argv.length !== 2 || argv[0] !== '--tunnel-client' || !path.win32.isAbsolute(argv[1])) fail('usage: m3-owner-run.cjs --tunnel-client <same absolute .exe>'); return { tunnelClient: path.resolve(argv[1]) }; }
function prepareRun({ options, env = process.env, worktree, now = Date.now(), runtimeRoot } = {}) {
  const contract = loadContract(); const ready = validateLocalReadiness({ contract, worktree, env }); const launch = buildRestrictedLaunch({ contract, worktree });
  const outputRoot = runtimeRoot || contract.runtimeRoot; const evidencePath = path.join(outputRoot, 'm3-tunnel-state.json'); let evidence; try { evidence = JSON.parse(fs.readFileSync(evidencePath, 'utf8')); } catch { fail('missing preflight evidence'); }
  if (evidence?.schema_version !== 2 || evidence.state !== 'DOCTOR_PASSED' || evidence.checkout_head !== ready.checkout_head || evidence.profile !== contract.tunnelProfile || evidence.tunnel_client !== options.tunnelClient) fail('preflight evidence is unbound');
  if (!Number.isFinite(Date.parse(evidence.generated_at)) || now - Date.parse(evidence.generated_at) > 10 * 60 * 1000) fail('preflight evidence is stale');
  if (!fs.existsSync(evidence.artifact) || sha(evidence.artifact) !== evidence.profile_sha256 || sha(launch.command) !== evidence.launcher_sha256 || sha(launch.policy_path) !== evidence.policy_sha256) fail('validated launch bytes no longer match');
  const sealed = fs.readFileSync(evidence.artifact); const runArtifact = path.join(outputRoot, `m3-launch-${evidence.profile_sha256}.yaml`);
  if (fs.existsSync(runArtifact)) { if (sha(runArtifact) !== evidence.profile_sha256) fail('launch artifact identity mismatch'); } else { fs.writeFileSync(runArtifact, sealed, { encoding: 'utf8', flag: 'wx' }); fs.chmodSync(runArtifact, 0o444); }
  if (sha(runArtifact) !== evidence.profile_sha256) fail('launch artifact write verification failed');
  return { command: options.tunnelClient, args: ['run', '--profile-file', runArtifact], cwd: launch.cwd, env: tunnelEnv(env, contract.credentialEnvironment), artifact: runArtifact };
}
function main(argv = process.argv.slice(2), env = process.env, worktree, spawnChild = spawn, runtimeRoot) { const spec = prepareRun({ options: parseArgs(argv), env, worktree, runtimeRoot }); return spawnChild(spec.command, spec.args, { cwd: spec.cwd, env: spec.env, stdio: 'inherit', windowsHide: true }); }
if (require.main === module) { try { const child = main(); child.once('error', (error) => { process.stderr.write(`M3 owner run failed: ${error.message}\n`); process.exitCode = 1; }); child.once('exit', (code) => { process.exitCode = code === null ? 1 : code; }); } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 2; } }
module.exports = { parseArgs, prepareRun, main };
