#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { loadContract, validateLocalReadiness } = require('./m3-remote-contract.cjs');

const root = path.resolve(__dirname, '..', '..');
const contractPath = path.join(__dirname, 'm3-remote-contract.json');
const base = JSON.parse(fs.readFileSync(contractPath, 'utf8'));
const secret = 'synthetic-m3-token-not-a-real-secret';
let passed = 0;
function pass(name) { passed += 1; process.stdout.write(`[PASS] ${name}\n`); }
function temporary(change) {
  const file = path.join(os.tmpdir(), `lnwjud-m3-${process.pid}-${Date.now()}-${Math.random().toString(16).slice(2)}.json`);
  const value = structuredClone(base); change(value); fs.writeFileSync(file, JSON.stringify(value), 'utf8'); return file;
}
function rejects(change, pattern) { const file = temporary(change); try { assert.throws(() => loadContract(file), pattern); pass(pattern.source); } finally { fs.rmSync(file, { force: true }); } }
function rejectsReadiness(change, pattern) { const file = temporary(change); try { assert.throws(() => validateLocalReadiness({ contract: loadContract(file), worktree: root, env: {} }), pattern); pass(pattern.source); } finally { fs.rmSync(file, { force: true }); } }

const contract = loadContract();
const blocked = validateLocalReadiness({ contract, worktree: root, env: {} });
assert.equal(blocked.state, 'BLOCKED(E)'); assert.equal(blocked.listener, 'NONE'); assert.equal(blocked.credential_present, false); assert(!JSON.stringify(blocked).includes(secret)); pass('absent credential is fail-closed and secret-free');
const ready = validateLocalReadiness({ contract, worktree: root, env: { [contract.credentialEnvironment]: secret } });
assert.equal(ready.state, 'READY_FOR_OWNER_ACTIVATION'); assert.equal(ready.credential_present, true); assert(!JSON.stringify(ready).includes(secret)); assert.deepEqual(ready.gateway_command, ['node', 'tools/lnwjud/ea-lab-gateway.cjs', '--policy', 'tools/lnwjud/ea-lab-policy.json']); pass('credential is presence-only and gateway is exact');
assert.throws(() => validateLocalReadiness({ contract, worktree: root, env: { [contract.credentialEnvironment]: secret, LNWJUD_UNRESTRICTED: '1' } }), /unrestricted upstream mode/); pass('unrestricted upstream mode denied');
rejects((x) => { x.listener = 'HTTP'; }, /listeners are forbidden/);
rejects((x) => { x.transport = 'INBOUND_HTTP'; }, /outbound stdio/);
rejects((x) => { x.gateway_command[1] = 'tools/lnwjud/evil.cjs'; }, /gateway_command/);
rejects((x) => { x.gateway_policy = '../ea-lab-policy.json'; }, /relative non-traversal/);
rejectsReadiness((x) => { x.canonical_base_sha = '0'.repeat(40); }, /worktree is outside canonical-base lineage/);
rejects((x) => { x.activation = 'AUTO'; }, /owner-required/);
process.stdout.write(`RESULT: ${passed} PASS\n`);
