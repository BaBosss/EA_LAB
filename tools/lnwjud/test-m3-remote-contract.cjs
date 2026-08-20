#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { loadContract, buildRestrictedLaunch, renderTunnelInit, validateLocalReadiness } = require('./m3-remote-contract.cjs');
const root = path.resolve(__dirname, '..', '..');
const contractPath = path.join(__dirname, 'm3-remote-contract.json');
const base = JSON.parse(fs.readFileSync(contractPath, 'utf8'));
const { restrictedChild } = require('./m3-restricted-launcher.cjs');
const { validateProfile } = require('./m3-owner-preflight.cjs');
const secret = 'synthetic-m3-token-not-a-real-secret'; let passed = 0;
function pass(name) { passed += 1; process.stdout.write(`[PASS] ${name}\n`); }
function temporary(change) { const file = path.join(os.tmpdir(), `lnwjud-m3-${process.pid}-${Date.now()}-${Math.random().toString(16).slice(2)}.json`); const value = structuredClone(base); change(value); fs.writeFileSync(file, JSON.stringify(value), 'utf8'); return file; }
function rejects(change, pattern) { const file = temporary(change); try { assert.throws(() => loadContract(file), pattern); pass(pattern.source); } finally { fs.rmSync(file, { force: true }); } }
function rejectsReadiness(change, pattern) { const file = temporary(change); try { assert.throws(() => validateLocalReadiness({ contract: loadContract(file), worktree: root, env: {} }), pattern); pass(pattern.source); } finally { fs.rmSync(file, { force: true }); } }
const contract = loadContract();
const local = validateLocalReadiness({ contract, worktree: root, env: {} });
assert.equal(local.state, 'LOCAL_READY_OWNER_PREFLIGHT_REQUIRED'); assert.equal(local.external_state, 'BLOCKED(E)'); assert.equal(local.listener, 'NONE'); assert.equal(local.credential_present, false); assert(!JSON.stringify(local).includes(secret)); pass('no credential is explicit external block and secret-free');
const tokenShaped = validateLocalReadiness({ contract, worktree: root, env: { [contract.credentialEnvironment]: secret } });
assert.equal(tokenShaped.state, 'LOCAL_READY_OWNER_PREFLIGHT_REQUIRED'); assert.equal(tokenShaped.credential_present, true); assert(!JSON.stringify(tokenShaped).includes(secret)); pass('token shape never creates a readiness green');
const launch = buildRestrictedLaunch({ contract, worktree: root }); assert(launch.command.endsWith('m3-restricted-launcher.cmd')); assert(path.isAbsolute(launch.command)); assert(path.isAbsolute(launch.policy_path)); assert.equal(launch.cwd, root); assert(renderTunnelInit({ contract, worktree: root }).includes(launch.command.replaceAll('\\', '/'))); pass('profile command is the absolute restricted launcher');
assert.equal(local.checkout_head.length, 40); assert.match(local.owner_preflight.doctor, /doctor --profile ea-lab-lnwjud-m3/); assert.match(local.owner_preflight.run, /mcp\.connection-max-ttl/); assert.match(local.owner_action, /OpenAI Secure MCP tunnel-client/); pass('owner handoff names exact profile, commands, and frozen head');
const profile = `tunnel_id: "tunnel_owner_value"\napi_key: "env:${contract.credentialEnvironment}"\ncommand: "${launch.command.replaceAll('\\', '/')}"\n`; validateProfile(profile, contract, launch); assert.throws(() => validateProfile(profile.replace(contract.credentialEnvironment, 'OTHER_KEY'), contract, launch), /restricted M3/); pass('profile validator couples client credential and launcher');
const child = restrictedChild({ worktree: root, env: { [contract.credentialEnvironment]: secret, CONTROL_PLANE_API_KEY: secret, LNWJUD_UNRESTRICTED: undefined, LNWJUD_SOURCE_ROOT: contract.upstreamSourceRoot, EA_LAB_APPROVED_WORKTREE: 'D:\\wrong', LNWJUD_DATA_PATH: 'D:\\wrong' } });
assert.equal(child.env.LNWJUD_UNRESTRICTED, undefined); assert.equal(child.env.CONTROL_PLANE_API_KEY, undefined); assert.equal(child.env[contract.credentialEnvironment], undefined); assert.equal(child.env.LNWJUD_SOURCE_ROOT, contract.upstreamSourceRoot); assert.equal(child.env.EA_LAB_APPROVED_WORKTREE, root); assert.equal(child.env.LNWJUD_DATA_PATH, contract.runtimeRoot); assert.deepEqual(child.args.slice(1), ['--policy', launch.policy_path]); pass('child environment is pinned and credential-free');
assert.throws(() => validateLocalReadiness({ contract, worktree: root, env: { LNWJUD_UNRESTRICTED: '1' } }), /unsafe upstream environment/); pass('unrestricted upstream mode denied');
assert.throws(() => validateLocalReadiness({ contract, worktree: root, env: { LNWJUD_SOURCE_ROOT: 'D:\\untrusted-upstream' } }), /unsafe upstream environment/); pass('untrusted source override denied');
const override = spawnSync(process.execPath, [path.join(root, 'tools', 'lnwjud', 'ea-lab-gateway.cjs')], { env: { ...process.env, LNWJUD_SOURCE_ROOT: 'D:\\untrusted-upstream' }, encoding: 'utf8' });
assert.notEqual(override.status, 0); assert.match(`${override.stdout}${override.stderr}`, /override is forbidden/); pass('gateway rejects untrusted source before upstream loading');
rejects((x) => { x.listener = 'HTTP'; }, /listeners are forbidden/); rejects((x) => { x.transport = 'INBOUND_HTTP'; }, /outbound stdio/); rejects((x) => { x.launcher = '../evil.cmd'; }, /relative non-traversal/); rejects((x) => { x.upstream_source_root = 'D:\\untrusted'; }, /approved source root/); rejects((x) => { x.runtime_root = 'D:\\EA_LAB_CONTROL\\nested\\bad'; }, /direct child/); rejectsReadiness((x) => { x.canonical_base_sha = '0'.repeat(40); }, /worktree is outside canonical-base lineage/); rejects((x) => { x.activation = 'AUTO'; }, /owner-required/);
process.stdout.write(`RESULT: ${passed} PASS\n`);
