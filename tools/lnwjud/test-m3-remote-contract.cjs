#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { loadContract, buildRestrictedLaunch, renderTunnelInit, validateLocalReadiness } = require('./m3-remote-contract.cjs');
const { parseArgs: parsePreflight, prepare } = require('./m3-owner-preflight.cjs');
const { prepareRun, main: runMain } = require('./m3-owner-run.cjs');
const root = path.resolve(__dirname, '..', '..'); const base = JSON.parse(fs.readFileSync(path.join(__dirname, 'm3-remote-contract.json'), 'utf8'));
const secret = 'synthetic-m3-token-not-a-real-secret'; let passed = 0;
function pass(name) { passed += 1; process.stdout.write(`[PASS] ${name}\n`); }
function temporary(change) { const file = path.join(os.tmpdir(), `lnwjud-m3-${process.pid}-${Date.now()}-${Math.random().toString(16).slice(2)}.json`); const value = structuredClone(base); change(value); fs.writeFileSync(file, JSON.stringify(value), 'utf8'); return file; }
function rejects(change, pattern) { const file = temporary(change); try { assert.throws(() => loadContract(file), pattern); pass(pattern.source); } finally { fs.rmSync(file, { force: true }); } }
function rejectsReadiness(change, pattern) { const file = temporary(change); try { assert.throws(() => validateLocalReadiness({ contract: loadContract(file), worktree: root, env: {} }), pattern); pass(pattern.source); } finally { fs.rmSync(file, { force: true }); } }
const contract = loadContract(); const local = validateLocalReadiness({ contract, worktree: root, env: {} });
assert.equal(local.state, 'LOCAL_READY_OWNER_PREFLIGHT_REQUIRED'); assert.equal(local.external_state, 'BLOCKED(E)'); assert.equal(local.listener, 'NONE'); assert(!JSON.stringify(local).includes(secret)); pass('no credential is explicit external block and secret-free');
const tokenShaped = validateLocalReadiness({ contract, worktree: root, env: { [contract.credentialEnvironment]: secret } }); assert.equal(tokenShaped.state, 'LOCAL_READY_OWNER_PREFLIGHT_REQUIRED'); assert.equal(tokenShaped.credential_present, true); assert(!JSON.stringify(tokenShaped).includes(secret)); pass('token shape never creates a readiness green');
const launch = buildRestrictedLaunch({ contract, worktree: root }); assert(launch.command.endsWith('m3-restricted-launcher.cmd')); assert(path.isAbsolute(launch.command)); assert.equal(launch.cwd, root); assert(renderTunnelInit({ contract, worktree: root }).includes(launch.command.replaceAll('\\', '/'))); pass('restricted launcher remains checkout-bound');
assert.match(local.owner_preflight.prepare, /m3-owner-preflight\.cjs/); assert.match(local.owner_preflight.run, /m3-owner-run\.cjs/); assert.equal(local.checkout_head.length, 40); pass('owner handoff requires sealed prepare then byte-checked run');
const sandbox = fs.mkdtempSync(path.join(os.tmpdir(), 'lnwjud-m3-sealed-')); const client = path.join(sandbox, 'tunnel-client.exe'); fs.writeFileSync(client, 'stub'); const calls = [];
function fakeExec(command, args) { calls.push({ command, args: [...args] }); if (args[0] === 'init') { const dir = args[args.indexOf('--profile-dir') + 1]; const profile = args[args.indexOf('--profile') + 1]; fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(path.join(dir, `${profile}.yaml`), `config_version: 1\ncontrol_plane: { tunnel_id: "tunnel_0123456789abcdef0123456789abcdef", api_key: "env:CONTROL_PLANE_API_KEY" }\nmcp: { commands: [ { channel: main, command: "${launch.command.replaceAll('\\', '/')}" } ] }\n`); } }
const safeEnv = { CONTROL_PLANE_API_KEY: secret, MCP_COMMAND: 'D:/untrusted.cmd', TUNNEL_CLIENT_PROFILE_FILE: 'D:/untrusted.yaml' };
const options = parsePreflight(['--tunnel-client', client, '--tunnel-id', 'tunnel_0123456789abcdef0123456789abcdef']);
// The fake init proves the sole runtime command originates from trusted --mcp-command, not any YAML text.
const evidence = prepare({ options, env: safeEnv, worktree: root, execFile: fakeExec, runtimeRoot: sandbox });
assert.equal(calls.length, 2); assert.equal(calls[0].args[calls[0].args.indexOf('--mcp-command') + 1], launch.command.replaceAll('\\', '/')); assert.equal(calls[0].args.includes('--profile-file'), false); assert.equal(calls[1].args[0], 'doctor'); assert.equal(calls[1].args[1], '--profile-file'); assert.equal(calls[1].args[2], evidence.artifact); pass('flow, quoted, and decoy owner YAML never enter the effective launch path');
let spawns = 0; const fakeSpawn = (command, args, options) => { spawns += 1; return { command, args, options }; };
const runOptions = { tunnelClient: client }; const runSpec = prepareRun({ options: runOptions, env: safeEnv, worktree: root, runtimeRoot: sandbox }); assert.equal(runSpec.args[0], 'run'); assert.equal(runSpec.args[1], '--profile-file'); assert.equal(runSpec.env.MCP_COMMAND, undefined); assert.equal(runSpec.env.TUNNEL_CLIENT_PROFILE_FILE, undefined); runMain(['--tunnel-client', client], safeEnv, root, fakeSpawn, sandbox); assert.equal(spawns, 1); pass('unchanged sealed artifact reaches only local launch preparation');
fs.appendFileSync(evidence.artifact, '# mutation'); assert.throws(() => runMain(['--tunnel-client', client], safeEnv, root, fakeSpawn, sandbox), /validated launch bytes/); assert.equal(spawns, 1); pass('post-preflight mutation denies before child spawn');
fs.writeFileSync(evidence.artifact, 'replacement'); assert.throws(() => runMain(['--tunnel-client', client], safeEnv, root, fakeSpawn, sandbox), /validated launch bytes/); assert.equal(spawns, 1); pass('post-preflight replacement denies before child spawn');
fs.rmSync(sandbox, { recursive: true, force: true });
assert.throws(() => validateLocalReadiness({ contract, worktree: root, env: { LNWJUD_UNRESTRICTED: '1' } }), /unsafe upstream environment/); pass('unrestricted upstream mode denied');
assert.throws(() => validateLocalReadiness({ contract, worktree: root, env: { LNWJUD_SOURCE_ROOT: 'D:\\untrusted-upstream' } }), /unsafe upstream environment/); pass('untrusted source override denied');
const override = spawnSync(process.execPath, [path.join(root, 'tools', 'lnwjud', 'ea-lab-gateway.cjs')], { env: { ...process.env, LNWJUD_SOURCE_ROOT: 'D:\\untrusted-upstream' }, encoding: 'utf8' }); assert.notEqual(override.status, 0); assert.match(`${override.stdout}${override.stderr}`, /override is forbidden/); pass('gateway rejects untrusted source before upstream loading');
rejects((x) => { x.listener = 'HTTP'; }, /listeners are forbidden/); rejects((x) => { x.transport = 'INBOUND_HTTP'; }, /outbound stdio/); rejects((x) => { x.launcher = '../evil.cmd'; }, /relative non-traversal/); rejects((x) => { x.upstream_source_root = 'D:\\untrusted'; }, /approved source root/); rejects((x) => { x.runtime_root = 'D:\\EA_LAB_CONTROL\\nested\\bad'; }, /direct child/); rejectsReadiness((x) => { x.canonical_base_sha = '0'.repeat(40); }, /worktree is outside canonical-base lineage/); rejects((x) => { x.activation = 'AUTO'; }, /owner-required/);
process.stdout.write(`RESULT: ${passed} PASS\n`);
