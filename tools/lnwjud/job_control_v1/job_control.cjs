'use strict';
// SOURCE/OFFLINE ONLY. No fs, subprocess, timer, network, Registry or runtime adapter.
const C = require('./request_contract.cjs');
const { refuse, hash, stable, clone, freeze, object, id, digest, time, parse, keys, validate, bindingHash } = C;
const PHASES = ['PREPARED', 'DISPATCH_INTENT', 'BOUND', 'PAUSE_REQUESTED', 'RESUME_INTENT'];
const RECEIPT_KEYS = ['schema', 'evidence_kind', 'request_id', 'idempotency_key', 'request_sha256',
  'request_bytes', 'request_location', 'job_id', 'binding_sha256', 'identity', 'checkpoint', 'operation',
  'created_utc', 'observed_utc', 'prepared_revision', 'parent_receipt_sha256', 'binding_evidence_sha256',
  'observed_evidence_sha256', 'budget_observation', 'stage_plan_sha256', 'outcome'];
const OBSERVATION_KEYS = ['job_id', 'binding_sha256', 'request_sha256', 'stage', 'index', 'current',
  'identity', 'runner_state', 'observation_utc', 'checkpoint_sha256', 'stage_complete',
  'pause_ack_request_sha256', 'consumer_id', 'evidence_sha256'];
const jobIdentity = r => 'jc-' + hash(r.lane_id + '\0' + r.idempotency_key).slice(0, 40);
const requestLocation = key => 'fixture-state://requests/' + key + '/bytes_base64';
function createJobControl({ store, environment, observer, stageConsumer, mode } = {}) {
  if (mode !== 'SYNTHETIC_FIXTURE' || store?.kind !== 'SYNTHETIC_FIXTURE' ||
      store.serialization !== 'EXCLUSIVE_LOCK_CAS_DURABLE_READBACK' || observer?.kind !== 'SYNTHETIC_FIXTURE' ||
      typeof environment !== 'function' || !['read', 'withLock', 'compareAndSwap', 'checkpoint'].every(k => typeof store[k] === 'function') ||
      !['observe', 'findExisting'].every(k => typeof observer[k] === 'function')) refuse('SOURCE_OFFLINE_ONLY');
  function snapshotEnvironment() {
    const raw = environment();
    if (!object(raw)) refuse('MALFORMED_ENVIRONMENT');
    const copy = clone({ ...raw, contract_bytes: null });
    copy.contract_bytes = Buffer.isBuffer(raw.contract_bytes) ? Buffer.from(raw.contract_bytes) : null;
    if (!Number.isSafeInteger(copy.minimum_revision) || copy.minimum_revision < 0 ||
        !(copy.expected_state_sha256 === null || digest(copy.expected_state_sha256)) ||
        !digest(copy.binding_evidence_sha256)) refuse('MALFORMED_ENVIRONMENT');
    return copy;
  }
  const empty = () => ({ schema: 'LNWJUD_JOB_CONTROL_FIXTURE_STORE_V1', revision: 0,
    previous_sha256: null, requests: {}, jobs: {} });
  function load(e) {
    const raw = store.read();
    if (raw !== null && !Buffer.isBuffer(raw)) refuse('MALFORMED_STATE');
    const bytes = raw === null ? null : Buffer.from(raw);
    if ((bytes === null ? null : hash(bytes)) !== e.expected_state_sha256) refuse('STALE_RECEIPT');
    if (bytes === null) {
      if (e.minimum_revision !== 0) refuse('STALE_RECEIPT');
      return { data: empty(), bytes: null };
    }
    const data = parse(bytes, 4 * 1024 * 1024);
    keys(data, ['schema', 'revision', 'previous_sha256', 'requests', 'jobs']);
    if (data.schema !== 'LNWJUD_JOB_CONTROL_FIXTURE_STORE_V1' || !Number.isSafeInteger(data.revision) ||
        data.revision < 1 || (data.revision === 1 ? data.previous_sha256 !== null : !digest(data.previous_sha256)) ||
        !object(data.requests) || !object(data.jobs) || !Object.keys(data.requests).length || !Object.keys(data.jobs).length) refuse('MALFORMED_STATE');
    if (data.revision < e.minimum_revision) refuse('STALE_RECEIPT');
    const ids = new Set(), revisions = new Set(), receipts = new Map(), decoded = new Map();
    for (const [key, record] of Object.entries(data.requests)) {
      keys(record, ['bytes_base64', 'receipt', 'receipt_sha256']);
      if (!id(key) || typeof record.bytes_base64 !== 'string' ||
          !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(record.bytes_base64)) refuse('MALFORMED_STATE');
      const b = Buffer.from(record.bytes_base64, 'base64');
      if (b.toString('base64') !== record.bytes_base64) refuse('MALFORMED_STATE');
      const parsed = parse(b), r = validate(b, e, parsed?.operation), p = record.receipt;
      keys(p, RECEIPT_KEYS);
      keys(p.budget_observation, ['remaining_repair', 'remaining_retry']);
      for (const kind of ['repair', 'retry']) {
        const remaining = p.budget_observation['remaining_' + kind];
        if (!Number.isSafeInteger(remaining) || remaining < 0 || remaining > r.budget[kind]) refuse('MALFORMED_STATE');
      }
      if (p.stage_plan_sha256 !== hash(stable(e.stages))) refuse('STAGE_PLAN_DRIFT');
      const created = time(p.created_utc), observed = time(p.observed_utc), now = time(e.now_utc);
      if (r.idempotency_key !== key || p.idempotency_key !== key || p.request_id !== r.request_id || ids.has(p.request_id) ||
          p.schema !== 'LNWJUD_JOB_CONTROL_RECEIPT_V1' || p.evidence_kind !== 'SYNTHETIC_FIXTURE' ||
          p.request_sha256 !== hash(b) || p.request_bytes !== b.length || p.request_location !== requestLocation(key) ||
          p.binding_sha256 !== bindingHash(r) || stable(p.identity) !== stable(C.identity(r)) ||
          stable(p.checkpoint) !== stable(r.checkpoint) || p.operation !== r.operation || !id(p.job_id) ||
          !Number.isSafeInteger(p.prepared_revision) || p.prepared_revision < 1 || p.prepared_revision > data.revision ||
          revisions.has(p.prepared_revision) || p.parent_receipt_sha256 !== r.checkpoint.parent_receipt_sha256 ||
          p.created_utc !== r.created_utc || created === null || observed === null || now === null || observed < created || observed > now ||
          !digest(p.binding_evidence_sha256) || (r.operation === C.OPS[0] ? p.observed_evidence_sha256 !== null : !digest(p.observed_evidence_sha256)) ||
          p.outcome !== 'PREPARED_OFFLINE_INTENT' || record.receipt_sha256 !== hash(stable(p))) refuse('MALFORMED_STATE');
      ids.add(p.request_id); revisions.add(p.prepared_revision); receipts.set(record.receipt_sha256, record); decoded.set(key, r);
    }
    for (const [key, record] of Object.entries(data.requests)) {
      const r = decoded.get(key), p = record.receipt;
      if (r.operation === C.OPS[0]) {
        if (p.job_id !== jobIdentity(r)) refuse('MALFORMED_STATE');
      } else {
        const parent = receipts.get(p.parent_receipt_sha256);
        if (!parent || parent.receipt.job_id !== p.job_id || parent.receipt.binding_sha256 !== p.binding_sha256 ||
            parent.receipt.prepared_revision >= p.prepared_revision || r.checkpoint.target_job_id !== p.job_id ||
            time(parent.receipt.observed_utc) > time(p.observed_utc) || parent.receipt.stage_plan_sha256 !== p.stage_plan_sha256 ||
            p.budget_observation.remaining_repair > parent.receipt.budget_observation.remaining_repair ||
            p.budget_observation.remaining_retry > parent.receipt.budget_observation.remaining_retry) refuse('MALFORMED_STATE');
      }
      if (!data.jobs[p.job_id]) refuse('MALFORMED_STATE');
    }
    const executions = new Set();
    for (const [jobId, j] of Object.entries(data.jobs)) {
      keys(j, ['job_id', 'binding_sha256', 'submission_key', 'latest_key', 'stage', 'index', 'phase',
        'intent_key', 'pause_key', 'checkpoint_sha256']);
      const origin = data.requests[j.submission_key], latest = data.requests[j.latest_key];
      if (jobId !== j.job_id || !id(jobId) || !PHASES.includes(j.phase) || !Number.isSafeInteger(j.index) || j.index < 0 ||
          e.stages[j.index] !== j.stage || !digest(j.binding_sha256) || !origin || !latest || origin.receipt.job_id !== jobId ||
          latest.receipt.job_id !== jobId || origin.receipt.operation !== C.OPS[0] || origin.receipt.binding_sha256 !== j.binding_sha256 ||
          latest.receipt.binding_sha256 !== j.binding_sha256) refuse('MALFORMED_STATE');
      if (e.remaining_repair > latest.receipt.budget_observation.remaining_repair ||
          e.remaining_retry > latest.receipt.budget_observation.remaining_retry) refuse('BUDGET_LEDGER_REGRESSION');
      const r = decoded.get(j.latest_key), original = decoded.get(j.submission_key);
      const execution = original.lane_id + '\0' + original.contract_id;
      if (executions.has(execution)) refuse('MALFORMED_STATE'); executions.add(execution);
      if (r.checkpoint.index !== j.index || r.checkpoint.stage !== j.stage || r.checkpoint.sha256 !== j.checkpoint_sha256 ||
          Object.values(data.requests).some(x => x.receipt.job_id === jobId && x.receipt.prepared_revision > latest.receipt.prepared_revision)) refuse('MALFORMED_STATE');
      const intent = ['DISPATCH_INTENT', 'RESUME_INTENT'].includes(j.phase);
      if (intent ? j.intent_key !== j.latest_key : j.intent_key !== null) refuse('MALFORMED_STATE');
      if (['PREPARED', 'DISPATCH_INTENT'].includes(j.phase) && (j.latest_key !== j.submission_key || j.index !== 0)) refuse('MALFORMED_STATE');
      if (j.phase === 'RESUME_INTENT' && r.operation !== 'resume_existing_job') refuse('MALFORMED_STATE');
      if (j.phase === 'PAUSE_REQUESTED') {
        const pause = data.requests[j.pause_key];
        if (!pause || pause.receipt.job_id !== jobId || pause.receipt.operation !== 'request_pause_after_stage' ||
            pause.receipt.checkpoint.index !== j.index || pause.receipt.checkpoint.stage !== j.stage ||
            !['request_pause_after_stage', 'adopt_existing_job'].includes(r.operation)) refuse('MALFORMED_STATE');
      } else if (j.pause_key !== null || (j.phase === 'BOUND' && r.operation === 'request_pause_after_stage')) refuse('MALFORMED_STATE');
    }
    return { data: clone(data), bytes };
  }
  function save(frame, label) {
    const prior = frame.bytes === null ? null : hash(frame.bytes);
    frame.data.revision++; frame.data.previous_sha256 = prior;
    const next = Buffer.from(stable(frame.data));
    store.checkpoint('before_' + label);
    if (store.compareAndSwap(prior, next) !== true) refuse('COMPETING_REVISION');
    store.checkpoint('after_' + label);
    const readback = store.read();
    if (!Buffer.isBuffer(readback) || !readback.equals(next)) refuse('RECEIPT_READBACK_MISMATCH');
    frame.bytes = next; store.checkpoint('readback_' + label);
  }
  function evidence(j, frame, e) {
    const o = observer.observe(j.job_id);
    if (!object(o) || stable(Object.keys(o).sort()) !== stable([...OBSERVATION_KEYS].sort())) return null;
    const unsigned = { ...o }; delete unsigned.evidence_sha256;
    const observed = time(o.observation_utc), now = time(e.now_utc), floor = time(e.observed_utc);
    const origin = frame.data.requests[j.submission_key].receipt;
    const terminal = ['SUCCEEDED', 'FAILED', 'CANCELLED', 'TIMED_OUT', 'POSTCONDITION_FAILED'];
    if (observed === null || now === null || floor === null || observed < floor || observed > now ||
        observed < time(frame.data.requests[j.latest_key].receipt.observed_utc) ||
        o.job_id !== j.job_id || o.binding_sha256 !== j.binding_sha256 || o.request_sha256 !== origin.request_sha256 ||
        o.stage !== j.stage || o.index !== j.index || o.current !== true || !digest(o.checkpoint_sha256) ||
        o.consumer_id !== origin.identity.direct_consumer || !digest(o.evidence_sha256) || o.evidence_sha256 !== hash(stable(unsigned)) ||
        typeof o.stage_complete !== 'boolean' || !(o.pause_ack_request_sha256 === null || digest(o.pause_ack_request_sha256)) ||
        (o.identity === 'PROVEN_RUNNING' ? o.runner_state !== 'RUNNING' || o.stage_complete || o.pause_ack_request_sha256 !== null :
          o.identity !== 'PROVEN_TERMINAL' || !terminal.includes(o.runner_state) || (o.stage_complete && o.runner_state !== 'SUCCEEDED'))) return null;
    return clone(o);
  }
  function qualifiedConsumer(e) {
    return stageConsumer?.kind === 'SYNTHETIC_FIXTURE' && stageConsumer.qualified === true &&
      stageConsumer.id === e.binding?.direct_consumer && typeof stageConsumer.dispatch === 'function';
  }
  function requireConsumer(e) { if (!qualifiedConsumer(e)) refuse('UNSUPPORTED_STAGE_CONSUMER'); }
  function current(j, frame, e) {
    const o = evidence(j, frame, e);
    let protocol = j.phase;
    if (['DISPATCH_INTENT', 'RESUME_INTENT'].includes(j.phase)) protocol = 'RECONCILE_REQUIRED';
    const pause = frame.data.requests[j.pause_key];
    if (j.phase === 'PAUSE_REQUESTED' && qualifiedConsumer(e) && o?.identity === 'PROVEN_TERMINAL' &&
        o.runner_state === 'SUCCEEDED' && o.stage_complete === true && o.pause_ack_request_sha256 === pause?.receipt.request_sha256) protocol = 'PAUSED_AFTER_STAGE';
    return { protocol_state: protocol, execution_state: o?.identity || 'UNKNOWN', durable_runner_state: o?.runner_state || 'UNKNOWN',
      reason: o ? 'QUALIFIED_SYNTHETIC_OBSERVATION' : 'CURRENT_IDENTITY_UNPROVEN', evidence_kind: 'SYNTHETIC_FIXTURE',
      job_id: j.job_id, stage: j.stage, index: j.index, checkpoint_sha256: o?.checkpoint_sha256 ?? null,
      progress: 'UNKNOWN', runtime_supported: false };
  }
  function result(record, j, frame, e) {
    return { receipt: clone(record.receipt), receipt_sha256: record.receipt_sha256, current: current(j, frame, e) };
  }
  function reconcile(j, frame, e) {
    if (['DISPATCH_INTENT', 'RESUME_INTENT'].includes(j.phase) && evidence(j, frame, e)) {
      j.phase = 'BOUND'; j.intent_key = null; save(frame, 'reconcile');
    }
  }
  function dispatch(j, frame, key, e) {
    requireConsumer(e);
    j.phase = 'DISPATCH_INTENT'; j.intent_key = key; save(frame, 'intent');
    invokeFixture(j, frame);
    if (evidence(j, frame, e)) { j.phase = 'BOUND'; j.intent_key = null; save(frame, 'ack'); }
  }
  function invokeFixture(j, frame) {
    store.checkpoint('before_dispatch');
    // A labelled in-process fixture counter only; never call any existing real runner.
    stageConsumer.dispatch(freeze({ job_id: j.job_id, stage: j.stage, index: j.index, binding_sha256: j.binding_sha256,
      request_sha256: frame.data.requests[j.submission_key].receipt.request_sha256 }));
    store.checkpoint('after_dispatch');
  }
  function run(operation, input) {
    if (!Buffer.isBuffer(input)) refuse('INVALID_REQUEST_BYTES');
    const bytes = Buffer.from(input);
    return store.withLock(() => {
      const e = snapshotEnvironment(), r = validate(bytes, e, operation), frame = load(e);
      const existing = frame.data.requests[r.idempotency_key];
      if (existing) {
        if (!Buffer.from(existing.bytes_base64, 'base64').equals(bytes)) refuse('IDEMPOTENCY_DRIFT');
        const j = frame.data.jobs[existing.receipt.job_id];
        if (j.phase === 'PREPARED' && j.submission_key === r.idempotency_key) {
          if (observer.observe(j.job_id) !== null || observer.findExisting(C.identity(r)) !== null) refuse('DUPLICATE_EXECUTION');
          dispatch(j, frame, r.idempotency_key, e);
        } else reconcile(j, frame, e);
        return result(existing, j, frame, e);
      }
      if (Object.values(frame.data.requests).some(x => x.receipt.request_id === r.request_id)) refuse('REQUEST_ID_REUSE');
      const bind = bindingHash(r); let j, observed = null;
      if (operation === 'submit_existing_contract_job') {
        requireConsumer(e);
        if (Object.values(frame.data.requests).some(x => x.receipt.operation === C.OPS[0] &&
              x.receipt.identity.lane_id === r.lane_id && x.receipt.identity.contract_id === r.contract_id) ||
            observer.findExisting(C.identity(r)) !== null) refuse('DUPLICATE_EXECUTION');
        j = { job_id: jobIdentity(r), binding_sha256: bind, submission_key: r.idempotency_key, latest_key: r.idempotency_key,
          stage: r.checkpoint.stage, index: 0, phase: 'PREPARED', intent_key: null, pause_key: null, checkpoint_sha256: null };
      } else {
        j = frame.data.jobs[r.checkpoint.target_job_id];
        if (!j || j.binding_sha256 !== bind) refuse('UNKNOWN_JOB');
        const latest = frame.data.requests[j.latest_key];
        if (latest.receipt_sha256 !== r.checkpoint.parent_receipt_sha256 ||
            time(e.observed_utc) < time(latest.receipt.observed_utc)) refuse('STALE_RECEIPT');
        observed = evidence(j, frame, e); if (!observed) refuse('CURRENT_IDENTITY_UNPROVEN');
        if (observed.checkpoint_sha256 !== r.checkpoint.sha256) refuse('CHECKPOINT_MISMATCH');
        if (operation === 'resume_existing_job') {
          requireConsumer(e);
          if (current(j, frame, e).protocol_state !== 'PAUSED_AFTER_STAGE' || r.checkpoint.index !== j.index + 1) refuse('RESUME_REFUSED');
        } else {
          if (r.checkpoint.stage !== j.stage || r.checkpoint.index !== j.index) refuse('CHECKPOINT_MISMATCH');
          if (operation === 'request_pause_after_stage') {
            requireConsumer(e); if (j.phase !== 'BOUND' || observed.identity !== 'PROVEN_RUNNING') refuse('PAUSE_REFUSED');
          }
          if (operation === 'adopt_existing_job') {
            if (!['BOUND', 'PAUSE_REQUESTED', 'DISPATCH_INTENT', 'RESUME_INTENT'].includes(j.phase)) refuse('ADOPTION_UNPROVEN');
            // The matching observation reconciles a lost acknowledgement, never redispatches.
            if (['DISPATCH_INTENT', 'RESUME_INTENT'].includes(j.phase)) { j.phase = 'BOUND'; j.intent_key = null; }
          }
        }
      }
      const p = { schema: 'LNWJUD_JOB_CONTROL_RECEIPT_V1', evidence_kind: 'SYNTHETIC_FIXTURE',
        request_id: r.request_id, idempotency_key: r.idempotency_key, request_sha256: hash(bytes), request_bytes: bytes.length,
        request_location: requestLocation(r.idempotency_key), job_id: j.job_id, binding_sha256: bind,
        identity: clone(C.identity(r)), checkpoint: clone(r.checkpoint), operation, created_utc: r.created_utc,
        observed_utc: e.observed_utc, prepared_revision: frame.data.revision + 1,
        parent_receipt_sha256: r.checkpoint.parent_receipt_sha256, binding_evidence_sha256: e.binding_evidence_sha256,
        observed_evidence_sha256: observed?.evidence_sha256 ?? null,
        budget_observation: { remaining_repair: e.remaining_repair, remaining_retry: e.remaining_retry },
        stage_plan_sha256: hash(stable(e.stages)), outcome: 'PREPARED_OFFLINE_INTENT' };
      const record = { bytes_base64: bytes.toString('base64'), receipt: p, receipt_sha256: hash(stable(p)) };
      frame.data.requests[r.idempotency_key] = record; frame.data.jobs[j.job_id] = j; j.latest_key = r.idempotency_key;
      if (operation === 'request_pause_after_stage') { j.phase = 'PAUSE_REQUESTED'; j.pause_key = r.idempotency_key; }
      if (operation === 'resume_existing_job') {
        // Request + new stage + resume intent are one atomic record. A gap stays reconcile-only.
        j.stage = r.checkpoint.stage; j.index = r.checkpoint.index; j.phase = 'RESUME_INTENT';
        j.intent_key = r.idempotency_key; j.pause_key = null;
      }
      if (operation !== 'submit_existing_contract_job') j.checkpoint_sha256 = r.checkpoint.sha256;
      save(frame, 'prepared');
      if (operation === 'submit_existing_contract_job') dispatch(j, frame, r.idempotency_key, e);
      if (operation === 'resume_existing_job') { invokeFixture(j, frame); reconcile(j, frame, e); }
      return result(record, j, frame, e);
    });
  }
  const api = Object.fromEntries(C.OPS.map(operation => [operation, bytes => run(operation, bytes)]));
  api.get_job_current = key => store.withLock(() => {
    if (!id(key)) refuse('INVALID_ID');
    const e = snapshotEnvironment(), frame = load(e), record = frame.data.requests[key];
    if (!record) refuse('UNKNOWN_RECEIPT');
    return result(record, frame.data.jobs[record.receipt.job_id], frame, e);
  });
  return Object.freeze(api);
}
module.exports = { createJobControl };
