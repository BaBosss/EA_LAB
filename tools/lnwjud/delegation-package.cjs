#!/usr/bin/env node
'use strict';

const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const REQUIRED_ROUTE = ['git_status', 'workspace_index_status', 'route_intent', 'tool_dynamic_filter', 'symbol_search', 'workspace_context'];
const REQUIRED_HARD_STOPS = ['no_deploy', 'no_trade', 'no_live', 'no_risk_change', 'no_push', 'no_history_rewrite'];
const TRUSTED_PARENT_PATH = path.join(__dirname, 'delegation-trusted-parent.json');

function rel(value) {
  if (typeof value !== 'string' || value.trim() === '') throw new Error('path is required');
  const normalized = value.replaceAll('\\', '/');
  if (path.win32.isAbsolute(value) || normalized.startsWith('/') || normalized.split('/').includes('..')) throw new Error(`path escape: ${value}`);
  return normalized.replace(/^\.\//, '');
}
function prefix(value, parent) { const base = parent.replace(/\/+$/, ''); return value === base || value.startsWith(`${base}/`); }
function secret(value) { return /(^|\/)(\.env|id_rsa|id_ed25519|credentials|secrets?)(\.|\/|$)/i.test(value); }
function head(worktree) { return execFileSync('git', ['rev-parse', 'HEAD'], { cwd: worktree, encoding: 'utf8', windowsHide: true }).trim(); }
function trustedWorktree() { return path.resolve(__dirname, '..', '..'); }
function requireText(value, name) { if (typeof value !== 'string' || value.trim() === '') throw new Error(`${name} is required`); return value; }
function sha(value, name) { value = requireText(value, name); if (!/^[0-9a-f]{40}$/i.test(value)) throw new Error(`${name} must be a 40-character SHA`); return value.toLowerCase(); }

function trustedParent() { const value = JSON.parse(fs.readFileSync(TRUSTED_PARENT_PATH, 'utf8')); if (value?.schema_version !== 1) throw new Error('trusted parent is invalid'); return value; }
function buildPackage(spec) {
  if (Object.keys(spec).some((key) => key.startsWith('parent_')) || Object.hasOwn(spec, 'trustedParentContext') || Object.hasOwn(spec, 'trusted_parent_context')) throw new Error('untrusted child may not supply parent context');
  const parent = trustedParent();
  const canonicalBaseSha = sha(parent.canonical_base_sha, 'trusted parent canonical_base_sha');
  if (spec.canonical_base_sha !== undefined && sha(spec.canonical_base_sha, 'canonical_base_sha') !== canonicalBaseSha) throw new Error('canonical base provenance mismatch');
  const worktree = path.resolve(requireText(spec.worktree, 'worktree'));
  if (worktree.toLowerCase() !== trustedWorktree().toLowerCase()) throw new Error('child may not override the trusted worktree');
  const currentHead = head(worktree);
  if (currentHead !== requireText(spec.expected_worktree_head_sha, 'expected_worktree_head_sha')) throw new Error('stale worktree HEAD; regenerate deterministic context');
  const allowed = spec.allowed_paths.map(rel);
  const parentAllowed = parent.allowed_paths.map(rel);
  const forbidden = spec.forbidden_paths.map(rel);
  if (!allowed.every((item) => parentAllowed.some((entry) => prefix(item, entry)))) throw new Error('child allowed paths may not exceed the parent scope');
  if (!parent.forbidden_paths.map(rel).every((item) => forbidden.includes(item))) throw new Error('child forbidden paths may not drop a parent restriction');
  const parentStops = [...new Set([...parent.hard_stops, ...REQUIRED_HARD_STOPS])];
  if (!parentStops.every((item) => spec.hard_stops.includes(item))) throw new Error('child hard stops are incomplete');
  const parentAuthority = parent.authority || {};
  const allowedAuthority = new Set(['allow_push', 'allow_deploy', 'allow_trade', 'allow_risk_change', 'allow_shutdown']);
  for (const [key, value] of Object.entries(parentAuthority)) {
    if (!allowedAuthority.has(key) || typeof value !== 'boolean') throw new Error('parent authority contract is invalid');
    if (spec.authority?.[key] !== value) throw new Error('authority propagation is incomplete');
  }
  for (const [key, value] of Object.entries(spec.authority || {})) {
    if (!allowedAuthority.has(key) || typeof value !== 'boolean' || (value === true && parentAuthority[key] !== true)) throw new Error('authority escalation denied');
  }
  if (!Array.isArray(spec.acceptance) || spec.acceptance.length === 0) throw new Error('deterministic acceptance is required');
  const boundedCallers = spec.bounded_callers || [];
  for (const item of [...spec.relevant_files, ...spec.affected_tests, ...boundedCallers]) {
    const file = rel(item.path || item);
    if (secret(file) || forbidden.some((entry) => prefix(file, entry)) || !allowed.some((entry) => prefix(file, entry))) throw new Error(`out-of-scope context: ${file}`);
    if (!fs.existsSync(path.join(worktree, file))) throw new Error(`missing context file: ${file}`);
  }
  for (const item of spec.relevant_files) if (typeof item === 'object') {
    if (!Array.isArray(item.symbols) || item.symbols.length === 0) throw new Error('relevant file symbols/ranges are required');
    const source = fs.readFileSync(path.join(worktree, rel(item.path)), 'utf8');
    if (!item.symbols.every((symbol) => typeof symbol === 'string' && source.includes(symbol))) throw new Error('relevant symbol/range does not exist');
  }
  const roi = spec.model_roi || {};
  for (const key of ['unique_output', 'downstream_skip', 'direct_consumer']) requireText(roi[key], `model_roi.${key}`);
  return {
    schema_version: 1,
    task_id: requireText(spec.task_id, 'task_id'), role: requireText(spec.role, 'role'), model: (() => { const model = requireText(spec.model, 'model').toLowerCase(); if (!['codex', 'qwen'].includes(model)) throw new Error('model must be codex or qwen'); return model; })(),
    runtime_forecast: requireText(spec.runtime_forecast, 'runtime_forecast'), objective: requireText(spec.objective, 'objective'),
    provenance: { canonical_base_sha: canonicalBaseSha, expected_worktree_head_sha: currentHead, worktree, branch: execFileSync('git', ['branch', '--show-current'], { cwd: worktree, encoding: 'utf8' }).trim() },
    scope: { allowed_paths: allowed, forbidden_paths: forbidden, authority: { ...spec.authority, hard_stops: parentStops } },
    m5_context_route: REQUIRED_ROUTE,
    relevant_files: spec.relevant_files, bounded_callers: boundedCallers, affected_tests: spec.affected_tests,
    known_accepted_evidence: spec.known_accepted_evidence || [], execution_method: 'Run the M5 route in order; use primitive search only when the package says context loses.',
    investigation_budget: spec.investigation_budget || '60m', loop_breaker: spec.loop_breaker || 'Same question twice: STOP and return UNKNOWN/BLOCKED.',
    acceptance: spec.acceptance, model_roi: roi, return_format: requireText(spec.return_format, 'return_format')
  };
}
function renderPrompt(pkg) { return `TASK=${pkg.task_id}\nMODEL=${pkg.model}\nCANONICAL_BASE_SHA=${pkg.provenance.canonical_base_sha}\nHEAD=${pkg.provenance.expected_worktree_head_sha}\nWORKTREE=${pkg.provenance.worktree}\nALLOWED=${pkg.scope.allowed_paths.join(',')}\nFORBIDDEN=${pkg.scope.forbidden_paths.join(',')}\nM5_ROUTE=${pkg.m5_context_route.join(' -> ')}\nFILES=${pkg.relevant_files.map((x) => x.path || x).join(',')}\nCALLERS=${pkg.bounded_callers.map((x) => x.path || x).join(',')}\nTESTS=${pkg.affected_tests.map((x) => x.path || x).join(',')}\nEVIDENCE=${pkg.known_accepted_evidence.join(';')}\nUNIQUE_OUTPUT=${pkg.model_roi.unique_output}\nDOWNSTREAM_SKIP=${pkg.model_roi.downstream_skip}\nDIRECT_CONSUMER=${pkg.model_roi.direct_consumer}\nBUDGET=${pkg.investigation_budget}\nLOOP_BREAKER=${pkg.loop_breaker}\nHARD_STOPS=${pkg.scope.authority.hard_stops.join(',')}\nACCEPTANCE=${pkg.acceptance.join(';')}\nRETURN=${pkg.return_format}`; }

if (require.main === module) {
  const [specPath, outPath] = process.argv.slice(2);
  if (!specPath || !outPath) throw new Error('usage: delegation-package.cjs <spec.json> <out.json>');
  const pkg = buildPackage(JSON.parse(fs.readFileSync(specPath, 'utf8')));
  fs.writeFileSync(outPath, JSON.stringify({ package: pkg, prompt: renderPrompt(pkg) }, null, 2));
}
module.exports = { buildPackage, renderPrompt };
