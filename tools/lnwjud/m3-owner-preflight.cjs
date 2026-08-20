#!/usr/bin/env node
'use strict';

// Owner-invoked only: validates an already-created tunnel-client profile and
// runs its doctor. It never prints credentials, tunnel IDs, or profile bodies.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { loadContract, buildRestrictedLaunch, validateLocalReadiness } = require('./m3-remote-contract.cjs');

function fail(message) { throw new Error(`M3 owner preflight refused: ${message}`); }
function absolute(value, name) { if (typeof value !== 'string' || !path.win32.isAbsolute(value)) fail(`${name} must be an absolute Windows path`); return path.resolve(value); }
function parseArgs(argv) { if (argv.length !== 4 || argv[0] !== '--tunnel-client' || argv[2] !== '--profile-dir') fail('usage: m3-owner-preflight.cjs --tunnel-client <absolute .exe> --profile-dir <absolute directory>'); return { tunnelClient: absolute(argv[1], 'tunnel-client'), profileDirectory: absolute(argv[3], 'profile-dir') }; }
function effectiveCommand(body, contract, launch) {
  if (body.includes('\0') || body.length > 65_536) fail('profile is not a bounded text file');
  const expected = launch.command.replaceAll('\\', '/');
  const commands = [];
  let tunnelId = 0; let apiKey = 0;
  for (const raw of body.replaceAll('\r\n', '\n').split('\n')) {
    const line = raw.replace(/\s+#.*$/, '');
    if (/^\s*tunnel_id\s*:\s*["'][^"']+["']\s*$/.test(line)) tunnelId += 1;
    if (new RegExp(`^\\s*api_key\\s*:\\s*["']env:${contract.credentialEnvironment}["']\\s*$`).test(line)) apiKey += 1;
    const key = /^\s*([A-Za-z0-9_-]+)\s*:\s*(.*)$/.exec(line);
    if (key?.[1] === 'command') commands.push({ indent: key[0].indexOf('command'), value: key[2].trim() });
    if (key?.[1] === 'command_line' || key?.[1] === 'executable' || key?.[1] === 'args') fail('unsupported alternate launch authority');
  }
  if (tunnelId !== 1 || apiKey !== 1 || commands.length !== 1) fail('profile must contain exactly one effective command, tunnel ID, and credential reference');
  const value = commands[0].value;
  const quoted = value.length >= 2 && ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) ? value.slice(1, -1) : null;
  if (quoted !== expected || commands[0].indent < 4) fail('profile effective command is not the restricted launcher');
  return Object.freeze({ executable: expected, args: [] });
}
function validateProfile(body, contract, launch) { return effectiveCommand(body, contract, launch); }
function publish(runtimeRoot, state, metadata) { fs.mkdirSync(runtimeRoot, { recursive: true }); fs.writeFileSync(path.join(runtimeRoot, 'm3-tunnel-state.json'), `${JSON.stringify({ schema_version: 1, state, ...metadata, generated_at: new Date().toISOString() })}\n`, 'utf8'); }
function main(argv = process.argv.slice(2), env = process.env, root) {
  const options = parseArgs(argv); const contract = loadContract(); const ready = validateLocalReadiness({ contract, worktree: root, env });
  if (typeof env[contract.credentialEnvironment] !== 'string' || env[contract.credentialEnvironment].trim() === '') fail(`${contract.credentialEnvironment} is required only for this owner process`);
  if (!fs.existsSync(options.tunnelClient)) fail('tunnel-client executable was not found');
  const launch = buildRestrictedLaunch({ contract, worktree: root }); const profile = path.join(options.profileDirectory, `${contract.tunnelProfile}.yaml`);
  try { validateProfile(fs.readFileSync(profile, 'utf8'), contract, launch); execFileSync(options.tunnelClient, ['doctor', '--profile', contract.tunnelProfile, '--profile-dir', options.profileDirectory, '--explain'], { cwd: launch.cwd, env, windowsHide: true, stdio: 'ignore', timeout: 60_000 }); publish(contract.runtimeRoot, 'DOCTOR_PASSED', { checkout_head: ready.checkout_head, profile: contract.tunnelProfile, profile_sha256: crypto.createHash('sha256').update(fs.readFileSync(profile)).digest('hex'), launcher_sha256: crypto.createHash('sha256').update(fs.readFileSync(launch.command)).digest('hex'), policy_sha256: crypto.createHash('sha256').update(fs.readFileSync(launch.policy_path)).digest('hex') }); return { state: 'DOCTOR_PASSED', checkout_head: ready.checkout_head }; }
  catch (error) { const state = /CONTROL_PLANE_API_KEY|auth|unauthori[sz]ed|forbidden/i.test(error instanceof Error ? error.message : '') ? 'AUTH_FAILED' : 'DOCTOR_FAILED'; publish(contract.runtimeRoot, state, { checkout_head: ready.checkout_head, profile: contract.tunnelProfile }); throw error; }
}
if (require.main === module) { try { process.stdout.write(`${JSON.stringify(main(), null, 2)}\n`); } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 2; } }
module.exports = { parseArgs, effectiveCommand, validateProfile, main };
