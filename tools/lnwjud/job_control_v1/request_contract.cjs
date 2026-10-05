'use strict';
// Inert source/offline envelope. No filesystem, process, Registry or provider access.
const crypto = require('node:crypto');
const { TextDecoder } = require('node:util');
class Refusal extends Error { constructor(code) { super(code); this.name = 'Refusal'; this.code = code; } }
const refuse = code => { throw new Refusal(code); };
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const stable = value => JSON.stringify(value, (_, x) => x && typeof x === 'object' && !Array.isArray(x)
  ? Object.fromEntries(Object.keys(x).sort().map(k => [k, x[k]])) : x);
const clone = value => JSON.parse(JSON.stringify(value));
const object = x => x !== null && typeof x === 'object' && !Array.isArray(x);
const id = x => typeof x === 'string' && /^[A-Za-z][A-Za-z0-9._-]{2,127}$/.test(x);
const digest = x => typeof x === 'string' && /^[a-f0-9]{64}$/.test(x);
const head = x => typeof x === 'string' && /^[a-f0-9]{40}$/.test(x);
function freeze(x) {
  if (x && typeof x === 'object') { for (const value of Object.values(x)) freeze(value); Object.freeze(x); }
  return x;
}
// UTC-only, calendar-checked, exact 100ns comparisons; never Date.parse offset guessing.
function time(value) {
  if (typeof value !== 'string') return null;
  const m = /^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})(?:\.(\d{1,7}))?Z$/.exec(value);
  if (!m) return null;
  const n = Date.parse(m[1] + 'T' + m[2] + 'Z');
  if (!Number.isFinite(n) || new Date(n).toISOString().slice(0, 19) !== m[1] + 'T' + m[2]) return null;
  return BigInt(n) * 10000n + BigInt((m[3] || '').padEnd(7, '0'));
}
function keys(value, names) {
  if (!object(value) || stable(Object.keys(value).sort()) !== stable([...names].sort())) refuse('MALFORMED_SCHEMA');
}
// Parse before conversion so escaped duplicate keys and raw-byte drift remain visible.
function parse(bytes, max = 65536) {
  if (!Buffer.isBuffer(bytes) || bytes.length === 0 || bytes.length > max) refuse('INVALID_REQUEST_BYTES');
  let s;
  try { s = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(bytes); }
  catch { refuse('INVALID_UTF8'); }
  let i = 0;
  const ws = () => { while (/[ \t\r\n]/.test(s[i] || '!')) i++; };
  function string() {
    const start = i++;
    let escaped = false;
    while (i < s.length) {
      const c = s[i++];
      if (!escaped && c === '"') {
        try { return JSON.parse(s.slice(start, i)); } catch { refuse('MALFORMED_JSON'); }
      }
      if (!escaped && c === '\\') escaped = true; else escaped = false;
    }
    refuse('MALFORMED_JSON');
  }
  function value(depth) {
    if (depth > 24) refuse('JSON_DEPTH');
    ws(); const c = s[i];
    if (c === '"') return string();
    if (c === '{') {
      i++; ws(); const out = Object.create(null), seen = new Set();
      if (s[i] === '}') { i++; return out; }
      while (i < s.length) {
        ws(); if (s[i] !== '"') refuse('MALFORMED_JSON');
        const key = string();
        if (seen.has(key) || ['__proto__', 'constructor', 'prototype'].includes(key)) refuse('DUPLICATE_OR_UNSAFE_KEY');
        seen.add(key); ws(); if (s[i++] !== ':') refuse('MALFORMED_JSON');
        out[key] = value(depth + 1); ws();
        const next = s[i++]; if (next === '}') return out; if (next !== ',') refuse('MALFORMED_JSON');
      }
    } else if (c === '[') {
      i++; ws(); const out = [];
      if (s[i] === ']') { i++; return out; }
      while (i < s.length) {
        out.push(value(depth + 1)); ws(); const next = s[i++];
        if (next === ']') return out; if (next !== ',') refuse('MALFORMED_JSON');
      }
    } else {
      const m = /^(?:true|false|null|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)/.exec(s.slice(i));
      if (m) {
        i += m[0].length; const x = JSON.parse(m[0]);
        if (typeof x === 'number' && (!Number.isFinite(x) || !Number.isSafeInteger(x) || Object.is(x, -0))) refuse('UNSAFE_NUMBER');
        return x;
      }
    }
    refuse('MALFORMED_JSON');
  }
  const result = value(0); ws(); if (i !== s.length) refuse('MALFORMED_JSON'); return result;
}
function component(c) {
  return !!c && c !== '.' && c !== '..' && !/^ |[. ]$/.test(c) &&
    !/[:?*<>"|\x00-\x1f\x7f]/.test(c) &&
    !/^(?:CON|PRN|AUX|NUL|COM[1-9\u00b9\u00b2\u00b3]|LPT[1-9\u00b9\u00b2\u00b3]|CONIN\$|CONOUT\$)(?:\.|$)/i.test(c);
}
function abs(value) {
  if (typeof value !== 'string' || value.trim() !== value) return false;
  const n = value.replaceAll('/', '\\');
  return /^[A-Za-z]:\\/.test(n) && n.slice(3).split('\\').every(component);
}
function relative(value) {
  return typeof value === 'string' && !value.includes('\\') && !value.startsWith('/') &&
    value.split('/').every(c => component(c) && c.toLowerCase() !== '.git');
}
const OPS = ['submit_existing_contract_job', 'adopt_existing_job', 'request_pause_after_stage', 'resume_existing_job'];
const BOUND = ['lane_id', 'contract_id', 'contract_sha256', 'source', 'allowlisted_paths', 'worktree',
  'resource_owner', 'acceptance_criteria', 'budget', 'direct_consumer', 'route', 'runtime_resource', 'host_id'];
const identity = r => Object.fromEntries(BOUND.map(k => [k, r[k]]));
const bindingHash = r => hash(stable(identity(r)));
function validate(bytes, env, operation) {
  const r = parse(bytes);
  keys(r, ['schema', 'request_id', 'idempotency_key', 'operation', ...BOUND, 'checkpoint', 'created_utc']);
  if (r.schema !== 'LNWJUD_JOB_CONTROL_REQUEST_V1' || !OPS.includes(r.operation) || r.operation !== operation) refuse('UNSUPPORTED_OPERATION');
  if (![r.request_id, r.idempotency_key, r.lane_id, r.contract_id].every(id)) refuse('INVALID_ID');
  if (!object(env)) refuse('MALFORMED_ENVIRONMENT');
  const now = time(env.now_utc), created = time(r.created_utc), observed = time(env.observed_utc);
  if (now === null || created === null || observed === null || created > now || observed < created || observed > now) refuse('INVALID_OR_FUTURE_TIME');
  if (!object(env.binding) || env.binding.lane_id !== r.lane_id) refuse('UNKNOWN_LANE');
  if (!Buffer.isBuffer(env.contract_bytes)) refuse('MISSING_CONTRACT');
  if (!digest(r.contract_sha256) || hash(env.contract_bytes) !== r.contract_sha256) refuse('CONTRACT_MISMATCH');
  keys(r.source, ['head', 'tree', 'config_sha256']);
  if (!head(r.source.head) || !head(r.source.tree) || !digest(r.source.config_sha256) || stable(r.source) !== stable(env.binding.source)) refuse('WRONG_SOURCE');
  keys(r.worktree, ['path', 'branch', 'git_common_root', 'identity_sha256']);
  if (!abs(r.worktree.path) || !abs(r.worktree.git_common_root) || typeof r.worktree.branch !== 'string' ||
      !/^[A-Za-z0-9._/-]+$/.test(r.worktree.branch) || r.worktree.branch.includes('..') || !digest(r.worktree.identity_sha256)) refuse('ARBITRARY_PATH');
  if (!Array.isArray(r.allowlisted_paths) || !r.allowlisted_paths.length || !r.allowlisted_paths.every(relative) ||
      new Set(r.allowlisted_paths.map(x => x.toLowerCase())).size !== r.allowlisted_paths.length) refuse('ARBITRARY_PATH');
  if (env.clean !== true) refuse('DIRTY_WORKTREE');
  if (env.path_identity_verified !== true) refuse('PATH_IDENTITY_UNPROVEN');
  if (!Array.isArray(r.acceptance_criteria) || !r.acceptance_criteria.length || !r.acceptance_criteria.every(id) ||
      new Set(r.acceptance_criteria).size !== r.acceptance_criteria.length) refuse('MISSING_ACCEPTANCE');
  keys(r.budget, ['repair', 'retry']);
  for (const name of ['repair', 'retry']) {
    if (!Number.isSafeInteger(r.budget[name]) || r.budget[name] < 0) refuse('INVALID_BUDGET');
    if (!Number.isSafeInteger(env['remaining_' + name]) || env['remaining_' + name] < 0 ||
        env['remaining_' + name] > r.budget[name]) refuse('BUDGET_LEDGER_UNPROVEN');
  }
  if (env.budget_available !== true) refuse('BUDGET_EXHAUSTED');
  keys(r.route, ['tool', 'provider']);
  if (r.route.tool !== 'EXISTING_RUNNER' || r.route.provider !== 'SYNTHETIC_FIXTURE') refuse('DISALLOWED_PROVIDER');
  if (![r.resource_owner, r.direct_consumer, r.host_id].every(id) || r.runtime_resource !== 'NOT_APPLICABLE_OFFLINE') refuse('BINDING_MISMATCH');
  if (env.resource_owner !== r.resource_owner || env.resource_available !== true) refuse('LEASED_RESOURCE');
  for (const k of BOUND) if (stable(r[k]) !== stable(env.binding[k])) refuse('BINDING_MISMATCH');
  keys(r.checkpoint, ['stage', 'index', 'sha256', 'parent_receipt_sha256', 'target_job_id']);
  const q = r.checkpoint;
  if (!id(q.stage) || !Number.isSafeInteger(q.index) || q.index < 0 || !Array.isArray(env.stages) ||
      !env.stages.length || !env.stages.every(id) || new Set(env.stages).size !== env.stages.length || env.stages[q.index] !== q.stage) refuse('INVALID_STAGE');
  if (operation === 'submit_existing_contract_job') {
    if (q.index !== 0 || q.sha256 !== null || q.parent_receipt_sha256 !== null || q.target_job_id !== null) refuse('INVALID_CHECKPOINT');
  } else if (!digest(q.sha256) || !digest(q.parent_receipt_sha256) || !id(q.target_job_id)) refuse('INVALID_CHECKPOINT');
  return freeze(clone(r));
}
module.exports = { Refusal, refuse, hash, stable, clone, freeze, object, id, digest, time, parse, keys,
  abs, relative, OPS, BOUND, identity, bindingHash, validate };
