'use strict';
// Typed production adapter. This module contains no filesystem/process/Registry/network
// access. Those surfaces are injected behind exact bridge/store/observer contracts.
const R = require('./runtime_request_contract.cjs');
const { refuse, hash, stable, clone, freeze, object, id, digest, time, parse, keys, validate, bindingHash, resolvedStage } = R;
const PHASES = ['PREPARED','DISPATCH_INTENT','BOUND','PAUSE_REQUESTED','RESUME_INTENT','LAUNCH_UNPROVEN'];
const RECEIPT_KEYS = ['schema','request_id','idempotency_key','request_sha256','request_bytes','request_location',
  'job_id','binding_sha256','operation','stage','stage_index','profile_id','profile_sha256','created_utc','observed_utc',
  'prepared_revision','parent_receipt_sha256','checkpoint_sha256','budget_observation','outcome'];
const logicalJobId = r => 'jc-' + hash(r.lane_id + '\0' + r.contract_id + '\0' + r.idempotency_key).slice(0,40);
const runnerJobId = (logical, index, stage) => 'jcstage-' + hash(logical + '\0' + index + '\0' + stage).slice(0,40);
const own = (x,k) => object(x) && Object.prototype.hasOwnProperty.call(x,k) ? x[k] : undefined;
function createProductionAdapter({ store, environment, bridge, executionIdentity, runnerStatus } = {}) {
  if (!store || store.serialization !== 'EXCLUSIVE_LOCK_CAS_DURABLE_READBACK' ||
      !['withLock','read','anchor','compareAndSwap','checkpoint'].every(k => typeof store[k] === 'function')) refuse('UNQUALIFIED_STORE');
  if (!bridge || bridge.kind !== 'WINDOWS_LONG_JOB_BRIDGE_V1' ||
      !['validateProfileBinding','dispatch','findExisting'].every(k => typeof bridge[k] === 'function')) refuse('UNQUALIFIED_BRIDGE');
  if (!executionIdentity || executionIdentity.kind !== 'LNWJUD_EXECUTION_IDENTITY_READER_V1' || typeof executionIdentity.get !== 'function')
    refuse('UNQUALIFIED_EXECUTION_IDENTITY');
  if (!runnerStatus || runnerStatus.kind !== 'EXISTING_LONG_JOB_RUNNER_STATUS_V1' || typeof runnerStatus.get !== 'function')
    refuse('UNQUALIFIED_RUNNER_STATUS');
  if (typeof environment !== 'function') refuse('MALFORMED_ENVIRONMENT');
  const empty = () => ({ schema:'LNWJUD_JOB_CONTROL_RUNTIME_STORE_V1', revision:0, previous_sha256:null, requests:{}, jobs:{} });
  function snapshotEnvironment() {
    const e = environment();
    if (!object(e) || !object(e.binding) || !Buffer.isBuffer(e.contract_bytes)) refuse('MALFORMED_ENVIRONMENT');
    const copy = clone({ ...e, contract_bytes:null }); copy.contract_bytes = Buffer.from(e.contract_bytes);
    return copy;
  }
  function assertProfile(e,r) {
    const admitted = resolvedStage(e.binding,r.stage);
    bridge.validateProfileBinding({ profile_id:admitted.profile_id, profile_sha256:admitted.profile_sha256,
      stage:r.stage, source_head:e.binding.source.head });
    return admitted;
  }
  function load(e) {
    const raw = store.read(), anchor = store.anchor();
    if (raw !== null && !Buffer.isBuffer(raw)) refuse('MALFORMED_STATE');
    const actual = raw === null ? null : hash(raw);
    if (!object(anchor) || !Number.isSafeInteger(anchor.revision) || anchor.revision < 0 ||
        !(anchor.sha256 === null || digest(anchor.sha256)) || anchor.sha256 !== actual) refuse('STALE_RECEIPT');
    if (raw === null) {
      if (anchor.revision !== 0 || anchor.sha256 !== null) refuse('STALE_RECEIPT');
      return { data:empty(), bytes:null };
    }
    const data = parse(raw, 4 * 1024 * 1024);
    keys(data, ['schema','revision','previous_sha256','requests','jobs']);
    if (data.schema !== 'LNWJUD_JOB_CONTROL_RUNTIME_STORE_V1' || !Number.isSafeInteger(data.revision) || data.revision < 1 ||
        data.revision !== anchor.revision || (data.revision === 1 ? data.previous_sha256 !== null : !digest(data.previous_sha256)) ||
        !object(data.requests) || !object(data.jobs) || !Object.keys(data.requests).length || !Object.keys(data.jobs).length)
      refuse('MALFORMED_STATE');
    const receiptHashes = new Map(), decoded = new Map(), revisions = new Set();
    for (const [key, record] of Object.entries(data.requests)) {
      if (!R.mapKey(key)) refuse('MALFORMED_STATE');
      keys(record, ['bytes_base64','receipt','receipt_sha256']);
      if (typeof record.bytes_base64 !== 'string' || !digest(record.receipt_sha256) ||
          !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(record.bytes_base64)) refuse('MALFORMED_STATE');
      const requestBytes = Buffer.from(record.bytes_base64,'base64');
      if (requestBytes.toString('base64') !== record.bytes_base64) refuse('MALFORMED_STATE');
      const parsed = parse(requestBytes), r = validate(requestBytes,e,parsed.operation,{admission:false}), p = record.receipt;
      const stageBinding = assertProfile(e,r);
      keys(p, RECEIPT_KEYS); keys(p.budget_observation,['remaining_repair','remaining_retry']);
      for (const kind of ['repair','retry']) {
        const remaining = p.budget_observation['remaining_' + kind];
        if (!Number.isSafeInteger(remaining) || remaining < 0 || remaining > e.binding.budget[kind]) refuse('MALFORMED_STATE');
      }
      const created = time(p.created_utc), observed = time(p.observed_utc), now = time(e.now_utc);
      if (p.schema !== 'LNWJUD_JOB_CONTROL_RUNTIME_RECEIPT_V1' || p.request_id !== r.request_id || p.idempotency_key !== key ||
          p.request_sha256 !== hash(requestBytes) || p.request_bytes !== requestBytes.length ||
          p.request_location !== 'runtime-store://requests/' + key + '/bytes_base64' || !id(p.job_id) ||
          p.binding_sha256 !== bindingHash(e.binding) || p.operation !== r.operation || p.stage !== r.stage || p.stage_index !== r.stage_index ||
          p.profile_id !== stageBinding.profile_id || p.profile_sha256 !== stageBinding.profile_sha256 || p.created_utc !== r.created_utc ||
          created === null || observed === null || now === null || observed < created || observed > now ||
          !Number.isSafeInteger(p.prepared_revision) || p.prepared_revision < 1 || p.prepared_revision > data.revision ||
          revisions.has(p.prepared_revision) || p.parent_receipt_sha256 !== r.parent_receipt_sha256 ||
          (p.operation === 'request_pause_after_stage' ? !digest(p.checkpoint_sha256) : p.checkpoint_sha256 !== r.checkpoint_sha256) ||
          p.outcome !== 'PREPARED_RUNTIME_INTENT' ||
          record.receipt_sha256 !== hash(stable(p)) || receiptHashes.has(record.receipt_sha256)) refuse('MALFORMED_STATE');
      revisions.add(p.prepared_revision); receiptHashes.set(record.receipt_sha256,record); decoded.set(key,r);
    }
    for (const [key,record] of Object.entries(data.requests)) {
      const r=decoded.get(key), p=record.receipt;
      if (r.operation === 'submit_existing_contract_job') {
        if (p.job_id !== logicalJobId(r) || p.parent_receipt_sha256 !== null || p.checkpoint_sha256 !== null || r.target_job_id !== null)
          refuse('MALFORMED_STATE');
      } else {
        const parent = receiptHashes.get(p.parent_receipt_sha256);
        if (!parent || parent.receipt.job_id !== p.job_id || parent.receipt.binding_sha256 !== p.binding_sha256 ||
            parent.receipt.prepared_revision >= p.prepared_revision || r.target_job_id !== p.job_id ||
            time(parent.receipt.observed_utc) > time(p.observed_utc)) refuse('MALFORMED_STATE');
      }
    }
    for (const [jobId,j] of Object.entries(data.jobs)) {
      keys(j, ['job_id','binding_sha256','submission_key','latest_key','phase','stage','index','runner_job_id',
        'launch_receipt_sha256','pause_key','checkpoint_sha256']);
      if (jobId !== j.job_id || !id(jobId) || !PHASES.includes(j.phase) || !digest(j.binding_sha256) ||
          j.binding_sha256 !== bindingHash(e.binding) || !Number.isSafeInteger(j.index) || j.index < 0 || e.binding.stages[j.index] !== j.stage ||
          !own(data.requests,j.submission_key) || !own(data.requests,j.latest_key)) refuse('MALFORMED_STATE');
      const origin = data.requests[j.submission_key], latest = data.requests[j.latest_key];
      const forJob = Object.entries(data.requests).filter(([,x]) => x.receipt.job_id === jobId);
      const max = forJob.reduce((a,b) => a[1].receipt.prepared_revision > b[1].receipt.prepared_revision ? a : b);
      if (max[0] !== j.latest_key || origin.receipt.operation !== 'submit_existing_contract_job' || origin.receipt.job_id !== jobId ||
          latest.receipt.job_id !== jobId || latest.receipt.stage !== j.stage || latest.receipt.stage_index !== j.index ||
          j.checkpoint_sha256 !== latest.receipt.checkpoint_sha256 || !(j.runner_job_id === null || id(j.runner_job_id)) ||
          !(j.launch_receipt_sha256 === null || digest(j.launch_receipt_sha256)) || !(j.pause_key === null || R.mapKey(j.pause_key)))
        refuse('MALFORMED_STATE');
      if (j.runner_job_id !== null && j.runner_job_id !== runnerJobId(jobId,j.index,j.stage)) refuse('MALFORMED_STATE');
      if (['DISPATCH_INTENT','RESUME_INTENT','LAUNCH_UNPROVEN','BOUND','PAUSE_REQUESTED'].includes(j.phase) && j.runner_job_id === null) refuse('MALFORMED_STATE');
      if (['BOUND','PAUSE_REQUESTED'].includes(j.phase) && !digest(j.launch_receipt_sha256)) refuse('MALFORMED_STATE');
      if (['DISPATCH_INTENT','RESUME_INTENT','LAUNCH_UNPROVEN'].includes(j.phase) && j.launch_receipt_sha256 !== null) refuse('MALFORMED_STATE');
      if (j.phase === 'PAUSE_REQUESTED') {
        const pause = own(data.requests,j.pause_key);
        if (!pause || pause.receipt.job_id !== jobId || pause.receipt.operation !== 'request_pause_after_stage') refuse('MALFORMED_STATE');
      } else if (j.pause_key !== null) refuse('MALFORMED_STATE');
    }
    return { data:clone(data), bytes:Buffer.from(raw) };
  }
  function save(frame,label) {
    const prior = frame.bytes === null ? null : hash(frame.bytes);
    frame.data.revision += 1; frame.data.previous_sha256 = prior;
    const next = Buffer.from(stable(frame.data));
    store.checkpoint('before_' + label);
    if (store.compareAndSwap(prior,next) !== true) refuse('COMPETING_REVISION');
    store.checkpoint('after_' + label);
    const readback = store.read(), anchor = store.anchor();
    if (!Buffer.isBuffer(readback) || !readback.equals(next) || anchor.revision !== frame.data.revision || anchor.sha256 !== hash(next))
      refuse('RECEIPT_READBACK_MISMATCH');
    frame.bytes = next; store.checkpoint('readback_' + label);
  }
  function observation(j,e) {
    if (!j.runner_job_id) return { execution_state:'UNKNOWN', runner_state:'UNKNOWN', checkpoint_sha256:null, stage_complete:false, reason:'NOT_DISPATCHED' };
    let identity = null, runner = null;
    try { identity = executionIdentity.get(j.runner_job_id); } catch { identity = null; }
    try { runner = runnerStatus.get(j.runner_job_id); } catch { runner = null; }
    const floor = time(e.observed_utc), now = time(e.now_utc);
    let executionState = 'UNKNOWN', reason = 'EXECUTION_IDENTITY_UNAVAILABLE';
    if (object(identity) && identity.job_id === j.runner_job_id &&
        ['PROVEN_RUNNING','PROVEN_TERMINAL','QUEUED','WAITING_RESOURCE','BLOCKED','UNKNOWN','IDENTITY_MISMATCH'].includes(identity.state)) {
      const observed = time(identity.observed_utc);
      if (observed !== null && floor !== null && now !== null && observed >= floor && observed <= now) {
        executionState = identity.state; reason = 'EXECUTION_IDENTITY_CURRENT';
      } else reason = 'EXECUTION_IDENTITY_STALE_OR_FUTURE';
    }
    let runnerState = 'UNKNOWN', checkpoint = null, stageComplete = false;
    if (object(runner) && runner.job_id === j.runner_job_id && typeof runner.state === 'string') {
      runnerState = runner.state; checkpoint = digest(runner.checkpoint_sha256) ? runner.checkpoint_sha256 : null;
      stageComplete = executionState === 'PROVEN_TERMINAL' && runnerState === 'COMPLETE' && checkpoint !== null;
    }
    return { execution_state:executionState, runner_state:runnerState, checkpoint_sha256:checkpoint, stage_complete:stageComplete, reason };
  }
  function current(j,e) {
    const o = observation(j,e); let protocol = j.phase;
    if (['DISPATCH_INTENT','RESUME_INTENT','LAUNCH_UNPROVEN'].includes(j.phase)) protocol = 'RECONCILE_REQUIRED';
    if (j.phase === 'PAUSE_REQUESTED' && o.stage_complete) protocol = 'PAUSED_AFTER_STAGE';
    else if (j.phase === 'BOUND' && o.stage_complete) protocol = 'STAGE_COMPLETE_AWAITING_DECISION';
    return freeze({ protocol_state:protocol, execution_state:o.execution_state, durable_runner_state:o.runner_state,
      reason:o.reason, job_id:j.job_id, runner_job_id:j.runner_job_id, stage:j.stage, index:j.index,
      checkpoint_sha256:o.checkpoint_sha256, stage_complete:o.stage_complete, progress:'UNKNOWN' });
  }
  function makePlan(j,record,e) {
    const stageBinding = resolvedStage(e.binding,j.stage);
    return freeze({ job_id:j.runner_job_id, logical_job_id:j.job_id, stage:j.stage, index:j.index,
      profile_id:stageBinding.profile_id, profile_sha256:stageBinding.profile_sha256, source_head:e.binding.source.head,
      binding_sha256:j.binding_sha256, request_sha256:record.receipt.request_sha256 });
  }
  function bindLaunch(j,frame,receipt,label) {
    if (!object(receipt) || receipt.job_id !== j.runner_job_id || !digest(receipt.launch_receipt_sha256)) refuse('LAUNCH_RECEIPT_INVALID');
    j.launch_receipt_sha256 = receipt.launch_receipt_sha256; j.phase = 'BOUND';
    save(frame,label); return true;
  }
  function reconcileIntent(j,frame,e) {
    if (!['DISPATCH_INTENT','RESUME_INTENT','LAUNCH_UNPROVEN'].includes(j.phase)) return false;
    const record = own(frame.data.requests,j.latest_key), existing = bridge.findExisting(makePlan(j,record,e));
    if (!existing) return false;
    return bindLaunch(j,frame,existing,'reconcile_existing');
  }
  function retryUnstartedIntent(j,frame,e) {
    const record = own(frame.data.requests,j.latest_key), plan = makePlan(j,record,e);
    const existing = bridge.findExisting(plan);
    if (existing) return bindLaunch(j,frame,existing,'reconcile_existing');
    try { return bindLaunch(j,frame,bridge.dispatch(plan),'dispatch_ack'); }
    catch (error) {
      if (error && ['ACTUATION_OUTCOME_UNPROVEN','LAUNCH_RECEIPT_READBACK_MISMATCH'].includes(error.code)) {
        j.phase = 'LAUNCH_UNPROVEN'; save(frame,'launch_unproven');
      }
      throw error;
    }
  }
  function dispatchStage(j,frame,e) {
    j.runner_job_id = runnerJobId(j.job_id,j.index,j.stage);
    j.launch_receipt_sha256 = null;
    j.phase = j.index === 0 ? 'DISPATCH_INTENT' : 'RESUME_INTENT';
    save(frame,'dispatch_intent');
    return retryUnstartedIntent(j,frame,e);
  }
  function result(record,j,e) { return freeze({ receipt:clone(record.receipt), receipt_sha256:record.receipt_sha256, current:current(j,e) }); }
  function run(operation,input) {
    if (!Buffer.isBuffer(input)) refuse('INVALID_REQUEST_BYTES');
    const requestBytes = Buffer.from(input);
    return store.withLock(() => {
      const e = snapshotEnvironment();
      const staticRequest = validate(requestBytes,e,operation,{admission:false});
      assertProfile(e,staticRequest);
      const frame = load(e);
      const existing = own(frame.data.requests,staticRequest.idempotency_key);
      if (existing) {
        if (!Buffer.from(existing.bytes_base64,'base64').equals(requestBytes)) refuse('IDEMPOTENCY_DRIFT');
        const j = own(frame.data.jobs,existing.receipt.job_id); if (!j) refuse('MALFORMED_STATE');
        if (j.phase === 'PREPARED') {
          validate(requestBytes,e,operation,{admission:true});
          dispatchStage(j,frame,e);
        } else if (['DISPATCH_INTENT','RESUME_INTENT'].includes(j.phase)) {
          if (!reconcileIntent(j,frame,e)) retryUnstartedIntent(j,frame,e);
        } else if (j.phase === 'LAUNCH_UNPROVEN') {
          reconcileIntent(j,frame,e);
        }
        return result(existing,j,e);
      }
      const r = validate(requestBytes,e,operation,{admission:true});
      assertProfile(e,r);
      if (Object.values(frame.data.requests).some(x => x.receipt.request_id === r.request_id)) refuse('REQUEST_ID_REUSE');
      let j, before = null;
      if (operation === 'submit_existing_contract_job') {
        if (Object.values(frame.data.requests).some(x => x.receipt.operation === 'submit_existing_contract_job')) refuse('DUPLICATE_EXECUTION');
        j = { job_id:logicalJobId(r), binding_sha256:bindingHash(e.binding), submission_key:r.idempotency_key,
          latest_key:r.idempotency_key, phase:'PREPARED', stage:r.stage, index:r.stage_index, runner_job_id:null,
          launch_receipt_sha256:null, pause_key:null, checkpoint_sha256:null };
      } else {
        j = own(frame.data.jobs,r.target_job_id);
        if (!j || j.binding_sha256 !== bindingHash(e.binding)) refuse('UNKNOWN_JOB');
        const parent = own(frame.data.requests,j.latest_key);
        if (!parent || parent.receipt_sha256 !== r.parent_receipt_sha256) refuse('STALE_RECEIPT');
        before = current(j,e);
        if (operation !== 'request_pause_after_stage' && r.checkpoint_sha256 !== before.checkpoint_sha256) refuse('CHECKPOINT_MISMATCH');
        if (operation === 'resume_existing_job') {
          if (before.protocol_state !== 'PAUSED_AFTER_STAGE' || r.stage_index !== j.index + 1 || e.binding.stages[r.stage_index] !== r.stage)
            refuse('RESUME_REFUSED');
        } else {
          if (r.stage_index !== j.index || r.stage !== j.stage) refuse('CHECKPOINT_MISMATCH');
          if (operation === 'adopt_existing_job' && !['PROVEN_RUNNING','PROVEN_TERMINAL'].includes(before.execution_state)) refuse('ADOPTION_UNPROVEN');
          if (operation === 'request_pause_after_stage' && (j.phase !== 'BOUND' || !digest(before.checkpoint_sha256))) refuse('PAUSE_REFUSED');
        }
      }
      const stageBinding = resolvedStage(e.binding,r.stage);
      const priorBudget = operation === 'submit_existing_contract_job' ? null : own(frame.data.requests,j.latest_key)?.receipt?.budget_observation;
      const budgetObservation = {
        remaining_repair: priorBudget ? Math.min(e.remaining_repair,priorBudget.remaining_repair) : e.remaining_repair,
        remaining_retry: priorBudget ? Math.min(e.remaining_retry,priorBudget.remaining_retry) : e.remaining_retry };
      const receiptCheckpoint = operation === 'request_pause_after_stage' ? before.checkpoint_sha256 : r.checkpoint_sha256;
      const receipt = { schema:'LNWJUD_JOB_CONTROL_RUNTIME_RECEIPT_V1', request_id:r.request_id,
        idempotency_key:r.idempotency_key, request_sha256:hash(requestBytes), request_bytes:requestBytes.length,
        request_location:'runtime-store://requests/' + r.idempotency_key + '/bytes_base64', job_id:j.job_id,
        binding_sha256:bindingHash(e.binding), operation, stage:r.stage, stage_index:r.stage_index,
        profile_id:stageBinding.profile_id, profile_sha256:stageBinding.profile_sha256,
        created_utc:r.created_utc, observed_utc:e.observed_utc, prepared_revision:frame.data.revision + 1,
        parent_receipt_sha256:r.parent_receipt_sha256, checkpoint_sha256:receiptCheckpoint,
        budget_observation:budgetObservation, outcome:'PREPARED_RUNTIME_INTENT' };
      const record = { bytes_base64:requestBytes.toString('base64'), receipt, receipt_sha256:hash(stable(receipt)) };
      frame.data.requests[r.idempotency_key] = record;
      if (operation !== 'submit_existing_contract_job') {
        j.latest_key = r.idempotency_key; j.checkpoint_sha256 = receiptCheckpoint;
      }
      frame.data.jobs[j.job_id] = j;
      if (operation === 'request_pause_after_stage') { j.phase = 'PAUSE_REQUESTED'; j.pause_key = r.idempotency_key; }
      if (operation === 'resume_existing_job') {
        j.stage = r.stage; j.index = r.stage_index; j.runner_job_id = null; j.launch_receipt_sha256 = null;
        j.pause_key = null; j.phase = 'PREPARED';
      }
      save(frame,'prepared');
      if (operation === 'submit_existing_contract_job' || operation === 'resume_existing_job') dispatchStage(j,frame,e);
      return result(record,j,e);
    });
  }
  const api = Object.fromEntries(R.OPS.map(op => [op, bytes => run(op,bytes)]));
  api.get_job_current = key => store.withLock(() => {
    if (!R.mapKey(key)) refuse('INVALID_MAP_KEY');
    const e = snapshotEnvironment(), frame = load(e), record = own(frame.data.requests,key);
    if (!record) refuse('UNKNOWN_RECEIPT');
    const j = own(frame.data.jobs,record.receipt.job_id); if (!j) refuse('MALFORMED_STATE');
    return result(record,j,e);
  });
  return Object.freeze(api);
}
module.exports = { createProductionAdapter, logicalJobId, runnerJobId };