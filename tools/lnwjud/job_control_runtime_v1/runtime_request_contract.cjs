'use strict';
// Source/offline contract for the production Job Control adapter. The client supplies
// identity and intent only: never executable paths, command text, argument lists, PIDs,
// filesystem targets, provider commands, Registry actions, or runtime resource names.
const C = require('../job_control_v1/request_contract.cjs');
const { Refusal, refuse, hash, stable, clone, freeze, object, id, mapKey, digest, time, parse, keys, relative } = C;
const OPS = [...C.OPS];
const REQUEST_KEYS = ['schema','request_id','idempotency_key','operation','lane_id','contract_id',
  'contract_sha256','source','stage','stage_index','checkpoint_sha256','parent_receipt_sha256',
  'target_job_id','created_utc'];
const BINDING_KEYS = ['lane_id','contract_id','contract_sha256','source','allowlisted_paths','worktree_identity_sha256',
  'resource_owner','runtime_resource','acceptance_criteria','budget','direct_consumer','host_id','stages','profile_by_stage'];
function validateBinding(binding) {
  keys(binding, BINDING_KEYS);
  if (![binding.lane_id,binding.contract_id,binding.resource_owner,binding.runtime_resource,
      binding.direct_consumer,binding.host_id].every(id) || !digest(binding.contract_sha256) ||
      !digest(binding.worktree_identity_sha256)) refuse('MALFORMED_BINDING');
  keys(binding.source, ['head','tree','config_sha256']);
  if (!/^[a-f0-9]{40}$/.test(binding.source.head) || !/^[a-f0-9]{40}$/.test(binding.source.tree) ||
      !digest(binding.source.config_sha256)) refuse('MALFORMED_BINDING');
  if (!Array.isArray(binding.allowlisted_paths) || binding.allowlisted_paths.length < 1 ||
      !binding.allowlisted_paths.every(relative) ||
      new Set(binding.allowlisted_paths.map(x => x.toLowerCase())).size !== binding.allowlisted_paths.length)
    refuse('MALFORMED_BINDING');
  if (!Array.isArray(binding.acceptance_criteria) || binding.acceptance_criteria.length < 1 ||
      !binding.acceptance_criteria.every(id) || new Set(binding.acceptance_criteria).size !== binding.acceptance_criteria.length)
    refuse('MALFORMED_BINDING');
  keys(binding.budget, ['repair','retry']);
  for (const kind of ['repair','retry']) if (!Number.isSafeInteger(binding.budget[kind]) || binding.budget[kind] < 0)
    refuse('MALFORMED_BINDING');
  if (!Array.isArray(binding.stages) || binding.stages.length < 1 || !binding.stages.every(id) ||
      new Set(binding.stages).size !== binding.stages.length || !object(binding.profile_by_stage)) refuse('MALFORMED_BINDING');
  keys(binding.profile_by_stage, binding.stages);
  for (const stage of binding.stages) {
    const p = binding.profile_by_stage[stage];
    keys(p, ['profile_id','profile_sha256']);
    if (!id(p.profile_id) || !digest(p.profile_sha256)) refuse('MALFORMED_BINDING');
  }
  return freeze(clone(binding));
}
function bindingHash(binding) { return hash(stable(validateBinding(binding))); }
function validate(bytes, env, operation, { admission = true } = {}) {
  const r = parse(bytes);
  keys(r, REQUEST_KEYS);
  if (r.schema !== 'LNWJUD_JOB_CONTROL_RUNTIME_REQUEST_V1' || !OPS.includes(r.operation) || r.operation !== operation)
    refuse('UNSUPPORTED_OPERATION');
  if (![r.request_id,r.idempotency_key,r.lane_id,r.contract_id,r.stage].every(id) || !mapKey(r.idempotency_key))
    refuse('INVALID_ID');
  if (!object(env) || !object(env.binding)) refuse('MALFORMED_ENVIRONMENT');
  const binding = validateBinding(env.binding);
  const now = time(env.now_utc), observed = time(env.observed_utc), created = time(r.created_utc);
  if (now === null || observed === null || created === null || created > now || observed > now || observed < created)
    refuse('INVALID_OR_FUTURE_TIME');
  if (env.lane_current !== true || r.lane_id !== binding.lane_id) refuse('UNKNOWN_LANE');
  if (r.contract_id !== binding.contract_id) refuse('CONTRACT_MISMATCH');
  if (!Buffer.isBuffer(env.contract_bytes) || !digest(r.contract_sha256) ||
      hash(env.contract_bytes) !== r.contract_sha256 || r.contract_sha256 !== binding.contract_sha256)
    refuse('CONTRACT_MISMATCH');
  keys(r.source, ['head','tree','config_sha256']);
  if (stable(r.source) !== stable(binding.source)) refuse('WRONG_SOURCE');
  if (env.worktree_identity_sha256 !== binding.worktree_identity_sha256) refuse('PATH_IDENTITY_UNPROVEN');
  if (env.resource_owner !== binding.resource_owner || env.runtime_resource !== binding.runtime_resource) refuse('LEASED_RESOURCE');
  for (const kind of ['repair','retry']) {
    const remaining = env['remaining_' + kind];
    if (!Number.isSafeInteger(remaining) || remaining < 0 || remaining > binding.budget[kind]) refuse('BUDGET_LEDGER_UNPROVEN');
  }
  if (admission) {
    if (env.clean !== true) refuse('DIRTY_WORKTREE');
    if (env.path_identity_verified !== true) refuse('PATH_IDENTITY_UNPROVEN');
    if (env.resource_available !== true) refuse('LEASED_RESOURCE');
    if (env.budget_available !== true) refuse('BUDGET_EXHAUSTED');
  }
  if (!Number.isSafeInteger(r.stage_index) || r.stage_index < 0 || binding.stages[r.stage_index] !== r.stage)
    refuse('INVALID_STAGE');
  const stageBinding = binding.profile_by_stage[r.stage];
  if (!stageBinding) refuse('UNKNOWN_LAUNCH_PROFILE');
  if (r.operation === 'submit_existing_contract_job') {
    if (r.stage_index !== 0 || r.checkpoint_sha256 !== null || r.parent_receipt_sha256 !== null || r.target_job_id !== null)
      refuse('INVALID_CHECKPOINT');
  } else {
    if (!digest(r.checkpoint_sha256) || !digest(r.parent_receipt_sha256) || !id(r.target_job_id))
      refuse('INVALID_CHECKPOINT');
  }
  return freeze(clone(r));
}
function resolvedStage(binding, stage) {
  const b = validateBinding(binding);
  if (!Object.prototype.hasOwnProperty.call(b.profile_by_stage, stage)) refuse('UNKNOWN_LAUNCH_PROFILE');
  return freeze(clone({ stage, ...b.profile_by_stage[stage] }));
}
module.exports = { Refusal, refuse, hash, stable, clone, freeze, object, id, mapKey, digest, time, parse, keys, relative,
  OPS, REQUEST_KEYS, BINDING_KEYS, validateBinding, bindingHash, validate, resolvedStage };