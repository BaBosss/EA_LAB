#!/usr/bin/env node
'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const MODULE = 'LNWJUD_SCHEDULED_CONTINUATION_V1';
const REQUIRED_HARD_STOPS = [
  'no_runtime_cutover',
  'no_deploy',
  'no_trade',
  'no_live',
  'no_risk_change',
  'no_history_rewrite'
];
const ALLOWED_SPEC_FIELDS = new Set([
  'schema_version', 'task_id', 'scheduled_base_sha', 'lane_id', 'job_id',
  'evidence_paths', 'completion_predicates', 'check_minutes', 'max_iterations',
  'authority'
]);

function fail(message) { throw new Error(`scheduled continuation refused: ${message}`); }
function text(value, name) {
  if (typeof value !== 'string' || value.trim() === '') fail(`${name} is required`);
  return value.trim();
}
function promptText(value, name) {
  const item = text(value, name).replace(/[\t-\r\u0085\u2028\u2029]+/g, ' ');
  if (/[\u0000-\u0008\u000E-\u001F\u007F-\u0084\u0086-\u009F]/.test(item)) {
    fail(`${name} contains a dangerous control character`);
  }
  return item;
}
function sha40(value, name) {
  const item = text(value, name).toLowerCase();
  if (!/^[0-9a-f]{40}$/.test(item)) fail(`${name} must be a 40-character SHA`);
  return item;
}
function safeId(value, name) {
  const item = text(value, name);
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{1,127}$/.test(item)) fail(`${name} is invalid`);
  return item;
}
function relative(value, name) {
  const item = text(value, name).replaceAll('\\', '/');
  if (path.win32.isAbsolute(value) || item.startsWith('/') || item.split('/').includes('..')) {
    fail(`${name} must be a relative non-traversal path`);
  }
  if (/(^|\/)(\.env|id_rsa|id_ed25519|credentials|secrets?)(\.|\/|$)/i.test(item)) {
    fail(`${name} may not reference credential material`);
  }
  return item.replace(/^\.\//, '');
}
function boundedInteger(value, name, min, max) {
  if (!Number.isInteger(value) || value < min || value > max) fail(`${name} must be ${min}..${max}`);
  return value;
}
function object(value, name) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) fail(`${name} must be an object`);
  return value;
}
function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonicalize(value[key])]));
  }
  return value;
}
function stableJson(value) { return JSON.stringify(canonicalize(value)); }
function digest(value) { return crypto.createHash('sha256').update(value).digest('hex'); }
function validateTaskPackage(source) {
  const wrapper = object(source, 'delegation package');
  const pkg = object(wrapper.package || wrapper, 'task package');
  if (pkg.schema_version !== 1) fail('task package schema_version must be 1');
  const taskId = safeId(pkg.task_id, 'task package task_id');
  const provenance = object(pkg.provenance, 'task package provenance');
  sha40(provenance.canonical_base_sha, 'task package canonical_base_sha');
  sha40(provenance.expected_worktree_head_sha, 'task package expected_worktree_head_sha');
  text(provenance.worktree, 'task package worktree');
  text(provenance.branch, 'task package branch');
  const scope = object(pkg.scope, 'task package scope');
  const authority = object(scope.authority, 'task package authority');
  if (!Array.isArray(authority.hard_stops)) fail('task package hard_stops are required');
  if (!Array.isArray(pkg.acceptance) || pkg.acceptance.length === 0) fail('task package acceptance is required');
  return { pkg, taskId, provenance, authority };
}

function renderPrompt(value) {
  const stateSources = [
    `LANE=${value.state_sources.lane_id}`,
    value.state_sources.job_id ? `JOB=${value.state_sources.job_id}` : null,
    `EVIDENCE=${value.state_sources.evidence_paths.join(',')}`
  ].filter(Boolean).join('\n');
  return [
    `EA_LAB SCHEDULED CONTINUATION — ${value.task_id}`,
    `MODULE=${MODULE}`,
    `SCHEDULED_BASE_SHA=${value.scheduled_base_sha}`,
    `TASK_CONTRACT_SHA256=${value.task_contract_sha256}`,
    stateSources,
    `HARD_STOPS=${value.hard_stops.join(',')}`,
    '',
    'At each scheduled iteration:',
    '1. Resolve current pushed origin/master and inspect only the durable state needed for this exact task.',
    '2. Inspect lane/job/evidence state before starting work; durable state beats chat/session memory.',
    '3. If the recorded job or writer lane is still RUNNING, do not duplicate it; only report/checkpoint.',
    '4. If every completion predicate and task acceptance item is satisfied, STOP; do not create more work.',
    '5. If origin/master moved from SCHEDULED_BASE_SHA, re-anchor in an isolated clean worktree and rerun only impacted acceptance.',
    '6. Continue only the already-approved task contract; scheduling grants NO NEW AUTHORITY.',
    '7. Never activate, restart, attach, or cut over the M3 Secure Tunnel as a side effect of continuation.',
    '8. Preserve unrelated dirty/staged/untracked work and never force-push or rewrite history.',
    `9. Re-check cadence hint: ${value.behavior.check_minutes} minutes; max continuation iterations: ${value.behavior.max_iterations}.`,
    '',
    `COMPLETION=${value.completion_predicates.join(';')}`,
    `ACCEPTANCE=${value.acceptance.join(';')}`,
    'Return PASS/COMPLETE, RUNNING/NO_DUPLICATE, or BLOCKED(<class + exact reason>).'
  ].join('\n');
}

function buildContinuation(spec, source) {
  object(spec, 'spec');
  if (Object.keys(spec).some((key) => !ALLOWED_SPEC_FIELDS.has(key))) fail('unknown spec field');
  if (spec.schema_version !== 1) fail('spec schema_version must be 1');
  if (spec.authority !== 'NO_NEW_AUTHORITY') fail('authority must remain NO_NEW_AUTHORITY');
  const { pkg, taskId, authority } = validateTaskPackage(source);
  if (safeId(spec.task_id, 'task_id') !== taskId) fail('task_id does not match delegation package');
  const evidencePaths = Array.isArray(spec.evidence_paths) ? spec.evidence_paths.map((item, i) => relative(item, `evidence_paths[${i}]`)) : fail('evidence_paths are required');
  if (evidencePaths.length === 0 || evidencePaths.length > 16) fail('evidence_paths must contain 1..16 items');
  const completion = Array.isArray(spec.completion_predicates) ? spec.completion_predicates.map((item, i) => promptText(item, `completion_predicates[${i}]`)) : fail('completion_predicates are required');
  if (completion.length === 0 || completion.length > 16) fail('completion_predicates must contain 1..16 items');
  const inheritedStops = authority.hard_stops.map((item, i) => promptText(item, `hard_stops[${i}]`));
  const hardStops = [...new Set([...inheritedStops, ...REQUIRED_HARD_STOPS])];
  const base = {
    schema_version: 1,
    module: MODULE,
    authority: 'NO_NEW_AUTHORITY',
    task_id: taskId,
    scheduled_base_sha: sha40(spec.scheduled_base_sha, 'scheduled_base_sha'),
    task_contract_sha256: digest(stableJson(pkg)),
    state_sources: {
      lane_id: safeId(spec.lane_id, 'lane_id'),
      job_id: spec.job_id === undefined || spec.job_id === null ? null : safeId(spec.job_id, 'job_id'),
      evidence_paths: evidencePaths
    },
    behavior: {
      check_minutes: boundedInteger(spec.check_minutes, 'check_minutes', 5, 180),
      max_iterations: boundedInteger(spec.max_iterations, 'max_iterations', 1, 24),
      on_running: 'DO_NOT_DUPLICATE',
      on_complete: 'STOP',
      on_origin_move: 'REANCHOR_ISOLATED_AND_RERUN_IMPACTED_ACCEPTANCE'
    },
    hard_stops: hardStops,
    completion_predicates: completion,
    acceptance: pkg.acceptance.map((item, i) => promptText(item, `acceptance[${i}]`))
  };
  const prompt = renderPrompt(base);
  return Object.freeze({ ...base, prompt, prompt_sha256: digest(prompt) });
}

function main(argv = process.argv.slice(2)) {
  if (argv.length !== 3) fail('usage: scheduled-continuation.cjs <spec.json> <delegation-package.json> <out.json>');
  const [specPath, packagePath, outPath] = argv;
  const spec = JSON.parse(fs.readFileSync(specPath, 'utf8'));
  const source = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
  const result = buildContinuation(spec, source);
  fs.writeFileSync(outPath, `${JSON.stringify(result, null, 2)}\n`, { encoding: 'utf8', flag: 'wx' });
  return result;
}

if (require.main === module) {
  try { main(); } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 2; }
}
module.exports = { MODULE, REQUIRED_HARD_STOPS, stableJson, validateTaskPackage, renderPrompt, buildContinuation, main };
