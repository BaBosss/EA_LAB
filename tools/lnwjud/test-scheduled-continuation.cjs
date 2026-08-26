#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const { buildContinuation, stableJson } = require('./scheduled-continuation.cjs');

let passed = 0;
function pass(name) { passed += 1; process.stdout.write(`[PASS] ${name}\n`); }
function rejects(spec, source, pattern, name) {
  assert.throws(() => buildContinuation(spec, source), pattern);
  pass(name);
}

const hardStops = ['no_deploy', 'no_trade', 'no_live', 'no_risk_change', 'no_history_rewrite'];
const source = {
  package: {
    schema_version: 1,
    task_id: 'ORDER-SCHEDULED-CONTINUATION',
    provenance: {
      canonical_base_sha: 'a'.repeat(40),
      expected_worktree_head_sha: 'b'.repeat(40),
      worktree: 'D:\\EA_LAB_worktrees\\lane',
      branch: 'lane'
    },
    scope: {
      allowed_paths: ['tools/lnwjud'],
      forbidden_paths: ['_vps_deploy'],
      authority: { hard_stops: hardStops }
    },
    acceptance: ['focused tests pass', 'no runtime cutover']
  }
};
const spec = {
  schema_version: 1,
  task_id: 'ORDER-SCHEDULED-CONTINUATION',
  scheduled_base_sha: 'c'.repeat(40),
  lane_id: 'lnwjud-scheduled-continuation-20260826',
  job_id: 'job-001',
  evidence_paths: ['DUMMY_RELATIVE_STATUS.json'.replace('DUMMY_', 'status/')],
  completion_predicates: ['job terminal COMPLETE', 'acceptance evidence present'],
  check_minutes: 25,
  max_iterations: 8,
  authority: 'NO_NEW_AUTHORITY'
};

const first = buildContinuation(spec, source);
const second = buildContinuation(structuredClone(spec), structuredClone(source));
assert.equal(stableJson(first), stableJson(second));
assert.equal(first.prompt_sha256.length, 64);
assert.equal(first.task_contract_sha256.length, 64);
pass('same inputs produce byte-stable semantic output and hashes');

assert.equal(first.behavior.on_running, 'DO_NOT_DUPLICATE');
assert.equal(first.behavior.on_complete, 'STOP');
assert.equal(first.behavior.on_origin_move, 'REANCHOR_ISOLATED_AND_RERUN_IMPACTED_ACCEPTANCE');
assert(first.hard_stops.includes('no_runtime_cutover'));
assert.match(first.prompt, /do not duplicate it/i);
assert.match(first.prompt, /scheduling grants NO NEW AUTHORITY/);
assert.match(first.prompt, /Never activate, restart, attach, or cut over the M3 Secure Tunnel/);
pass('continuation is resume-only and cannot activate M3 runtime');
rejects({ ...spec, authority: 'AUTO' }, source, /NO_NEW_AUTHORITY/, 'authority escalation is refused');
rejects({ ...spec, task_id: 'OTHER-TASK' }, source, /does not match/, 'task contract mismatch is refused');
rejects({ ...spec, evidence_paths: ['../secret.txt'] }, source, /non-traversal/, 'path traversal is refused');
rejects({ ...spec, evidence_paths: ['credentials/token.txt'] }, source, /credential material/, 'credential material path is refused');
rejects({ ...spec, completion_predicates: [] }, source, /1\.\.16/, 'empty completion predicate set is refused');
rejects({ ...spec, check_minutes: 4 }, source, /5\.\.180/, 'too-fast cadence hint is refused');
rejects({ ...spec, max_iterations: 25 }, source, /1\.\.24/, 'unbounded iteration count is refused');
rejects({ ...spec, surprise: 'hidden data' }, source, /unknown spec field/, 'unknown input fields are refused');

const noJob = buildContinuation({ ...spec, job_id: null }, source);
assert.equal(noJob.state_sources.job_id, null);
assert(!noJob.prompt.includes('JOB=null'));
pass('job id is optional without weakening lane/evidence binding');

const changedPackage = structuredClone(source);
changedPackage.package.acceptance.push('one more gate');
const changed = buildContinuation(spec, changedPackage);
assert.notEqual(changed.task_contract_sha256, first.task_contract_sha256);
pass('task-contract fingerprint changes when acceptance changes');

assert(!JSON.stringify(first).match(/OPENAI_API_KEY|CONTROL_PLANE_API_KEY|token-not-a-real-secret/));
pass('artifact contains no credential channel or injected secret value');

process.stdout.write(`RESULT: ${passed} PASS\n`);
