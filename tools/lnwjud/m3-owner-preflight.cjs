#!/usr/bin/env node
'use strict';

// Owner-invoked only: validates an already-created tunnel-client profile and
// runs its doctor. It never prints credentials, tunnel IDs, or profile bodies.
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { loadContract, buildRestrictedLaunch, validateLocalReadiness } = require('./m3-remote-contract.cjs');

function fail(message) { throw new Error(`M3 owner preflight refused: ${message}`); }
function absolute(value, name) { if (typeof value !== 'string' || !path.win32.isAbsolute(value)) fail(`${name} must be an absolute Windows path`); return path.resolve(value); }
function parseArgs(argv) { if (argv.length !== 4 || argv[0] !== '--tunnel-client' || argv[2] !== '--profile-dir') fail('usage: m3-owner-preflight.cjs --tunnel-client <absolute .exe> --profile-dir <absolute directory>'); return { tunnelClient: absolute(argv[1], 'tunnel-client'), profileDirectory: absolute(argv[3], 'profile-dir') }; }
function validateProfile(body, contract, launch) {
  if (body.includes('\0') || body.length > 65_536) fail('profile is not a bounded text file');
  const command = launch.command.replaceAll('\\', '/').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const required = [new RegExp(`^\\s*tunnel_id:\\s*["'][^"']+["']\\s*$`, 'm'), new RegExp(`^\\s*api_key:\\s*["']env:${contract.credentialEnvironment}["']\\s*$`, 'm'), new RegExp(`^\\s*command:\\s*["']${command}["']\\s*$`, 'm')];
  if (!required.every((pattern) => pattern.test(body))) fail('profile is not the restricted M3 tunnel-client profile');
}
function publish(runtimeRoot, state) { fs.mkdirSync(runtimeRoot, { recursive: true }); fs.writeFileSync(path.join(runtimeRoot, 'm3-tunnel-state.json'), `${JSON.stringify({ schema_version: 1, state, generated_at: new Date().toISOString() })}\n`, 'utf8'); }
function main(argv = process.argv.slice(2), env = process.env, root) {
  const options = parseArgs(argv); const contract = loadContract(); const ready = validateLocalReadiness({ contract, worktree: root, env });
  if (typeof env[contract.credentialEnvironment] !== 'string' || env[contract.credentialEnvironment].trim() === '') fail(`${contract.credentialEnvironment} is required only for this owner process`);
  if (!fs.existsSync(options.tunnelClient)) fail('tunnel-client executable was not found');
  const launch = buildRestrictedLaunch({ contract, worktree: root }); const profile = path.join(options.profileDirectory, `${contract.tunnelProfile}.yaml`);
  try { validateProfile(fs.readFileSync(profile, 'utf8'), contract, launch); execFileSync(options.tunnelClient, ['doctor', '--profile', contract.tunnelProfile, '--profile-dir', options.profileDirectory, '--explain'], { cwd: launch.cwd, env, windowsHide: true, stdio: 'ignore', timeout: 60_000 }); publish(contract.runtimeRoot, 'DOCTOR_PASSED'); return { state: 'DOCTOR_PASSED', checkout_head: ready.checkout_head }; }
  catch (error) { const state = /CONTROL_PLANE_API_KEY|auth|unauthori[sz]ed|forbidden/i.test(error instanceof Error ? error.message : '') ? 'AUTH_FAILED' : 'DOCTOR_FAILED'; publish(contract.runtimeRoot, state); throw error; }
}
if (require.main === module) { try { process.stdout.write(`${JSON.stringify(main(), null, 2)}\n`); } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 2; } }
module.exports = { parseArgs, validateProfile, main };
