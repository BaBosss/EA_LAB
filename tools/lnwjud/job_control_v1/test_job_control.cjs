'use strict';
// SYNTHETIC_FIXTURE only. Files stay in a fresh, marked os.tmpdir root; no real job/Registry/process calls.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const C = require('./request_contract.cjs');
const { createJobControl } = require('./job_control.cjs');
const { hash, stable, clone, Refusal } = C;
const PREFIX = 'LNWJUD_JOB_CONTROL_SYNTHETIC_FIXTURE_';
const ALLOWLIST = ['tools/lnwjud/job_control_v1/job_control.cjs', 'tools/lnwjud/job_control_v1/request_contract.cjs',
  'tools/lnwjud/job_control_v1/test_job_control.cjs', 'tools/lnwjud/job_control_v1/test_job_control_faults.cjs',
  'docs/workflows/LNWJUD_JOB_CONTROL_V1_SOURCE_OFFLINE.md'];
const bytes = x => Buffer.from(JSON.stringify(x));
function optional(file) { try { return fs.readFileSync(file); } catch (e) { if (e.code === 'ENOENT') return null; throw e; } }
// Fixture port of the existing _long_job_runner_lib.ps1 CreateNew/flush/atomic-replace pattern.
// It is intentionally not exported as a production storage or runner adapter.
function atomic(file, content) {
  const temporary = file + '.next'; let fd;
  try { fd = fs.openSync(temporary, 'wx'); }
  catch (e) { if (e.code === 'EEXIST') throw new Refusal('STORAGE_RECONCILE_REQUIRED'); throw e; }
  try { fs.writeFileSync(fd, content); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
  fs.renameSync(temporary, file);
}
class FixtureStore {
  constructor(root, control) {
    this.root = root; this.control = control; this.held = false; this.kind = 'SYNTHETIC_FIXTURE';
    this.serialization = 'EXCLUSIVE_LOCK_CAS_DURABLE_READBACK';
    assert.equal(fs.lstatSync(root).isSymbolicLink(), false);
    assert.equal(fs.readFileSync(path.join(root, 'SYNTHETIC_FIXTURE'), 'utf8'), 'NO_RUNTIME\n');
  }
  checkpoint(event) {
    this.control.events.push(event);
    if (this.control.interleave) this.control.interleave(event);
    if (this.control.fault === event) { this.control.fault = null; throw new Refusal('INJECTED_FAULT:' + event); }
  }
  withLock(fn) {
    const lock = path.join(this.root, 'exclusive.lock'); let fd;
    try { fd = fs.openSync(lock, 'wx'); }
    catch (e) { if (e.code === 'EEXIST') throw new Refusal('STORE_LOCKED'); throw e; }
    this.held = true;
    try { this.checkpoint('reservation_acquired'); return fn(); }
    finally { this.held = false; fs.closeSync(fd); fs.unlinkSync(lock); }
  }
  read() {
    if (this.control.readOverride !== undefined) {
      const result = this.control.readOverride; delete this.control.readOverride; return result;
    }
    return optional(path.join(this.root, 'state.json'));
  }
  anchor() {
    const b = optional(path.join(this.root, 'anchor.json'));
    if (b === null) return { revision: 0, sha256: null };
    const a = C.parse(b); C.keys(a, ['revision', 'sha256']);
    if (!Number.isSafeInteger(a.revision) || a.revision < 1 || !C.digest(a.sha256)) throw new Refusal('MALFORMED_STATE');
    return a;
  }
  compareAndSwap(prior, next) {
    assert.equal(this.held, true, 'CAS must run under the same exclusive reservation');
    const actual = optional(path.join(this.root, 'state.json'));
    if ((actual === null ? null : hash(actual)) !== prior || this.anchor().sha256 !== prior) return false;
    if (this.control.casConflict) { this.control.casConflict = false; return false; }
    const file = path.join(this.root, 'state.json'), temporary = file + '.next';
    this.checkpoint('storage_before_write'); let fd;
    try { fd = fs.openSync(temporary, 'wx'); }
    catch (e) { if (e.code === 'EEXIST') throw new Refusal('STORAGE_RECONCILE_REQUIRED'); throw e; }
    try { fs.writeFileSync(fd, next); fs.fsyncSync(fd); this.checkpoint('storage_after_write'); }
    finally { fs.closeSync(fd); }
    this.checkpoint('storage_before_replace'); fs.renameSync(temporary, file);
    this.checkpoint('storage_after_replace');
    atomic(path.join(this.root, 'anchor.json'), bytes({ revision: C.parse(next, 4 * 1024 * 1024).revision, sha256: hash(next) }));
    this.checkpoint('storage_after_anchor'); return true;
  }
}
function sign(observation) { const o = clone(observation); delete o.evidence_sha256; return { ...o, evidence_sha256: hash(stable(o)) }; }
function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), PREFIX));
  fs.writeFileSync(path.join(root, 'SYNTHETIC_FIXTURE'), 'NO_RUNTIME\n', { flag: 'wx' });
  const control = { events: [], fault: null, interleave: null, casConflict: false };
  const contract = Buffer.from('SYNTHETIC_FIXTURE approved contract; no production authority\n');
  const binding = {
    lane_id: 'fixture-lane', contract_id: 'fixture-contract', contract_sha256: hash(contract),
    source: { head: 'a'.repeat(40), tree: 'b'.repeat(40), config_sha256: hash('fixture-config') },
    allowlisted_paths: [...ALLOWLIST],
    worktree: { path: 'C:\\SYNTHETIC_FIXTURE\\worktree', branch: 'fixture/job-control',
      git_common_root: 'C:\\SYNTHETIC_FIXTURE\\common.git', identity_sha256: hash('fixture-worktree') },
    resource_owner: 'fixture-owner', acceptance_criteria: ['FIXTURE-ONLY', 'ZERO-RUNTIME', 'RECEIPT-BEFORE-DISPATCH'],
    budget: { repair: 1, retry: 2 }, direct_consumer: 'fixture-consumer',
    route: { tool: 'EXISTING_RUNNER', provider: 'SYNTHETIC_FIXTURE' },
    runtime_resource: 'NOT_APPLICABLE_OFFLINE', host_id: 'fixture-host'
  };
  const env = { binding: clone(binding), contract_bytes: contract, clean: true, path_identity_verified: true,
    resource_owner: binding.resource_owner, resource_available: true, remaining_repair: 1, remaining_retry: 2,
    budget_available: true, stages: ['stage-alpha', 'stage-beta', 'stage-gamma'],
    now_utc: '2026-10-05T12:00:01.0000000Z', observed_utc: '2026-10-05T12:00:01.0000000Z',
    binding_evidence_sha256: hash('SYNTHETIC immutable binding observation') };
  const f = { root, control, env, binding, sequence: 0, hideObservation: false };
  f.consumerState = () => {
    const b = optional(path.join(root, 'consumer.json'));
    return b === null ? { calls: [], observations: {} } : JSON.parse(b.toString('utf8'));
  };
  f.writeConsumer = value => atomic(path.join(root, 'consumer.json'), bytes(value));
  f.count = () => f.consumerState().calls.length;
  f.observer = {
    kind: 'SYNTHETIC_FIXTURE',
    observe: jobId => {
      if (Array.isArray(f.observationSequence) && f.observationSequence.length) return clone(f.observationSequence.shift());
      return Object.hasOwn(f, 'observationOverride') ? f.observationOverride : clone(f.consumerState().observations[jobId] || null);
    },
    findExisting: () => Object.hasOwn(f, 'externalExisting') ? f.externalExisting : (f.consumerState().calls[0] || null)
  };
  f.consumer = { kind: 'SYNTHETIC_FIXTURE', qualified: true, id: binding.direct_consumer,
    dispatch(payload) {
      assert.equal(Object.isFrozen(payload), true);
      const state = JSON.parse(fs.readFileSync(path.join(root, 'state.json'), 'utf8'));
      const job = state.jobs[payload.job_id]; assert.ok(job);
      assert.ok(['DISPATCH_INTENT', 'RESUME_INTENT'].includes(job.phase));
      assert.equal(f.store.anchor().sha256, hash(fs.readFileSync(path.join(root, 'state.json'))));
      assert.equal(control.events.at(-1), 'before_dispatch');
      assert.ok(control.events.includes(job.phase === 'RESUME_INTENT' ? 'readback_prepared' : 'readback_intent'));
      const c = f.consumerState();
      assert.equal(c.calls.some(x => x.job_id === payload.job_id && x.index === payload.index), false, 'no repeated stage execution');
      c.calls.push(clone(payload));
      if (!f.hideObservation) c.observations[payload.job_id] = sign({ ...payload, current: true,
        identity: 'PROVEN_RUNNING', runner_state: 'RUNNING', observation_utc: env.observed_utc,
        checkpoint_sha256: hash('running:' + payload.job_id + ':' + payload.index), stage_complete: false,
        pause_ack_request_sha256: null, consumer_id: binding.direct_consumer });
      f.writeConsumer(c); control.events.push('fixture_dispatch');
    }
  };
  f.newApi = () => {
    const store = new FixtureStore(root, control);
    const api = createJobControl({ mode: 'SYNTHETIC_FIXTURE', store, observer: f.observer, stageConsumer: f.consumer,
      environment: () => { const a = store.anchor(); return { minimum_revision: a.revision, expected_state_sha256: a.sha256, ...env }; } });
    return { store, api };
  };
  f.restart = () => { const next = f.newApi(); f.store = next.store; f.api = next.api; return f.api; };
  f.restart();
  f.request = (operation = 'submit_existing_contract_job', previous = null) => {
    const n = ++f.sequence;
    const index = previous ? previous.current.index + (operation === 'resume_existing_job' ? 1 : 0) : 0;
    return { schema: 'LNWJUD_JOB_CONTROL_REQUEST_V1', request_id: 'fixture-request-' + n,
      idempotency_key: 'fixture-key-' + n, operation, ...clone(binding),
      checkpoint: { stage: env.stages[index], index, sha256: previous?.current.checkpoint_sha256 ?? null,
        parent_receipt_sha256: previous?.receipt_sha256 ?? null, target_job_id: previous?.receipt.job_id ?? null },
      created_utc: '2026-10-05T12:00:00.0000000Z' };
  };
  f.submit = () => { const request = f.request(); return { request, bytes: bytes(request), result: f.api.submit_existing_contract_job(bytes(request)) }; };
  f.setObservation = (jobId, patch) => {
    const c = f.consumerState(); c.observations[jobId] = sign({ ...c.observations[jobId], ...clone(patch) }); f.writeConsumer(c);
  };
  f.pause = result => {
    const request = f.request('request_pause_after_stage', result);
    return f.api.request_pause_after_stage(bytes(request));
  };
  f.completePause = result => {
    f.setObservation(result.receipt.job_id, { identity: 'PROVEN_TERMINAL', runner_state: 'SUCCEEDED', stage_complete: true,
      pause_ack_request_sha256: result.receipt.request_sha256, checkpoint_sha256: hash('completed:' + result.receipt.job_id + ':' + result.current.index) });
    return f.api.get_job_current(result.receipt.idempotency_key);
  };
  f.snapshot = () => Object.fromEntries(['state.json', 'anchor.json', 'consumer.json'].map(name => [name, optional(path.join(root, name))?.toString('base64') ?? null]));
  f.tamper = transform => {
    const b = optional(path.join(root, 'state.json')); const value = JSON.parse(b.toString());
    const changed = transform(value); const next = bytes(changed === undefined ? value : changed);
    fs.writeFileSync(path.join(root, 'state.json'), next);
    fs.writeFileSync(path.join(root, 'anchor.json'), bytes({ revision: Math.max(1, value.revision || 1), sha256: hash(next) }));
  };
  f.destroy = () => {
    assert.ok(path.basename(root).startsWith(PREFIX));
    assert.equal(fs.lstatSync(root).isSymbolicLink(), false);
    assert.equal(fs.readFileSync(path.join(root, 'SYNTHETIC_FIXTURE'), 'utf8'), 'NO_RUNTIME\n');
    fs.rmSync(root, { recursive: true, force: false });
  };
  return f;
}
function expectRefusal(fn, code) {
  assert.throws(fn, error => error instanceof Refusal && (code === undefined ||
    (Array.isArray(code) ? code.includes(error.code) : error.code === code)), 'expected typed refusal: ' + code);
}
function unchanged(f, fn, code) {
  const before = f.snapshot(), count = f.count(); expectRefusal(fn, code);
  assert.deepEqual(f.snapshot(), before, 'refusal must not mutate authoritative fixture bytes');
  assert.equal(f.count(), count, 'refusal must not dispatch');
}
function runCases(cases, suite) {
  let passed = 0; const failures = [];
  for (const [name, test] of cases) {
    const f = fixture();
    try { test(f); passed++; console.log('PASS ' + name); }
    catch (error) { failures.push(name); console.error('FAIL ' + name + '\n' + error.stack); }
    finally { f.destroy(); }
  }
  console.log(JSON.stringify({ suite, evidence_kind: 'SYNTHETIC_FIXTURE', total: cases.length, passed,
    failed: failures.length, failures, real_dispatches: 0, runtime_qualified: false }));
  if (failures.length) process.exitCode = 1;
}
function positiveCases() {
  const cases = [];
  const add = (name, fn) => cases.push([name, fn]);
  add('five typed interfaces only; no shell or process endpoint', f => {
    assert.deepEqual(Object.keys(f.api).sort(), [...C.OPS, 'get_job_current'].sort()); assert.ok(Object.isFrozen(f.api));
  });
  add('full identity frozen; source and acceptance retained', f => {
    const r = f.request(), a = f.store.anchor();
    const validated = C.validate(bytes(r), { ...f.env, minimum_revision: a.revision }, r.operation);
    assert.ok(Object.isFrozen(validated)); assert.ok(Object.isFrozen(validated.source)); assert.ok(Object.isFrozen(validated.allowlisted_paths));
    assert.deepEqual(C.identity(validated), f.binding);
  });
  add('durable PREPARED and intent readback precede single fixture dispatch', f => {
    const { request, result } = f.submit(); assert.equal(f.count(), 1);
    assert.equal(result.current.execution_state, 'PROVEN_RUNNING'); assert.equal(result.current.runtime_supported, false);
    assert.deepEqual(result.receipt.identity, f.binding); assert.equal(result.receipt.request_sha256, hash(bytes(request)));
    const events = f.control.events;
    assert.ok(events.indexOf('readback_prepared') < events.indexOf('before_intent'));
    assert.ok(events.indexOf('readback_intent') < events.indexOf('fixture_dispatch'));
    assert.equal(result.receipt.request_location, 'fixture-state://requests/' + request.idempotency_key + '/bytes_base64');
  });
  add('same key same bytes returns exact immutable receipt and job', f => {
    const s = f.submit(), after = f.snapshot(); const replay = f.api.submit_existing_contract_job(s.bytes);
    assert.deepEqual(replay.receipt, s.result.receipt); assert.equal(replay.receipt_sha256, s.result.receipt_sha256);
    assert.deepEqual(f.snapshot(), after); assert.equal(f.count(), 1);
  });
  add('whitespace is preserved in frozen raw request bytes', f => {
    const r = f.request(), raw = Buffer.from(JSON.stringify(r, null, 2) + '\n');
    const p = f.api.submit_existing_contract_job(raw); assert.equal(p.receipt.request_sha256, hash(raw));
    const saved = JSON.parse(fs.readFileSync(path.join(f.root, 'state.json'), 'utf8'));
    assert.ok(Buffer.from(saved.requests[r.idempotency_key].bytes_base64, 'base64').equals(raw));
  });
  add('restart reopens durable state and observation; replay count remains one', f => {
    const s = f.submit(); f.restart(); const current = f.api.get_job_current(s.request.idempotency_key);
    assert.deepEqual(current.receipt, s.result.receipt); assert.equal(current.current.execution_state, 'PROVEN_RUNNING');
    f.api.submit_existing_contract_job(s.bytes); assert.equal(f.count(), 1);
  });
  add('lost ACK exact replay reconciles existing job without launch', f => {
    const r = f.request(), raw = bytes(r); f.control.fault = 'after_dispatch';
    expectRefusal(() => f.api.submit_existing_contract_job(raw), 'INJECTED_FAULT:after_dispatch');
    assert.equal(f.count(), 1); f.restart();
    const before = f.api.get_job_current(r.idempotency_key); assert.equal(before.current.protocol_state, 'RECONCILE_REQUIRED');
    const recovered = f.api.submit_existing_contract_job(raw); assert.deepEqual(recovered.receipt, before.receipt);
    assert.equal(recovered.current.protocol_state, 'BOUND'); assert.equal(f.count(), 1);
  });
  add('lost ACK direct adoption uses matching evidence and records provenance', f => {
    const r = f.request(); f.control.fault = 'after_dispatch';
    expectRefusal(() => f.api.submit_existing_contract_job(bytes(r)), 'INJECTED_FAULT:after_dispatch');
    f.restart(); const existing = f.api.get_job_current(r.idempotency_key);
    const adopt = f.request('adopt_existing_job', existing), adopted = f.api.adopt_existing_job(bytes(adopt));
    assert.equal(adopted.receipt.job_id, existing.receipt.job_id); assert.equal(adopted.current.protocol_state, 'BOUND');
    assert.equal(adopted.receipt.parent_receipt_sha256, existing.receipt_sha256); assert.ok(C.digest(adopted.receipt.observed_evidence_sha256));
    assert.equal(f.count(), 1);
  });
  add('overlapping same-key admissions serialize under one exclusive fixture lock', f => {
    const r = f.request(), raw = bytes(r); let collision = 0;
    f.control.interleave = event => {
      if (event === 'before_prepared' && collision === 0) {
        collision++; const other = f.newApi().api; unchanged(f, () => other.submit_existing_contract_job(raw), 'STORE_LOCKED');
      }
    };
    const first = f.api.submit_existing_contract_job(raw); f.control.interleave = null;
    const second = f.newApi().api.submit_existing_contract_job(raw);
    assert.equal(collision, 1); assert.deepEqual(first.receipt, second.receipt); assert.equal(f.count(), 1);
  });
  add('adopt running job adds no execution and keeps frozen budgets', f => {
    const s = f.submit(); f.env.remaining_repair = 0; f.env.remaining_retry = 1;
    const r = f.request('adopt_existing_job', s.result), a = f.api.adopt_existing_job(bytes(r));
    assert.equal(a.receipt.job_id, s.result.receipt.job_id); assert.equal(f.count(), 1);
    assert.deepEqual(a.receipt.identity.budget, s.result.receipt.identity.budget);
    assert.equal(f.env.remaining_repair, 0); assert.equal(f.env.remaining_retry, 1);
  });
  add('get is read-only; mutable returned values cannot alter durable bytes', f => {
    const s = f.submit(), before = f.snapshot(); const result = f.api.get_job_current(s.request.idempotency_key);
    result.receipt.identity.source.head = 'c'.repeat(40); result.current.index = 9;
    assert.deepEqual(f.snapshot(), before); assert.equal(f.api.get_job_current(s.request.idempotency_key).receipt.identity.source.head, 'a'.repeat(40));
  });
  add('unavailable identity stays UNKNOWN not zero or PASS', f => {
    const s = f.submit(); f.observationOverride = null; const before = f.snapshot();
    const current = f.api.get_job_current(s.request.idempotency_key).current;
    assert.equal(current.execution_state, 'UNKNOWN'); assert.equal(current.progress, 'UNKNOWN');
    assert.equal(current.checkpoint_sha256, null); assert.deepEqual(f.snapshot(), before);
  });
  add('terminal success and terminal failure remain distinct from running', f => {
    const s = f.submit();
    for (const state of ['SUCCEEDED', 'FAILED', 'CANCELLED', 'TIMED_OUT', 'POSTCONDITION_FAILED']) {
      f.setObservation(s.result.receipt.job_id, { identity: 'PROVEN_TERMINAL', runner_state: state, stage_complete: state === 'SUCCEEDED' });
      const current = f.api.get_job_current(s.request.idempotency_key).current;
      assert.equal(current.execution_state, 'PROVEN_TERMINAL'); assert.equal(current.durable_runner_state, state);
      assert.notEqual(current.protocol_state, 'PAUSED_AFTER_STAGE');
    }
  });
  add('pause intent lets active stage continue; bare terminal is not pause ACK', f => {
    const s = f.submit(), p = f.pause(s.result); assert.equal(p.current.protocol_state, 'PAUSE_REQUESTED');
    assert.equal(p.current.execution_state, 'PROVEN_RUNNING'); assert.equal(f.count(), 1);
    f.setObservation(p.receipt.job_id, { identity: 'PROVEN_TERMINAL', runner_state: 'SUCCEEDED', stage_complete: true });
    assert.equal(f.api.get_job_current(p.receipt.idempotency_key).current.protocol_state, 'PAUSE_REQUESTED');
  });
  add('matching stage checkpoint and exact pause ACK qualify synthetic paused state', f => {
    const p = f.pause(f.submit().result), paused = f.completePause(p);
    assert.equal(paused.current.protocol_state, 'PAUSED_AFTER_STAGE'); assert.equal(paused.current.durable_runner_state, 'SUCCEEDED');
    assert.equal(paused.current.runtime_supported, false); assert.equal(f.count(), 1);
  });
  add('resume advances same job once and cannot rerun completed stage', f => {
    const p = f.completePause(f.pause(f.submit().result)); const r = f.request('resume_existing_job', p), raw = bytes(r);
    const resumed = f.api.resume_existing_job(raw); assert.equal(resumed.receipt.job_id, p.receipt.job_id);
    assert.equal(resumed.current.index, 1); assert.equal(resumed.current.stage, 'stage-beta'); assert.equal(f.count(), 2);
    f.restart(); const replay = f.api.resume_existing_job(raw); assert.deepEqual(replay.receipt, resumed.receipt); assert.equal(f.count(), 2);
    const wrong = f.request('resume_existing_job', resumed); wrong.checkpoint.index = 0; wrong.checkpoint.stage = 'stage-alpha';
    unchanged(f, () => f.api.resume_existing_job(bytes(wrong)), 'RESUME_REFUSED');
  });
  add('resume receipt binds the single acknowledged completion observation', f => {
    const p = f.completePause(f.pause(f.submit().result));
    const completed = clone(f.consumerState().observations[p.receipt.job_id]);
    f.observationSequence = [completed];
    const r = f.request('resume_existing_job', p), resumed = f.api.resume_existing_job(bytes(r));
    assert.equal(resumed.receipt.observed_evidence_sha256, completed.evidence_sha256);
    assert.equal(resumed.receipt.checkpoint.sha256, completed.checkpoint_sha256);
    assert.equal(resumed.current.index, 1); assert.equal(f.count(), 2);
  });
  add('adoption during pause preserves the original pause ACK identity', f => {
    const p = f.pause(f.submit().result); const a = f.api.adopt_existing_job(bytes(f.request('adopt_existing_job', p)));
    f.completePause(p); const paused = f.api.get_job_current(a.receipt.idempotency_key);
    assert.equal(paused.current.protocol_state, 'PAUSED_AFTER_STAGE');
    f.api.resume_existing_job(bytes(f.request('resume_existing_job', paused))); assert.equal(f.count(), 2);
  });
  add('all declared stages resume in order with immutable original receipt', f => {
    const s = f.submit(); let result = s.result;
    for (let index = 1; index < 3; index++) {
      const p = f.completePause(f.pause(result)); result = f.api.resume_existing_job(bytes(f.request('resume_existing_job', p)));
      assert.equal(result.current.index, index); assert.equal(result.receipt.job_id, s.result.receipt.job_id);
    }
    assert.equal(f.count(), 3); assert.deepEqual(f.api.get_job_current(s.request.idempotency_key).receipt, s.result.receipt);
    const p = f.completePause(f.pause(result)), r = f.request('resume_existing_job', p); r.checkpoint.stage = 'undeclared-stage';
    unchanged(f, () => f.api.resume_existing_job(bytes(r)), 'INVALID_STAGE');
  });
  add('unqualified real consumer is explicitly unsupported without mutation', f => {
    f.consumer.kind = 'REAL_RUNNER'; unchanged(f, () => f.api.submit_existing_contract_job(bytes(f.request())), 'UNSUPPORTED_STAGE_CONSUMER');
    assert.equal(f.count(), 0);
  });
  add('consumer qualification loss blocks pause and resume', f => {
    const s = f.submit(); f.consumer.qualified = false;
    unchanged(f, () => f.api.request_pause_after_stage(bytes(f.request('request_pause_after_stage', s.result))), 'UNSUPPORTED_STAGE_CONSUMER');
    f.consumer.qualified = true; const p = f.completePause(f.pause(s.result)); f.consumer.qualified = false;
    unchanged(f, () => f.api.resume_existing_job(bytes(f.request('resume_existing_job', p))), 'UNSUPPORTED_STAGE_CONSUMER');
  });
  add('exact 100ns UTC and JSON whitespace parser positive cases', () => {
    assert.equal(C.time('2026-10-05T12:00:00.0000001Z') - C.time('2026-10-05T12:00:00.0000000Z'), 1n);
    assert.equal(C.time('2024-02-29T00:00:00Z') !== null, true);
    assert.deepEqual(clone(C.parse(Buffer.from(' \t\r\n{"a":[true,false,null,12],"b":"escaped \\\"quote\\\""}\n'))),
      { a: [true, false, null, 12], b: 'escaped "quote"' });
  });
  add('offline source imports have no runner, shell, fs, timer or network implementation', () => {
    const allowed = new Set(['node:crypto', 'node:util', './request_contract.cjs']);
    for (const file of ['request_contract.cjs', 'job_control.cjs']) {
      const text = fs.readFileSync(path.join(__dirname, file), 'utf8');
      for (const match of text.matchAll(/require\(['"]([^'"]+)['"]\)/g)) assert.ok(allowed.has(match[1]), match[1]);
      assert.equal(/\b(?:eval|Function|setInterval|setTimeout|fetch|execSync|spawnSync|import)\s*\(/.test(text), false);
    }
  });
  add('absolute Git common-root may contain the real .git directory name', () => {
    assert.equal(C.abs('C:\\SYNTHETIC_FIXTURE\\repo\\.git'), true);
    assert.equal(C.relative('.git/config'), false);
  });
  return cases;
}
module.exports = { fixture, bytes, sign, expectRefusal, unchanged, runCases, positiveCases, ALLOWLIST, optional, atomic, assert, fs, path, C };
if (require.main === module) runCases(positiveCases(), 'JOB_CONTROL_V1_POSITIVE');
