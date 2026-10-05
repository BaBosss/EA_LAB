'use strict';
const { fixture, bytes, sign, expectRefusal, unchanged, runCases, assert, fs, path, C } = require('./test_job_control.cjs');
const { createJobControl } = require('./job_control.cjs');
const { clone, hash, stable } = C;
function faultCases() {
  const cases = [];
  const add = (group, name, test) => cases.push([group + ' ' + name, test]);
  const invalidRequest = (group, name, mutate, code) => add(group, name, f => {
    const r = f.request(); mutate(r, f); unchanged(f, () => f.api.submit_existing_contract_job(bytes(r)), code); assert.equal(f.count(), 0);
  });
  invalidRequest('NEG01_UNKNOWN_LANE', 'unregistered id', r => { r.lane_id = 'unknown-lane'; }, 'UNKNOWN_LANE');
  for (const value of [null, false, [], '']) invalidRequest('NEG01_UNKNOWN_LANE', 'invalid id ' + JSON.stringify(value), r => { r.lane_id = value; });
  invalidRequest('NEG01_UNKNOWN_LANE', 'missing trusted catalogue', (_, f) => { f.env.binding = null; }, 'UNKNOWN_LANE');
  for (const field of ['head', 'tree', 'config_sha256']) {
    for (const value of [null, '', 'c'.repeat(field === 'config_sha256' ? 64 : 40)])
      invalidRequest('NEG02_WRONG_SOURCE', field + '=' + JSON.stringify(value), r => { r.source[field] = value; }, 'WRONG_SOURCE');
    invalidRequest('NEG02_WRONG_SOURCE', 'missing ' + field, r => { delete r.source[field]; }, 'MALFORMED_SCHEMA');
  }
  for (const value of [false, null, 'true', 0, undefined]) invalidRequest('NEG03_DIRTY_WORKTREE', 'clean=' + value,
    (_, f) => { f.env.clean = value; }, 'DIRTY_WORKTREE');
  for (const value of [null, undefined, 'not bytes']) invalidRequest('NEG04_MISSING_CONTRACT', String(value),
    (_, f) => { f.env.contract_bytes = value; }, 'MISSING_CONTRACT');
  for (const value of [null, '', 'c'.repeat(64), 'A'.repeat(64)]) invalidRequest('NEG05_CONTRACT_MISMATCH', String(value),
    r => { r.contract_sha256 = value; }, 'CONTRACT_MISMATCH');
  invalidRequest('NEG05_CONTRACT_MISMATCH', 'changed contract bytes', (_, f) => { f.env.contract_bytes = Buffer.from('different fixture contract'); }, 'CONTRACT_MISMATCH');
  for (const style of ['whitespace', 'order', 'request-id', 'timestamp']) add('NEG06_IDEMPOTENCY_DRIFT', style, f => {
    const s = f.submit(); let raw;
    if (style === 'whitespace') raw = Buffer.from(JSON.stringify(s.request, null, 2));
    if (style === 'order') raw = bytes(Object.fromEntries(Object.entries(s.request).reverse()));
    if (style === 'request-id') raw = bytes({ ...s.request, request_id: 'changed-request-id' });
    if (style === 'timestamp') raw = bytes({ ...s.request, created_utc: '2026-10-05T12:00:00.0000001Z' });
    unchanged(f, () => f.api.submit_existing_contract_job(raw), 'IDEMPOTENCY_DRIFT'); assert.equal(f.count(), 1);
  });
  invalidRequest('NEG07_LEASED_RESOURCE', 'other owner', (_, f) => { f.env.resource_owner = 'other-owner'; }, 'LEASED_RESOURCE');
  for (const value of [false, null, undefined, 1, 'true']) invalidRequest('NEG07_LEASED_RESOURCE', 'available=' + value,
    (_, f) => { f.env.resource_available = value; }, 'LEASED_RESOURCE');
  add('NEG08_DUPLICATE_EXECUTION', 'another key cannot create a second job', f => {
    f.submit(); unchanged(f, () => f.api.submit_existing_contract_job(bytes(f.request())), 'DUPLICATE_EXECUTION');
  });
  for (const external of [{ job_id: 'already-existing' }, { identity: 'UNKNOWN' }, undefined])
    invalidRequest('NEG08_DUPLICATE_EXECUTION', 'external result=' + JSON.stringify(external), (_, f) => { f.externalExisting = external; }, 'DUPLICATE_EXECUTION');
  add('NEG08_DUPLICATE_EXECUTION', 'request id cannot be reused under a new key', f => {
    const s = f.submit(), r = f.request(); r.request_id = s.request.request_id;
    unchanged(f, () => f.api.submit_existing_contract_job(bytes(r)), 'REQUEST_ID_REUSE');
  });
  add('NEG09_STALE_RECEIPT', 'wrong parent hash', f => {
    const s = f.submit(), r = f.request('adopt_existing_job', s.result); r.checkpoint.parent_receipt_sha256 = 'f'.repeat(64);
    unchanged(f, () => f.api.adopt_existing_job(bytes(r)), 'STALE_RECEIPT');
  });
  add('NEG09_STALE_RECEIPT', 'revision below trusted floor', f => {
    const s = f.submit(); f.env.minimum_revision = f.store.anchor().revision + 1;
    unchanged(f, () => f.api.submit_existing_contract_job(s.bytes), 'STALE_RECEIPT');
  });
  add('NEG09_STALE_RECEIPT', 'same revision different anchored bytes', f => {
    const s = f.submit(); f.env.expected_state_sha256 = 'f'.repeat(64);
    unchanged(f, () => f.api.submit_existing_contract_job(s.bytes), 'STALE_RECEIPT');
  });
  add('NEG09_STALE_RECEIPT', 'missing state cannot erase trusted high-water revision', f => {
    f.env.minimum_revision = 1; unchanged(f, () => f.api.submit_existing_contract_job(bytes(f.request())), 'STALE_RECEIPT');
  });
  add('NEG09_STALE_RECEIPT', 'old parent after adoption', f => {
    const s = f.submit(); f.api.adopt_existing_job(bytes(f.request('adopt_existing_job', s.result)));
    unchanged(f, () => f.api.request_pause_after_stage(bytes(f.request('request_pause_after_stage', s.result))), 'STALE_RECEIPT');
  });
  const corrupt = [
    ['null root', () => null], ['array root', () => []], ['string root', () => 'bad'], ['number root', () => 7],
    ['zero revision', d => { d.revision = 0; }], ['null revision', d => { d.revision = null; }],
    ['missing previous hash', d => { d.previous_sha256 = null; }], ['unknown schema', d => { d.schema = 'other'; }],
    ['array requests', d => { d.requests = []; }], ['numeric requests', d => { d.requests = 1; }],
    ['boolean jobs', d => { d.jobs = true; }], ['empty jobs', d => { d.jobs = {}; }],
    ['unknown phase', d => { Object.values(d.jobs)[0].phase = 'RUNNING'; }],
    ['missing stage', d => { delete Object.values(d.jobs)[0].stage; }],
    ['wrong index', d => { Object.values(d.jobs)[0].index = 2; }],
    ['string index', d => { Object.values(d.jobs)[0].index = '0'; }],
    ['bad latest key', d => { Object.values(d.jobs)[0].latest_key = 'missing-key'; }],
    ['spurious intent', d => { Object.values(d.jobs)[0].intent_key = Object.keys(d.requests)[0]; }],
    ['spurious pause', d => { Object.values(d.jobs)[0].pause_key = Object.keys(d.requests)[0]; }],
    ['invalid base64', d => { Object.values(d.requests)[0].bytes_base64 = '%%%'; }],
    ['zero request bytes', d => { Object.values(d.requests)[0].bytes_base64 = ''; }],
    ['wrong receipt digest', d => { Object.values(d.requests)[0].receipt_sha256 = 'c'.repeat(64); }],
    ['wrong receipt identity', d => { const r = Object.values(d.requests)[0]; r.receipt.identity.source.head = 'c'.repeat(40); r.receipt_sha256 = hash(stable(r.receipt)); }],
    ['wrong receipt location', d => { const r = Object.values(d.requests)[0]; r.receipt.request_location = 'C:\\arbitrary'; r.receipt_sha256 = hash(stable(r.receipt)); }],
    ['future receipt observation', d => { const r = Object.values(d.requests)[0]; r.receipt.observed_utc = '2026-10-05T13:00:00Z'; r.receipt_sha256 = hash(stable(r.receipt)); }],
    ['unknown receipt outcome', d => { const r = Object.values(d.requests)[0]; r.receipt.outcome = 'RUNTIME_ACCEPTED'; r.receipt_sha256 = hash(stable(r.receipt)); }],
    ['invalid prepared sequence', d => { const r = Object.values(d.requests)[0]; r.receipt.prepared_revision = d.revision + 1; r.receipt_sha256 = hash(stable(r.receipt)); }]
  ];
  for (const [name, transform] of corrupt) add('NEG10_MALFORMED_STATE', name, f => {
    const s = f.submit(); f.tamper(transform); unchanged(f, () => f.api.get_job_current(s.request.idempotency_key));
  });
  add('NEG10_MALFORMED_STATE', 'orphan parent provenance after adoption', f => {
    const s = f.submit(), a = f.api.adopt_existing_job(bytes(f.request('adopt_existing_job', s.result)));
    f.tamper(d => {
      const record = d.requests[a.receipt.idempotency_key]; const request = JSON.parse(Buffer.from(record.bytes_base64, 'base64'));
      request.checkpoint.parent_receipt_sha256 = 'c'.repeat(64); const raw = bytes(request);
      record.bytes_base64 = raw.toString('base64'); record.receipt.request_sha256 = hash(raw); record.receipt.request_bytes = raw.length;
      record.receipt.checkpoint = request.checkpoint; record.receipt.parent_receipt_sha256 = request.checkpoint.parent_receipt_sha256;
      record.receipt_sha256 = hash(stable(record.receipt));
    });
    unchanged(f, () => f.api.get_job_current(a.receipt.idempotency_key), 'MALFORMED_STATE');
  });
  const invalidTimes = [null, true, [], {}, '', '2026-02-30T12:00:00Z', '2026-10-05T24:00:00Z',
    '2026-10-05T12:60:00Z', '2026-10-05T12:00:60Z', '2026-10-05T12:00:00+07:00', '2026-10-05T12:00:00+99:99',
    '2026-10-05T12:00:02Z', '2026-10-05T12:00:01.0000001Z', '2026-10-05T12:00:00.12345678Z'];
  for (const value of invalidTimes) invalidRequest('NEG11_FUTURE_TIMESTAMP', JSON.stringify(value), r => { r.created_utc = value; }, 'INVALID_OR_FUTURE_TIME');
  for (const field of ['now_utc', 'observed_utc']) invalidRequest('NEG11_FUTURE_TIMESTAMP', 'unknown ' + field,
    (_, f) => { f.env[field] = null; }, 'INVALID_OR_FUTURE_TIME');
  invalidRequest('NEG11_FUTURE_TIMESTAMP', 'observation predates request', (_, f) => { f.env.observed_utc = '2026-10-05T11:59:59Z'; }, 'INVALID_OR_FUTURE_TIME');
  invalidRequest('NEG11_FUTURE_TIMESTAMP', 'observation from future', (_, f) => { f.env.observed_utc = '2026-10-05T12:00:02Z'; }, 'INVALID_OR_FUTURE_TIME');
  for (const value of [null, [], '', true, [null], ['FIXTURE-ONLY', 'FIXTURE-ONLY']]) invalidRequest('NEG12_MISSING_ACCEPTANCE', JSON.stringify(value),
    r => { r.acceptance_criteria = value; }, 'MISSING_ACCEPTANCE');
  invalidRequest('NEG12_MISSING_ACCEPTANCE', 'arbitrary unaccepted criterion', r => { r.acceptance_criteria = ['NOT-APPROVED']; }, 'BINDING_MISMATCH');
  for (const value of [null, 'openai', 'SYNTHETIC_FIXTURE ', 'REAL_RUNNER']) invalidRequest('NEG13_DISALLOWED_PROVIDER', JSON.stringify(value),
    r => { r.route.provider = value; }, 'DISALLOWED_PROVIDER');
  for (const value of [null, 'shell', 'exec', 'start_process']) invalidRequest('NEG13_DISALLOWED_PROVIDER', 'tool=' + value,
    r => { r.route.tool = value; }, 'DISALLOWED_PROVIDER');
  for (const field of ['command', 'shell', 'executable', 'arguments', 'prompt', 'process_id']) invalidRequest('NEG14_GENERIC_SHELL', field,
    r => { r[field] = 'not executable; negative fixture'; }, 'MALFORMED_SCHEMA');
  invalidRequest('NEG14_GENERIC_SHELL', 'nested shell route', r => { r.route.command = 'not executable'; }, 'MALFORMED_SCHEMA');
  invalidRequest('NEG14_GENERIC_SHELL', 'unknown typed operation', r => { r.operation = 'generic_shell'; }, 'UNSUPPORTED_OPERATION');
  const badAbsolute = ['relative/path', 'C:relative', '/tmp/workspace/C:\\mixed', '\\\\server\\share\\folder', '\\\\?\\C:\\folder',
    'C:\\a\\..\\b', 'C:\\a\\.\\b', 'C:\\a\\NUL', 'C:\\a\\COM1.txt', 'C:\\a\\COM\u00b9', 'C:\\a\\CONIN$',
    'C:\\a\\x:stream', 'C:\\a\\trailing.', 'C:\\a\\ trailing', 'C:\\a\\bad\nname', 'C:\\a\\*'];
  for (const value of badAbsolute) for (const field of ['path', 'git_common_root']) invalidRequest('NEG15_ARBITRARY_PATH', field + '=' + JSON.stringify(value),
    r => { r.worktree[field] = value; }, 'ARBITRARY_PATH');
  for (const value of ['../outside', 'a/../outside', '/absolute', 'C:/outside', 'a\\b', 'a//b', '.git/config', 'a/NUL',
    'a/name:stream', 'a/trailing.', 'a/file?', 'a/b\u007f']) invalidRequest('NEG15_ARBITRARY_PATH', 'relative=' + JSON.stringify(value),
    r => { r.allowlisted_paths = [value]; }, 'ARBITRARY_PATH');
  invalidRequest('NEG15_ARBITRARY_PATH', 'well-formed but unadmitted worktree', r => { r.worktree.path = 'C:\\UNADMITTED\\worktree'; }, 'BINDING_MISMATCH');
  invalidRequest('NEG15_ARBITRARY_PATH', 'well-formed unadmitted path', r => { r.allowlisted_paths = ['tools/unadmitted.cjs']; }, 'BINDING_MISMATCH');
  for (const value of [false, null, undefined, 'true']) invalidRequest('NEG15_ARBITRARY_PATH', 'reparse/identity unproven=' + value,
    (_, f) => { f.env.path_identity_verified = value; }, 'PATH_IDENTITY_UNPROVEN');
  invalidRequest('NEG15_ARBITRARY_PATH', 'case-insensitive duplicate scopes', r => { r.allowlisted_paths = ['tools/a.cjs', 'TOOLS/a.cjs']; }, 'ARBITRARY_PATH');
  const badJson = [
    ['empty', Buffer.alloc(0), 'INVALID_REQUEST_BYTES'], ['oversize', Buffer.alloc(65537, 32), 'INVALID_REQUEST_BYTES'],
    ['invalid UTF8', Buffer.from([0xc3, 0x28]), 'INVALID_UTF8'], ['UTF8 BOM', Buffer.from('\ufeff{}'), 'MALFORMED_JSON'],
    ['duplicate key', Buffer.from('{"a":1,"a":2}'), 'DUPLICATE_OR_UNSAFE_KEY'],
    ['escaped duplicate key', Buffer.from('{"a":1,"\\u0061":2}'), 'DUPLICATE_OR_UNSAFE_KEY'],
    ['prototype pollution key', Buffer.from('{"__proto__":{}}'), 'DUPLICATE_OR_UNSAFE_KEY'],
    ['NaN literal', Buffer.from('{"a":NaN}'), 'MALFORMED_JSON'], ['overflow', Buffer.from('{"a":1e309}'), 'UNSAFE_NUMBER'],
    ['unsafe integer', Buffer.from('{"a":9007199254740993}'), 'UNSAFE_NUMBER'],
    ['fraction', Buffer.from('{"a":0.5}'), 'UNSAFE_NUMBER'], ['negative zero', Buffer.from('{"a":-0}'), 'UNSAFE_NUMBER'],
    ['trailing token', Buffer.from('{}{}'), 'MALFORMED_JSON'], ['leading zero', Buffer.from('{"a":01}'), 'MALFORMED_JSON'],
    ['trailing comma', Buffer.from('{"a":1,}'), 'MALFORMED_JSON'], ['unclosed string', Buffer.from('{"a":"oops}'), 'MALFORMED_JSON'],
    ['invalid escape', Buffer.from('{"a":"\\q"}'), 'MALFORMED_JSON'], ['excess depth', Buffer.from('['.repeat(26) + '0' + ']'.repeat(26)), 'JSON_DEPTH']
  ];
  for (const [name, raw, code] of badJson) add('STRICT_BYTES', name, f => { unchanged(f, () => f.api.submit_existing_contract_job(raw), code); });
  for (const value of [null, undefined, '{}', new Uint8Array([1, 2])]) add('STRICT_BYTES', 'non-buffer ' + String(value), f => {
    unchanged(f, () => f.api.submit_existing_contract_job(value), 'INVALID_REQUEST_BYTES');
  });
  for (const field of ['remaining_repair', 'remaining_retry']) for (const value of [null, undefined, false, -1, 3, 0.5])
    invalidRequest('BUDGET', field + '=' + value, (_, f) => { f.env[field] = value; }, 'BUDGET_LEDGER_UNPROVEN');
  for (const value of [false, null, undefined, 1]) invalidRequest('BUDGET', 'author availability=' + value,
    (_, f) => { f.env.budget_available = value; }, 'BUDGET_EXHAUSTED');
  invalidRequest('BUDGET', 'request cannot reset allocation', r => { r.budget.retry = 10; }, 'BINDING_MISMATCH');
  for (const field of ['minimum_revision', 'expected_state_sha256', 'binding_evidence_sha256']) invalidRequest('ENVIRONMENT', 'missing ' + field,
    (_, f) => { f.env[field] = undefined; }, 'MALFORMED_ENVIRONMENT');
  const invalidObservations = [
    ['stale', { observation_utc: '2026-10-05T12:00:00Z' }], ['future', { observation_utc: '2026-10-05T12:00:01.0000001Z' }],
    ['different job', { job_id: 'different-job' }], ['different binding', { binding_sha256: 'c'.repeat(64) }],
    ['different request', { request_sha256: 'c'.repeat(64) }], ['different stage', { stage: 'stage-beta' }],
    ['wrong index', { index: 1 }], ['not current', { current: false }], ['null current', { current: null }],
    ['creation mismatch', { identity: 'DIFFERENT_CREATION_IDENTITY' }], ['unknown identity', { identity: 'UNKNOWN' }],
    ['false terminal', { identity: 'PROVEN_RUNNING', runner_state: 'SUCCEEDED' }],
    ['untyped completion', { stage_complete: 'true' }], ['unknown consumer', { consumer_id: 'other-consumer' }],
    ['null checkpoint', { checkpoint_sha256: null }], ['future malformed offset', { observation_utc: '2026-10-05T12:00:00+99:99' }]
  ];
  for (const [name, patch] of invalidObservations) add('IDENTITY_UNKNOWN', name, f => {
    const s = f.submit(), r = f.request('adopt_existing_job', s.result);
    f.setObservation(s.result.receipt.job_id, patch);
    const before = f.snapshot(), current = f.api.get_job_current(s.request.idempotency_key).current;
    assert.equal(current.execution_state, 'UNKNOWN'); assert.deepEqual(f.snapshot(), before);
    unchanged(f, () => f.api.adopt_existing_job(bytes(r)), 'CURRENT_IDENTITY_UNPROVEN');
  });
  add('IDENTITY_UNKNOWN', 'observation hash mismatch', f => {
    const s = f.submit(); f.observationOverride = { ...f.consumerState().observations[s.result.receipt.job_id], evidence_sha256: 'c'.repeat(64) };
    assert.equal(f.api.get_job_current(s.request.idempotency_key).current.execution_state, 'UNKNOWN');
  });
  for (const patch of [{ pause_ack_request_sha256: 'c'.repeat(64) }, { stage_complete: false },
    { runner_state: 'FAILED', stage_complete: false }, { consumer_id: 'other-consumer' }]) add('PAUSE_RESUME_NEGATIVE', JSON.stringify(patch), f => {
    const p = f.completePause(f.pause(f.submit().result)), r = f.request('resume_existing_job', p);
    f.setObservation(p.receipt.job_id, patch);
    assert.notEqual(f.api.get_job_current(p.receipt.idempotency_key).current.protocol_state, 'PAUSED_AFTER_STAGE');
    unchanged(f, () => f.api.resume_existing_job(bytes(r)), ['RESUME_REFUSED', 'CURRENT_IDENTITY_UNPROVEN']);
  });
  add('PAUSE_RESUME_NEGATIVE', 'checkpoint drift', f => {
    const p = f.completePause(f.pause(f.submit().result)), r = f.request('resume_existing_job', p); r.checkpoint.sha256 = 'c'.repeat(64);
    unchanged(f, () => f.api.resume_existing_job(bytes(r)), 'CHECKPOINT_MISMATCH');
  });
  add('PAUSE_RESUME_NEGATIVE', 'no receipt adoption cannot create job', f => {
    const r = f.request('adopt_existing_job'); r.checkpoint = { stage: 'stage-alpha', index: 0,
      sha256: 'a'.repeat(64), parent_receipt_sha256: 'b'.repeat(64), target_job_id: 'unknown-job' };
    unchanged(f, () => f.api.adopt_existing_job(bytes(r)), 'UNKNOWN_JOB');
  });
  const points = ['reservation_acquired', 'before_prepared', 'storage_before_write', 'storage_after_write', 'storage_before_replace',
    'storage_after_replace', 'storage_after_anchor', 'after_prepared', 'readback_prepared', 'before_intent', 'after_intent',
    'readback_intent', 'before_dispatch', 'after_dispatch', 'before_ack', 'after_ack', 'readback_ack'];
  for (const point of points) add('FAULT_SUBMIT', point, f => {
    const r = f.request(), raw = bytes(r); f.control.fault = point;
    expectRefusal(() => f.api.submit_existing_contract_job(raw), 'INJECTED_FAULT:' + point);
    const count = f.count(); assert.ok(count <= 1); f.restart();
    if (['storage_after_write', 'storage_before_replace'].includes(point)) {
      unchanged(f, () => f.api.submit_existing_contract_job(raw), 'STORAGE_RECONCILE_REQUIRED');
    } else if (point === 'storage_after_replace') {
      unchanged(f, () => f.api.submit_existing_contract_job(raw), 'STALE_RECEIPT');
    } else if (['after_intent', 'readback_intent', 'before_dispatch'].includes(point)) {
      const before = f.snapshot(), recovered = f.api.submit_existing_contract_job(raw);
      assert.equal(recovered.current.protocol_state, 'RECONCILE_REQUIRED'); assert.equal(recovered.current.execution_state, 'UNKNOWN');
      assert.equal(f.count(), 0); assert.deepEqual(f.snapshot(), before);
    } else {
      const recovered = f.api.submit_existing_contract_job(raw); assert.equal(f.count(), 1);
      assert.equal(recovered.current.execution_state, 'PROVEN_RUNNING');
      const again = f.api.submit_existing_contract_job(raw); assert.deepEqual(again.receipt, recovered.receipt); assert.equal(f.count(), 1);
    }
  });
  add('FAULT_STORAGE', 'readback mismatch before intent; restart verifies exact PREPARED bytes', f => {
    const r = f.request(), raw = bytes(r);
    f.control.interleave = event => { if (event === 'after_prepared') { f.control.interleave = null; f.control.readOverride = Buffer.from('torn'); } };
    expectRefusal(() => f.api.submit_existing_contract_job(raw), 'RECEIPT_READBACK_MISMATCH'); assert.equal(f.count(), 0);
    f.restart(); const result = f.api.submit_existing_contract_job(raw); assert.equal(result.current.execution_state, 'PROVEN_RUNNING'); assert.equal(f.count(), 1);
  });
  add('FAULT_STORAGE', 'competing CAS revision changes no authoritative bytes', f => {
    f.control.casConflict = true; unchanged(f, () => f.api.submit_existing_contract_job(bytes(f.request())), 'COMPETING_REVISION');
  });
  add('FAULT_STORAGE', 'orphan exclusive lock fails closed without stealing it', f => {
    const lock = path.join(f.root, 'exclusive.lock'); fs.writeFileSync(lock, 'SYNTHETIC crash lock', { flag: 'wx' });
    unchanged(f, () => f.api.submit_existing_contract_job(bytes(f.request())), 'STORE_LOCKED');
    assert.equal(fs.readFileSync(lock, 'utf8'), 'SYNTHETIC crash lock');
  });
  for (const reanchor of [false, true]) add('FAULT_STORAGE', 'torn state reanchor=' + reanchor, f => {
    const s = f.submit(), raw = fs.readFileSync(path.join(f.root, 'state.json')), torn = raw.subarray(0, Math.floor(raw.length / 2));
    fs.writeFileSync(path.join(f.root, 'state.json'), torn);
    if (reanchor) fs.writeFileSync(path.join(f.root, 'anchor.json'), bytes({ revision: f.store.anchor().revision, sha256: hash(torn) }));
    unchanged(f, () => f.api.submit_existing_contract_job(s.bytes), reanchor ? 'MALFORMED_JSON' : 'STALE_RECEIPT');
  });
  add('FAULT_UNOBSERVABLE', 'launch gap never redispatches after restart', f => {
    f.hideObservation = true; const s = f.submit(); assert.equal(s.result.current.protocol_state, 'RECONCILE_REQUIRED');
    assert.equal(s.result.current.execution_state, 'UNKNOWN'); assert.equal(f.count(), 1); f.restart();
    const before = f.snapshot(), replay = f.api.submit_existing_contract_job(s.bytes);
    assert.equal(replay.current.execution_state, 'UNKNOWN'); assert.deepEqual(replay.receipt, s.result.receipt);
    assert.deepEqual(f.snapshot(), before); assert.equal(f.count(), 1);
    unchanged(f, () => f.api.submit_existing_contract_job(bytes(f.request())), 'DUPLICATE_EXECUTION');
  });
  for (const point of ['before_prepared', 'after_prepared', 'readback_prepared', 'before_dispatch', 'after_dispatch', 'before_reconcile', 'after_reconcile'])
    add('FAULT_RESUME', point, f => {
      const paused = f.completePause(f.pause(f.submit().result)), r = f.request('resume_existing_job', paused), raw = bytes(r);
      f.control.fault = point; expectRefusal(() => f.api.resume_existing_job(raw), 'INJECTED_FAULT:' + point);
      const count = f.count(); assert.ok(count <= 2); f.restart();
      const recovered = f.api.resume_existing_job(raw);
      if (['after_prepared', 'readback_prepared', 'before_dispatch'].includes(point)) {
        assert.equal(recovered.current.protocol_state, 'RECONCILE_REQUIRED'); assert.equal(recovered.current.execution_state, 'UNKNOWN'); assert.equal(f.count(), 1);
      } else { assert.equal(recovered.current.execution_state, 'PROVEN_RUNNING'); assert.equal(f.count(), 2); }
      assert.equal(recovered.receipt.job_id, paused.receipt.job_id);
      assert.equal(f.consumerState().calls.filter(x => x.index === 0).length, 1);
      const again = f.api.resume_existing_job(raw); assert.deepEqual(again.receipt, recovered.receipt); assert.equal(f.count(), point === 'before_prepared' ? 2 : count);
    });
  add('OFFLINE_CEILING', 'nonfixture mode cannot construct runtime adapter', f => {
    unchanged(f, () => createJobControl({ mode: 'RUNTIME', store: f.store, environment: () => f.env, observer: f.observer, stageConsumer: f.consumer }), 'SOURCE_OFFLINE_ONLY');
  });
  for (const kind of ['repair', 'retry']) add('BUDGET_REGRESSION', 'cannot replenish spent ' + kind + ' on adoption or replay', f => {
    const s = f.submit(); f.env.remaining_repair = 0; f.env.remaining_retry = 1;
    const adopted = f.api.adopt_existing_job(bytes(f.request('adopt_existing_job', s.result)));
    assert.deepEqual(adopted.receipt.budget_observation, { remaining_repair: 0, remaining_retry: 1 });
    f.env['remaining_' + kind]++;
    unchanged(f, () => f.api.get_job_current(adopted.receipt.idempotency_key), 'BUDGET_LEDGER_REGRESSION');
    unchanged(f, () => f.api.adopt_existing_job(bytes(f.request('adopt_existing_job', adopted))), 'BUDGET_LEDGER_REGRESSION');
  });
  for (const change of ['append', 'rename']) add('STAGE_PLAN_DRIFT', change + ' future stage after admission', f => {
    const s = f.submit();
    if (change === 'append') f.env.stages.push('unadmitted-stage'); else f.env.stages[2] = 'unadmitted-stage';
    unchanged(f, () => f.api.submit_existing_contract_job(s.bytes), 'STAGE_PLAN_DRIFT');
  });
  add('STAGE_PLAN_DRIFT', 'resume cannot select a replacement stage', f => {
    const paused = f.completePause(f.pause(f.submit().result)); f.env.stages[1] = 'unadmitted-stage';
    unchanged(f, () => f.api.resume_existing_job(bytes(f.request('resume_existing_job', paused))), 'STAGE_PLAN_DRIFT');
  });
  add('NEG09_STALE_RECEIPT', 'new action cannot use observation older than parent receipt', f => {
    const s = f.submit(), request = f.request('adopt_existing_job', s.result);
    f.env.observed_utc = '2026-10-05T12:00:00.5000000Z';
    unchanged(f, () => f.api.adopt_existing_job(bytes(request)), 'STALE_RECEIPT');
  });
  return cases;
}
module.exports = { faultCases };
if (require.main === module) {
  const cases = faultCases(); runCases(cases, 'JOB_CONTROL_V1_FAULT_NEGATIVE');
  const coverage = {};
  for (const [name] of cases) { const group = name.split(' ')[0]; coverage[group] = (coverage[group] || 0) + 1; }
  for (let n = 1; n <= 15; n++) assert.ok(Object.keys(coverage).some(k => k.startsWith('NEG' + String(n).padStart(2, '0') + '_')));
  console.log(JSON.stringify({ coverage, negative_categories: 15, evidence_kind: 'SYNTHETIC_FIXTURE', production_concurrency_qualified: false }));
}
