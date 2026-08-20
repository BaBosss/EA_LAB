#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const { buildPackage, renderPrompt } = require('./delegation-package.cjs');
const worktree = path.resolve(__dirname, '..', '..');
const base = {
  task_id: 'M7-CONTROL-PLANE-CONTEXT', role: 'EA-WORKER', model: 'qwen', runtime_forecast: 'NORMAL <=30m', objective: 'Prepare bounded M7 evidence context.',
  expected_worktree_head_sha: require('node:child_process').execFileSync('git', ['rev-parse', 'HEAD'], { cwd: worktree, encoding: 'utf8' }).trim(), worktree,
  allowed_paths: ['tools/lnwjud/'], forbidden_paths: ['.env', 'PROJECT_STATE.md', 'AGENTS.md', 'AGENT_TASKBOARD.md', 'ea_template/', 'portfolio/'],
  authority: { allow_push: false, allow_deploy: false, allow_trade: false, allow_risk_change: false, allow_shutdown: false }, hard_stops: ['no_deploy', 'no_trade', 'no_live', 'no_risk_change', 'no_push', 'no_history_rewrite', 'no_shutdown'],
  relevant_files: [{ path: 'tools/lnwjud/ea-lab-gateway.cjs', symbols: ['READ_TOOLS', 'METADATA_TOOLS'] }, { path: 'tools/lnwjud/test-gateway.cjs', symbols: ['connect', 'assertDenied'] }],
  bounded_callers: ['tools/lnwjud/test-gateway.cjs'], affected_tests: ['tools/lnwjud/test-gateway.cjs', 'tools/lnwjud/test-delegation-package.cjs'],
  known_accepted_evidence: ['M0-M5 PASS; M3 BLOCKED(E); 45 security checks PASS'], model_roi: { unique_output: 'M7 context contract', downstream_skip: 'no manual prompt rediscovery', direct_consumer: 'M7 control-plane integration' },
  acceptance: ['exact SHA', 'bounded scope', 'tests supplied'], return_format: 'PASS/BLOCKED with exact evidence'
};
function rejects(change, pattern) { const spec = structuredClone(base); change(spec); assert.throws(() => buildPackage(spec), pattern); }
const pkg = buildPackage(base); const prompt = renderPrompt(pkg);
const codexPkg = buildPackage({ ...base, model: 'codex' });
const staleSpec = { ...base, worktree: path.resolve(worktree, '..', 'lnwjud-execution-plane-20260820'), expected_worktree_head_sha: '0'.repeat(40) };
assert.equal(pkg.provenance.expected_worktree_head_sha, base.expected_worktree_head_sha); assert(prompt.includes('LOOP_BREAKER=')); assert(prompt.includes('M5_ROUTE=')); assert(prompt.includes('CANONICAL_BASE_SHA=')); assert(prompt.includes('DIRECT_CONSUMER=')); assert(prompt.includes('CALLERS='));
assert.equal(codexPkg.model, 'codex');
assert.throws(() => buildPackage(staleSpec), /trusted worktree/);
const regenerated = buildPackage({ ...base, worktree, expected_worktree_head_sha: base.expected_worktree_head_sha });
assert(renderPrompt(regenerated).includes(`HEAD=${base.expected_worktree_head_sha}`));
rejects((x) => { x.expected_worktree_head_sha = '0'.repeat(40); }, /stale worktree HEAD/);
rejects((x) => { x.worktree = path.resolve(worktree, '..', 'lnwjud-execution-plane-20260820'); }, /trusted worktree/);
rejects((x) => { x.canonical_base_sha = 'NOT-A-SHA'; }, /40-character SHA/);
rejects((x) => { x.canonical_base_sha = '0'.repeat(40); }, /canonical base provenance/);
assert.equal(buildPackage(base, { canonical_base_sha: '0'.repeat(40), worktree: 'D:\\EA_LAB', allowed_paths: ['tools/'], forbidden_paths: [], authority: {}, hard_stops: [] }).provenance.canonical_base_sha, 'f399615afe36505c1f111ced817e56dc50d5b42d');
rejects((x) => { x.trustedParentContext = { canonical_base_sha: '0'.repeat(40) }; }, /untrusted child may not supply parent context/);
rejects((x) => { x.relevant_files = [{ path: 'AGENTS.md', symbols: ['x'] }]; }, /out-of-scope/);
rejects((x) => { x.bounded_callers = ['AGENTS.md']; }, /out-of-scope/);
rejects((x) => { x.allowed_paths = ['tools/']; }, /exceed the parent scope/);
rejects((x) => { x.parent_authority = { allow_push: true }; }, /may not supply parent/);
rejects((x) => { x.allowed_paths = ['tools/lnwjud-evil/']; }, /exceed the parent scope/);
rejects((x) => { x.forbidden_paths = ['.env']; }, /drop a parent restriction/);
rejects((x) => { x.authority.allow_push = true; }, /authority (escalation|propagation)/);
rejects((x) => { x.authority.unknown = false; }, /authority escalation/);
rejects((x) => { delete x.authority.allow_shutdown; }, /authority propagation/);
rejects((x) => { x.model = 'arbitrary'; }, /model must be codex or qwen/);
rejects((x) => { x.hard_stops = x.hard_stops.filter((item) => item !== 'no_shutdown'); }, /hard stops/);
rejects((x) => { x.relevant_files = [{ path: 'tools/lnwjud/fixtures/.env', symbols: ['x'] }]; }, /out-of-scope/);
rejects((x) => { x.relevant_files = [{ path: 'tools/lnwjud/ea-lab-gateway.cjs', symbols: ['missingSymbol'] }]; }, /symbol/);
rejects((x) => { x.acceptance = []; }, /acceptance/);
rejects((x) => { x.model_roi.direct_consumer = ''; }, /direct_consumer/);
console.log('RESULT: 19 PASS');
