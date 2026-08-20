#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
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
assert.equal(contract.tunnelClientSha256, '6649169733686805ca16cccd91774594d0c017fd729c37ad4ce1cd18323d9ae8'); assert.equal(contract.tunnelClientVersion, 'v0.0.12'); assert.equal(contract.tunnelClientSourceRef, 'https://github.com/openai/tunnel-client/releases/tag/v0.0.12'); pass('loadContract returns the exact approved tunnel-client identity');
assert.equal(local.state, 'LOCAL_READY_OWNER_PREFLIGHT_REQUIRED'); assert.equal(local.external_state, 'BLOCKED(E)'); assert.equal(local.listener, 'NONE'); assert(!JSON.stringify(local).includes(secret)); pass('no credential is explicit external block and secret-free');
const tokenShaped = validateLocalReadiness({ contract, worktree: root, env: { [contract.credentialEnvironment]: secret } }); assert.equal(tokenShaped.state, 'LOCAL_READY_OWNER_PREFLIGHT_REQUIRED'); assert.equal(tokenShaped.credential_present, true); assert(!JSON.stringify(tokenShaped).includes(secret)); pass('token shape never creates a readiness green');
const launch = buildRestrictedLaunch({ contract, worktree: root }); assert(launch.command.endsWith('m3-restricted-launcher.cmd')); assert(path.isAbsolute(launch.command)); assert.equal(launch.cwd, root); assert(renderTunnelInit({ contract, worktree: root }).includes(launch.command.replaceAll('\\', '/'))); pass('restricted launcher remains checkout-bound');
assert.match(local.owner_preflight.prepare, /m3-owner-preflight\.cjs/); assert.match(local.owner_preflight.run, /m3-owner-run\.cjs/); assert.equal(local.checkout_head.length, 40); pass('owner handoff requires sealed prepare then byte-checked run');
function freshClient(bytes = 'stub') { const sandbox = fs.mkdtempSync(path.join(os.tmpdir(), 'lnwjud-m3-sealed-')); const client = path.join(sandbox, 'tunnel-client.exe'); fs.writeFileSync(client, bytes); return { sandbox, client }; }
function clientSha256(file) { return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'); }
function initExec(mcpCommand) { const calls = []; const exec = (command, args) => { calls.push({ command, args: [...args] }); if (args[0] === 'init') { const dir = args[args.indexOf('--profile-dir') + 1]; const profile = args[args.indexOf('--profile') + 1]; fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(path.join(dir, `${profile}.yaml`), `config_version: 1\ncontrol_plane: { tunnel_id: "tunnel_0123456789abcdef0123456789abcdef", api_key: "env:CONTROL_PLANE_API_KEY" }\nmcp: { commands: [ { channel: main, command: "${mcpCommand}" } ] }\n`); } }; exec.calls = calls; return exec; }
const safeEnv = { CONTROL_PLANE_API_KEY: secret, MCP_COMMAND: 'D:/untrusted.cmd', TUNNEL_CLIENT_PROFILE_FILE: 'D:/untrusted.yaml' };

const primary = freshClient(); const primarySha = clientSha256(primary.client); const boundContract = { ...contract, tunnelClientSha256: primarySha };
const fakeExec = initExec(launch.command.replaceAll('\\', '/'));
const options = parsePreflight(['--tunnel-client', primary.client, '--tunnel-id', 'tunnel_0123456789abcdef0123456789abcdef']);
// The fake init proves the sole runtime command originates from trusted --mcp-command, not any YAML text.
const evidence = prepare({ options, env: safeEnv, worktree: root, execFile: fakeExec, runtimeRoot: primary.sandbox, contract: boundContract });
assert.equal(fakeExec.calls.length, 2); assert.equal(fakeExec.calls[0].args[fakeExec.calls[0].args.indexOf('--mcp-command') + 1], launch.command.replaceAll('\\', '/')); assert.equal(fakeExec.calls[0].args.includes('--profile-file'), false); assert.equal(fakeExec.calls[1].args[0], 'doctor'); assert.equal(fakeExec.calls[1].args[1], '--profile-file'); assert.equal(fakeExec.calls[1].args[2], evidence.artifact); assert.equal(evidence.tunnel_client_sha256, primarySha); pass('flow, quoted, and decoy owner YAML never enter the effective launch path');

let spawns = 0; const fakeSpawn = (command, args, options) => { spawns += 1; return { command, args, options }; };
const runOptions = { tunnelClient: primary.client };
const runSpec = prepareRun({ options: runOptions, env: safeEnv, worktree: root, runtimeRoot: primary.sandbox, contract: boundContract }); assert.equal(runSpec.args[0], 'run'); assert.equal(runSpec.args[1], '--profile-file'); assert.equal(runSpec.env.MCP_COMMAND, undefined); assert.equal(runSpec.env.TUNNEL_CLIENT_PROFILE_FILE, undefined);
runMain(['--tunnel-client', primary.client], safeEnv, root, fakeSpawn, primary.sandbox, boundContract); assert.equal(spawns, 1); pass('unchanged sealed artifact and approved binary reach only local launch preparation');
fs.appendFileSync(evidence.artifact, '# mutation'); assert.throws(() => runMain(['--tunnel-client', primary.client], safeEnv, root, fakeSpawn, primary.sandbox, boundContract), /validated launch bytes/); assert.equal(spawns, 1); pass('post-preflight mutation denies before child spawn');
fs.writeFileSync(evidence.artifact, 'replacement'); assert.throws(() => runMain(['--tunnel-client', primary.client], safeEnv, root, fakeSpawn, primary.sandbox, boundContract), /validated launch bytes/); assert.equal(spawns, 1); pass('post-preflight replacement denies before child spawn');

// Re-seal a clean, fresh-timestamped artifact for the freshness and identity probes below.
function reseal() { return prepare({ options, env: safeEnv, worktree: root, execFile: fakeExec, runtimeRoot: primary.sandbox, contract: boundContract }); }
reseal();
function withEvidence(mutate) { const file = path.join(primary.sandbox, 'm3-tunnel-state.json'); const value = JSON.parse(fs.readFileSync(file, 'utf8')); mutate(value); fs.writeFileSync(file, JSON.stringify(value)); }
function withGeneratedAtOffset(offsetMs) { withEvidence((value) => { value.generated_at = new Date(Date.now() + offsetMs).toISOString(); }); }
function denyOnRun(label) { assert.throws(() => runMain(['--tunnel-client', primary.client], safeEnv, root, fakeSpawn, primary.sandbox, boundContract), /preflight evidence is stale/); assert.equal(spawns, 1); pass(label); }

// two-sided freshness: fail-closed in both directions, before child creation
withGeneratedAtOffset(-20 * 60 * 1000); denyOnRun('past -20m evidence denies before child spawn');
withGeneratedAtOffset(2 * 60 * 1000); denyOnRun('future +2m evidence denies before child spawn');
withGeneratedAtOffset(24 * 3600 * 1000); denyOnRun('future +24h evidence denies before child spawn');
withGeneratedAtOffset(10 * 365 * 24 * 3600 * 1000); denyOnRun('future +10y evidence denies before child spawn');
withEvidence((value) => { value.generated_at = 'not-a-timestamp'; }); denyOnRun('malformed generated_at denies before child spawn');
withEvidence((value) => { delete value.generated_at; }); denyOnRun('missing generated_at denies before child spawn');
withGeneratedAtOffset(-5 * 60 * 1000); { const spec = prepareRun({ options: runOptions, env: safeEnv, worktree: root, runtimeRoot: primary.sandbox, contract: boundContract }); assert.equal(spec.args[0], 'run'); } pass('recent evidence (-5m) still passes freshness');
withGeneratedAtOffset(30 * 1000); { const spec = prepareRun({ options: runOptions, env: safeEnv, worktree: root, runtimeRoot: primary.sandbox, contract: boundContract }); assert.equal(spec.args[0], 'run'); } pass('small future skew (+30s) still passes freshness within the accepted tolerance');
reseal();

// trusted tunnel-client identity: only a repository-pinned SHA-256 is authority, never a self-derived one
// Production m3-remote-contract.json is now bound (LNWJUD M3 tunnel-client identity binding); this fixture
// contract overrides tunnelClientSha256 back to null so the fail-closed UNBOUND path stays covered.
const unboundContract = { ...contract, tunnelClientSha256: null };
assert.throws(() => prepare({ options, env: safeEnv, worktree: root, execFile: fakeExec, runtimeRoot: primary.sandbox, contract: unboundContract }), /TUNNEL_CLIENT_IDENTITY_UNBOUND/); pass('preflight fails closed when no approved tunnel-client identity is configured');
assert.throws(() => prepareRun({ options: runOptions, env: safeEnv, worktree: root, runtimeRoot: primary.sandbox, contract: unboundContract }), /TUNNEL_CLIENT_IDENTITY_UNBOUND/); pass('run fails closed when no approved tunnel-client identity is configured');
const rogue = freshClient('an-unapproved-binary');
assert.throws(() => prepare({ options: { tunnelClient: rogue.client, tunnelId: options.tunnelId }, env: safeEnv, worktree: root, execFile: fakeExec, runtimeRoot: primary.sandbox, contract: boundContract }), /not the approved identity/); pass('preflight refuses an executable path whose bytes do not match the approved hash');
assert.throws(() => prepareRun({ options: { tunnelClient: rogue.client }, env: safeEnv, worktree: root, runtimeRoot: primary.sandbox, contract: boundContract }), /not the approved identity/); assert.equal(spawns, 1); pass('run refuses an executable path whose bytes do not match the approved hash, zero spawn');
const originalPrimaryBytes = fs.readFileSync(primary.client);
fs.writeFileSync(primary.client, 'swapped-after-preflight');
assert.throws(() => prepareRun({ options: runOptions, env: safeEnv, worktree: root, runtimeRoot: primary.sandbox, contract: boundContract }), /not the approved identity/); assert.equal(spawns, 1); pass('tunnel-client binary replaced after preflight denies before spawn');
fs.writeFileSync(primary.client, originalPrimaryBytes);
fs.rmSync(primary.sandbox, { recursive: true, force: true });
fs.rmSync(rogue.sandbox, { recursive: true, force: true });
assert.throws(() => validateLocalReadiness({ contract, worktree: root, env: { LNWJUD_UNRESTRICTED: '1' } }), /unsafe upstream environment/); pass('unrestricted upstream mode denied');
assert.throws(() => validateLocalReadiness({ contract, worktree: root, env: { LNWJUD_SOURCE_ROOT: 'D:\\untrusted-upstream' } }), /unsafe upstream environment/); pass('untrusted source override denied');
const override = spawnSync(process.execPath, [path.join(root, 'tools', 'lnwjud', 'ea-lab-gateway.cjs')], { env: { ...process.env, LNWJUD_SOURCE_ROOT: 'D:\\untrusted-upstream' }, encoding: 'utf8' }); assert.notEqual(override.status, 0); assert.match(`${override.stdout}${override.stderr}`, /override is forbidden/); pass('gateway rejects untrusted source before upstream loading');
rejects((x) => { x.listener = 'HTTP'; }, /listeners are forbidden/); rejects((x) => { x.transport = 'INBOUND_HTTP'; }, /outbound stdio/); rejects((x) => { x.launcher = '../evil.cmd'; }, /relative non-traversal/); rejects((x) => { x.upstream_source_root = 'D:\\untrusted'; }, /approved source root/); rejects((x) => { x.runtime_root = 'D:\\EA_LAB_CONTROL\\nested\\bad'; }, /direct child/); rejectsReadiness((x) => { x.canonical_base_sha = '0'.repeat(40); }, /worktree is outside canonical-base lineage/); rejects((x) => { x.activation = 'AUTO'; }, /owner-required/);
process.stdout.write(`RESULT: ${passed} PASS\n`);
